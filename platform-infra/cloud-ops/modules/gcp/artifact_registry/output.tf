output "artifact_registry_url" {
  value = "${google_artifact_registry_repository.docker_repo.location}-docker.pkg.dev/${google_artifact_registry_repository.docker_repo.project}/${google_artifact_registry_repository.docker_repo.repository_id}"
  description = "The URL to push docker images to"
}
