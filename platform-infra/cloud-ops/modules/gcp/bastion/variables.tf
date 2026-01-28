variable "instance_name" {
  type        = string
  nullable    = false
  description = "Name of the instance."
}

variable "availability_zone" {
  type        = string
  nullable    = false
  description = "Availability zone."
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

variable "machine_type" {
  type        = string
  nullable    = false
  default     = "e2-micro"
  description = "Machine type"
}

variable "machine_image" {
  type        = string
  nullable    = false
  default     = "debian-cloud/debian-11"
  description = "Machine image"
}

variable "bastion_network_tags" {
  type        = list(string)
  nullable    = false
  default     = [ "bastion" ]
  description = "Bastion host network tags"
}

variable "bastion_host_ports" {
  type        = list(string)
  nullable    = false
  default     = [ "22" , "8888" ]
  description = "Bastion host network ports"
}

variable "vpc_name" {
  type        = string
  nullable    = false
  description = "VPC name (google_compute_network.vpc_network.name)"
}

variable "bastion_members" {
  type        = list(string)
  description = "List of users, groups, SAs who need access to the bastion host"
  default     = ["user:awhdes@gmail.com"]
}
