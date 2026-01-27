module "payments_gsa_ksa" {
  source = "../modules/gcp/gsa-ksa"
  project_id = var.project_id

  gcp_service_account_id = "payments"
  gcp_service_account_name = "Payments Service Account"
  kubernetes_service_account_namespaced_name = "payments/payments"

  secret_ids = [ module.db_cluster_payments.password_secret_id ]
}
