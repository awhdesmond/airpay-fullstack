# airpay

Design the infrastructure architecture for a real-time payment processing system on Kubernetes & GCP with the given conditions:

* Architecture baseline (K8s + networking + traffic)
* Scalability & Capacity (must go beyond HPA)
* Data layer for payments (correctness + performance)
* High Availability to meet 99.99%
* DR Plan (RTO < 1h, RPO < 15m) — must be concrete
* Observability + Incident Readiness (must be actionable)
* Security / Compliance (payments baseline)

| Dimension                                       | Description                                                                                                                                                                                  |
|-------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| CICD                                            | Pipelines, IaC, GitOps (ArgoCD), Terraform (Atlantis) & Ansible                                                                                                                              |
| Networking (GKE)                                | 1. VPC-Native + Dataplane V2. 2. Gateway API + HTTPRoute + Internal/External Gateways, GCP ALB.                                                                                              |
| Networking                                      | (NAT Gateways)	HA NAT Gateway VMs (MIGs) + NLB + GCP Routes to the NLB                                                                                                                       |
| Scalability (Kubernetes Cluster)                | Cluster Autoscaler                                                                                                                                                                           |
| Scalability (Application)                       | HPA, VPA, KEDA                                                                                                                                                                               |
| Scalability (Databases)                         | Postgres Single Primary (Vertical scaling) + Multiple Read Replicas                                                                                                                          |
| Reliability (HA Kubernetes Cluster)             | Regional Control Plane, Multiple-AZs Data Plane. Resource Quotas (~20%) for platform components.                                                                                             |
| Reliability (HA Application)                    | Liveness Probes, Readiness Probes, Pod Anti-Affinity, AZ topologySpreadConstraints, Pod PDB, Pod QoS (Request == Limit). Resource Quotas + LimitRanges for pod resources                     |
| Reliability (Databases, Business Continuity)    | 1. Patroni + etcd for automated DB failover (AZ), 2. DB automated backups, RPO (15m), 3. Sync replication within AZ, Async replication across regions. 4. Manual-switch for DR cross-region failover               |
| Performance (Read Latency)                      | Redis Cache (write through) Use this for high-speed balance checks and idempotency keys (deduplication) with a write-through strategy to Spanner to ensure data integrity.                   |
| Observability (Cluster Metrics)                 | OTel Collector (Prometheus) + Thanos + Grafana (API server latency, Pending Pods, Node Status)                                                                                               |
| Observability (App Metrics)                     | OTel Collector (Prometheus) + Thanos + Grafana (latency to process each payment - Queue + Processing)                                                                                        |
| Observability (Blackbox & Synthetic Probes)     | Synthetic Probes, attempts $1.00 dollar transactions to verify full payment flow                                                                                                             |
| Observability (Logs)                            | Leverage GCP Cloud Logging, structured logging to stdout                                                                                                                                     |
| Obvservability (Traces)                         | Service Mesh or OTel W3C trace context                                                                                                                                                       |
| Observability (Costs)                           | Enable GKE Cost Allocation. Add labels such as team, product etc.                                                                                                                            |
| Alerting (SLO-based Alerts)                     | SLOTH, collect SLI and set 99.99% as SLO. Actionable alert runbooks. Alertmanager + Thanos Ruler                                                                                             |
| Security (Secrets & Encryption)                 | GCP secrets manager, secret-store-csi, encryption on DB VM disk (by default have)                                                                                                            |
| Security (IAM)                                  | GKE workload identity, IAM user + groups. Principle of least privilege, lock down PROD env (apps vs. devops)                                                                                 |
| Security (Networking, Zero-Trust)               | 1. Firewall rules to control network traffic to VMs (public, private subnets). 2. GKE Network Policies to deny by default. 3. Ambient mesh to support mTLS between pods. 4. Egress Filtering using FQDN Network policies. |
| Security (Container Images)                     | Artifact Registry vulnerability scan (Clair) + Distroless Base Images + SBOMs (trivy)                                                                                                        |
| Security (Pod Runtime)                          | Pod security standards (PSS) + Pod security adminssion (PSA) + Security context, Linux capabilities + SeccompProfile                                                                         |
| Security (DDOS, Rate-limiting, IP Whitelisting) | GCP Cloud Armor (DDOS + WAF rules)                                                                                                                                                           |
| Security (Day 2 Operations)                     | OS Image Patching (Packer), Vulnerability Scans using Wiz to mitigate CVEs. Read/Write Audit logs.                                                                                                                  |
| Security (Business Continuity)                  | DB backups across projects with lockdown permissions                                                                                                                                         |

View repo site at https://awhdesmond.github.io/airpay-fullstack/


# Directory Structure

* `payments-api` - Golang application to simulate a double entry ledger payment service
* `payments-app-gitops-k8s` - GitOps repository for `payments-api`
* `platform-infra` -  Main infrastructure repository
* `platform-infra/cloud-ops` -  Main terraform directory, containing the configuration for modules and GCP projects.
* `platform-infra/gitops-k8s/devops-components` - Main GitOps directory for centralised devops components.
* `platform-infra/gitops-k8s/platform-components` - Main GitOps directory for platform components to be deployed in GKE clusters.
* `platform-infra/db-ops` - Main Ansible directory for running database operations.
