# airpay

Design the infrastructure architecture for a real-time payment processing system on Kubernetes & GCP with the given conditions:

* Architecture baseline (K8s + networking + traffic)
* Scalability & Capacity (must go beyond HPA)
* Data layer for payments (correctness + performance)
* High Availability to meet 99.99%
* DR Plan (RTO < 1h, RPO < 15m) — must be concrete
* Observability + Incident Readiness (must be actionable)
* Security / Compliance (payments baseline)

| Dimension                                       | Description                                                                                                                                                                                                               |
|-------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| CICD                                            | Pipelines, IaC, GitOps (ArgoCD), Terraform (Atlantis) & Ansible                                                                                                                                                           |
| Networking (GKE)                                | 1. VPC-Native + Dataplane V2. 2. Gateway API (GKE Gateway controller) + HTTPRoute + External GCP ALB.                                                                                                                     |
| Networking (NAT Gateways)                       | HA NAT Gateway VMs (MIGs) + NLB + GCP Routes to the NLB                                                                                                                                                                   |
| Scalability (Kubernetes Cluster)                | Cluster Autoscaler                                                                                                                                                                                                        |
| Scalability (Application)                       | HPA, VPA, KEDA                                                                                                                                                                                                            |
| Scalability (Databases)                         | Postgres Single Primary (Vertical scaling) + Multiple Read Replicas                                                                                                                                                       |
| Reliability (HA Kubernetes Cluster)             | Regional Control Plane, Multiple-AZs Data Plane. Resource Quotas (~20%) for platform components.                                                                                                                          |
| Reliability (HA Application)                    | Liveness Probes, Readiness Probes, Pod Anti-Affinity, AZ topologySpreadConstraints, Pod PDB, Pod QoS (Request == Limit). Resource Quotas + LimitRanges for pod resources                                                  |
| Reliability (Databases, Business Continuity)    | 1. Patroni + etcd for automated DB failover (AZ), 2. DB automated backups, RPO (15m), 3. Sync replication within AZ, Async replication across regions. 4. Manual-switch for DR cross-region failover                      |
| Performance (Read Latency)                      | Redis Cache (write through)                                                                                                                                                                                               |
| Observability (Cluster Metrics)                 | OTel Collector + Prometheus + Thanos + Grafana (API server latency, Pending Pods, Node Status)                                                                                                                            |
| Observability (App Metrics)                     | OTel Collector + Prometheus + Thanos + Grafana (latency to process each payment - Queue + Processing)                                                                                                                     |
| Observability (Blackbox & Synthetic Probes)     | Synthetic Probes, attempts $1.00 dollar transactions to verify full payment flow                                                                                                                                          |
| Observability (Logs)                            | Leverage GCP Cloud Logging, structured logging to stdout                                                                                                                                                                  |
| Obvservability (Traces)                         | Service Mesh or OTel W3C trace context                                                                                                                                                                                    |
| Observability (Costs)                           | Enable GKE Cost Allocation. Add labels such as team, product etc.                                                                                                                                                         |
| Alerting (SLO-based Alerts)                     | SLOTH, collect SLI and set 99.99% as SLO. Actionable alert runbooks. Alertmanager + Thanos Ruler                                                                                                                          |
| Security (Secrets & Encryption)                 | GCP secrets manager, secret-store-csi, encryption on DB VM disk.                                                                                                                                                          |
| Security (IAM)                                  | GKE workload identity, IAM user + groups. Principle of least privilege, lock down PROD env (apps vs. devops)                                                                                                              |
| Security (Networking, Zero-Trust)               | 1. Firewall rules to control network traffic to VMs (public, private subnets). 2. GKE Network Policies to deny by default. 3. Ambient mesh to support mTLS between pods. 4. Egress Filtering using FQDN Network policies. |
| Security (Container Images)                     | Artifact Registry vulnerability scan (Clair) + Distroless Base Images + SBOMs (trivy)                                                                                                                                     |
| Security (Pod Runtime)                          | Pod security standards (PSS) + Pod security adminssion (PSA) + Security context, Linux capabilities + SeccompProfile                                                                                                      |
| Security (DDOS, Rate-limiting, IP Whitelisting) | GCP Cloud Armor (DDOS + WAF rules)                                                                                                                                                                                        |
| Security (Day 2 Operations)                     | OS Image Patching (Packer), Vulnerability Scans using Wiz to mitigate CVEs. |
| Security (Business Continuity)                  | DB backups across projects with lockdown permissions                        |

## SLO

99.99%
~ 8.6s daily,
~ 1m weekly,
~ 4m monthly,
~ 52m yearly.

## DR Plan
1. RTO (Recovery Time Objective) - The amount of time that can be taken to bring the service back up online.
2. RPO (Recovery Point Objective) - The amount of time where data can be loss.

Same resources & configuration as primary site, e.g LBs, replicas etc. But GKE set to 0 nodes.
1. Bring up DR site first - e.g increase GKE node pools
2. Then switch traffic.

## TODO
1. DR ansible playbook
2. Payment flow diagram with all the stages?


# Architecture (DevOps centralised project)

## GCR

Centralised Artifact registry using DOCKER format with image scanning enabled. (hub and spoke pattern)


# Architecture (Application Projects)

* Split the environment into DEV + PROD project to provide isolation.

## VPC

Both the primary and failover region has one VPC created each.

### Subnets

Each VPC has 2 main subnets - `default` and `gke`. The `gke` subnet has 2 additional secondary IP CIDRs for pods and services.
* Private google access enabled.

### NAT Gateways
* Highly available NAT Gateways with STATIC IPs are provisioned to provide internet access to intethe VPC.
* Route tables are configured accordingly using network tags to route default `0.0.0.0/0` to the NAT Gateways passthrough NLB.


## GKE

A GKE cluster is deployed to provide the container orchestration platform.
* Networking - VPC-Native Cluster, Dataplane V2, Private Control Plane endpoints, Nodes only have private IPs.
* Addons - DNS Cache, HTTP Load Balancing (Gateway API), Cost Allocation
* Workloads Autoscaling - Metrics server and HPA enabled.
* Cluster Autoscaling - Cluster Autoscaler using BALANCED profile, Node Pool with autoscaling enabled.
* Observability - Dataplane V2 Observability enabled, Logging for system components and workloads enabled.



