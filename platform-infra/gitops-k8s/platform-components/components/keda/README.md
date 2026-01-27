#  KEDA

KEDA is a Kubernetes-based Event Driven Autoscaler. With KEDA, you can drive the scaling of any container in Kubernetes based on the number of events needing to be processed.

KEDA is a single-purpose and lightweight component that can be added into any Kubernetes cluster. KEDA works alongside standard Kubernetes components like the Horizontal Pod Autoscaler and can extend functionality without overwriting or duplication. With KEDA, you can explicitly map the apps you want to use event-driven scale, with other apps continuing to function. This makes KEDA a flexible and safe option to run alongside any number of any other Kubernetes applications or frameworks.

```bash
ROOT_DIR=$(git rev-parse --show-toplevel)

pushd ${ROOT_DIR}/platform-infra/gitops-k8s/platform-components/components/keda

helm repo add kedacore https://kedacore.github.io/charts
helm pull kedacore/keda --untar --untardir temp_charts
helm template keda \
    temp_charts/keda \
    --output-dir base \
    --namespace platform-monitoring \
    --include-crds

mv base/keda/templates base/
mv base/keda/crds base/
rm -rf temp_charts base/keda

pushd base
kustomize create --autodetect --recursive
popd
popd
```

## References

* https://keda.sigs.k8s.io/getting-started/installation
* https://github.com/GoogleCloudPlatform/keda-provider-gcp/
* https://www.tothenew.com/blog/guide-to-using-secret-manager-with-gke-csi-driver/
