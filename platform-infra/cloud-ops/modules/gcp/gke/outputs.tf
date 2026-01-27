output "gke_cluster_name" {
  value = google_container_cluster.primary.name
}

output "gke_node_sa_email" {
  value = google_service_account.gke_node_sa.email
}
