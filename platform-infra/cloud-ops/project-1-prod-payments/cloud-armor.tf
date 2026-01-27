resource "google_compute_security_policy" "gateway_policy" {
  name        = "ca-waf-rate-limit"
  description = "WAF and Rate Limiting for GKE Gateway"
  type        = "CLOUD_ARMOR" # Required for global L7 Load Balancers

  rule {
    priority = 1000
    action   = "deny(403)" # Return 403 Forbidden if matched
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('owasp-crs-v030001')"
      }
    }
    description = "Block OWASP Top 10 attacks (SQLi, XSS, etc)"
  }

  rule {
    priority = 2000
    action   = "throttle" # Special action for rate limiting

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"] # Apply to all source IPs
      }
    }
    description = "Rate limit: 100 req/min per IP"

    rate_limit_options {
      conform_action = "allow"     # Allow requests under the limit
      exceed_action  = "deny(429)" # Return 429 Too Many Requests if over limit
      enforce_on_key = "IP"        # Count requests per unique client IP

      rate_limit_threshold {
        count        = 200 # Threshold count
        interval_sec = 60  # Interval in seconds
      }
    }
  }

  rule {
    priority = 2147483647 # Max priority number (lowest precedence)
    action   = "allow"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow rule"
  }
}
