# gitops-k8s
Gitops repository for K8s platform components in DevOps Cluster.

## Devops Components

Devops components are centralised services provided by the DevOps/Platform team. They live in the devops cluster.

| Component         | Namespace         |
|-------------------|-------------------|
| ArgoCD            | platform-argocd   |
| Atlantis          | platform-atlantis |
| Kgateway          | platform-gateways |
| Secrets Store CSI | platform-secrets  |
| cert-manager      | platform-certs    |


## Platform Components

Platform components provide foundational cluster-level functionalities and capabilities to support services deployed by product teams. They are deployed in every cluster.

| Component         | Namespace         |
|-------------------|-------------------|
| Kgateway          | platform-gateways |
| Secrets Store CSI | platform-secrets  |
| cert-manager      | platform-certs    |
| kyverno           | platform-kyverno    |
| ambient-mesh      | platform-istio-system    |

`components/*`

* k8s manifests for deploying a platform component.
* Sub-directories indicates which environment to deploy.

`setups/*`

* Setups are groups of related components that should be deployed together to provide some functionality.
* Provides an ordering for deploying the components.
