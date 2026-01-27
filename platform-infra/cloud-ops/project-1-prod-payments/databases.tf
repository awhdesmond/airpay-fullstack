locals {
  vpc_name                     = "vpc-default"
  subnet_name_default          = "subnet-default"
  failover_subnet_name_default = "subnet-default"

  main_region     = var.region_primary
  failover_region = var.region_failover
}

module "db_cluster_payments" {
  source = "../modules/gcp/db_cluster"

  project_id      = var.project_id
  region_main     = local.main_region
  region_failover = local.failover_region
  db_cluster_name = "db-payments"

  db_nodes_vpc_network     = local.vpc_name
  db_nodes_subnet_main     = local.subnet_name_default
  db_nodes_subnet_failover = local.failover_subnet_name_default
}

