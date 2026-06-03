# EKS Addons Modules

Collection of independent Terraform modules that install and configure EKS cluster addons. Each sub-module manages one functional area and can be deployed or updated independently.

## Sub-modules

| Module | Purpose | Resources |
|--------|---------|-----------|
| [core](core/) | CoreDNS, kube-proxy, vpc-cni, metrics-server | EKS addons + IAM |
| [lb-controller](lb-controller/) | AWS Load Balancer Controller + ALB IngressClass | Helm + IAM + k8s |
| [cluster-autoscaler](cluster-autoscaler/) | Kubernetes Cluster Autoscaler | Helm + IAM |
| [ebs-csi](ebs-csi/) | EBS CSI Driver + gp3 StorageClass | EKS addon + IAM + k8s |
| [secret-store-csi](secret-store-csi/) | Secrets Store CSI + RDS credential mount | Helm + IAM + k8s |
| [pod-identity-s3](pod-identity-s3/) | S3 access via Pod Identity for app pods | IAM + k8s |

## Dependency Graph

```
core  ←────────────────────────────────────────── (must be first)
  ↑
  ├── lb-controller         (also needs: vpc)
  ├── cluster-autoscaler
  ├── ebs-csi
  ├── secret-store-csi      (also needs: rds)
  └── pod-identity-s3
```

`core` must be applied first because it deploys the **EKS Pod Identity Agent** DaemonSet. All other modules create `aws_eks_pod_identity_association` resources that require the agent to be running.

## IAM Pattern

All modules use **EKS Pod Identity** exclusively:

```
IAM Role (trust: pods.eks.amazonaws.com)
    ↕
aws_eks_pod_identity_association  (role ↔ namespace/serviceaccount)
    ↕
Kubernetes ServiceAccount
    ↕
Pod (automatically receives temporary credentials)
```

No OIDC provider, no annotation-based IRSA — credentials are injected directly by the Pod Identity Agent.

## Common Variables

All sub-modules share these base variables:

| Variable | Type | Description |
|----------|------|-------------|
| `cluster_name` | string | EKS cluster name |
| `cluster_endpoint` | string | EKS API server endpoint |
| `cluster_ca_certificate` | string | Base64-encoded cluster CA |
| `aws_region` | string | AWS region |
| `account_id` | string | AWS account ID |
| `environment` | string | Environment name (dev/staging/prod) |
| `tags` | map(string) | Tags applied to all AWS resources |

## Provider Requirements

| Module | AWS | Helm | Kubernetes | Null |
|--------|-----|------|------------|------|
| core | ✓ | ✓ | — | — |
| lb-controller | ✓ | ✓ | ✓ | — |
| cluster-autoscaler | ✓ | ✓ | — | — |
| ebs-csi | ✓ | — | ✓ | — |
| secret-store-csi | ✓ | ✓ | ✓ | ✓ |
| pod-identity-s3 | ✓ | — | ✓ | — |

Helm and Kubernetes providers are configured in each module's `providers.tf` using exec-based authentication:
```bash
aws --region <region> eks get-token --cluster-name <name> \
  --role arn:aws:iam::<account>:role/terraform --output json
```
