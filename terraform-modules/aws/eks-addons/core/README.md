# eks-addons/core

Deploys the mandatory base EKS addons that every other addon depends on. Must be applied before any other `eks-addons/*` module.

## Resources Created

| Resource | Name | Description |
|----------|------|-------------|
| `aws_eks_addon` | `pod_identity_agent` | EKS Pod Identity Agent DaemonSet |
| `aws_eks_addon` | `coredns` | CoreDNS cluster DNS |
| `aws_eks_addon` | `kube_proxy` | Node network rules |
| `aws_eks_addon` | `vpc_cni` | AWS VPC CNI for pod networking |
| `aws_iam_role` | `vpc_cni` | IAM role for vpc-cni (Pod Identity) |
| `aws_iam_role_policy_attachment` | — | Attaches `AmazonEKS_CNI_Policy` |
| `aws_eks_pod_identity_association` | `vpc_cni` | Links vpc-cni role to `aws-node` SA |
| `helm_release` | `metrics_server` | Kubernetes Metrics Server |

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cluster_name` | string | — | EKS cluster name |
| `cluster_endpoint` | string | — | EKS API server endpoint |
| `cluster_ca_certificate` | string | — | Base64-encoded cluster CA |
| `aws_region` | string | — | AWS region |
| `account_id` | string | — | AWS account ID |
| `environment` | string | `"dev"` | Environment name |
| `coredns_version` | string | `"v1.14.3-eksbuild.2"` | EKS addon version for CoreDNS |
| `kube_proxy_version` | string | `"v1.35.3-eksbuild.11"` | EKS addon version for kube-proxy |
| `vpc_cni_version` | string | `"v1.22.1-eksbuild.2"` | EKS addon version for vpc-cni |
| `metrics_server_version` | string | `"3.12.2"` | Helm chart version for metrics-server |
| `tags` | map(string) | `{}` | Tags applied to all AWS resources |

## Outputs

| Output | Description |
|--------|-------------|
| `pod_identity_agent_addon_arn` | ARN of the Pod Identity Agent addon |
| `coredns_addon_arn` | ARN of the CoreDNS addon |
| `kube_proxy_addon_arn` | ARN of the kube-proxy addon |
| `vpc_cni_addon_arn` | ARN of the vpc-cni addon |
| `vpc_cni_role_arn` | ARN of the IAM role for vpc-cni |

## Usage

```hcl
module "eks_addons_core" {
  source = "../../../terraform-modules/aws/eks-addons/core"

  cluster_name           = module.eks.cluster_name
  cluster_endpoint       = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_certificate_authority
  aws_region             = "us-east-1"
  account_id             = "088317451471"
  environment            = "dev"

  coredns_version        = "v1.14.3-eksbuild.2"
  kube_proxy_version     = "v1.35.3-eksbuild.11"
  vpc_cni_version        = "v1.22.1-eksbuild.2"
  metrics_server_version = "3.12.2"

  tags = { Environment = "dev" }
}
```

## Notes

- The **Pod Identity Agent** addon (`aws_eks_addon.pod_identity_agent`) must be `ACTIVE` before any other module creates `aws_eks_pod_identity_association` resources. All sibling modules declare a `dependency "core"` in their Terragrunt config to enforce this ordering.
- The vpc-cni addon uses Pod Identity (not IRSA) — the `aws-node` ServiceAccount in `kube-system` is associated with the created IAM role.
