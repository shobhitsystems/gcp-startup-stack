locals {
  service_accounts = {
    app = {
      display = "App SA — Cloud Run workload"
      roles   = [
        "roles/run.invoker",
        "roles/secretmanager.secretAccessor",
        "roles/cloudsql.client",
        "roles/monitoring.metricWriter",
        "roles/logging.logWriter",
        "roles/cloudtrace.agent",
      ]
    }
    deployer = {
      display = "Deployer SA — CI/CD pipeline"
      roles   = [
        "roles/run.admin",
        "roles/artifactregistry.writer",
        "roles/iam.serviceAccountUser",
        "roles/secretmanager.viewer",
        "roles/cloudbuild.builds.editor",
        "roles/storage.objectAdmin",
      ]
    }
    terraform = {
      display = "Terraform SA — IaC automation"
      roles   = [
        "roles/editor",
        "roles/resourcemanager.projectIamAdmin",
        "roles/secretmanager.admin",
      ]
    }
  }
}

resource "google_service_account" "accounts" {
  for_each     = local.service_accounts
  project      = var.project_id
  account_id   = "${var.env}-${each.key}"
  display_name = each.value.display
  description  = "Managed by Terraform — gcp-startup-stack"
}

resource "google_project_iam_member" "bindings" {
  for_each = {
    for pair in flatten([
      for name, sa in local.service_accounts : [
        for role in sa.roles : { key = "${name}/${role}", name = name, role = role }
      ]
    ]) : pair.key => pair
  }
  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.accounts[each.value.name].email}"
}

# Workload Identity Federation for GitHub Actions
data "google_project" "project" { project_id = var.project_id }

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "${var.env}-github-pool"
  display_name              = "GitHub Actions — ${var.env}"
  description               = "Keyless auth — no service account keys stored in GitHub"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }

  attribute_condition = "attribute.repository_owner == \"${var.github_org}\""

  oidc { issuer_uri = "https://token.actions.githubusercontent.com" }
}

resource "google_service_account_iam_member" "github_wif" {
  service_account_id = google_service_account.accounts["deployer"].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${var.github_repo}"
}
