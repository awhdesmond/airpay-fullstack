variable "project_id" {
  description = "GCP project ID"
  type        = string
  nullable    = false
  default     = "project-0-devops"
}

variable "region_primary" {
  description = "GCP region (primary site)"
  type        = string
  default     = "australia-southeast1"
}
