#!/bin/bash
set -e

# --- UPDATE THESE VALUES ---
PROJECT_ID= <<Bootstrap project ID>>
REGION="us-central1"
ENV="dev"
TF_SA_NAME="${ENV}-terraform"
GITHUB_ORG="shobhitsystems"
GITHUB_REPO="gcp-startup-stack"
# ---------------------------

# Use project number to guarantee uniqueness
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
BUCKET_NAME="${PROJECT_ID}-tfstate-${ENV}-${PROJECT_NUMBER}"

echo "🚀 Starting bootstrap for project: $PROJECT_ID"

# 1. Enable required APIs
echo "🔧 Enabling APIs..."
gcloud services enable iam.googleapis.com cloudresourcemanager.googleapis.com \
    iamcredentials.googleapis.com sts.googleapis.com storage.googleapis.com \
    run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com \
    --project="$PROJECT_ID"

# 2. Create Terraform State Bucket (skip if exists)
echo "🪣 Checking GCS bucket..."
if gsutil ls -p "$PROJECT_ID" "gs://$BUCKET_NAME" >/dev/null 2>&1; then
    echo "✅ Bucket already exists: gs://$BUCKET_NAME"
else
    echo "🪣 Creating bucket: gs://$BUCKET_NAME"
    gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://$BUCKET_NAME"
    gsutil versioning set on "gs://$BUCKET_NAME"
fi

# 3. Create Terraform Service Account
TF_SA_EMAIL="${TF_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
if gcloud iam service-accounts describe "$TF_SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "✅ Terraform SA exists: $TF_SA_EMAIL"
else
    gcloud iam service-accounts create "$TF_SA_NAME" \
        --display-name="Terraform SA — IaC automation" \
        --project="$PROJECT_ID"
    echo "👤 Created Terraform SA: $TF_SA_EMAIL"
fi

# 4. Workload Identity Federation setup
echo "🔐 Setting up Workload Identity Federation..."
if gcloud iam workload-identity-pools describe "${ENV}-github-pool" \
    --project="$PROJECT_ID" --location="global" >/dev/null 2>&1; then
    echo "✅ WIF pool already exists."
else
    gcloud iam workload-identity-pools create "${ENV}-github-pool" \
        --project="$PROJECT_ID" \
        --location="global" \
        --display-name="GitHub Actions — ${ENV}"
fi

if gcloud iam workload-identity-pools providers describe "github-oidc" \
    --project="$PROJECT_ID" --location="global" \
    --workload-identity-pool="${ENV}-github-pool" >/dev/null 2>&1; then
    echo "✅ WIF provider already exists."
else
    gcloud iam workload-identity-pools providers create-oidc "github-oidc" \
        --project="$PROJECT_ID" \
        --location="global" \
        --workload-identity-pool="${ENV}-github-pool" \
        --display-name="GitHub OIDC" \
        --issuer-uri="https://token.actions.githubusercontent.com" \
        --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner,attribute.ref=assertion.ref" \
        --attribute-condition="attribute.repository_owner=='${GITHUB_ORG}'"
fi

# 5. Bind Terraform SA to WIF provider
echo "🔑 Binding Terraform SA to WIF provider..."
gcloud iam service-accounts add-iam-policy-binding "$TF_SA_EMAIL" \
    --project="$PROJECT_ID" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${ENV}-github-pool/attribute.repository/${GITHUB_ORG}/${GITHUB_REPO}" \
    --condition=None || true

echo "✅ Bootstrap complete!"
echo "--------------------------------------------------"
echo "Terraform State Bucket: gs://$BUCKET_NAME"
echo "Terraform Service Account: $TF_SA_EMAIL"
echo "Workload Identity Provider (for GitHub Actions):"
echo "  projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/${ENV}-github-pool/providers/github-oidc"
echo "--------------------------------------------------"
