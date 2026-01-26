variable "project_id" {
  description = "GCP project ID"
  type        = string
  nullable    = false
  default     = "project-1-dev-payments-airpay"
}

variable "region_primary" {
  description = "GCP region (primary site)"
  type        = string
  default     = "australia-southeast1"
}

variable "region_failover" {
  description = "GCP region (failover site)"
  type        = string
  default     = "australia-southeast2"
}
