locals {
  nat_gateway_healthchecks_tag = "nat-gateway-allow-health-checks"
}

# ---------------------------------------------------------
# 1. STATIC PUBLIC IPs (The VIPs)
# ---------------------------------------------------------
resource "google_compute_address" "nat_external_ips" {
  count = var.gateway_count

  name   = "${var.name}-vip-${count.index + 1}"
  region = var.region
}


# ---------------------------------------------------------
# 2. INSTANCE TEMPLATES (Specific IP per Template)
# ---------------------------------------------------------
resource "google_compute_instance_template" "nat_gateway_templates" {
  count = var.gateway_count

  name_prefix  = "${var.name}-template-${count.index + 1}-"
  machine_type = var.machine_type
  region       = var.region

  can_ip_forward = true
  tags           = var.gateway_network_tags + [local.nat_gateway_healthchecks_tag]

  disk {
    source_image = var.os_source_image
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network    = var.vpc_name
    subnetwork = var.subnet_name

    access_config {
      # BINDING THE STATIC IP HERE
      nat_ip = google_compute_address.nat_external_ips[count.index].address
    }
  }

  metadata_startup_script = <<-EOT
    #! /bin/bash
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

    iptables -t nat -A POSTROUTING -o $(ip route show to default | awk '{print $5}') -j MASQUERADE
  EOT

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------
# 3. SPLIT MIGs (1 Instance per MIG)
# ---------------------------------------------------------
resource "google_compute_region_instance_group_manager" "nat_migs" {
  count = var.gateway_count

  name               = "${var.name}-mig-${count.index + 1}"
  base_instance_name = "${var.name}-mig-${count.index + 1}"
  region             = var.region
  target_size        = 1

  version {
    instance_template = google_compute_instance_template.nat_gateway_templates[count.index].id
  }

  auto_healing_policies {
    health_check      = google_compute_region_health_check.nat_health_check.id
    initial_delay_sec = 60
  }
}

# ---------------------------------------------------------
# 4. LOAD BALANCER (Aggregating the Split MIGs)
# ---------------------------------------------------------

# Health Check
resource "google_compute_region_health_check" "nat_health_check" {
  name   = "${var.name}-health-check"
  region = var.region

  tcp_health_check {
    port = "22"
  }
}

# Backend Service
resource "google_compute_region_backend_service" "nat_backend_service" {
  name                  = "${var.name}-backend-service"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"

  # DYNAMIC BLOCK: Adds both MIGs to this single backend service
  dynamic "backend" {
    for_each = google_compute_region_instance_group_manager.nat_migs
    content {
      group = backend.value.instance_group
    }
  }

  health_checks = [google_compute_region_health_check.nat_health_check.id]
}

# Forwarding Rule (The Internal VIP)
resource "google_compute_forwarding_rule" "nat_ilb_forwarding_rule" {
  name                  = "${var.name}-ilb-frontend"
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.nat_backend_service.id
  all_ports             = true
  network               = var.vpc_name
  subnetwork            = var.subnet_name
  allow_global_access   = true
}

# ---------------------------------------------------------
# 5. ROUTING & FIREWALL
# ---------------------------------------------------------
resource "google_compute_route" "route_internet_via_nat" {
  name         = "route-internet-via-${var.name}-ilb"
  dest_range   = "0.0.0.0/0"
  network      = var.vpc_name
  next_hop_ilb = google_compute_forwarding_rule.nat_ilb_forwarding_rule.id
  priority     = 1000

  tags = var.route_network_tags
}

resource "google_compute_firewall" "allow_health_check" {
  name    = "allow-${var.name}-health-check"
  network = var.vpc_name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = [local.nat_gateway_healthchecks_tag]
}

resource "google_compute_firewall" "allow_internal_to_nat" {
  name    = "allow-internal-to-${var.name}"
  network = var.vpc_name

  allow {
    protocol = "all"
  }

  source_tags = var.route_network_tags
  target_tags = var.gateway_network_tags
}
