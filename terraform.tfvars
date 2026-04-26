# Copy to terraform.tfvars and fill in your values

project_id         = '${{ secrets.GCP_PROJECT_ID }}
region             = "us-cental1"
env                = "dev"
github_org         = "shobhitsystems"
github_repo        = "gcp-startup-stack"

# Optional — only needed for budget alerts
# billing_account_id = "ABCDEF-123456-GHIJKL"
monthly_budget_usd = 100
