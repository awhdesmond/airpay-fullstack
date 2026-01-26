# ---------------------------------------------------------------------------------------------------------------------
# 1. SUBNETS
# ---------------------------------------------------------------------------------------------------------------------
resource "google_compute_subnetwork" "gke_subnet" {
  name          = var.subnet_name
  region        = var.region
  network       = var.vpc_id
  ip_cidr_range = var.subnet_primary_ip_cidr

  dynamic "secondary_ip_range" {
    for_each = var.subnet_secondary_ip_cidrs
    content {
      range_name = secondary_ip_range.name
      ip_cidr_range = secondary_ip_range.ip_cidr_range
    }
  }

  # This acts as a gateway for VMs without public IPs to reach
  # Google APIs (storage, logging, gcr.io) internally.
  private_ip_google_access = true
}
