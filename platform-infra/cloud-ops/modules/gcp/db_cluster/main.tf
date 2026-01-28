locals {
  pg_disk_size      = 500
  etcd_disk_size    = 10
  pg_boot_disk_size = 100

  data_disk_type = "pd-ssd"
  boot_disk_type = "pd-balanced"
}

# ---------------------------------------------------------------------------------------------------------------------
# 1. Service Account
# ---------------------------------------------------------------------------------------------------------------------

resource "google_service_account" "db_cluster_sa" {
  account_id   = "${var.db_cluster_name}-sa"
  display_name = "${var.db_cluster_name} Service Account"
}

resource "google_project_iam_member" "snapshot_permissions" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/compute.storageAdmin",       # Full control over snapshots and disks
    "roles/compute.instanceAdmin.v1",   # Required if performing guest-flush/quiescing
    "roles/compute.resourceAdmin"       # Required to create/attach Resource Policies
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.db_cluster_sa.email}"
}

# ---------------------------------------------------------------------------------------------------------------------
# 2. Disks
# ---------------------------------------------------------------------------------------------------------------------

resource "google_compute_disk" "pg_disk" {
  for_each = { for node in var.db_nodes : node.name => instance }

  name = "${each.key}-pg-data"
  zone = each.value.zone
  type = local.data_disk_type # SSD recommended for DB
  size = local.pg_disk_size   # Adjust size as needed
}

resource "google_compute_disk" "etcd_disk" {
  for_each = { for node in var.db_nodes : node.name => instance }

  name = "${each.key}-etcd-data"
  zone = each.value.zone
  type = local.data_disk_type # Etcd is very latency sensitive; SSD is mandatory
  size = local.etcd_disk_size # Etcd data is small
}

# ---------------------------------------------------------------------------------------------------------------------
# 3. Networking
# ---------------------------------------------------------------------------------------------------------------------

resource "google_compute_address" "db_nodes_internal_ip" {
  for_each = { for node in var.db_nodes : node.name => instance }

  name         = "pg-internal-ip-main-${each.value.name}"
  subnetwork   = each.value.is_failover ? var.db_nodes_subnet_failover : var.db_nodes_subnet_main
  address_type = "INTERNAL"
}

resource "google_compute_firewall" "allow_internal_postgres_ha" {
  name    = "allow-internal-postgres-ha-${var.db_cluster_name}"
  network = var.db_nodes_vpc_network

  allow {
    protocol = "tcp"
    ports = [
      "5432", # PostgreSQL Replication & Client Access
      "2379", # Etcd Client API (Patroni talking to DCS)
      "2380", # Etcd Peer API (Etcd nodes syncing with each other)
      "8008"  # Patroni REST API (Leader elections & Health checks)
    ]
  }

  # This rule applies effectively across regions
  # provided they are in the same VPC.
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  source_tags = [var.db_cluster_name]
  target_tags = [var.db_cluster_name]
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "allow-iap-ssh-${var.db_cluster_name}"
  network = var.db_nodes_vpc_network

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # This is the specific range Google uses for IAP forwarding
  source_ranges = ["35.235.240.0/20"]
  target_tags   = [var.db_cluster_name]
}

locals {
  backup_node = one([for node in var.db_nodes : node if node.is_backup == "true"])
}


# ---------------------------------------------------------------------------------------------------------------------
# 4. Nodes
# ---------------------------------------------------------------------------------------------------------------------


