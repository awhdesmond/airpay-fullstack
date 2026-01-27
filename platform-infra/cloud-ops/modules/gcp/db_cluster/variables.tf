variable "project_id" {
  type = string
  nullable = false
  description = "Project id"
}

variable "region_main" {
  type = string
  nullable = false
  default = "australia-southeast1"
  description = "Main region"
}

variable "region_failover" {
  type = string
  nullable = false
  default = "australia-southeast2"
  description = "Failover region"
}

variable "db_cluster_name" {
  type        = string
  nullable    = false
  description = "Name of the db cluster"
}

variable "db_nodes" {
  default = [
    { name = "pg-1", zone = "australia-southeast1-a", machine_type = "n2-standard-2", is_async = "false", is_backup = "false", is_failover : "false" },
    { name = "pg-2", zone = "australia-southeast1-b", machine_type = "n2-standard-2", is_async = "false", is_backup = "false", is_failover : "false" },
    { name = "pg-3", zone = "australia-southeast1-c", machine_type = "n2-standard-2", is_async = "false", is_backup = "false", is_failover : "false" },
    { name = "pg-bk", zone = "australia-southeast1-a", machine_type = "e2-medium", is_async = "false", is_backup = "true", is_failover : "false" },
    { name = "failover-pg-1", zone = "australia-southeast2-b", machine_type = "n2-standard-2", is_async = "true", is_backup = "false", is_failover : "true" }
  ]
  type = list(object({
    name         = string,
    zone         = string,
    machine_type = string,
    subnet       = string,
    is_async     = string,
    is_backup    = string,
    is_failover  = string,

  }))
  description = "List of DB nodes in main region"
}

variable "db_nodes_os_image" {
  type        = string
  default     = "debian-cloud/debian-11"
  description = "PG Node os image"
}


variable "db_nodes_vpc_network" {
  type        = string
  default     = "vpc-default"
  description = "DB nodes vpc network"
}


variable "db_nodes_subnet_main" {
  type        = string
  default     = "subnet-default"
  description = "Main subnet to deploy the DB nodes"
}

variable "db_nodes_subnet_failover" {
  type        = string
  default     = "failover-subnet-default"
  description = "Failover subnet to deploy the DB nodes"
}

