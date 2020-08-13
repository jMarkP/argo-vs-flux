# argo-vs-flux
Comparing ArgoCD and FluxCD

## What?
Simulating G-Research's Kubernetes workloads and requirements and comparing how ArgoCD and FluxCD might satisfy them.

## Categories for comparison

- Ability to deploy arbitrary k8s resources
- Permissions restricted to specific namespaces
- Elegant handling of deploying to multiple clusters (with possibly different config per cluster)
- Support for custom Git formats
- The ingress question - make it easy to include the cluster's hostname in ingress bindings
- Secrets handling - fill secrets from Vault
- High integrity - deny write access to production namespaces
- User experience
- Metadata - who released what, when
- Metrics
- Alerts - broken releases, out of sync with Git
- Support for emitting events on sync
- Turnkey - how easy it can be deployed to a new environment

## Current status
- ArgoCD test script mostly working
- Investigating Argo's RBAC setup