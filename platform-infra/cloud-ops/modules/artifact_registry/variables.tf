variable "location" {
  type        = string
  nullable    = false
  description = "Region of the artifact registry"
}

variable "repository_id" {
  type        = string
  nullable    = false
  description = "Name of the artifact repository"
}

variable "description" {
  type        = string
  nullable    = false
  description = "Description for the repository"
}

variable "format" {
  type        = string
  nullable    = false
  description = "Format of the repository"
  default     = "DOCKER"
}

variable "consumer_gke_sa_emails" {
  type = list(string)
  default = [ ]
  description = "List of Service Account's email running the GKE nodes in the consumer project"
}
