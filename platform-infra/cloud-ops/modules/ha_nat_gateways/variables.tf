# ---------------------------------------------------------------------------------------------------------------------
# General + Networking
# ---------------------------------------------------------------------------------------------------------------------

variable "project_id" {
  type        = string
  nullable    = false
  description = "GCP Project ID"
}

variable "name" {
  type        = string
  nullable    = true
  description = "NAT Gateway Name"
  default     = "ha-nat-gateways"
}

variable "region" {
  type        = string
  nullable    = false
  description = "Region for the MIG."
}

variable "vpc_name" {
  type        = string
  nullable    = false
  description = "VPC Name"
}

variable "subnet_name" {
  type        = string
  nullable    = false
  description = "Subnet Name"
}

variable "gateway_count" {
  type        = number
  nullable    = true
  default     = 2
  description = "Number of NAT Gateway Instances"
}

variable "gateway_network_tags" {
  type        = list(string)
  nullable    = false
  description = "Instance's network tags"
  default     = ["nat-gateway"]
}

variable "route_network_tags" {
  type        = list(string)
  nullable    = false
  description = "Which network tags to apply the routing rule"
  default     = []
}

# ---------------------------------------------------------------------------------------------------------------------
# OS
# ---------------------------------------------------------------------------------------------------------------------

variable "machine_type" {
  type        = string
  nullable    = true
  description = "Machine Type"
  default     = "e2-medium"
}

variable "os_source_image" {
  type        = string
  nullable    = true
  description = "OS Source Image"
  default     = "debian-cloud/debian-11"
}


