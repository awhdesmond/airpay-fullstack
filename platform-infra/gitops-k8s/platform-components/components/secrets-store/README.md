#  Secrets Store CSI Driver

Secrets Store CSI Driver for Kubernetes secrets - Integrates secrets stores with Kubernetes via a Container Storage Interface (CSI) volume.

The Secrets Store CSI Driver secrets-store.csi.k8s.io allows Kubernetes to mount multiple secrets, keys, and certs stored in enterprise-grade external secrets stores into their pods as a volume. Once the Volume is attached, the data in it is mounted into the container’s file system.

```bash
ROOT_DIR=$(git rev-parse --show-toplevel)

pushd ${ROOT_DIR}/platform-infra/gitops-k8s/platform-components/components/secrets-store

helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm pull secrets-store-csi-driver/secrets-store-csi-driver --untar --untardir temp_charts
helm template secrets-store-csi-driver \
    temp_charts/secrets-store-csi-driver \
    --output-dir base \
    --namespace platform-secrets \
    --set syncSecret.enabled=true\
    --include-crds

mv base/secrets-store-csi-driver/templates base/
mv base/secrets-store-csi-driver/crds base/
rm -rf charts base/secrets-store-csi-driver

pushd base
kustomize create --autodetect --recursive
popd
popd
```

## References

* https://secrets-store-csi-driver.sigs.k8s.io/getting-started/installation
* https://github.com/GoogleCloudPlatform/secrets-store-csi-driver-provider-gcp/
* https://www.tothenew.com/blog/guide-to-using-secret-manager-with-gke-csi-driver/
