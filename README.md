# Fyxt — Local GitOps + Kubernetes Take-Home

## Overview

This repository implements a local GitOps deployment for the Fyxt DevOps Engineer take-home exercise.

The solution demonstrates:

- Kind for a local Kubernetes cluster
- ArgoCD for GitOps continuous delivery
- Helm for Kubernetes application packaging
- Separate `staging` and `production` namespaces
- Kubernetes HPA for production
- Kubernetes Secrets for application configuration
- Metrics Server for resource metrics and HPA
- Kubernetes startup, readiness and liveness probes
- CPU and memory resource requests and limits
- A small Python Flask application
- A non-root application container

The application is deployed to both staging and production on the same Kubernetes cluster.

---

## Architecture

The solution consists of:

1. A local Kind Kubernetes cluster
2. ArgoCD running in the `argocd` namespace
3. A `staging` namespace containing the staging application
4. A `production` namespace containing the production application
5. A Git repository containing the application, Helm chart and ArgoCD Application manifests
6. Metrics Server providing CPU metrics for the production HPA

### Architecture Flow

```text
Developer
   |
   | git push
   v
GitHub Repository
   |
   v
ArgoCD Root Application
   |
   +----------------------+----------------------+
   |                                             |
   v                                             v
Staging Application                       Production Application
   |                                             |
   v                                             v
staging namespace                         production namespace
   |                                             |
   v                                             v
1 application pod                         3 application pods
                                                 |
                                                 v
                                                HPA
                                             3 -> 6 pods

ArgoCD continuously monitors the Git repository and reconciles the desired Kubernetes state.

The staging and production applications use the same Helm chart with different environment-specific values.

The Kubernetes Service is configured as ClusterIP, so the application is not directly exposed outside the cluster.

For local testing, the production service can be accessed using kubectl port-forward.

## Repository Structure
fyxt-take-home/
├── app/
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── bootstrap.sh
├── gitops/
│   ├── root-app.yaml
│   ├── staging.yaml
│   └── production.yaml
├── helm/
│   └── fyxt-app/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-staging.yaml
│       ├── values-production.yaml
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── hpa.yaml
│           ├── secret.yaml
│           └── _helpers.tpl
└── README.md
### Key Components
app/ — Flask application and Dockerfile.
bootstrap.sh — Creates the local Kind cluster and installs the required platform components.
gitops/ — ArgoCD Application manifests implementing the GitOps model.
helm/fyxt-app/ — Reusable Helm chart containing the Kubernetes resources.
values-staging.yaml — Staging-specific configuration.
values-production.yaml — Production-specific configuration.
## Prerequisites

The following tools are required:

Docker Desktop
WSL2
Kind
kubectl
Helm
Git

Docker Desktop must be running before executing the bootstrap script.

### Verify the tools
docker --version
kubectl version --client
kind version
helm version
git --version
### Verify Docker connectivity
docker info

The commands above confirm that the required CLI tools are installed and that Docker is accessible from the WSL environment.

## How to Run
### 1. Clone the repository
git clone https://github.com/maligitpractice/fyxt-take-home.git
cd fyxt-take-home
### 2. Make the bootstrap script executable
chmod +x bootstrap.sh
### 3. Run the bootstrap script
./bootstrap.sh

The bootstrap script performs the following steps:

Creates the Kind cluster if it does not already exist.
Builds the application Docker image as fyxt-demo:1.0.
Loads the image into the Kind cluster.
Installs Metrics Server.
Configures Metrics Server for the Kind environment.
Installs ArgoCD.
Waits for ArgoCD to become available.
Applies the ArgoCD root Application.
Displays Metrics Server, ArgoCD and Application status.

After the initial bootstrap, ArgoCD manages the application resources through GitOps.

## Verify the Cluster
### Check the Kubernetes nodes
kubectl get nodes

Expected:

NAME                       STATUS   ROLES           AGE   VERSION
fyxt-local-control-plane   Ready    control-plane   ...   v1.35.0

The exact Kubernetes version may vary depending on the Kind node image.

### Check the cluster context
kubectl config current-context

Expected:

kind-fyxt-local
## Verify ArgoCD
### Check ArgoCD pods
kubectl get pods -n argocd

All ArgoCD components should eventually reach the Running state.

### Check ArgoCD Applications
kubectl get applications -n argocd

Expected applications include:

NAME              SYNC STATUS   HEALTH STATUS
fyxt-production   Synced        Healthy
fyxt-root         Synced        Healthy
fyxt-staging      Synced        Healthy

The exact output may vary while ArgoCD is synchronizing.

The fyxt-root Application follows the ArgoCD app-of-apps pattern.

The root Application points to the gitops/ directory, which contains the staging and production Application definitions.

## Verify Staging
### Check staging pods
kubectl get pods -n staging

Expected:

One application pod
Pod status should be Running
Readiness should be successful
### Check staging deployment
kubectl get deployment -n staging
### Check staging service
kubectl get service -n staging

The staging Service uses the ClusterIP service type.

## Verify Production
### Check production pods
kubectl get pods -n production

Expected:

Three application pods
Pods should be Running
Readiness probes should be successful
### Check production deployment
kubectl get deployment -n production
### Check production service
kubectl get service -n production

The production Service uses the ClusterIP service type.

### Check the production HPA
kubectl get hpa -n production

The production HPA is configured with:

Minimum replicas: 3
Maximum replicas: 6
CPU target: 70%
## Metrics Server

Metrics Server provides resource metrics required by the production HPA.

### Check Metrics Server
kubectl get pods -n kube-system | grep metrics
### Check CPU and memory metrics
kubectl top pods -n production

Metrics should be available after Metrics Server has started successfully.

## Application

The Flask application exposes the following endpoints.

### Application endpoints
/
/health

The /health endpoint is used by the Kubernetes startup, readiness and liveness probes.

### Application response

The root endpoint returns application information similar to:

{
  "application": "fyxt-demo",
  "environment": "production",
  "log_level": "info",
  "secret_configured": true,
  "message": "Hello from Fyxt GitOps"
}
## Testing the Application
### Port-forward the production service
kubectl port-forward svc/fyxt-production-fyxt-app 8080:80 -n production

Keep the port-forward process running.

### Test the health endpoint

In another terminal:

curl http://localhost:8080/health

Expected:

OK
### Test the application endpoint
curl http://localhost:8080/

The response should contain the application name, environment and GitOps message.

## Helm vs Kustomize

Helm was selected because staging and production share the same application structure while requiring different configuration.

The reusable Helm chart contains the Kubernetes resources, while environment-specific values are maintained separately.

This avoids duplicating Kubernetes manifests and makes environment differences explicit.

Kustomize would also be a valid option, especially when the primary requirement is patching or overlaying Kubernetes manifests.

## Environment Configuration

The same Helm chart is used for both environments.

### Staging

Staging uses:

helm/fyxt-app/values-staging.yaml

The staging environment is configured with one application replica.

### Production

Production uses:

helm/fyxt-app/values-production.yaml

The production environment is configured with three replicas and an HPA that can scale the application up to six replicas.

## Resource Requests and Limits

Resource requests and limits are defined in the Helm configuration.

### Requests

CPU and memory requests allow Kubernetes to determine the resources required by each application pod.

### Limits

CPU and memory limits provide boundaries for resource consumption by the application containers.

### Environment-specific resources

Staging and production can use different resource and replica configurations through their respective values files.

Production is configured for higher availability and horizontal scaling.

## Kubernetes Probes

The application Deployment defines startup, readiness and liveness probes.

### Startup Probe

The startup probe allows the container time to start before Kubernetes begins evaluating the other health checks.

### Readiness Probe

The readiness probe determines whether the application is ready to receive traffic.

### Liveness Probe

The liveness probe helps Kubernetes detect an unhealthy application container and restart it when necessary.

All three probes use the /health endpoint.

## Container Security

The application container is configured to run as a non-root user.

This follows the principle of least privilege and reduces the security impact of a potential container compromise.

The container image also uses a lightweight Python base image.

## Secrets

Application configuration that should not be hard-coded into the application is provided through a Kubernetes Secret.

The Helm chart creates the required Secret and exposes the configuration to the application through Kubernetes environment variables.

### Production Secret Management

For this local exercise, Kubernetes Secrets are used to demonstrate secret injection.

In a production environment, sensitive values should be managed using a dedicated secret-management solution such as AWS Secrets Manager, AWS Systems Manager Parameter Store, or an external secrets operator.

Secrets should not be committed as plain-text credentials to Git.

## GitOps Model

The repository follows a GitOps model where Git represents the desired state of the Kubernetes environment.

### Root Application

The gitops/root-app.yaml file defines the ArgoCD root Application.

The root Application points ArgoCD to the gitops/ directory.

### Environment Applications

The gitops/staging.yaml and gitops/production.yaml files define the staging and production ArgoCD Applications.

Each environment Application references the same Helm chart with different values files.

### GitOps Flow
Developer
   |
   | Commit and push
   v
Git Repository
   |
   v
ArgoCD
   |
   +------------------+
   |                  |
   v                  v
Staging            Production
   |                  |
   v                  v
Helm Release       Helm Release
   |                  |
   v                  v
Kubernetes         Kubernetes

ArgoCD continuously reconciles the Kubernetes resources with the desired state stored in Git.

## Sync Policy

ArgoCD uses automated synchronization for the environment Applications.

### Automated Sync

When changes are committed to the configured Git path, ArgoCD can automatically synchronize the Kubernetes resources.

### Prune

Pruning allows ArgoCD to remove Kubernetes resources that no longer exist in the desired Git state.

### Self-Heal

Self-healing allows ArgoCD to restore resources when the live Kubernetes state is changed manually and differs from the desired Git state.

This helps maintain Git as the source of truth.

## Promotion Flow

The environment configuration supports a simple promotion model.

### Typical Flow
Developer change
      |
      v
Git commit
      |
      v
### Staging
      |
      | Validation
      v
### Production
### Local Exercise

For this local take-home exercise, both staging and production Applications are defined in Git and reconciled by ArgoCD.

The environments use separate values files while sharing the same Helm chart.

## Production Considerations
### What Would Be Different in Production?

A production implementation would typically include:

Managed Kubernetes such as Amazon EKS instead of Kind
Private container registry such as Amazon ECR
CI pipelines for automated image builds and testing
Image vulnerability scanning
External secret management
TLS and ingress configuration
Centralized logging
Prometheus and Grafana or managed monitoring
Network policies
Role-based access control
High availability across multiple nodes or availability zones
Automated backups and disaster recovery
Resource quotas and namespace policies
Controlled promotion workflows

The local exercise intentionally focuses on demonstrating the core GitOps and Kubernetes workflow.

## Troubleshooting & Cleanup
### Common Checks

Check cluster status:

kubectl get nodes

Check all application resources:

kubectl get all -n staging
kubectl get all -n production

Check ArgoCD Applications:

kubectl get applications -n argocd

Check application logs:

kubectl logs -n production deployment/fyxt-production-fyxt-app

Check HPA:

kubectl get hpa -n production

Check resource metrics:

kubectl top pods -n production
### Re-run Bootstrap

If troubleshooting requires recreating the local environment:

kind delete cluster --name fyxt-local
./bootstrap.sh
### Delete the Local Cluster
kind delete cluster --name fyxt-local

This removes the local Kubernetes cluster and its resources.

## Final Verification
### Check Git status
git status
### Check ArgoCD Applications
kubectl get applications -n argocd
Check staging
kubectl get pods -n staging
Check production
kubectl get pods -n production
Check production HPA
kubectl get hpa -n production
### Check Metrics Server
kubectl top pods -n production
## Take-Home Summary

This implementation demonstrates:

Local Kubernetes using Kind
GitOps using ArgoCD
Helm-based application packaging
Staging and production environment separation
Automated ArgoCD synchronization
HPA-based production scaling
Kubernetes health probes
CPU and memory resource management
Kubernetes Secret usage
Non-root container execution
Local Docker image workflow

