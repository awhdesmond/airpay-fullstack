# kgateway

Kgateway is the most mature and widely deployed gateway in the market today. Built on open source and open standards, kgateway is a dual control plane that implements the Kubernetes Gateway API for both Envoy and agentgateway. This unique architecture enables kgateway to provide unified API connectivity spanning from traditional HTTP/gRPC workloads to advanced AI agent orchestration.

With a control plane that scales from lightweight microgateway deployments between services, to massively parallel centralized gateways handling billions of API calls, to advanced AI gateway use cases for safety, security, and governance, kgateway brings omni-directional API connectivity to any cloud and any environment.

Kgateway is designed for:

* Advanced Ingress Controller and Next-Gen API Gateway: Aggregate web APIs and apply functions like authentication, authorization and rate limiting in one place. Powered by Envoy or agentgateway and programmed with the Gateway API, kgateway is a world-leading Cloud Native ingress.

* AI Gateway for LLM Consumption: Protect models, tools, agents, and data from inappropriate access. Manage traffic to LLM providers, enrich prompts at a system level, and apply prompt guards for safety and compliance.

* Inference Gateway for Generative Models: Intelligently route to AI inference workloads in Kubernetes environments utilizing the Inference Extension project.

* Native MCP and Agent-to-Agent Gateway: Federate Model Context Protocol tool services and secure agent-to-agent communications with a single scalable endpoint powered by agentgateway.

* Hybrid Application Migration: Route to backends implemented as microservices, serverless functions or legacy apps. Gradually migrate from legacy code while maintaining existing systems.

```bash
ROOT_DIR=$(git rev-parse --show-toplevel)

pushd ${ROOT_DIR}/platform-infra/gitops-k8s/platform-components/components/kgateway

helm template kgateway-crds \
    --version v2.1.2 \
    --output-dir ./charts \
    oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds

helm template \
    --version v2.1.2 \
    --namespace platform-gateways \
    --output-dir ./charts \
    kgateway \
    oci://cr.kgateway.dev/kgateway-dev/charts/kgateway

mv charts/kgateway/templates base/
rm -rf charts

pushd base
kustomize create --autodetect --recursive
popd
popd
```

# References

* https://kgateway.dev/docs/envoy/latest/install/helm/
* https://kgateway.dev/docs/envoy/latest/integrations/external-dns-cert-manager/
* https://cert-manager.io/docs/configuration/acme/http01/
