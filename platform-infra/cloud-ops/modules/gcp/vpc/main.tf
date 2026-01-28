# ---------------------------------------------------------------------------------------------------------------------
# 1. VPC
# ---------------------------------------------------------------------------------------------------------------------
resource "google_compute_network" "vpc_network" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

# ---------------------------------------------------------------------------------------------------------------------
# 2. FIREWALL RULES
# ---------------------------------------------------------------------------------------------------------------------
resource "google_compute_firewall" "allow_internal" {
  name        = "allow-internal"
  description = "Default allow_internal firewall rule"
  network     = google_compute_network.vpc_network.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  priority      = 60000
  source_ranges = ["10.0.0.0/8"]
}
