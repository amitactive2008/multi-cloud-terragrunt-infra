# eks-addons/secret-store-csi

Deploys the [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/) with the AWS Secrets Provider, and configures RDS credential mounting for application pods. Secrets are fetched from AWS Secrets Manager and optionally synced as Kubernetes Secrets.

## Resources Created

| Resource | Name | Description |
|----------|------|-------------|
| `helm_release` | `secrets_store_csi_driver` | Secrets Store CSI Driver chart v1.6.0 |
| `helm_release` | `aws_secrets_provider` | AWS Secrets & Config Provider chart v3.1.0 |
| `aws_iam_role` | `rds_secret_reader` | IAM role for pods that mount RDS credentials |
| `aws_iam_role_policy` | `rds_secret_read` | Allows `secretsmanager:GetSecretValue` on the RDS secret |
| `aws_eks_pod_identity_association` | `rds` | Links role to `<namespace>/<service_account_name>` |
| `kubernetes_service_account_v1` | `rds` | ServiceAccount annotated for Pod Identity |
| `null_resource` | `secret_provider_class` | Applies a `SecretProviderClass` via `kubectl` |

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cluster_name` | string | — | EKS cluster name |
| `cluster_endpoint` | string | — | EKS API server endpoint |
| `cluster_ca_certificate` | string | — | Base64-encoded cluster CA |
| `aws_region` | string | — | AWS region |
| `account_id` | string | — | AWS account ID |
| `environment` | string | `"dev"` | Environment name |
| `namespace` | string | `"default"` | Kubernetes namespace |
| `service_account_name` | string | `"rds-sa"` | ServiceAccount that mounts RDS credentials |
| `rds_secret_arn` | string | — | ARN of the Secrets Manager secret (required) |
| `secret_provider_class_name` | string | `"rds-credentials"` | Name of the SecretProviderClass |
| `tags` | map(string) | `{}` | Tags applied to all AWS resources |

## Outputs

| Output | Description |
|--------|-------------|
| `iam_role_arn` | ARN of the IAM role for RDS secret access |
| `pod_identity_association_arn` | ARN of the Pod Identity association |
| `service_account_name` | Kubernetes ServiceAccount name (`rds-sa`) |
| `secret_provider_class_name` | Name of the SecretProviderClass (`rds-credentials`) |
| `k8s_secret_name` | Kubernetes Secret synced from Secrets Manager (`rds-credentials`) |

## Usage

```hcl
module "eks_addons_secret_store_csi" {
  source = "../../../terraform-modules/aws/eks-addons/secret-store-csi"

  cluster_name           = module.eks.cluster_name
  cluster_endpoint       = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_certificate_authority
  aws_region             = "us-east-1"
  account_id             = "088317451471"
  environment            = "dev"

  namespace                  = "default"
  service_account_name       = "rds-sa"
  rds_secret_arn             = module.rds.secret_arn
  secret_provider_class_name = "rds-credentials"

  tags = { Environment = "dev" }
}
```

## Mounting RDS Credentials in a Pod

Pods must use the `rds-sa` ServiceAccount and mount the SecretProviderClass as a volume:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  serviceAccountName: rds-sa
  containers:
    - name: app
      image: my-app:latest
      volumeMounts:
        - name: rds-creds
          mountPath: /mnt/secrets
          readOnly: true
      env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: rds-credentials   # synced Kubernetes Secret
              key: password
  volumes:
    - name: rds-creds
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: rds-credentials
```

## RDS Secret Format (Secrets Manager)

The secret is expected to contain JSON:
```json
{
  "username": "admin",
  "password": "...",
  "host": "dev-mysql.xxxx.us-east-1.rds.amazonaws.com",
  "port": "3306",
  "dbname": "mydb"
}
```

## Dependencies

- **core** — Pod Identity Agent must be running before the Pod Identity association is created
- **rds** — `rds_secret_arn` is pulled from the RDS module output
