#!/usr/bin/env bash
set -aeuo pipefail

echo "Running setup.sh"
echo "Waiting until configuration package is healthy/installed..."
${KUBECTL} wait configuration.pkg platform-ref-apigateway --for=condition=Healthy --timeout 5m
${KUBECTL} wait configuration.pkg platform-ref-apigateway --for=condition=Installed --timeout 5m

echo "Creating cloud credential secret..."
${KUBECTL} -n upbound-system create secret generic aws-creds --from-literal=credentials="${UPTEST_CLOUD_CREDENTIALS}" \
    --dry-run=client -o yaml | ${KUBECTL} apply -f -

echo "Waiting until provider-aws is healthy..."
${KUBECTL} wait provider.pkg upbound-provider-aws --for condition=Healthy --timeout 5m

echo "Waiting for all pods to come online..."
"${KUBECTL}" -n upbound-system wait --for=condition=Available deployment --all --timeout=5m

echo "Waiting for all XRDs to be established..."
kubectl wait xrd --all --for condition=Established

echo "Creating a default aws provider config..."
cat <<EOF | ${KUBECTL} apply -f -
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    secretRef:
      key: credentials
      name: aws-creds
      namespace: upbound-system
    source: Secret
EOF

echo "Creating provider-helm config..."
cat <<EOF | ${KUBECTL} apply -f -
apiVersion: helm.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: in-cluster
spec:
  credentials:
    source: InjectedIdentity
EOF

function getProviderSA() {
  ${KUBECTL} -n upbound-system get sa -o name | grep "$1" | sed -e 's|serviceaccount\/|upbound-system:|g'
}

SA=$(getProviderSA provider-helm)
${KUBECTL} create clusterrolebinding provider-helm-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}" --dry-run=client  -o yaml | ${KUBECTL} apply -f -
echo "Creating provider-kubernetes config..."
cat <<EOF | ${KUBECTL} apply -f -
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
EOF
SA=$(getProviderSA provider-kubernetes)
${KUBECTL} create clusterrolebinding provider-kubernetes-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}" --dry-run=client  -o yaml | ${KUBECTL} apply -f -
