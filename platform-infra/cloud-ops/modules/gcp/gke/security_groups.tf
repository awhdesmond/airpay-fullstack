# 1. Define the Parent Group
resource "googleworkspace_group" "gke_security" {
  email       = "gke-security-groups@airpay.com"
  name        = "GKE Security Groups"
  description = "Parent group for GKE RBAC"
}

# 2. Define your Dev Team Group (if not already managed)
resource "googleworkspace_group" "dev_team" {
  email = "dev-team@airpay.com"
  name  = "Developers"
}

# 3. Nest Dev Team inside GKE Security
resource "googleworkspace_group_member" "dev_team_membership" {
  group_id = googleworkspace_group.gke_security.id
  email    = googleworkspace_group.dev_team.email
  role     = "MEMBER"
}
