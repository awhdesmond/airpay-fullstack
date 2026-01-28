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
    log_type = "DATA_READ"  # Captures get/list/watch of data
  }
}

resource "google_storage_bucket" "audit_log_storage" {
  name          = "${var.project_id}-audit-logs"
  location      = local.region
  force_destroy = false

  lifecycle_rule {
    condition {
      age = 365 # Retain logs for 1 year
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_logging_project_sink" "gcs_audit_sink" {
  name        = "audit-logs-to-gcs"
  destination = "storage.googleapis.com/${google_storage_bucket.audit_log_storage.name}"

  filter = "logName:\"logs/cloudaudit.googleapis.com%2Fdata_access\""
  unique_writer_identity = true
}


resource "google_storage_bucket_iam_member" "sink_member" {
  bucket = google_storage_bucket.audit_log_storage.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.gcs_audit_sink.writer_identity
}
