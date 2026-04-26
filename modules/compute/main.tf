data "google_project" "project" { project_id = var.project_id }

resource "google_artifact_registry_repository" "images" {
  project       = var.project_id
  location      = var.region
  repository_id = "${var.env}-images"
  format        = "DOCKER"
  description   = "Application images — managed by Terraform"
  labels        = { env = var.env, managed = "terraform" }

  cleanup_policies {
    id     = "keep-last-10"
    action = "KEEP"
    most_recent_versions { keep_count = 10 }
  }
  cleanup_policies {
  id     = "delete-untagged-after-7-days"
  action = "DELETE"
  condition {
    tag_state  = "UNTAGGED"
    older_than = "604800s" # 7 days in seconds
  }
}
}

# Cloud Build SA needs to push images
resource "google_artifact_registry_repository_iam_member" "cloudbuild" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.images.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# App SA needs to pull images
resource "google_artifact_registry_repository_iam_member" "app_reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.images.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.app_sa_email}"
}

# Cloud Run service
resource "google_cloud_run_v2_service" "app" {
  project  = var.project_id
  name     = "${var.env}-app"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = var.app_sa_email

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }

    vpc_access {
      connector = "projects/${var.project_id}/locations/${var.region}/connectors/${var.env}-connector"
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      resources {
        limits = { cpu = "1", memory = "512Mi" }
        cpu_idle          = true
        startup_cpu_boost = true
      }

      env {
        name = "ENV"
        value = var.env 
      }
      env {
        name = "PROJECT_ID"
        value = var.project_id
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = var.db_secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "API_KEY"
        value_source {
          secret_key_ref {
            secret  = var.api_secret_id
            version = "latest"
          }
        }
      }

      liveness_probe {
        http_get { path = "/" }
        initial_delay_seconds = 5
        period_seconds        = 30
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Cloud Build SA needs run.admin + iam.serviceAccountUser
resource "google_project_iam_member" "cloudbuild_run" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}
