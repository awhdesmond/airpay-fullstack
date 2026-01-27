# Ambient Mesh

Ambient mesh layers on top of a cloud native environment to transparently enable zero-trust security, observability, and advanced traffic management. An ambient mesh is a service mesh that operates independently of the workloads that are enrolled in it. Compared to a traditional (“sidecar”) service mesh, where a proxy server is injected as a sidecar into your apps and implements all data plane functionality, an ambient mesh splits the functionality related to network routing and transport security (Layer 3 and Layer 4 of the OSI model, generally referred to as “L4”) and the functionality related to HTTP or other application protocols (Layer 7, or “L7”).

```bash
ROOT_DIR=$(git rev-parse --show-toplevel)

pushd ${ROOT_DIR}/platform-infra/gitops-k8s/platform-components/components/ambient-mesh

helm repo add istio https://istio-release.storage.googleapis.com/charts
for chart in base istiod cni ztunnel; do
    helm pull istio/${chart} --untar --untardir temp_charts
    helm template ${chart} \
        temp_charts/${chart} \
        --output-dir base/manifests/${chart} \
        --namespace platform-istio-system \
        --include-crds
    mv base/manifests/${chart}/${chart}/templates base/manifests/${chart}
    rm -rf temp_charts base/manifests/${chart}/${chart}
done

pushd base
kustomize create --autodetect --recursive
popd
popd
```




