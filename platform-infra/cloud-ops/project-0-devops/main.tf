locals {
  vpc_name            = "vpc-primary-default"
  subnet_name_default = "subnet-default"
  subnet_name_gke     = "subnet-gke"
  region              = var.region_primary

  gke_cluster_name           = "default"
  gke_cluster_pod_range_name = "gke-pod-cidr"
  gke_cluster_svc_range_name = "gke-service-cidr"
}

# ---------------------------------------------------------------------------------------------------------------------
# 1. NETWORKING
# ---------------------------------------------------------------------------------------------------------------------

module "vpc" {
  source   = "../modules/gcp/vpc"
  vpc_name = local.vpc_name
}

module "subnet_default" {
  source = "../modules/gcp/subnet"
  vpc_id = module.vpc.vpc_id
  region = local.region

  subnet_name            = local.subnet_name_default
  subnet_primary_ip_cidr = "10.0.0.0/16"
}

module "subnet_gke" {
  source = "../modules/gcp/subnet"

  vpc_id = module.vpc.vpc_id
  region = local.region

  subnet_name            = local.subnet_name_gke
  subnet_primary_ip_cidr = "10.10.0.0/16"
  subnet_secondary_ip_cidrs = [
    { name = local.gke_cluster_pod_range_name, ip_cidr_range = "10.11.0.0/16" },
    { name = local.gke_cluster_svc_range_name, ip_cidr_range = "10.12.0.0/16" }
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# 1.1 HA NAT Gateways
# ---------------------------------------------------------------------------------------------------------------------

module "ha_nat_gateways" {
  source = "../modules/gcp/ha_nat_gateways"

  project_id = var.project_id
  name        = "ha-nat-gateways"
  region      = local.region
  vpc_name    = local.vpc_name
  subnet_name = local.subnet_name_default
  route_network_tags = ["gke-nodes-${local.gke_cluster_name}"]
}

# ---------------------------------------------------------------------------------------------------------------------
# 2. GCR (Shared)
# ---------------------------------------------------------------------------------------------------------------------

module "gcr" {
  source = "../modules/gcp/artifact_registry"

  location      = local.region
  repository_id = "default-repo"
  description   = "Default Docker Image Repository"

  consumer_gke_sa_emails = []
}

# ---------------------------------------------------------------------------------------------------------------------
# 3. GKE
# ---------------------------------------------------------------------------------------------------------------------

module "gke_cluster_default" {
  source = "../modules/gcp/gke"

  project_id   = var.project_id
  location     = local.region
  cluster_name = local.gke_cluster_name

  vpc_id                      = module.vpc.vpc_id
  subnet_id                   = module.gke_subnet.subnet_id
  subnet_pods_ip_cidr_name    = local.gke_cluster_pod_range_name
  subnet_service_ip_cidr_name = local.gke_cluster_svc_range_name

  primary_node_pool_name = "node-pool-primary"
  node_pool_network_tags = ["gke-nodes-${local.gke_cluster_name}"]
}

# ---------------------------------------------------------------------------------------------------------------------
# 3.1 Bastion Host
# ---------------------------------------------------------------------------------------------------------------------

module "bastion_a" {
  source = "../modules/gcp/bastion"
  instance_name = "bastion-australia-southeast1a"
  availability_zone = "australia-southeast1a"
  vpc_name = local.vpc_name
  vpc_id = module.vpc.vpc_id
  subnet_id = module.gke_subnet.subnet_id
}

module "bastion_b" {
  source = "../modules/gcp/bastion"
  instance_name = "bastion-australia-southeast1b"
  availability_zone = "australia-southeast1b"
  vpc_name = local.vpc_name
  vpc_id = module.vpc.vpc_id
  subnet_id = module.gke_subnet.subnet_id
}


# ---------------------------------------------------------------------------------------------------------------------
# 4. Atlantis
# ---------------------------------------------------------------------------------------------------------------------

resource "google_service_account" "atlantis_broker" {
  account_id = "atlantis-broker"
}

resource "google_service_account" "atlantis_dev" {
  account_id = "atlantis-deployer-dev"
}

resource "google_service_account" "atlantis_prod" {
  account_id = "atlantis-deployer-prod"
}

resource "google_service_account_iam_member" "broker_can_impersonate_dev" {
  service_account_id = google_service_account.atlantis_dev.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.atlantis_broker.email}"
}

resource "google_service_account_iam_member" "broker_can_impersonate_prod" {
  service_account_id = google_service_account.atlantis_prod.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.atlantis_broker.email}"
}