resource "google_compute_instance" "db_nodes" {
  for_each = { for node in var.db_nodes : node.name => instance }

  name         = each.key
  machine_type = each.value.machine_type
  zone         = each.value.zone

  labels = {
    pg_cluster  = each.key
    is_async    = each.value.is_async
    is_backup   = each.value.is_backup
    is_failover = each.value.is_failover
  }

  # Network tags for firewall rules
  tags = [
    "${var.db_cluster_name}",
    "postgres-ha",
  ]

  metadata = {
    enable-oslogin = "TRUE"
  }

  boot_disk {
    initialize_params {
      image = var.db_nodes_os_image
      size  = local.pg_boot_disk_size
      type  = local.boot_disk_type
    }
  }

  # Attached Disk for etcd
  attached_disk {
    source      = google_compute_disk.etcd_disk[each.key].name
    device_name = "etcd-data" # Maps to /dev/disk/by-id/google-etcd-data
  }

  # Attached Disk for Postgres
  attached_disk {
    source      = google_compute_disk.pg_disk[each.key].name
    device_name = "pg-data" # Maps to /dev/disk/by-id/google-pg-data
  }

  network_interface {
    network    = var.db_nodes_vpc_network
    subnetwork = each.value.subnet
    network_ip = google_compute_address.db_nodes_internal_ip[each.key].address
  }

  service_account {
    email  = google_service_account.db_cluster_sa.email
    scopes = ["cloud-platform"]
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# 5. Disk backups
# ---------------------------------------------------------------------------------------------------------------------

resource "google_cloud_scheduler_job" "snapshot_15min" {
  name             = "${var.db_cluster_name}-15min-snapshot-trigger"
  description      = "Triggers a snapshot for Postgres disk every 15 mins"
  schedule         = "*/15 * * * *"
  time_zone        = "UTC"
  attempt_deadline = "320s"

  http_target {
    http_method = "POST"
    uri         = "https://compute.googleapis.com/compute/v1/projects/${var.project_id}/zones/${backup_node.zone}/disks/${backup_node.name}-pg-data/createSnapshot"

    oauth_token {
      service_account_email = google_service_account.db_cluster_sa.email
    }

    # Optional: Snapshot naming convention using timestamp
    body = base64encode(jsonencode({
      "name": "pg-backup-${var.db_cluster_name}-${formatdate("YYYYMMDD-hhmm", timestamp())}"
    }))
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# 6. Load Balancer
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# 6.1 Unmanaged instance group
# ---------------------------------------------------------------------------------------------------------------------
resource "google_compute_instance_group" "pg_ig_main" {
  name        = "${var.db_cluster_name}-ig-main"
  description = "Postgres Main Cluster Instance Group"

  # dynamically add all nodes from the main region
  instances = [
   for node in var.db_nodes: google_compute_instance.db_nodes[node.name].self_link
   if node.is_failover == "false" && node.is_backup == "false"
  ]

  named_port {
    name = "patroni"
    port = 8008
  }

  named_port {
    name = "postgres"
    port = 5432
  }
}

resource "google_compute_instance_group" "pg_ig_failover" {
  name        = "${var.db_cluster_name}-ig-replica"
  description = "Postgres Failover Cluster Instance Group"

  # dynamically add all nodes from the main region
  instances = [
   for node in var.db_nodes: google_compute_instance.db_nodes[node.name].self_link
   if node.is_failover == "true" && node.is_backup == "false"
  ]

  named_port {
    name = "patroni"
    port = 8008
  }

  named_port {
    name = "postgres"
    port = 5432
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# 6.2 Health Checks
# ---------------------------------------------------------------------------------------------------------------------
resource "google_compute_health_check" "pg_hc_primary" {
  name               = "${var.db_cluster_name}-hc-primary"
  check_interval_sec = 10
  timeout_sec        = 5

  http_health_check {
    port         = 8008
    request_path = "/master"
  }
}

resource "google_compute_health_check" "pg_hc_replica" {
  name               = "${var.db_cluster_name}-hc-replica"
  check_interval_sec = 10
  timeout_sec        = 5

  http_health_check {
    port         = 8008
    request_path = "/replica"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# 6.3 Backend services & Forwarding Rules (Main)
# ---------------------------------------------------------------------------------------------------------------------
resource "google_compute_region_backend_service" "pg_backend_main_primary" {
  name                  = "${var.db_cluster_name}-pg-backend-main-primary"
  region                = var.region_main
  load_balancing_scheme = "INTERNAL"
  protocol              = "TCP"
  backend {
    group          = google_compute_instance_group.pg_ig_main.id
    balancing_mode = "CONNECTION"
  }

  health_checks = [google_compute_health_check.pg_hc_primary.id]
}

resource "google_compute_region_backend_service" "pg_backend_main_replica" {
  name                  = "${var.db_cluster_name}-pg-backend-main-replica"
  region                = var.region_main
  load_balancing_scheme = "INTERNAL"
  protocol              = "TCP"
  backend {
    group          = google_compute_instance_group.pg_ig_main.id
    balancing_mode = "CONNECTION"
  }

  health_checks = [google_compute_health_check.pg_hc_replica]
}

resource "google_compute_forwarding_rule" "pg_main_lb_frontend_primary" {
  name                  = "${var.db_cluster_name}-pg-main-lb-frontend-primary"
  region                = var.region_main
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.pg_backend_main_primary.id
  ports                 = ["5432"]
  network               = var.db_nodes_vpc_network
  subnetwork            = var.db_nodes_subnet_main
}

resource "google_compute_forwarding_rule" "pg_main_lb_frontend_replica" {
  name                  = "${var.db_cluster_name}-pg-main-lb-frontend-replica"
  region                = var.region_main
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.pg_backend_main_replica.id
  ports                 = ["5432"]
  network               = var.db_nodes_vpc_network
  subnetwork            = var.db_nodes_subnet_main
}


# ---------------------------------------------------------------------------------------------------------------------
# 6.3 Backend services & Forwarding Rules (Failover)
# ---------------------------------------------------------------------------------------------------------------------
resource "google_compute_region_backend_service" "pg_backend_failover_primary" {
  name                  = "${var.db_cluster_name}-pg-backend-failover-primary"
  region                = var.region_failover
  load_balancing_scheme = "INTERNAL"
  protocol              = "TCP"
  backend {
    group          = google_compute_instance_group.pg_ig_failover.id
    balancing_mode = "CONNECTION"
  }

  health_checks = [google_compute_health_check.pg_hc_primary.id]
}

resource "google_compute_region_backend_service" "pg_backend_failover_replica" {
  name                  = "${var.db_cluster_name}-pg-backend-failover-replica"
  region                = var.region_failover
  load_balancing_scheme = "INTERNAL"
  protocol              = "TCP"
  backend {
    group          = google_compute_instance_group.pg_ig_failover.id
    balancing_mode = "CONNECTION"
  }

  health_checks = [google_compute_health_check.pg_hc_replica]
}

resource "google_compute_forwarding_rule" "pg_failover_lb_frontend_primary" {
  name                  = "${var.db_cluster_name}-pg-failover-lb-frontend-primary"
  region                = var.region_failover
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.pg_backend_failover_primary.id
  ports                 = ["5432"]
  network               = var.db_nodes_vpc_network
  subnetwork            = var.db_nodes_subnet_failover
}

resource "google_compute_forwarding_rule" "pg_failover_lb_frontend_replica" {
  name                  = "${var.db_cluster_name}-pg-failover-lb-frontend-replica"
  region                = var.region_failover
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.pg_backend_failover_replica.id
  ports                 = ["5432"]
  network               = var.db_nodes_vpc_network
  subnetwork            = var.db_nodes_subnet_failover
}



# ---------------------------------------------------------------------------------------------------------------------
# 7. Password
# ---------------------------------------------------------------------------------------------------------------------

resource "random_password" "postgres_password" {
  length           = 16
  special          = true
  override_special = "!@#$%^&*()_+="
}

resource "google_secret_manager_secret" "postgres_password_secret" {
  secret_id = "${var.db_cluster_name}-postgres-password"
  replication {
    auto {}
  }
  # Add deletion_protection to prevent accidental deletion (optional, defaults to false)
  deletion_protection = true
}

resource "google_secret_manager_secret_version" "postgres_password_version" {
  secret      = google_secret_manager_secret.postgres_password_secret.id
  secret_data = random_password.postgres_password.result
  deletion_policy = "DISABLE"
}

resource "random_password" "replicator_password" {
  length           = 16
  special          = true
  override_special = "!@#$%^&*()_+="
}

resource "google_secret_manager_secret" "replicator_password_secret" {
  secret_id = "${var.db_cluster_name}-replicator-password"
  replication {
    auto {}
  }
  # Add deletion_protection to prevent accidental deletion (optional, defaults to false)
  deletion_protection = true
}

resource "google_secret_manager_secret_version" "database_password_version" {
  secret      = google_secret_manager_secret.replicator_password_secret.id
  secret_data = random_password.replicator_password.result
  deletion_policy = "DISABLE"
}
