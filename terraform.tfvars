# Copy to terraform.tfvars and fill in your values

project_id         = "your-gcp-project-id"
region             = "asia-south1"
env                = "demo"
github_org         = "your-github-org"
github_repo        = "your-repo-name"

# Optional — only needed for budget alerts
# billing_account_id = "ABCDEF-123456-GHIJKL"
monthly_budget_usd = 100
