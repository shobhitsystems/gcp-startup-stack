output "db_instance_name"      { value = google_sql_database_instance.postgres.name }
output "db_private_ip"         { value = google_sql_database_instance.postgres.private_ip_address }
output "db_connection_name"    { value = google_sql_database_instance.postgres.connection_name }
output "db_password_secret_id" { value = google_secret_manager_secret.db_password.secret_id }
output "db_url_secret_id"      { value = google_secret_manager_secret.db_url.secret_id }
output "api_key_secret_id"     { value = google_secret_manager_secret.api_key.secret_id }
