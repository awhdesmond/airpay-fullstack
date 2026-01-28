locals {
  audit_logs_services = [
    "iam.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "secretmanager.googleapis.com",
  ]
}

resource "google_project_iam_audit_config" "gke_audit_logs" {
  for_each = local.audit_logs_services

  project = var.project_id
  service = each.value

  audit_log_config {
    log_type = "ADMIN_READ" # Captures create/update/delete of data
  }

  audit_log_config {
    log_type = "DATA_WRITE" # Captures create/update/delete of data
  }

  audit_log_config {
    log_type = "DATA_READ" # Captures get/list/watch of data
  }
}

resource "google_logging_project_sink" "gcs_central_audit_sink" {
  name        = "audit-logs-to-gcs"
  project     = var.project_id
  destination = "storage.googleapis.com/project-0-devops-audit-logs"
  filter                 = "logName:\"logs/cloudaudit.googleapis.com%2Fdata_access\""
  unique_writer_identity = true
}


resource "google_storage_bucket_iam_member" "central_sink_permissions" {
  bucket = "project-0-devops-audit-logs"
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.gcs_central_audit_sink.writer_identity
}
