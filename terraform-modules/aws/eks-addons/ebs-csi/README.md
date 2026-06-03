# eks-addons/ebs-csi

Deploys the [AWS EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver) as an EKS managed addon and creates a `gp3` StorageClass set as the cluster default.

## Resources Created

| Resource | Name | Description |
|----------|------|-------------|
| `aws_iam_role` | `ebs_csi_driver` | IAM role for the EBS CSI controller |
| `aws_iam_role_policy_attachment` | — | Attaches `AmazonEBSCSIDriverPolicy` |
| `aws_eks_pod_identity_association` | `ebs_csi_driver` | Links role to `kube-system/ebs-csi-controller-sa` |
| `aws_eks_addon` | `ebs_csi_driver` | EBS CSI Driver addon v1.60.1-eksbuild.1 |
| `kubernetes_storage_class` | `ebs_gp3` | gp3 StorageClass (encrypted, WaitForFirstConsumer) |

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cluster_name` | string | — | EKS cluster name |
| `cluster_endpoint` | string | — | EKS API server endpoint |
| `cluster_ca_certificate` | string | — | Base64-encoded cluster CA |
| `aws_region` | string | — | AWS region |
| `account_id` | string | — | AWS account ID |
| `environment` | string | `"dev"` | Environment name |
| `ebs_csi_driver_version` | string | `"v1.60.1-eksbuild.1"` | EKS addon version |
| `tags` | map(string) | `{}` | Tags applied to all AWS resources |

## Outputs

| Output | Description |
|--------|-------------|
| `ebs_csi_role_arn` | ARN of the IAM role for the EBS CSI driver |
| `ebs_csi_addon_arn` | ARN of the aws-ebs-csi-driver EKS addon |
| `ebs_gp3_storage_class` | Name of the gp3 StorageClass (`ebs-gp3`) |

## Usage

```hcl
module "eks_addons_ebs_csi" {
  source = "../../../terraform-modules/aws/eks-addons/ebs-csi"

  cluster_name           = module.eks.cluster_name
  cluster_endpoint       = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_certificate_authority
  aws_region             = "us-east-1"
  account_id             = "088317451471"
  environment            = "dev"

  ebs_csi_driver_version = "v1.60.1-eksbuild.1"

  tags = { Environment = "dev" }
}
```

## StorageClass Details

The `ebs-gp3` StorageClass is created with:
- `type: gp3` (better baseline performance than gp2 at lower cost)
- `encrypted: "true"` (AES-256, AWS-managed key)
- `volumeBindingMode: WaitForFirstConsumer` (defers provisioning until pod is scheduled to an AZ)
- Annotation `storageclass.kubernetes.io/is-default-class: "true"` (becomes cluster default)

### Example PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ebs-gp3
  resources:
    requests:
      storage: 10Gi
```

## Dependencies

- **core** — Pod Identity Agent must be running before the Pod Identity association is created
