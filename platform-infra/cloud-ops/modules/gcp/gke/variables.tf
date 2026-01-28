# ---------------------------------------------------------------------------------------------------------------------
# General
# ---------------------------------------------------------------------------------------------------------------------

variable "project_id" {
  type        = string
  nullable    = false
  description = "GCP Project ID"
}

variable "cluster_name" {
  type        = string
  nullable    = false
  description = "Name of the GKE cluster."
}

variable "location" {
  type        = string
  nullable    = false
  description = "Region of the GKE cluster."
}

# ---------------------------------------------------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------------------------------------------------

variable "master_ipv4_cidr_block" {
  type        = string
  nullable    = false
  default     = "172.16.0.0/28"
  description = "VPC ID"
}

variable "vpc_id" {
  type        = string
  nullable    = false
  description = "VPC ID"
}

variable "subnet_id" {
  type        = string
  nullable    = false
  description = "Subnet ID"
}

variable "subnet_pods_ip_cidr_name" {
  type        = string
  nullable    = false
  description = "Subnet Pods IP CIDR name"
}

variable "subnet_service_ip_cidr_name" {
  type        = string
  nullable    = false
  description = "Subnet Services IP CIDR name"
}

# ---------------------------------------------------------------------------------------------------------------------
# Autoscaling
# ---------------------------------------------------------------------------------------------------------------------
variable "autoscaling_resource_limits_cpu_min" {
  type        = number
  nullable    = true
  default     = 1
  description = "Autoscaling resouce limits cpu min"
}

variable "autoscaling_resource_limits_cpu_max" {
  type        = number
  nullable    = true
  default     = 1024
  description = "Autoscaling resouce limits cpu max"
}

variable "autoscaling_resource_limits_mem_min" {
  type        = number
  nullable    = true
  default     = 1
  description = "Autoscaling resouce limits mem min"
}

variable "autoscaling_resource_limits_mem_max" {
  type        = number
  nullable    = true
  default     = 2048
  description = "Autoscaling resouce limits mem max"
}


# ---------------------------------------------------------------------------------------------------------------------
# Node Pools
# ---------------------------------------------------------------------------------------------------------------------

variable "primary_node_pool_name" {
  type        = string
  nullable    = false
  description = "Primary nodepool name"
}

variable "primary_node_pool_node_count" {
  type        = number
  nullable    = false
  default     = 3
  description = "Primary nodepool node count"
}

variable "primary_node_pool_machine_type" {
  type        = string
  nullable    = false
  default     = "e2-medium"
  description = "Primary nodepool machine type"
}

variable "node_pool_network_tags" {
  type        = list(string)
  nullable    = false
  description = "Primary nodepool node's network tags"
  default     = ["gke-nodes"]
}

# ---------------------------------------------------------------------------------------------------------------------
# IAM
# ---------------------------------------------------------------------------------------------------------------------

variable "dev_team_groups" {
  type = list(string)
  default = [ "group:dev-team@airpay.com" ]
  description = "List of dev teams to grant cluster viewer access"
}

