#!/bin/bash
set -e

# =============================================================================
# GCP Bootstrap Script
# -----------------------------------------------------------------------------
# This script sets up everything needed for Terraform to manage your GCP
# project via GitHub Actions using Workload Identity Federation (no keys!).
#
# What it does:
#   1. Enables all required GCP APIs
#   2. Creates a GCS bucket to store Terraform remote state
#   3. Creates a dedicated Terraform service account
#   4. Sets up Workload Identity Federation for keyless GitHub Actions auth
#   5. Binds the Terraform SA to the WIF provider (scoped to your repo)
#   6. Grants the Terraform SA all necessary project-level IAM roles
#
# Prerequisites:
#   - gcloud CLI installed and authenticated
#   - You must have Owner or Editor + IAM Admin on the target project
#
# Usage:
#   chmod +x bootstrap.sh && ./bootstrap.sh
# =============================================================================

# --- UPDATE THESE VALUES BEFORE RUNNING ---
PROJECT_ID="Your project id here"   # GCP project ID (not project number)
REGION="us-central1"                # Region for the Terraform state bucket
ENV="dev"                           # Environment prefix: dev | staging | prod
TF_SA_NAME="${ENV}-terraform"       # Name of the Terraform service account
GITHUB_ORG="shobhitsystems"         # Your GitHub org or username
GITHUB_REPO="gcp-startup-stack"     # Your GitHub repository name
# ------------------------------------------

# Derive values automatically — no need to change these
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
BUCKET_NAME="${PROJECT_ID}-tfstate-${ENV}-${PROJECT_NUMBER}"
TF_SA_EMAIL="${TF_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo ""
echo "=============================================="
echo "  GCP Bootstrap — Project: $PROJECT_ID"
echo "  Environment  : $ENV"
echo "  Region       : $REGION"
echo "=============================================="
echo ""

# =============================================================================
# STEP 1 — Enable Required GCP APIs
# -----------------------------------------------------------------------------
# These APIs must be active before any resources (buckets, SAs, WIF pools,
# Cloud Run services, etc.) can be created by Terraform or this script.
# =============================================================================
echo "📡 [1/6] Enabling required GCP APIs..."
echo "        (This may take a minute on a fresh project)"
gcloud services enable \
    iam.googleapis.com \
    cloudresourcemanager.googleapis.com \
    iamcredentials.googleapis.com \
    sts.googleapis.com \
    storage.googleapis.com \
    run.googleapis.com \
    artifactregistry.googleapis.com \
    cloudbuild.googleapis.com \
    --project="$PROJECT_ID"
echo "✅ APIs enabled."
echo ""

# =============================================================================
# STEP 2 — Create Terraform Remote State Bucket
# -----------------------------------------------------------------------------
# Terraform stores its state file in this GCS bucket so that all team members
# and CI/CD pipelines share the same state. Versioning is enabled so you can
# roll back to a previous state if something goes wrong.
#
# Bucket name format: <project-id>-tfstate-<env>-<project-number>
# The project number suffix guarantees global uniqueness.
# =============================================================================
echo "🪣 [2/6] Checking Terraform state bucket..."
if gsutil ls -p "$PROJECT_ID" "gs://$BUCKET_NAME" >/dev/null 2>&1; then
    echo "✅ Bucket already exists — skipping creation: gs://$BUCKET_NAME"
else
    echo "   Creating bucket: gs://$BUCKET_NAME"
    gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://$BUCKET_NAME"
    gsutil versioning set on "gs://$BUCKET_NAME"
    echo "✅ Bucket created with versioning enabled."
fi
echo ""

# =============================================================================
# STEP 3 — Create Terraform Service Account
# -----------------------------------------------------------------------------
# A dedicated service account is used by Terraform (both locally and via
# GitHub Actions) to manage GCP resources. Using a dedicated SA — rather than
# a personal account — follows the principle of least privilege and makes
# permission auditing much easier.
# =============================================================================
echo "👤 [3/6] Checking Terraform service account..."
if gcloud iam service-accounts describe "$TF_SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "✅ Service account already exists — skipping creation: $TF_SA_EMAIL"
else
    gcloud iam service-accounts create "$TF_SA_NAME" \
        --display-name="Terraform SA — IaC automation" \
        --project="$PROJECT_ID"
    echo "✅ Service account created: $TF_SA_EMAIL"
fi
echo ""

# =============================================================================
# STEP 4 — Configure Workload Identity Federation (WIF)
# -----------------------------------------------------------------------------
# WIF allows GitHub Actions to authenticate as the Terraform SA without
# storing a long-lived JSON key anywhere. Instead, GitHub exchanges a
# short-lived OIDC token for a GCP access token at runtime.
#
# This step creates:
#   • A WIF Pool  — a container for external identity providers
#   • A WIF Provider — maps GitHub OIDC token claims to GCP attributes
#
# The attribute condition restricts access to your GitHub org only,
# preventing other GitHub users from impersonating this SA.
# =============================================================================
echo "🔐 [4/6] Configuring Workload Identity Federation..."

# Create the WIF pool (skip if it already exists)
if gcloud iam workload-identity-pools describe "${ENV}-github-pool" \
    --project="$PROJECT_ID" --location="global" >/dev/null 2>&1; then
    echo "   WIF pool already exists — skipping: ${ENV}-github-pool"
