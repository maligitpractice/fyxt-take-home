#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="fyxt-local"
ARGOCD_NAMESPACE="argocd"

echo "==> Creating kind cluster: ${CLUSTER_NAME}"

if kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  echo "Cluster ${CLUSTER_NAME} already exists."
else
  kind create cluster --name "${CLUSTER_NAME}"
fi

echo "==> Building application image"

docker build -t fyxt-demo:1.0 ./app

echo "==> Loading image into kind"

kind load docker-image fyxt-demo:1.0 --name "${CLUSTER_NAME}"

echo "==> Installing ArgoCD"

kubectl create namespace "${ARGOCD_NAMESPACE}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n "${ARGOCD_NAMESPACE}" --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "==> Waiting for ArgoCD server"

kubectl wait \
  --namespace "${ARGOCD_NAMESPACE}" \
  --for=condition=Available \
  deployment/argocd-server \
  --timeout=180s

echo "==> Applying root Application"

kubectl apply -f gitops/root-app.yaml

echo "==> Bootstrap complete"

echo
echo "ArgoCD pods:"
kubectl get pods -n "${ARGOCD_NAMESPACE}"

echo
echo "Applications:"
kubectl get applications -n "${ARGOCD_NAMESPACE}"
