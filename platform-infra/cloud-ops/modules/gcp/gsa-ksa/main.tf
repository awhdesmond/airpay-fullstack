# 1. Create the Google Service Account (GSA)
resource "google_service_account" "gsa" {
  project      = var.project_id
  account_id   = var.gcp_service_account_id
  display_name = var.gcp_service_account_name
}

# 2. Bind GSA and KSA via Workload Identity User role
resource "google_service_account_iam_member" "workload_identity_binding" {
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.gsa.name
  # Format: serviceAccount:PROJECT_ID.svc.id.goog[NAMESPACE/KSA_NAME]
  member = "serviceAccount:${var.project_id}.svc.id.goog[${var.kubernetes_service_account_namespaced_name}]"
}

# 2. Grant permissions to the GSA (e.g., Storage Viewer)
resource "google_secret_manager_secret_iam_member" "secret_access" {
  for_each = toset(var.secret_ids)

  secret_id = each.key
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.gsa.email}"
}