else
    echo "   Creating WIF pool: ${ENV}-github-pool"
    gcloud iam workload-identity-pools create "${ENV}-github-pool" \
        --project="$PROJECT_ID" \
        --location="global" \
        --display-name="GitHub Actions — ${ENV}"
    echo "   ✅ WIF pool created."
fi

# Create the OIDC provider inside the pool (skip if it already exists)
if gcloud iam workload-identity-pools providers describe "github-oidc" \
    --project="$PROJECT_ID" --location="global" \
    --workload-identity-pool="${ENV}-github-pool" >/dev/null 2>&1; then
    echo "   WIF provider already exists — skipping: github-oidc"
else
    echo "   Creating WIF OIDC provider: github-oidc"
    gcloud iam workload-identity-pools providers create-oidc "github-oidc" \
        --project="$PROJECT_ID" \
        --location="global" \
        --workload-identity-pool="${ENV}-github-pool" \
        --display-name="GitHub OIDC" \
        --issuer-uri="https://token.actions.githubusercontent.com" \
        --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner,attribute.ref=assertion.ref" \
        --attribute-condition="attribute.repository_owner=='${GITHUB_ORG}'"
    echo "   ✅ WIF provider created."
fi
echo "✅ Workload Identity Federation configured."
echo ""

# =============================================================================
# STEP 5 — Bind Terraform SA to the WIF Provider
# -----------------------------------------------------------------------------
# This binding allows GitHub Actions workflows running inside the specified
# repository to impersonate the Terraform SA. The principalSet is scoped to
# the exact repo (GITHUB_ORG/GITHUB_REPO) for maximum security — no other
# repo in your org can assume this identity.
# =============================================================================
echo "🔗 [5/6] Binding Terraform SA to WIF provider..."
echo "   Scoped to repo: ${GITHUB_ORG}/${GITHUB_REPO}"
gcloud iam service-accounts add-iam-policy-binding "$TF_SA_EMAIL" \
    --project="$PROJECT_ID" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${ENV}-github-pool/attribute.repository/${GITHUB_ORG}/${GITHUB_REPO}" \
    --condition=None || true
echo "✅ SA binding complete."
echo ""

# =============================================================================
# STEP 6 — Grant Project-Level IAM Roles to Terraform SA
# -----------------------------------------------------------------------------
# These roles give Terraform the permissions it needs to create and manage
# all resources in your project. Each role is scoped to this project only.
#
# Role breakdown:
#   artifactregistry.admin        — Push/pull Docker images & manage repos
#   run.admin                     — Deploy and manage Cloud Run services
#   compute.networkAdmin          — Create/manage VPCs, subnets, firewall rules
#   cloudsql.admin                — Create and configure Cloud SQL instances
#   resourcemanager.projectIamAdmin — Manage IAM policies on this project
#   secretmanager.admin           — Create and manage secrets
#   vpcaccess.admin               — Manage Serverless VPC Access connectors
#   storage.admin                 — Create/manage GCS buckets and objects
#   iam.serviceAccountAdmin       — Create and manage service accounts
# =============================================================================
echo "🔑 [6/6] Granting project-level IAM roles to Terraform SA..."

declare -a PROJECT_ROLES=(
    "roles/artifactregistry.admin"          # Docker image registry management
    "roles/run.admin"                       # Cloud Run service deployment
    "roles/compute.networkAdmin"            # VPC, subnets, firewall rules
    "roles/cloudsql.admin"                  # Cloud SQL instance management
    "roles/resourcemanager.projectIamAdmin" # Project IAM policy management
    "roles/secretmanager.admin"             # Secret creation and access control
    "roles/vpcaccess.admin"                 # Serverless VPC Access connectors
    "roles/storage.admin"                   # GCS bucket and object management
    "roles/iam.serviceAccountAdmin"         # Service account management
)

for ROLE in "${PROJECT_ROLES[@]}"; do
    # Extract a clean role name for the log message (strip the "roles/" prefix)
    ROLE_SHORT="${ROLE#roles/}"
    echo "   ➕ Binding: $ROLE_SHORT"
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$TF_SA_EMAIL" \
        --role="$ROLE" \
        --quiet
done

echo "✅ All IAM roles granted."
echo ""

# =============================================================================
# Bootstrap Complete — Summary
# =============================================================================
echo "=============================================="
echo "  ✅ Bootstrap Complete!"
echo "=============================================="
echo ""
echo "  State Bucket   : gs://$BUCKET_NAME"
echo "  Terraform SA   : $TF_SA_EMAIL"
echo ""
echo "  Workload Identity Provider"
echo "  (paste this into your GitHub Actions workflow):"
echo ""
echo "  projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/${ENV}-github-pool/providers/github-oidc"
echo ""
echo "  GitHub Actions workflow snippet:"
echo "  ----------------------------------------"
echo "  - uses: google-github-actions/auth@v2"
echo "    with:"
echo "      workload_identity_provider: 'projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/${ENV}-github-pool/providers/github-oidc'"
echo "      service_account: '$TF_SA_EMAIL'"
echo "=============================================="
echo ""
