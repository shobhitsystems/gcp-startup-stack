output "trigger_name" { value = length(google_cloudbuild_trigger.deploy) > 0 ? google_cloudbuild_trigger.deploy[0].name : "no-trigger-github-not-configured" }
