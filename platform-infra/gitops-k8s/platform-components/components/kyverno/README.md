# Kyverno

Kyverno (Greek for “govern”) is a cloud native policy engine. It was originally built for Kubernetes and now can also be used outside of Kubernetes clusters as a unified policy language.

Kyverno allows platform engineers to automate security, compliance, and best practices validation and deliver secure self-service to application teams.

```bash
ROOT_DIR=$(git rev-parse --show-toplevel)

pushd ${ROOT_DIR}/platform-infra/gitops-k8s/platform-components/components/kyverno

helm repo add kyverno https://kyverno.github.io/kyverno/
helm fetch \
    --untar \
    --untardir charts \
    kyverno/kyverno

helm template \
    --output-dir base \
    --namespace platform-kyverno \
    --set admissionController.replicas=3 \
    --set backgroundController.replicas=2 \
    --set cleanupController.replicas=2 \
    --set reportsController.replicas=2 \
    --include-crds \
    kyverno \
    charts/kyverno

mv base/kyverno/templates base/
mv base/kyverno/charts base/
rm -rf charts base/kyverno

pushd base
kustomize create --autodetect --recursive
popd
popd
```

