# eks-addons/pod-identity-s3

Creates an IAM role with S3 access permissions and associates it with a Kubernetes ServiceAccount via **EKS Pod Identity**. Application pods that use the ServiceAccount automatically receive temporary AWS credentials for S3 operations.

## Resources Created

| Resource | Name | Description |
|----------|------|-------------|
| `aws_iam_role` | `s3_access` | IAM role for pods needing S3 access |
| `aws_iam_policy` | `s3_access` | GetObject / PutObject / DeleteObject / ListBucket on target bucket |
| `aws_iam_role_policy_attachment` | — | Attaches policy to role |
| `aws_eks_pod_identity_association` | `s3_access` | Links role to `<namespace>/<service_account_name>` |
| `kubernetes_service_account_v1` | `s3_access` | ServiceAccount with Pod Identity labels |

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cluster_name` | string | — | EKS cluster name |
| `cluster_endpoint` | string | — | EKS API server endpoint |
| `cluster_ca_certificate` | string | — | Base64-encoded cluster CA |
| `aws_region` | string | — | AWS region |
| `account_id` | string | — | AWS account ID |
| `environment` | string | `"dev"` | Environment name |
| `s3_bucket_name` | string | — | S3 bucket the role will be granted access to (required) |
| `s3_access_namespace` | string | `"default"` | Kubernetes namespace for the ServiceAccount |
| `s3_access_service_account` | string | `"s3-access-sa"` | ServiceAccount name |
| `tags` | map(string) | `{}` | Tags applied to all AWS resources |

## Outputs

| Output | Description |
|--------|-------------|
| `s3_access_role_arn` | ARN of the IAM role for S3 access |
| `s3_access_service_account` | Kubernetes ServiceAccount name (`s3-access-sa`) |

## Usage

```hcl
module "eks_addons_pod_identity_s3" {
  source = "../../../terraform-modules/aws/eks-addons/pod-identity-s3"

  cluster_name           = module.eks.cluster_name
  cluster_endpoint       = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_certificate_authority
  aws_region             = "us-east-1"
  account_id             = "088317451471"
  environment            = "dev"

  s3_bucket_name             = "my-app-bucket"
  s3_access_namespace        = "default"
  s3_access_service_account  = "s3-access-sa"

  tags = { Environment = "dev" }
}
```

## Using S3 Access in a Pod

Pods must reference the `s3-access-sa` ServiceAccount — no additional configuration needed. The Pod Identity Agent injects temporary credentials automatically via the `AWS_CONTAINER_CREDENTIALS_FULL_URI` environment variable.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: s3-app
spec:
  serviceAccountName: s3-access-sa
  containers:
    - name: app
      image: amazon/aws-cli:latest
      command: ["aws", "s3", "ls", "s3://my-app-bucket/"]
```

## IAM Permissions Granted

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:ListBucket",
    "s3:GetBucketLocation",
    "s3:GetObjectVersion",
    "s3:GetObjectAcl"
  ],
  "Resource": [
    "arn:aws:s3:::<bucket>",
    "arn:aws:s3:::<bucket>/*"
  ]
}
```

`s3:ListAllMyBuckets` is also granted at the `*` resource level.

## Dependencies

- **core** — Pod Identity Agent must be running before the Pod Identity association is created
