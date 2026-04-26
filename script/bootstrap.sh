#!/bin/bash
set -e

PROJECT_ID=<<Your BootStrap Project ID>>
REGION="us-central1"
ENV="demo"
TF_SA_NAME="${ENV}-terraform"
DEPLOYER_SA_NAME="${ENV}-deployer"

# Use project number to guarantee uniqueness
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
BUCKET_NAME="${PROJECT_ID}-tfstate-${ENV}-${PROJECT_NUMBER}"

echo "🚀 Starting bootstrap for project: $PROJECT_ID"

# Enable APIs
gcloud services enable iam.googleapis.com cloudresourcemanager.googleapis.com \
    iamcredentials.googleapis.com sts.googleapis.com storage.googleapis.com \
    run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com \
    --project="$PROJECT_ID"

# Create bucket if not exists
echo "🪣 Checking GCS bucket..."
if gsutil ls -p "$PROJECT_ID" "gs://$BUCKET_NAME" >/dev/null 2>&1; then
    echo "✅ Bucket already exists: gs://$BUCKET_NAME"
else
    echo "🪣 Creating bucket: gs://$BUCKET_NAME"
    gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://$BUCKET_NAME"
    gsutil versioning set on "gs://$BUCKET_NAME"
fi

# Create Terraform SA
TF_SA_EMAIL="${TF_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
if gcloud iam service-accounts describe "$TF_SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "✅ Terraform SA exists: $TF_SA_EMAIL"
else
    gcloud iam service-accounts create "$TF_SA_NAME" \
        --display-name="Terraform SA — IaC automation" \
        --project="$PROJECT_ID"
fi

# Create Deployer SA
DEPLOYER_SA_EMAIL="${DEPLOYER_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
if gcloud iam service-accounts describe "$DEPLOYER_SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "✅ Deployer SA exists: $DEPLOYER_SA_EMAIL"
else
    gcloud iam service-accounts create "$DEPLOYER_SA_NAME" \
        --display-name="Deployer SA — CI/CD pipeline" \
        --project="$PROJECT_ID"
fi

echo "✅ Bootstrap complete!"
echo "--------------------------------------------------"
echo "Terraform State Bucket: gs://$BUCKET_NAME"
echo "Terraform Service Account: $TF_SA_EMAIL"
echo "Workload Identity Provider:"
echo "  projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/${ENV}-github-pool/providers/github-oidc"
echo "--------------------------------------------------"
