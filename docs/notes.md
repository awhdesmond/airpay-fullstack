
# Architecture Overview

In designing the infrastructure architecture for **airpay**, we adopt the hub-and-spoke pattern, with a centralised command-and-control project (`project-0-devops`) that hosts centralisd platform services for managing other application or business domain related projects (`project-1-dev-payments`).

Each application or business domain is given two isolated GCP projects - `dev` and `prod`. This provides isolation between the two environments, where the `dev` project can be used to iterate quickly, with less security restrictions, while the `prod` project contains the actual production environment, with more resources as well as security & IAM restrictions.

This design is illustrated in how our `terraform` directory is organized. There is a common set of modules, applicable to any projects, but each project has its own directory and terraform state.

## SLO of 99.99% availability

Availability SLO of 99.99% gives use the following error budget:
* ~ 8.6s daily,
* ~ 1m weekly,
* ~ 4m monthly,
* ~ 52m yearly.

To meet this requirement, our design focuses on leveraging multi-AZs configuration, with multiple replicas, as well as autoscaling capabilties.

# Networking

Each project comes with a default VPC, with 2 default subnets - one in the main region, and another in the failover (disaster recovery) region.

All subnets are private, and they access the public network through a set of Highly-Available NAT Gateway GCE instances (implemented using GCP NLB & Routes). Each NAT Gateway is also provisioned with an unique static public IP. This is a requirement for other vendors to whitelist the IPs from our environment.

By default, all internal nodes are able to communicate with each other, as allowed by a low priority firewall rule.

The VPCs of various application projects are connected to the VPC of the centralised project through VPC peering.

# GKE Clusters

Each project comes with 2 default GKE clusters - one in the main region and the other in the failover region. The GKE cluster has a primary node pool, which has autoscaling enabled, based on the amount of CPU and Memory required by the applications.

**Features of each GKE Cluster:**
1. Regional GKE clusters, with control plane and nodes across multiple AZs.
2. Private nodes and private endpoints. The cluster's control plane can only be accessed by IAP aware proxy.
3. VPC-Native and uses Dataplane V2 (Cilium).
4. Addons - DNS Cache, HTTP Load Balancing, Vertical Pod Autoscaler, Dataplane V2 Metrics, Cost Allocation, Gateway API.
5. Nodes use COS_CONTAINERD which is optimised for running container workloads.

The default node pool of the GKE cluster in the failover region is configured with 0 nodes during normal operations. During disaster recovery, the team can increase the number of nodes to scale up the cluster (NOTE: we will still deploy the kubernetes manifests in both main and failover region).

## Autoscaling

We enabled Cluster Autoscaler for our GKE cluster, and configured the min and max number of nodes in the default node pool.

## Platform Components of each GKE cluster
Platform components provide foundational cluster-level functionalities and capabilities to support services deployed by product developers. Thses are mainly found in `platform-infra/gitops-k8s/platform-components`.

### secrets-store-csi

`platform-infra/gitops-k8s/platform-components/setups/02-secrets-store`.

Secrets Store CSI Driver for Kubernetes secrets - Integrates secrets stores with Kubernetes via a Container Storage Interface (CSI) volume.

The Secrets Store CSI Driver secrets-store.csi.k8s.io allows Kubernetes to mount multiple secrets, keys, and certs stored in enterprise-grade external secrets stores into their pods as a volume. Once the Volume is attached, the data in it is mounted into the container’s file system.

### cert-manager

`platform-infra/gitops-k8s/platform-components/setups/03-cert-manager`.

cert-manager creates TLS certificates for workloads in your Kubernetes or OpenShift cluster and renews the certificates before they expire.

cert-manager can obtain certificates from a variety of certificate authorities, including: Let's Encrypt, HashiCorp Vault, CyberArk Certificate Manager and private PKI.

### Gateways

`platform-infra/gitops-k8s/platform-components/setups/04-gateways`.

Each cluster has a set of common ingress gateways used to accept traffic from clients outside of the cluster. The first is an external gateway, that is used to accept traffic from the public network. The second is an internal gateway, that is used to accept traffic from internal services outside of the cluster.

The Gateways are provisioned using the Gateway API, and multiple services can share common gateways using HTTPRoutes.

#### Kgateway

Kgateway is the most mature and widely deployed gateway in the market today. Built on open source and open standards, kgateway is a dual control plane that implements the Kubernetes Gateway API for both Envoy and agentgateway. This unique architecture enables kgateway to provide unified API connectivity spanning from traditional HTTP/gRPC workloads to advanced AI agent orchestration.

Both the external and internal clusters are provisioned using `kgateway` GatewayClass.

