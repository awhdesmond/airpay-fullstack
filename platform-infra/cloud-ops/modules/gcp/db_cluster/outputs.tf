output "lb_address" {
  value = google_compute_forwarding_rule.pg_lb_frontend.ip_address
  description = "Database Load Balancer primary IP address"
}

output "password_secret_id" {
  value = google_secret_manager_secret.postgres_password_secret.id
  description = "Postgres Password Secret ID"
}