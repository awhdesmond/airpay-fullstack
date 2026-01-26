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

