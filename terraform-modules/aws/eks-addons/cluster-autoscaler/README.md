# eks-addons/cluster-autoscaler

Deploys [Kubernetes Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler) via Helm. Automatically scales node groups up when pods are unschedulable and down when nodes are underutilised.

## Resources Created

| Resource | Name | Description |
|----------|------|-------------|
| `aws_iam_role` | `cluster_autoscaler` | IAM role for the autoscaler pod |
| `aws_iam_policy` | `cluster_autoscaler` | EC2/autoscaling describe & modify permissions |
| `aws_iam_role_policy_attachment` | — | Attaches policy to role |
| `aws_eks_pod_identity_association` | `cluster_autoscaler` | Links role to `kube-system/cluster-autoscaler` |
| `helm_release` | `cluster_autoscaler` | Cluster Autoscaler chart v9.43.2 |

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cluster_name` | string | — | EKS cluster name |
| `cluster_endpoint` | string | — | EKS API server endpoint |
| `cluster_ca_certificate` | string | — | Base64-encoded cluster CA |
| `aws_region` | string | — | AWS region |
| `account_id` | string | — | AWS account ID |
| `environment` | string | `"dev"` | Environment name |
| `cluster_autoscaler_version` | string | `"9.43.2"` | Helm chart version |
| `tags` | map(string) | `{}` | Tags applied to all AWS resources |

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_autoscaler_role_arn` | ARN of the IAM role for Cluster Autoscaler |

## Usage

```hcl
module "eks_addons_cluster_autoscaler" {
  source = "../../../terraform-modules/aws/eks-addons/cluster-autoscaler"

  cluster_name           = module.eks.cluster_name
  cluster_endpoint       = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_certificate_authority
  aws_region             = "us-east-1"
  account_id             = "088317451471"
  environment            = "dev"

  cluster_autoscaler_version = "9.43.2"

  tags = { Environment = "dev" }
}
```

## IAM Permissions

The policy (`cluster-autoscaler-policy.json`) grants:
- `autoscaling:Describe*` / `SetDesiredCapacity` / `TerminateInstanceInAutoScalingGroup`
- `ec2:DescribeLaunchTemplateVersions` / `DescribeInstanceTypes`
- `eks:DescribeNodegroup`

Auto-discovery is configured via Helm values: the controller finds node groups tagged with `k8s.io/cluster-autoscaler/<cluster-name>=owned`.

## Dependencies

- **core** — Pod Identity Agent must be running before the Pod Identity association is created
