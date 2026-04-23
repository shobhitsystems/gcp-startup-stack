resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = "${var.env}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "Startup stack VPC — managed by Terraform"
}

resource "google_compute_subnetwork" "app" {
  project                  = var.project_id
  name                     = "${var.env}-app-subnet"
  ip_cidr_range            = "10.10.0.0/24"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_router" "router" {
  project = var.project_id
  name    = "${var.env}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  project                            = var.project_id
  name                               = "${var.env}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  log_config { 
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# VPC peering for Cloud SQL private IP
resource "google_compute_global_address" "sql_private_ip" {
  project       = var.project_id
  name          = "${var.env}-sql-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "sql_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.sql_private_ip.name]
}

# VPC Access connector for Cloud Run → VPC traffic
resource "google_vpc_access_connector" "connector" {
  project       = var.project_id
  name          = "${var.env}-connector"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.8.0.0/28"
  min_instances = 2
  max_instances = 3
  machine_type  = "e2-micro"
}
