variable "project_id" {
  type        = string
  nullable    = false
  description = "The GCP Project ID"
}

variable "gcp_service_account_id" {
  type        = string
  nullable    = false
  description = "GCP service account ID"
}

variable "gcp_service_account_name" {
  type        = string
  nullable    = false
  description = "GCP service account name"
}

variable "kubernetes_service_account_namespaced_name" {
  type        = string
  nullable    = false
  description = "GKE service account - namespace/name"
}

variable "secret_ids" {
  type = list(string)
  default = []
  description = "List of secret ids to grant permission to"
}
