output "app_sa_email"               { value = google_service_account.accounts["app"].email }
output "deployer_sa_email"          { value = google_service_account.accounts["deployer"].email }
output "workload_identity_provider" { value = google_iam_workload_identity_pool_provider.github.name }
