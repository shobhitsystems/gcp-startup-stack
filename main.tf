terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google      = { source = "hashicorp/google",      version = "~> 5.0" }
    google-beta = { source = "hashicorp/google-beta", version = "~> 5.0" }
    random      = { source = "hashicorp/random",      version = "~> 3.0" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# ─── Enable all required APIs up front ───────────────────────────────────────

resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudtrace.googleapis.com",
    "billingbudgets.googleapis.com",
  ])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ─── Foundation: VPC + Subnets + NAT ─────────────────────────────────────────

module "foundation" {
  source     = "./modules/foundation"
  project_id = var.project_id
  region     = var.region
  env        = var.env
  depends_on = [google_project_service.apis]
}

# ─── IAM: Service accounts + Workload Identity Federation ────────────────────

module "iam" {
  source        = "./modules/iam"
  project_id    = var.project_id
  env           = var.env
  github_org    = var.github_org
  github_repo   = var.github_repo
  depends_on    = [google_project_service.apis]
}

# ─── Data: Cloud SQL (private, no public IP) + Secret Manager ────────────────

module "data" {
  source             = "./modules/data"
  project_id         = var.project_id
  region             = var.region
  env                = var.env
  network_self_link  = module.foundation.network_self_link
  app_sa_email       = module.iam.app_sa_email
  depends_on         = [module.foundation]
}

# ─── Compute: Artifact Registry + Cloud Run ───────────────────────────────────

module "compute" {
  source       = "./modules/compute"
  project_id   = var.project_id
  region       = var.region
  env          = var.env
  network_name = module.foundation.network_name
  db_secret_id = module.data.db_password_secret_id
  api_secret_id = module.data.api_key_secret_id
  app_sa_email  = module.iam.app_sa_email
  depends_on    = [module.data, module.iam]
}

# ─── Observability: Budget alerts + Log sink ──────────────────────────────────
## Commented out due to demo deployment
/*
resource "google_billing_budget" "main" {
  billing_account = var.billing_account_id
  display_name    = "${var.env}-startup-stack-budget"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.monthly_budget_usd)
    }
  }

  threshold_rules { threshold_percent = 0.5 }
  threshold_rules { threshold_percent = 0.8 }
  threshold_rules { threshold_percent = 1.0 }

  all_updates_rule {
    monitoring_notification_channels = []
    disable_default_iam_recipients   = false
  }
}
*/
