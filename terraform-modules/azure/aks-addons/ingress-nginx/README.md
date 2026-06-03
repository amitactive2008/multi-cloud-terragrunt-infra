# terraform-modules/azure/aks-addons/ingress-nginx

Deploys the **NGINX Ingress Controller** via Helm. This is the Azure equivalent of the AWS Load Balancer Controller — it provisions an Azure Load Balancer and routes HTTP/HTTPS traffic to Kubernetes services.

## Resources Created

| Resource | Description |
|----------|-------------|
| `helm_release.ingress_nginx` | NGINX Ingress Controller in `ingress-nginx` namespace |

## Usage

```hcl
module "ingress_nginx" {
  source              = "../../terraform-modules/azure/aks-addons/ingress-nginx"
  cluster_name        = "dev-aks"
  resource_group_name = "dev-aks-rg"
  location            = "eastus"
  subscription_id     = "00000000-…"
  environment         = "dev"
  oidc_issuer_url     = "https://…"
  ingress_nginx_version = "4.11.3"
  service_type          = "LoadBalancer"
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `cluster_name` | `string` | — | AKS cluster name |
| `resource_group_name` | `string` | — | Cluster resource group |
| `location` | `string` | — | Azure region |
| `subscription_id` | `string` | — | Azure subscription ID |
| `environment` | `string` | — | Environment name |
| `oidc_issuer_url` | `string` | — | OIDC issuer URL |
| `ingress_nginx_version` | `string` | `4.11.3` | Helm chart version |
| `service_type` | `string` | `LoadBalancer` | Kubernetes service type |
| `static_public_ip` | `bool` | `false` | Create a static Azure public IP |
| `tags` | `map(string)` | `{}` | Tags for Azure resources |

## Outputs

| Name | Description |
|------|-------------|
| `ingress_nginx_status` | Helm release status |

## Differences from AWS lb-controller

| Feature | AWS | Azure |
|---------|-----|-------|
| Ingress class | `alb` | `nginx` |
| Load balancer | AWS ALB | Azure Load Balancer |
| Identity | Pod Identity + IRSA | Workload Identity |
| Annotation style | `alb.ingress.kubernetes.io/*` | `nginx.ingress.kubernetes.io/*` |
