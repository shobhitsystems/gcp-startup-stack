output "service_name"   { value = google_cloud_run_v2_service.app.name }
output "service_url"    { value = google_cloud_run_v2_service.app.uri }
output "registry_host"  { value = "${var.region}-docker.pkg.dev" }
output "registry_path"  { value = "${var.region}-docker.pkg.dev/${var.project_id}/${var.env}-images" }
