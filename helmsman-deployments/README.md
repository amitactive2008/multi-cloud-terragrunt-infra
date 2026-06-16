# Helmsman Deployments

Helm chart deployments managed with [Helmsman](https://github.com/Praqma/helmsman).
Folder structure mirrors the Terragrunt layout in `terragrunt/`.

## Structure

```
helmsman-deployments/
├── aws/
│   ├── eci-dev/
│   │   ├── account.env
│   │   └── us-east-1/
│   │       ├── region.env
│   │       └── dev/
│   │           ├── env.env
│   │           ├── deploy.sh          ← entry-point
│   │           ├── monitoring/        ← Prometheus, Grafana, Alertmanager, Blackbox Exporter
│   │           ├── autoscaling/       ← VPA, Prometheus Adapter (custom-metrics HPA)
│   │           ├── external-dns/      ← Route53 DNS sync
│   │           └── ingress-controllers/ ← NGINX, HAProxy, Kong
│   └── eci-prod/
│       └── ... (same structure, prod-sized values)
├── azure/
└── gcp/
```

## Env Var Hierarchy (mirrors `find_in_parent_folders` in Terragrunt)

```
account.env  →  region.env  →  env.env  →  <component>/.env
```

## Quick Start

```bash
# Install Helmsman
brew install helmsman

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name dev-eks --profile jenkins

# Dry-run (preview changes)
cd helmsman-deployments/aws/eci-dev/us-east-1/dev
./deploy.sh

# Apply all
./deploy.sh --apply

# Apply single component
./deploy.sh --apply monitoring
```

## Components

See [aws/eci-dev/us-east-1/dev/README.md](aws/eci-dev/us-east-1/dev/README.md) for full component list and prerequisites.
