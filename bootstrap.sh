#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="fyxt-local"
ARGOCD_NAMESPACE="argocd"
APP_IMAGE="fyxt-demo:1.0"

echo "==> Creating kind cluster: ${CLUSTER_NAME}"

if kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  echo "Cluster ${CLUSTER_NAME} already exists."
else
  kind create cluster --name "${CLUSTER_NAME}"
fi

echo "==> Building application image"

docker build -t "${APP_IMAGE}" ./app

echo "==> Loading image into kind"

kind load docker-image "${APP_IMAGE}" --name "${CLUSTER_NAME}"

echo "==> Installing Metrics Server"

kubectl apply \
  -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo "==> Configuring Metrics Server for kind"

kubectl patch deployment metrics-server \
  -n kube-system \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

echo "==> Waiting for Metrics Server"

kubectl rollout status \
  deployment/metrics-server \
  -n kube-system \
  --timeout=180s

echo "==> Installing ArgoCD"

kubectl create namespace "${ARGOCD_NAMESPACE}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply \
  -n "${ARGOCD_NAMESPACE}" \
  --server-side \
  --force-conflicts \
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
echo "Metrics Server:"
kubectl get pods -n kube-system -l k8s-app=metrics-server

echo
echo "ArgoCD pods:"
kubectl get pods -n "${ARGOCD_NAMESPACE}"

echo
echo "Applications:"
kubectl get applications -n "${ARGOCD_NAMESPACE}"
