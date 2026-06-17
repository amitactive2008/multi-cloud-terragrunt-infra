# External DNS Module

This Terraform module deploys External DNS on EKS with IAM Pod Identity (IRSA) for automatic Route53 DNS record management.

## Features

- **Automatic DNS Management**: Syncs Kubernetes Ingress and Service resources to Route53
- **Pod Identity Support**: Uses EKS Pod Identity (IRSA) for secure AWS credential handling
- **Zone Filtering**: Configure which Route53 hosted zones to manage
- **Domain Filtering**: Limit external-dns to specific domain names
- **Highly Configurable**: Supports Helm values override for fine-tuning

## Usage

```hcl
module "external_dns" {
  source = "../../../terraform-modules/aws/eks-addons/external-dns"

  cluster_name           = data.aws_eks_cluster.this.name
  cluster_endpoint       = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = data.aws_eks_cluster.this.certificate_authority[0].data
  aws_region             = var.aws_region
  account_id             = var.account_id

  # Route53 Configuration
  route53_zone_ids   = ["Z00208349B1KPAQN1J8J"]
  route53_domain_filters = ["linuxworms.in"]

  # Optional: TXT record ownership
  txt_owner_id = "${var.cluster_name}-external-dns"

  # Optional: Helm overrides
  external_dns_version = "1.15.0"
  replicas            = 2
  log_level          = "info"

  tags = {
    Terraform = "true"
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `cluster_name` | EKS cluster name | string | - | yes |
| `cluster_endpoint` | EKS cluster API endpoint | string | - | yes |
| `cluster_ca_certificate` | Base64-encoded cluster CA cert | string | - | yes |
| `aws_region` | AWS region | string | - | yes |
| `account_id` | AWS account ID | string | - | yes |
| `environment` | Environment name (dev/staging/prod) | string | `"dev"` | no |
| `external_dns_version` | Helm chart version | string | `"1.15.0"` | no |
| `external_dns_namespace` | Kubernetes namespace | string | `"external-dns"` | no |
| `create_namespace` | Create namespace if not exists | bool | `true` | no |
| `route53_zone_ids` | Route53 hosted zone IDs to manage | list(string) | `[]` | no |
| `route53_domain_filters` | Limit to specific domains | list(string) | `[]` | no |
| `policy` | Record management policy (sync/upsert-only) | string | `"sync"` | no |
| `txt_owner_id` | TXT record owner identifier | string | `""` | no |
| `replicas` | Number of replicas | number | `1` | no |
| `log_level` | Log level (debug/info/warning/error) | string | `"info"` | no |
| `interval` | Reconciliation interval | string | `"1m"` | no |
| `trigger_loop_on_event` | Trigger update on resource changes | bool | `true` | no |
| `sources` | K8s sources (ingress, service, etc.) | list(string) | `["ingress", "service"]` | no |
| `helm_set_values` | Additional Helm values | map(string) | `{}` | no |
| `tags` | Tags for AWS resources | map(string) | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `external_dns_role_arn` | ARN of the IAM role |
| `external_dns_role_name` | Name of the IAM role |
| `helm_release_name` | Helm release name |
| `helm_release_status` | Release status |
| `namespace` | Kubernetes namespace |
| `pod_identity_association_id` | Pod Identity Association ID |

## Requirements

- EKS cluster with Pod Identity support (EKS 1.26+)
- Kubernetes provider 2.27+
- Helm provider 2.12+
- AWS provider 5.0+

## IAM Permissions

The module creates an IAM role with the following Route53 permissions:

- `route53:ChangeResourceRecordSets` - Change DNS records
- `route53:ListHostedZones` - List hosted zones
- `route53:ListResourceRecordSets` - List DNS records
- `route53:GetChange` - Check change status

## Example: Linuxworms.in Setup

```hcl
module "external_dns_linuxworms" {
  source = "../../../terraform-modules/aws/eks-addons/external-dns"

  cluster_name           = aws_eks_cluster.dev_eks.name
  cluster_endpoint       = aws_eks_cluster.dev_eks.endpoint
  cluster_ca_certificate = base64encode(aws_eks_cluster.dev_eks.certificate_authority[0].data)
  aws_region             = "us-east-1"
  account_id             = "088317451471"

  # Manage only linuxworms.in domain
  route53_zone_ids       = ["Z00208349B1KPAQN1J8J"]
  route53_domain_filters = ["linuxworms.in"]
  txt_owner_id           = "dev-eks-linuxworms"

  external_dns_version = "1.15.0"
  policy              = "sync"
  replicas            = 1
}
```

## Notes

- The module creates a Kubernetes namespace `external-dns` by default
- Service account `external-dns` is automatically configured
- Pod Identity Association connects the service account to the IAM role
- All DNS records created/managed by External DNS will have a TXT record with the owner ID

## Troubleshooting

### Pod cannot assume IAM role

Check Pod Identity Association:
```bash
kubectl get pods -n external-dns
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns
```

### No DNS records being created

1. Verify zone ID and domain filters match your Route53 configuration
2. Check Ingress/Service resources have proper annotations
3. Review logs: `kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns`

### Unexpected records in Route53

The `txt_owner_id` prevents External DNS from managing records created by other tools. Set a unique value per cluster.