#### GCP External L7 Application Load Balancers

In addition to Kgateway, we also provision one common GCP external L7 application load balancer. This is to support adding cloud armor rate-limitng and WAF rules for better network security.

#### TLS Certificates

It is assumed that we will purchase our own TLS certificates from a reputable vendor such as DigiCert. We can purchase a wildcard certificate for `*.airpay.com` which can be provisioned into the cluster by saving them in a secret manager and using an in-cluster operator to rotate them as kubernetes secrets.

### Kyverno

`platform-infra/gitops-k8s/platform-components/setups/05-kyverno`.

Kyverno (Greek for “govern”) is a cloud native policy engine. It was originally built for Kubernetes and now can also be used outside of Kubernetes clusters as a unified policy language. Kyverno allows platform engineers to automate security, compliance, and best practices validation and deliver secure self-service to application teams.

Kyverno allows us to use ClusterPolicy for deploying the default NetworkPolicies and label the namespace to follow pod security policies, plus be added to the ambient mesh, whenever a new namespace is created.

#### Default Network Policies

The default network policies deny pods from accessing the public network. It also only allows access to certain components in the cluster, such as DNS, ztunnels, and kubelet.

### Ambient Mesh

`platform-infra/gitops-k8s/platform-components/setups/06-ambient-mesh`.

Ambient mesh layers on top of a cloud native environment to transparently enable zero-trust security, observability, and advanced traffic management. An ambient mesh is a service mesh that operates independently of the workloads that are enrolled in it.

We mainly deploy ambient mesh to leverage its L4 capabilities using ztunnel to facilitate mTLS communication between pods in the cluster, for added network security.

### Monitoring Components

`platform-infra/gitops-k8s/platform-components/setups/07-monitoring`.

Each cluster also comes with a set of monitoring-related components.

#### Kube-state-metrics

kube-state-metrics (KSM) is an add-on agent that listens to the Kubernetes API server and generates metrics about the state of the various objects within the cluster, such as Pods, Deployments, and Nodes. These metrics are exported in a raw, un-modified Prometheus format, allowing external monitoring systems like Prometheus and Grafana to collect and analyze them.

#### OTel Collector

The OpenTelemetry Collector offers a vendor-agnostic implementation of how to receive, process and export telemetry data. It removes the need to run, operate, and maintain multiple agents/collectors. This works with improved scalability and supports open source observability data formats (e.g. Jaeger, Prometheus, Fluent Bit, etc.) sending to one or more open source or commercial backends.

The OTel collector scrapes prometheus metrics from services, pods and remote writes them to Thanos Receiver, in the centralised cluster.

#### Keda

KEDA is a Kubernetes-based Event Driven Autoscaler. With KEDA, you can drive the scaling of any container in Kubernetes based on the number of events needing to be processed.

KEDA queries Thanos querier to activate various triggers for scaling workloads based on application metrics.

> In addition to HPA, Keda, the GKE cluster also has VPA enabled, and while VPA scales the pods based on CPU and memory utilisation, Keda scales the number of replicas using application-level metrics, providing multi-dimensional scaling capabilities.

# Centralised Cluster, CI/CD and GitOps

To manage all the other business domain clusters, we adopt a hub-and-spoke design, where there will be a central command-and-control environment `project-0-devops`, providing platform services to manage applications across our entire infrastructure.

We adopt Infrastructure-as-Code practice, using GitOps to provision applications, cloud resources into our environment.

## ArgoCD

* `platform-infra/gitops-k8s/devops-components/setups/01-argocd`

ArgoCD provides a GitOps platform for us, as well as developers to deploy applications and components to multiple clusters. We mainly use ApplicationSet to deploy the platform components described above into all the other GKE clusters, including the DevOps GKE cluster itself.

## Atlantis & Terraform

* `platform-infra/gitops-k8s/devops-components/components/atlantis/prod/repo-config.yaml`
* `platform-infra/cloud-ops/project-0-devops/main.tf` -> `4. Atlantis`

Atlantis is an application for automating Terraform via pull requests. It is deployed as a standalone application into your infrastructure. No third-party has access to your credentials. Atlantis listens for GitHub, GitLab or Bitbucket webhooks about Terraform pull requests. It then runs `terraform plan` and comments with the output back on the pull request. When you want to apply, comment `atlantis apply` on the pull request and Atlantis will run `terraform apply` and comment back with the output.

We leverage on service account impersonation when running Atlantis. The atlantis pod maps to the `atlantis-broker` GCP IAM service account, who has the ability to impersonate either the `atlantis-deployer-dev` or `atlantis-deployer-prod` GCP IAM service account. Those deployer accounts are given the neccessary IAM permissions in different GCP projects to provision various cloud resources.

