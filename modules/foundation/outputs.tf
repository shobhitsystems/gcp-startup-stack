output "network_name"      { value = google_compute_network.vpc.name }
output "network_self_link" { value = google_compute_network.vpc.self_link }
output "subnet_name"       { value = google_compute_subnetwork.app.name }
output "connector_id"      { value = google_vpc_access_connector.connector.id }
output "sql_vpc_connection"{ value = google_service_networking_connection.sql_vpc_connection.id }
