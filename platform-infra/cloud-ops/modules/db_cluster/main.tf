locals {
  pg_disk_size      = 500
  etcd_disk_size    = 10
  pg_boot_disk_size = 100

  data_disk_type = "pd-ssd"
  boot_disk_type = "pd-balanced"
}

resource "google_service_account" "db_cluster_sa" {
  account_id   = "${var.db_cluster_name}-sa"
  display_name = "${var.db_cluster_name} Service Account"
}

resource "google_project_iam_member" "snapshot_permissions" {
  for_each = toset([
    "roles/compute.storageAdmin",       # Full control over snapshots and disks
    "roles/compute.instanceAdmin.v1",   # Required if performing guest-flush/quiescing
    "roles/compute.resourceAdmin"       # Required to create/attach Resource Policies
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.db_cluster_sa.email}"
}

resource "google_compute_disk" "pg_disk" {
  for_each = { for node in var.pg_nodes : node.name => instance }

  name = "${each.key}-pg-data"
  zone = each.value.zone
  type = local.data_disk_type # SSD recommended for DB
  size = local.pg_disk_size   # Adjust size as needed
}

resource "google_compute_disk" "etcd_disk" {
  # Filter the loop to only create disks for nodes where is_etcd is true
  for_each = { for node in var.pg_nodes : node.name => instance }

  name = "${each.key}-etcd-data"
  zone = each.value.zone
  type = local.data_disk_type # Etcd is very latency sensitive; SSD is mandatory
  size = local.etcd_disk_size # Etcd data is small
}

resource "google_compute_instance" "pg_nodes" {
  for_each = { for node in var.pg_nodes : node.name => instance }

  name         = each.key
  machine_type = each.value.machine_type
  zone         = each.value.zone

  labels = {
    is_etcd     = each.value.is_etcd
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
      image = var.pg_nodes_os_image
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
    network    = var.pg_nodes_vpc_network
    subnetwork = each.value.subnet
  }

  service_account {
    email  = google_service_account.postgres_sa.email

    # Instance needs permissions to write logs and metrics
    scopes = ["cloud-platform"]
  }
}

# Allows all nodes with tag 'db-cluster-prod' to talk to each other
resource "google_compute_firewall" "allow_internal_postgres_ha" {
  name    = "allow-internal-postgres-ha-${var.db_cluster_name}"
  network = var.pg_nodes_vpc_network

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
  source_tags = [var.db_cluster_name]
  target_tags = [var.db_cluster_name]
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "allow-iap-ssh-${var.db_cluster_name}"
  network = var.pg_nodes_vpc_network

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # This is the specific range Google uses for IAP forwarding
  source_ranges = ["35.235.240.0/20"]
  target_tags   = [var.db_cluster_name]
}

locals {
  backup_node = one([for node in var.pg_nodes : node if node.is_backup == "true"])
}

# Cloud Scheduler Job to trigger a Snapshot every 15 mins
resource "google_cloud_scheduler_job" "snapshot_15min" {
  name             = "postgres-15min-snapshot-trigger"
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
