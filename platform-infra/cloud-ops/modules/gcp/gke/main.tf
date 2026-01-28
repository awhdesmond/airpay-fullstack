# ---------------------------------------------------------------------------------------------------------------------
# 1. PRIVATE GKE CLUSTER
# ---------------------------------------------------------------------------------------------------------------------
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.location

  initial_node_count       = 1
  remove_default_node_pool = true

  network           = var.vpc_id
  subnetwork        = var.subnet_id
  datapath_provider = "ADVANCED_DATAPATH"

  ip_allocation_policy {
    cluster_secondary_range_name  = var.subnet_pods_ip_cidr_name
    services_secondary_range_name = var.subnet_service_ip_cidr_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  master_authorized_networks_config {
    private_endpoint_enforcement_enabled = true
  }

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  addons_config {
    dns_cache_config {
      enabled = true
    }
    http_load_balancing {
      disabled = false
    }
  }

  vertical_pod_autoscaling {
    enabled = true
  }

  cost_management_config {
    enabled = true
  }

  cluster_autoscaling {
    enabled             = true
    autoscaling_profile = "BALANCED"

    resource_limits {
      resource_type = "cpu"
      minimum       = var.autoscaling_resource_limits_cpu_min
      maximum       = var.autoscaling_resource_limits_cpu_max
    }
    resource_limits {
      resource_type = "memory"
      minimum       = var.autoscaling_resource_limits_mem_min
      maximum       = var.autoscaling_resource_limits_mem_max # GB
    }
  }

  monitoring_config {
    advanced_datapath_observability_config {
      enable_metrics = true
      enable_relay   = true
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  authenticator_groups_config {
    security_group = "gke-security-groups@airpay.com"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# 2. GKE SA
# ---------------------------------------------------------------------------------------------------------------------

resource "google_service_account" "gke_node_sa" {
  account_id   = "${var.cluster_name}-gke-node-sa"
  display_name = "GKE Node Service Account"
  description  = "Identity for GKE nodes to interact with GCP APIs"
}

resource "google_project_iam_member" "gke_node_iam" {
  for_each = toset([
    "roles/logging.logWriter",                   # To send logs to Cloud Logging
    "roles/monitoring.metricWriter",             # To send metrics to Cloud Monitoring
    "roles/monitoring.viewer",                   # To view monitoring data (helper)
    "roles/stackdriver.resourceMetadata.writer", # To write metadata (labels, etc.)
    "roles/artifactregistry.reader"              # To pull images from your private registry
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}


# ---------------------------------------------------------------------------------------------------------------------
# 3. NODE POOL
# ---------------------------------------------------------------------------------------------------------------------
resource "google_container_node_pool" "primary_nodes" {
  name       = var.primary_node_pool_name
  location   = var.location
  cluster    = google_container_cluster.primary.name
  node_count = var.primary_node_pool_node_count

  network_config {
    enable_private_nodes = true
  }

  autoscaling {
    min_node_count = var.primary_node_pool_node_count
    max_node_count = 5
  }

  node_config {
    preemptible = false
    image_type   = "COS_CONTAINERD"
    machine_type = var.primary_node_pool_machine_type
    service_account = google_service_account.gke_node_sa.email

    boot_disk {
      size_gb   = 50
      disk_type = "pd-balanced"
    }

    kubelet_config {
      cpu_cfs_quota = true
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    tags = var.node_pool_network_tags
  }

  # Ignore changes to node_count, so Terraform doesn't try to reset it
  # after the autoscaler has scaled it up/down.
  lifecycle {
    ignore_changes = [node_count]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# 4. NODE POOL
# ---------------------------------------------------------------------------------------------------------------------

# Grant the group permission to fetch credentials for BOTH clusters
resource "google_project_iam_member" "dev_team_cluster_viewer" {
  for_each = var.dev_team_groups

  project = var.project_id
  role    = "roles/container.clusterViewer"
  member  = each.value
}

# (Optional) Allow them to view logs/metrics
resource "google_project_iam_member" "dev_team_logging" {
  for_each = var.dev_team_groups

  project = var.project_id
  role    = "roles/logging.viewer"
  member  = each.value
}
