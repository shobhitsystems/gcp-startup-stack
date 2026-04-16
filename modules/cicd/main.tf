resource "google_cloudbuild_trigger" "deploy" {
  count       = var.github_owner != "" ? 1 : 0
  project     = var.project_id
  name        = "${var.env}-deploy"
  description = "Full startup stack pipeline: test → build → scan → push → deploy → smoke test"
  location    = "global"

  github {
    owner = var.github_owner
    name  = var.github_repo
    push  { branch = "^main$" }
  }

  substitutions = {
    _REGION       = var.region
    _PROJECT_ID   = var.project_id
    _ENV          = var.env
    _SERVICE_NAME = var.cloud_run_service
    _REGISTRY     = var.registry_host
    _IMAGE_NAME   = "app"
  }

  filename = "cloudbuild.yaml"
}
