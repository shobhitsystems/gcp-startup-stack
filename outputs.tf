output "app_url" {
  description = "Live URL of the deployed Cloud Run service"
  value       = module.compute.service_url
}

output "registry_path" {
  description = "Artifact Registry path for Docker images"
  value       = module.compute.registry_path
}

output "db_connection_name" {
  description = "Cloud SQL connection name — use in --add-cloudsql-instances flag"
  value       = module.data.db_connection_name
}

output "workload_identity_provider" {
  description = "GitHub secret GCP_WORKLOAD_IDENTITY_PROVIDER"
  value       = module.iam.workload_identity_provider
}

output "deployer_sa_email" {
  description = "GitHub secret GCP_SERVICE_ACCOUNT"
  value       = module.iam.deployer_sa_email
}

output "app_sa_email" {
  description = "App service account — attached to Cloud Run service"
  value       = module.iam.app_sa_email
}

output "summary" {
  description = "Full summary of what was deployed"
  value = <<-EOT
╔══════════════════════════════════════════════════════════════╗
║       GCP Startup Stack — Deployed Successfully             ║
║       Built by Shobhit Systems (shobhitsystems.com)         ║
╚══════════════════════════════════════════════════════════════╝

Live app URL:
  ${module.compute.service_url}

What was deployed:
  ✓ VPC with private subnet, Cloud NAT, Cloud Router
  ✓ Artifact Registry (${var.region}-docker.pkg.dev/${var.project_id}/${var.env}-images)
  ✓ Cloud Run service (${module.compute.service_name})
  ✓ Cloud SQL PostgreSQL — private IP only, no public endpoint
  ✓ Secret Manager — DB password + API key
  ✓ IAM — 3 least-privilege service accounts
  ✓ Workload Identity Federation — GitHub Actions, no stored keys
  ✓ Budget alerts at 50/80/100% of $${var.monthly_budget_usd}/month

To deploy your app manually:
  docker build -t ${var.region}-docker.pkg.dev/${var.project_id}/${var.env}-images/app:latest ./sample-app
  docker push ${var.region}-docker.pkg.dev/${var.project_id}/${var.env}-images/app:latest
  gcloud run deploy ${module.compute.service_name} \
    --image=${var.region}-docker.pkg.dev/${var.project_id}/${var.env}-images/app:latest \
    --region=${var.region}

When you're ready to add CI/CD, add these GitHub Secrets:
  GCP_WORKLOAD_IDENTITY_PROVIDER = ${module.iam.workload_identity_provider}
  GCP_SERVICE_ACCOUNT            = ${module.iam.deployer_sa_email}
  GCP_PROJECT_ID                 = ${var.project_id}
  GCP_REGION                     = ${var.region}
EOT
}
