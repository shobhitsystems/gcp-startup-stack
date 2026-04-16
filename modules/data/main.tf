resource "random_id" "db_suffix" { byte_length = 4 }
resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
resource "random_password" "api_key" {
  length  = 48
  special = false
}

# ─── Cloud SQL PostgreSQL (private IP only) ───────────────────────────────────

resource "google_sql_database_instance" "postgres" {
  project             = var.project_id
  name                = "${var.env}-postgres-${random_id.db_suffix.hex}"
  database_version    = "POSTGRES_15"
  region              = var.region
  deletion_protection = false   # allow terraform destroy in demo

  settings {
    tier              = "db-f1-micro"   # smallest tier for demo — upgrade for prod
    availability_type = "ZONAL"
    disk_autoresize   = true
    disk_size         = 10
    disk_type         = "PD_SSD"

    ip_configuration {
      ipv4_enabled                                  = false   # NO public IP
      private_network                               = var.network_self_link
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "02:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings { retained_backups = 7 }
    }

    insights_config {
      query_insights_enabled = true
      query_string_length    = 1024
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    user_labels = { env = var.env, managed = "terraform" }
  }

  depends_on = [var.network_self_link]
}

resource "google_sql_database" "app" {
  project  = var.project_id
  instance = google_sql_database_instance.postgres.name
  name     = "appdb"
}

resource "google_sql_user" "app" {
  project  = var.project_id
  instance = google_sql_database_instance.postgres.name
  name     = "appuser"
  password = random_password.db_password.result
}

# ─── Secret Manager ───────────────────────────────────────────────────────────

resource "google_secret_manager_secret" "db_password" {
  project   = var.project_id
  secret_id = "${var.env}-db-password"
  labels    = { env = var.env, managed = "terraform" }
  replication { auto {} }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

resource "google_secret_manager_secret" "db_url" {
  project   = var.project_id
  secret_id = "${var.env}-db-url"
  labels    = { env = var.env, managed = "terraform" }
  replication { auto {} }
}

resource "google_secret_manager_secret_version" "db_url" {
  secret      = google_secret_manager_secret.db_url.id
  secret_data = "postgresql://appuser:${random_password.db_password.result}@${google_sql_database_instance.postgres.private_ip_address}/appdb"
}

resource "google_secret_manager_secret" "api_key" {
  project   = var.project_id
  secret_id = "${var.env}-api-key"
  labels    = { env = var.env, managed = "terraform" }
  replication { auto {} }
}

resource "google_secret_manager_secret_version" "api_key" {
  secret      = google_secret_manager_secret.api_key.id
  secret_data = random_password.api_key.result
}

# Grant app SA access to all secrets
resource "google_secret_manager_secret_iam_member" "app_db_password" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.app_sa_email}"
}

resource "google_secret_manager_secret_iam_member" "app_db_url" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_url.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.app_sa_email}"
}

resource "google_secret_manager_secret_iam_member" "app_api_key" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.app_sa_email}"
}
