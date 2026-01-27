variable "project_id" {
  type = string
  nullable = false
  description = "Project id"
}

variable "db_cluster_name" {
  type        = string
  nullable    = false
  description = "Name of the db cluster"
}

variable "pg_nodes" {
  default = [
    { name = "pg-1", zone = "australia-southeast1-a", machine_type = "n2-standard-2", subnet = "subnet-default", is_etcd = "true", is_async = "false", is_backup = "false", is_failover : "false" },
    { name = "pg-2", zone = "australia-southeast1-b", machine_type = "n2-standard-2", subnet = "subnet-default", is_etcd = "true", is_async = "false", is_backup = "false", is_failover : "false" },
    { name = "pg-3", zone = "australia-southeast1-c", machine_type = "n2-standard-2", subnet = "subnet-default", is_etcd = "true", is_async = "false", is_backup = "false", is_failover : "false" },
    { name = "pg-bk", zone = "australia-southeast1-a", machine_type = "e2-medium", subnet = "subnet-default", is_etcd = "false", is_async = "false", is_backup = "true", is_failover : "false" },
    { name = "failover-pg-1", zone = "australia-southeast2-b", machine_type = "n2-standard-2", subnet = "failover-subnet-default", is_etcd = "false", is_async = "true", is_backup = "false", is_failover : "true" }
  ]
  type = list(object({
    name         = string,
    zone         = string,
    machine_type = string,
    subnet       = string,
    is_etcd      = string,
    is_async     = string,
    is_backup    = string,
    is_failover  = string,

  }))
  description = "List of pg nodes in main region"
}

variable "pg_nodes_os_image" {
  type        = string
  default     = "debian-cloud/debian-11"
  description = "PG Node os image"
}

variable "pg_nodes_vpc_network" {
  type        = string
  default     = "vpc-default"
  description = "PG nodes vpc network"
}
