# eks-addons/lb-controller

Deploys the [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/) via Helm and registers the `alb` IngressClass. Enables automatic provisioning of Application Load Balancers from Kubernetes Ingress resources.

## Resources Created

| Resource | Name | Description |
|----------|------|-------------|
| `aws_iam_role` | `lb_controller` | IAM role for the controller pod |
| `aws_iam_policy` | `lb_controller` | ALB/NLB management permissions |
| `aws_iam_role_policy_attachment` | — | Attaches policy to role |
| `aws_eks_pod_identity_association` | `lb_controller` | Links role to `kube-system/aws-load-balancer-controller` |
| `helm_release` | `lb_controller` | AWS LB Controller chart v1.10.0 |
| `kubernetes_ingress_class_v1` | `alb` | IngressClass `alb` (controller: `ingress.k8s.aws/alb`) |

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cluster_name` | string | — | EKS cluster name |
| `cluster_endpoint` | string | — | EKS API server endpoint |
| `cluster_ca_certificate` | string | — | Base64-encoded cluster CA |
| `aws_region` | string | — | AWS region |
| `account_id` | string | — | AWS account ID |
| `environment` | string | `"dev"` | Environment name |
| `vpc_id` | string | — | VPC ID passed to the controller |
| `lb_controller_version` | string | `"1.10.0"` | Helm chart version |
| `tags` | map(string) | `{}` | Tags applied to all AWS resources |

## Outputs

| Output | Description |
|--------|-------------|
| `lb_controller_role_arn` | ARN of the IAM role for the controller |
| `ingress_class_name` | Name of the ALB IngressClass (`alb`) |

## Usage

```hcl
module "eks_addons_lb_controller" {
  source = "../../../terraform-modules/aws/eks-addons/lb-controller"

  cluster_name           = module.eks.cluster_name
  cluster_endpoint       = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_certificate_authority
  aws_region             = "us-east-1"
  account_id             = "088317451471"
  environment            = "dev"
  vpc_id                 = module.vpc.vpc_id

  lb_controller_version = "1.10.0"

  tags = { Environment = "dev" }
}
```

## Creating an ALB Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app-svc
                port:
                  number: 80
```

## Dependencies

- **core** — Pod Identity Agent must be running before the Pod Identity association is created
- **vpc** — `vpc_id` is passed from the VPC module output
