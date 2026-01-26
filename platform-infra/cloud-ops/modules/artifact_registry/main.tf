resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.location
  repository_id = var.repository_id
  description   = var.description
  format        = var.format

  docker_config {
    immutable_tags = true
  }

  vulnerability_scanning_config {
    enablement_config = "INHERITED"
  }
}

resource "google_artifact_registry_repository_iam_member" "allow_cross_project_pull" {
  for_each = toset(var.consumer_gke_sa_emails)

  location   = var.location
  repository = var.repository_id

  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${each.value}"
}
