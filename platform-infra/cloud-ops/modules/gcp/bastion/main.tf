# ---------------------------------------------------------------------------------------------------------------------
# 1. BASTION HOST
# ---------------------------------------------------------------------------------------------------------------------
resource "google_service_account" "bastion_sa" {
  account_id   = "bastion-sa"
  display_name = "Bastion Service Account"
}

resource "google_compute_instance" "bastion" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.availability_zone
  tags         = var.bastion_network_tags

  # Ensure OS Login is enabled for IAM SSH access
  metadata = {
    enable-oslogin = "TRUE"
  }

  boot_disk {
    initialize_params {
      image = var.machine_image
      size = 10
    }
  }

  network_interface {
    network    = var.vpc_id
    subnetwork = var.subnet_id
    # No access_config block = No Public IP
  }

  service_account {
    email  = google_service_account.bastion_sa.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = <<-EOT
  #!/bin/bash
  set -e

  # 1. Install Tinyproxy
  apt-get update
  apt-get install -y tinyproxy

  # 2. Configure Tinyproxy
  # We back up the original config
  cp /etc/tinyproxy/tinyproxy.conf /etc/tinyproxy/tinyproxy.conf.bak

  # Append the required access rules to the configuration file.
  # We allow localhost (127.0.0.1) and the Google IAP IP range.
  cat <<EOF >> /etc/tinyproxy/tinyproxy.conf

  # --- Added by Terraform Startup Script ---
  Allow 127.0.0.1
  Allow ::1
  Allow 35.235.240.0/20
  # -----------------------------------------
  EOF

  # 3. Restart the service to apply changes
  systemctl restart tinyproxy
  EOT
}

resource "google_compute_firewall" "allow_ssh_iap_to_bastion" {
  name    = "allow-ssh-ingress-iap-to-bastion"
  network = var.vpc_name

  allow {
    protocol = "tcp"
    ports    = var.bastion_host_ports
  }
  source_ranges = ["35.235.240.0/20"] # Limit this to your IP in production
  target_tags   = var.bastion_network_tags
}

# 3. Layer 1 Security: IAP Tunnel Access
#    - Grants permission to open the tunnel ONLY for this specific instance
resource "google_iap_tunnel_instance_iam_binding" "iap_access" {
  zone     = var.availability_zone
  instance = google_compute_instance.bastion.name
  role     = "roles/iap.tunnelResourceAccessor"
  members  = var.bastion_members
}

# 4. Layer 2 Security: OS Login Access
#    - Grants permission to log in to the Linux OS ONLY for this specific instance
resource "google_compute_instance_iam_binding" "os_login_access" {
  zone          = var.availability_zone
  instance_name = google_compute_instance.bastion.name
  role          = "roles/compute.osAdminLogin"
  members       = var.bastion_members
}
