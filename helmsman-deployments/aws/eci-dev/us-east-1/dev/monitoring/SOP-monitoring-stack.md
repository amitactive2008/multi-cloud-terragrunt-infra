# Monitoring Stack SOP (EKS dev)

## Scope
This SOP installs and operates the monitoring stack in EKS dev using Helmsman and an internal ALB.

Components:
- Prometheus
- Grafana
- Alertmanager
- prometheus-blackbox-exporter

Ingress model:
- Internal ALB only (no public internet exposure)
- Single ALB with grouped ingress resources
- Listener ports: 3000 (Grafana), 9090 (Prometheus), 9093 (Alertmanager)

## Files
- DSF: dsf.yaml
- Helmsman values: values/kube-prometheus-stack-values.yaml
- ALB ingress manifest: ingress-monitoring-alb.yaml
- Deployment entrypoint: ../deploy.sh --apply monitoring

## Prerequisites
- kubectl connected to EKS context
- Helmsman installed
- Helm installed
- AWS profile exported
- .env present with ACCOUNT_NAME

Required environment variables:
- KUBE_CONTEXT
- ENVIRONMENT
- AWS_PROFILE
- ACCOUNT_NAME

Manual example:

```bash
cd helmsman-deployments/aws/eci-dev/us-east-1/dev/monitoring
export KUBE_CONTEXT='arn:aws:eks:us-east-1:088317451471:cluster/dev-eks'
export ENVIRONMENT='dev'
export AWS_PROFILE='amit'
export ACCOUNT_NAME='eci-dev'
```

## Installation
Run one command from the dev folder:

```bash
cd helmsman-deployments/aws/eci-dev/us-east-1/dev
./deploy.sh --apply monitoring
```

Manual execution (if you need explicit control):

```bash
cd helmsman-deployments/aws/eci-dev/us-east-1/dev/monitoring
export KUBE_CONTEXT='arn:aws:eks:us-east-1:088317451471:cluster/dev-eks'
export ENVIRONMENT='dev'
export AWS_PROFILE='amit'
export ACCOUNT_NAME='eci-dev'

helmsman --apply -f dsf.yaml
kubectl apply -f ingress-monitoring-alb.yaml
```

What the standard flow does:
1. Applies Helmsman desired state from monitoring/dsf.yaml
2. Applies internal ALB ingress resources from monitoring/ingress-monitoring-alb.yaml
3. Prints ingress status

## Post-Install Verification

```bash
kubectl get pods -n monitoring
kubectl get ingress -n monitoring -o wide
helm ls -n monitoring
```

Expected ingress address pattern:
- internal-<name>.us-east-1.elb.amazonaws.com

## Access Model

### From inside VPC/VPN
Use internal ALB endpoints:
- http://<internal-alb-dns>:3000 (Grafana)
- http://<internal-alb-dns>:9090 (Prometheus)
- http://<internal-alb-dns>:9093 (Alertmanager)

### From outside VPC
Internal ALB is not reachable directly.
Use kubectl port-forward instead:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/prometheus-prometheus 9090:9090
kubectl port-forward -n monitoring svc/prometheus-alertmanager 9093:9093
```

Then access:
- http://localhost:3000
- http://localhost:9090
- http://localhost:9093

## Grafana Login
- Username: admin
- Password is sourced from secret: grafana-admin-secret

Check secret:

```bash
kubectl get secret grafana-admin-secret -n monitoring
```

## Troubleshooting

### Helmsman env variable error
If you see ACCOUNT_NAME unset:
- Ensure .env exists and exports ACCOUNT_NAME
- Or export ACCOUNT_NAME in shell before running deploy.sh

### Ingress not getting ALB address
- Verify AWS Load Balancer Controller is healthy
- Verify ingressClassName is alb
- Verify ingress annotations include:
  - alb.ingress.kubernetes.io/scheme: internal
  - alb.ingress.kubernetes.io/target-type: ip
  - alb.ingress.kubernetes.io/group.name

### ALB not reachable
- Confirm source machine has network path to VPC (VPN/bastion/peering)
- Confirm security groups and NACLs allow required ports

## Upgrade Procedure
1. Update chart values files as needed
2. Re-run:

```bash
./deploy.sh --apply monitoring
```

## Rollback
If chart upgrade fails:

```bash
helm history kube-prometheus-stack -n monitoring
helm rollback kube-prometheus-stack <revision> -n monitoring
```
