# eks-addons/efs-csi-driver

Deploys the [AWS EFS CSI Driver](https://github.com/kubernetes-sigs/aws-efs-csi-driver) as an EKS managed addon, provisions an encrypted EFS file system with mount targets in each private subnet, and creates a `efs-sc` StorageClass for dynamic volume provisioning.

## Resources Created

| Resource | Name | Description |
|----------|------|-------------|
| `aws_iam_role` | `efs_csi_driver` | IAM role for the EFS CSI controller |
| `aws_iam_role_policy_attachment` | — | Attaches `AmazonEFSCSIDriverPolicy` |
| `aws_eks_pod_identity_association` | `efs_csi_driver` | Links role to `kube-system/efs-csi-controller-sa` |
| `aws_eks_addon` | `efs_csi_driver` | EFS CSI Driver managed addon |
| `aws_security_group` | `efs` | Allows NFS (2049) ingress from the VPC CIDR |
| `aws_efs_file_system` | `this` | Encrypted EFS file system (elastic throughput) |
| `aws_efs_mount_target` | `this[*]` | One mount target per private subnet |
| `aws_efs_access_point` | `root` | Default access point at `/data` (uid/gid 1000) |
| `kubernetes_storage_class` | `efs-sc` | Dynamic StorageClass using EFS access points |

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cluster_name` | string | — | EKS cluster name |
| `cluster_endpoint` | string | — | EKS API server endpoint |
| `cluster_ca_certificate` | string | — | Base64-encoded cluster CA |
| `aws_region` | string | — | AWS region |
| `account_id` | string | — | AWS account ID |
| `environment` | string | `"dev"` | Environment name |
| `efs_csi_driver_version` | string | `"v2.1.4-eksbuild.1"` | EKS addon version |
| `vpc_id` | string | — | VPC ID for the EFS security group |
| `vpc_cidr` | string | — | VPC CIDR block for NFS ingress rule |
| `private_subnet_ids` | list(string) | — | Private subnet IDs for mount targets |
| `performance_mode` | string | `"generalPurpose"` | `generalPurpose` or `maxIO` |
| `throughput_mode` | string | `"elastic"` | `bursting`, `provisioned`, or `elastic` |
| `transition_to_ia` | string | `"AFTER_30_DAYS"` | IA lifecycle transition; `""` to disable |
| `tags` | map(string) | `{}` | Tags applied to all AWS resources |

## Outputs

| Output | Description |
|--------|-------------|
| `efs_csi_role_arn` | ARN of the IAM role for the EFS CSI driver |
| `efs_csi_addon_arn` | ARN of the aws-efs-csi-driver EKS addon |
| `efs_file_system_id` | ID of the EFS file system |
| `efs_file_system_arn` | ARN of the EFS file system |
| `efs_file_system_dns_name` | DNS name of the EFS file system |
| `efs_access_point_id` | ID of the default EFS access point |
| `efs_security_group_id` | ID of the EFS security group |
| `efs_storage_class` | Name of the StorageClass (`efs-sc`) |

## Usage

```hcl
module "eks_addons_efs_csi" {
  source = "../../../terraform-modules/aws/eks-addons/efs-csi-driver"

  cluster_name           = module.eks.cluster_name
  cluster_endpoint       = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_certificate_authority
  aws_region             = "us-east-1"
  account_id             = "088317451471"
  environment            = "dev"

  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = "10.0.0.0/16"
  private_subnet_ids = module.vpc.private_subnet_ids

  efs_csi_driver_version = "v2.1.4-eksbuild.1"

  tags = { Environment = "dev" }
}
```

## StorageClass Details

The `efs-sc` StorageClass uses `efs-ap` provisioning mode — each PVC gets a dedicated EFS Access Point under `/dynamic/<uuid>`, providing strong isolation between workloads.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-data
spec:
  accessModes: [ReadWriteMany]
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi   # EFS is elastic; this value is advisory only
```

## Dependencies

- **core** — Pod Identity Agent must be running before the Pod Identity association is created
- **vpc** — VPC ID, CIDR, and private subnet IDs are required for mount targets