## Monitoring Components

* `platform-infra/gitops-k8s/devops-components/setups/03-monitoring`

The centralised DevOps cluster also hosts several centralised monitoring components.

### Thanos

We provision centralised thanos receivers to collect metrics from the OTel collectors (in every GKE cluster) and save them to a GCS bucket. There is also a Thanos Querier as well as Store Gateway for querying the saved metrics.

### Grafana

Grafana is provisioned to visualise the metrics, and uses the Thanos Querier as datasource.

# Databases

The design of the database cluster and provisioning takes into account the tradeoff between consistency (correctness) and latency (performance), as well as costs.

## Database Cluster

* `platform-infra/cloud-ops/modules/gcp/db_cluster/main.tf`

The default setup include 1 primary instance, 2 read replicas, 1 backup read replica (smaller machine type) in the same region, but different AZs, as well as 1 read replica in a different region for failover.

The primary instance synchronously replicates to the read replicas (since they are in the same region, the latency should be acceptable), while asynchronously replicating to the read replica in the failover region.

During the provisioning, the db passwords are generated randomly and saved into GCP secret manager, where they will be read by the secret-store CSI provisioned in every cluster, using the Workload Identity federation permission of the GCP IAM Service account binded to the GKE service account.

Each database cluster also includes 1 network load balancer for the primary and 1 network load balancer for the read replicas (except the backup).

We also run backup cloudrunner jobs every 15 minutes to create a snapshot of the postgres data disk to meet the RPO requirements.

## Ansible `db-ops`

While Terraform provisions the necessary cloud resources for the database cluster, the Ansible playbooks and roles in `db-ops` installs etcd, postgres and patroni onto the provisioned VM instances.

We use Ansible `gcp_compute` plugin to discover the DB hosts, setup the disks and filesystems, before installing etcd, postgres and patroni services.

## Regional Failover

In the event of a disaster recovery scenario, we can disable the `standby_cluster` configuration in patroni to promote the failover replica to become a primary instance.

# Application

`payments-api` contains a small Golang program to simulate a payment service.

**Reliability Features:**
* Structured logging to stdout
* Using environment variables for configuration
* Expose application-level metrics for KEDA scaling.
* Contains a health endpoint for liveness/readiness probes.

* `payments-app-gitops-k8s` contains the GitOps manifests for deploying payments to GKE cluster.

**Reliability Features:**
* PodAntiAffinity to spread pods across different nodes
* TopologicalSpreadConstraints to spread pods across availability zones
* PodDisruptionBudget to maintain a minimum number of replicas during voluntary disruptions
* HTTPRoutes to expose API to public network via Gateway (with TLS)
* VerticalPodAutoscaler for right-sizing the pods.
* Keda ScaledObject for scaling the deployment based on application-level metrics (e.g number of requests per pod)
* Guranteed QoS where requests == limits
* Liveness probes and readiness probe configured.

**Security Features:**
* securityContext preventing containers from running as root user, default seccomp profile and dropping all linux capabilities, and preventing privilege escalation.
* Multi-staged builds using distroless images.
* GCR has vulnerability scanning enabled.


# Disaster Recovery Runbook

**Key Idea:** DR Site has parity as primary site, including GKE manifests, cloud resources e.g LBs.

* RTO (Recovery Time Objective) - The amount of time that can be taken to bring the service back up online. Aiming about 40mins.
* RPO (Recovery Point Objective) - The amount of time where data can be loss. Should be less than 15mins due to asynchronous replication from primary to failover cluster.

1. [30mins] Bring up DR site applications - Increase GKE node pools node count on Terraform.
2. [30mins, in parallel with 1] Bring up DR site databases - Run `db-ops/play-db-failover` for all databases.
3. [10mins] Switch DNS configuration of the domain names from primary site to disaster recovery site, using DNS or CDN provider platform.

# TODO

1. Regular & automated OS patching for all GCE VM instances (DBs, NAT Gateways).
2. DB backups across projects with lockdown permissions.
3. Observability - Traces
4. Synthetic probes, attempts $1.00 dollar transactions to verify full payment flow.
5. Redis Cache (write through) Use this for high-speed balance checks and idempotency keys (deduplication) with a write-through strategy to ensure data integrity.
6. Resource Quotas (~20%) for platform components. LimitRanges for application namespaces.
7. SBOMs and workload attestations.
8. More work on IAM, integrating DevOps components to GCP IAM, Google Groups SSO.
9. Bastion host to access private GKE endpoints, with IAP-aware proxy.
