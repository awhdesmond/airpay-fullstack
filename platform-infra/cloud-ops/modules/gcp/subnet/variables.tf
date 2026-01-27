variable "vpc_id" {
  type        = string
  nullable    = false
  description = "ID of the VPC."
}

variable "region" {
  type        = string
  nullable    = false
  description = "Subnet region"
}

variable "subnet_name" {
  type        = string
  nullable    = false
  description = "Subnet name."
}

variable "subnet_primary_ip_cidr" {
  type        = string
  nullable    = false
  default     = "10.0.0.0/16"
  description = "Subnet Primary IP CIDR."
}

variable "subnet_secondary_ip_cidrs" {
  type = list(object({
    name = string,
    ip_cidr_range = string
  }))
  nullable = true
  default = []
  description = "Subnet Secondary IP CIDRs"
}
