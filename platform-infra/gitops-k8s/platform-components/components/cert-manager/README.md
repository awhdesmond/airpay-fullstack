#  cert-manager

cert-manager creates TLS certificates for workloads in your Kubernetes or OpenShift cluster and renews the certificates before they expire.

cert-manager can obtain certificates from a variety of certificate authorities, including: Let's Encrypt, HashiCorp Vault, CyberArk Certificate Manager and private PKI.

With cert-manager's Certificate resource, the private key and certificate are stored in a Kubernetes Secret which is mounted by an application Pod or used by an Ingress controller. With csi-driver, csi-driver-spiffe, or istio-csr , the private key is generated on-demand, before the application starts up; the private key never leaves the node and it is not stored in a Kubernetes Secret.


```bash
ROOT_DIR=$(git rev-parse --show-toplevel)

pushd ${ROOT_DIR}/platform-infra/gitops-k8s/platform-components/components/cert-manager

helm template cert-manager \
    --version v1.19.2 \
    --namespace platform-certs \
    --output-dir ./charts \
    --set config.apiVersion="controller.config.cert-manager.io/v1alpha1" \
    --set config.kind="ControllerConfiguration" \
    --set config.enableGatewayAPI=true \
    --set crds.enabled=true \
    oci://quay.io/jetstack/charts/cert-manager

mv charts/cert-manager/templates base/
rm -rf charts

pushd base
kustomize create --autodetect --recursive
popd
popd
```

## References

* https://cert-manager.sigs.k8s.io/getting-started/installation
* https://cert-manager.io/docs/usage/gateway/
