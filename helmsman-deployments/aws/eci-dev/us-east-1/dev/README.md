# Helmsman Deployments — AWS / eci-dev / us-east-1 / dev

## Overview

This directory mirrors the structure of `terragrunt/aws/eci-dev/us-east-1/dev/`
but manages **Helm chart deployments** via [Helmsman](https://github.com/Praqma/helmsman)
instead of Terraform resources.

```
dev/
├── env.env                  # environment variables (cluster, domain, etc.)
├── deploy.sh                # single entry-point to deploy all components
├── ingress-controllers/
│   ├── dsf.yaml             # NGINX + HAProxy + Kong ingress controllers
│   ├── .env                 # component-level env overrides
│   └── values/
│       ├── nginx-values.yaml
│       ├── haproxy-values.yaml
│       └── kong-values.yaml
├── monitoring/
│   ├── dsf.yaml             # Helmsman Desired State File
│   ├── .env                 # component-level env overrides
│   ├── ingress-monitoring-alb.yaml  # internal ALB ingress (single ALB, multi-port)
│   ├── SOP-monitoring-stack.md      # install/use SOP for monitoring stack
│   └── values/
│       ├── kube-prometheus-stack-values.yaml
│       └── blackbox-exporter-values.yaml
├── autoscaling/
│   ├── dsf.yaml
│   ├── .env
│   └── values/
│       ├── vpa-values.yaml
│       └── prometheus-adapter-values.yaml
└── external-dns/
    ├── dsf.yaml
    ├── .env
    └── values/
        └── external-dns-values.yaml
```

## Components Deployed

| Component | Helm Chart | Namespace | Purpose |
|---|---|---|---|
| NGINX Ingress | `ingress-nginx/ingress-nginx` | `ingress-nginx` | Default IngressClass, AWS NLB |
| HAProxy Ingress | `haproxytech/kubernetes-ingress` | `haproxy-controller` | Opt-in IngressClass `haproxy` |
| Kong Ingress | `kong/kong` | `kong` | Opt-in IngressClass `kong`, API Gateway |
| Prometheus | `prometheus-community/kube-prometheus-stack` | `monitoring` | Metrics collection & storage |
| Grafana | bundled in `kube-prometheus-stack` | `monitoring` | Metrics visualization |
| Alertmanager | bundled in `kube-prometheus-stack` | `monitoring` | Alert routing |
| Blackbox Exporter | `prometheus-community/prometheus-blackbox-exporter` | `monitoring` | HTTP/TCP/ICMP endpoint probing |
| VPA | `fairwinds-stable/vpa` | `kube-system` | Vertical Pod Autoscaler |
| Prometheus Adapter | `prometheus-community/prometheus-adapter` | `monitoring` | Custom metrics API for HPA |
| ExternalDNS | `external-dns/external-dns` | `external-dns` | Route53 DNS sync |

> **HPA** (Horizontal Pod Autoscaler) is a native Kubernetes controller — no Helm
> chart is required. CPU/memory HPA works out-of-the-box once `metrics-server` is
> running (already deployed via `terragrunt/.../eks-addons/core`). For custom
> metric HPA, use `Prometheus Adapter` (included above).

## Prerequisites

1. **Helmsman binary**
   ```bash
   brew install helmsman
   ```

2. **kubeconfig updated**
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name dev-eks --profile jenkins
   
   or

   aws eks update-kubeconfig --region us-east-1 --name dev-eks --role-arn arn:aws:iam::088317451471:role/dev-eks-devops-group-EKSAdminFullAccessRole --profile amit
   ```

3. **Grafana admin secret** (one-time):
   ```bash
   kubectl create secret generic grafana-admin-secret \
     --namespace monitoring \
     --from-literal=admin-user=admin \
     --from-literal=admin-password=<your-password>
   ```

4. **IAM Role for ExternalDNS** — Create an IAM role
   `arn:aws:iam::088317451471:role/external-dns-dev` with Route53 write permissions
   and register it with EKS Pod Identity (same pattern as `pod-identity-s3` in Terraform).

## Usage

```bash
cd helmsman-deployments/aws/eci-dev/us-east-1/dev

# Dry-run all components (default)
./deploy.sh

# Apply all components
./deploy.sh --apply

# Apply a single component
./deploy.sh --apply ingress-controllers
./deploy.sh --apply monitoring
./deploy.sh --apply autoscaling
./deploy.sh --apply external-dns

# Destroy a single component
./deploy.sh --destroy monitoring
```

Monitoring flow notes:
- `./deploy.sh --apply monitoring` now performs two steps:
   1. Helmsman apply for monitoring charts (`monitoring/dsf.yaml`)
   2. Internal ALB ingress apply (`monitoring/ingress-monitoring-alb.yaml`)
- `./deploy.sh --destroy monitoring` removes both charts and internal ALB ingress.

SOP:
- See `monitoring/SOP-monitoring-stack.md` for full install, verification, and access guidance.

## Env Vars Hierarchy

Variables are sourced in order (mirrors Terragrunt `find_in_parent_folders`):

```
account.env  (eci-dev/account.env)
   └── region.env  (us-east-1/region.env)
          └── env.env  (dev/env.env)
                 └── <component>/.env  (component-level overrides)
```

Update `env.env` to change `KUBE_CONTEXT`, `DOMAIN`, or `HOSTED_ZONE_ID`.