# Binds the "Broker" GSA to the Kubernetes Service Account in the DevOps Cluster
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.atlantis_broker.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[atlantis/atlantis]"
}

locals {
    target_dev_projects = [
    "project-1-dev-payments",
  ]

  target_prod_projects = [
    "project-1-prod-payments",
  ]
}

locals {
  atlantis_roles = [
    "roles/container.admin",                 # GKE Lifecycle
    "roles/compute.networkAdmin",            # VPC, NAT, Router, Firewalls
    "roles/compute.instanceAdmin.v1",        # VM Instances (NAT Gateways)
    "roles/iam.serviceAccountAdmin",         # Create Service Accounts
    "roles/resourcemanager.projectIamAdmin", # Manage IAM Bindings on resources
    "roles/iam.serviceAccountUser",          # Attach SAs to resources
    "roles/serviceusage.serviceUsageAdmin",  # Enable Google APIs
    "roles/storage.admin",                   # GCS buckets
  ]

  atlantis_project_dev_role_pairs = flatten([
    for project in target_dev_projects : [
      for role in local.atlantis_roles : {
        project = project
        role    = role
        key     = "${project}-${role}"
      }
    ]
  ])

  atlantis_project_prod_role_pairs = flatten([
    for project in target_dev_projects : [
      for role in local.atlantis_roles : {
        project = project
        role    = role
        key     = "${project}-${role}"
      }
    ]
  ])
}

resource "google_project_iam_member" "dev_deployer_permissions" {
  for_each = toset(local.atlantis_project_dev_role_pairs)

  project = each.value.project
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.atlantis_dev.email}"
}

resource "google_project_iam_member" "prod_deployer_permissions" {
  for_each = toset(local.atlantis_project_prod_role_pairs)

  project = each.value.project
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.atlantis_prod.email}"
}

# ---------------------------------------------------------------------------------------------------------------------
# 5. Thanos
# ---------------------------------------------------------------------------------------------------------------------

resource "google_storage_bucket" "thanos_metrics_bucket" {
  name          = "thanos-metrics-bucket" # Must be globally unique
  location      = local.region
  force_destroy = false

  # Recommended: Enforce IAM controls and disable legacy ACLs
  uniform_bucket_level_access = true
  public_access_prevention = "enforced"

  versioning {
    enabled = true
  }
}

resource "google_service_account" "thanos_sa" {
  account_id   = "thanos-writer"
  display_name = "Thanos Metrics Writer"
}

resource "google_storage_bucket_iam_member" "thanos_bucket_admin" {
  bucket = "thanos-metrics-bucket"
  role   = "roles/storage.objectAdmin" # Read/Write access
  member = "serviceAccount:${google_service_account.thanos_sa.email}"
}

resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.thanos_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:project-0-devops.svc.id.goog[platform-monitoring/thanos-writer]"
}

# ---------------------------------------------------------------------------------------------------------------------
# 6. Ansible
# ---------------------------------------------------------------------------------------------------------------------

locals {
  ansible_roles = [
    "roles/compute.osAdminLogin"
  ]

  ansible_project_dev_role_pairs = flatten([
    for project in target_dev_projects : [
      for role in local.ansible_roles : {
        project = project
        role    = role
        key     = "${project}-${role}"
      }
    ]
  ])

  ansible_project_prod_role_pairs = flatten([
    for project in target_dev_projects : [
      for role in local.ansible_roles : {
        project = project
        role    = role
        key     = "${project}-${role}"
      }
    ]
  ])
}
resource "google_service_account" "ansible_sa" {
  account_id   = "ansible-automation-sa"
  display_name = "Ansible Remote Access Identity"
}

resource "google_project_iam_member" "ansible_os_admin" {
  for_each = toset(local.atlantis_project_dev_role_pairs)

  project = each.value.project
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.ansible_sa.email}"
}

resource "tls_private_key" "ansible_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "google_os_login_ssh_public_key" "ansible_key_upload" {
  user = google_service_account.ansible_sa.email
  key  = tls_private_key.ansible_ssh_key.public_key_openssh
}

resource "google_secret_manager_secret" "ansible_key_secret" {
  secret_id = "ansible-ssh-private-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "ansible_key_version" {
  secret      = google_secret_manager_secret.ansible_key_secret.id
  secret_data = tls_private_key.ansible_ssh_key.private_key_pem
}



