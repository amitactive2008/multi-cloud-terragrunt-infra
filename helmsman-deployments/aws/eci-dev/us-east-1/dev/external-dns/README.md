# External DNS Deployment Guide

## Overview

External DNS automatically manages Route53 DNS records based on Kubernetes Ingress and Service resources. When you create an Ingress with a hostname, External DNS will automatically create or update the corresponding Route53 DNS record to point to the load balancer.

## Prerequisites

1. **Kubernetes Cluster**: EKS cluster with OIDC provider configured
2. **Helmsman**: Installed and configured locally
3. **AWS CLI**: Configured with appropriate credentials
4. **Route53 Hosted Zone**: Already created with Zone ID `Z00208349B1KPAQN1J8J`
5. **IAM Permissions**: Ability to create IAM roles and policies

## Step 1: Create IAM Role and Policy (IRSA Setup)

External DNS requires an IAM role that can be assumed by the Kubernetes service account using Pod Identity (IRSA - IAM Roles for Service Accounts).

### Execute the following commands:

```bash
# Set variables
AWS_PROFILE=amit
AWS_REGION=us-east-1
CLUSTER=dev-eks
ROLE_NAME=external-dns-dev
ZONE_ID=Z00208349B1KPAQN1J8J

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)

# Get OIDC provider from cluster
OIDC_ISSUER=$(aws eks describe-cluster --name "$CLUSTER" --region "$AWS_REGION" --profile "$AWS_PROFILE" --query "cluster.identity.oidc.issuer" --output text)
OIDC_PROVIDER=${OIDC_ISSUER#https://}

# Create trust policy JSON
cat >/tmp/external-dns-trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com",
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:external-dns:external-dns"
        }
      }
    }
  ]
}
EOF

# Create Route53 policy JSON
cat >/tmp/external-dns-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": [
        "arn:aws:route53:::hostedzone/${ZONE_ID}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:ListHostedZonesByName",
        "route53:ListResourceRecordSets"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file:///tmp/external-dns-trust.json \
  --profile "$AWS_PROFILE" 2>/dev/null || echo "Role may already exist, updating trust policy..."

# Update trust policy (in case role exists)
aws iam update-assume-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-document file:///tmp/external-dns-trust.json \
  --profile "$AWS_PROFILE"

# Attach Route53 policy
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name external-dns-route53-inline \
  --policy-document file:///tmp/external-dns-policy.json \
  --profile "$AWS_PROFILE"

# Verify role was created
aws iam get-role --role-name "$ROLE_NAME" --profile "$AWS_PROFILE" --query 'Role.Arn' --output text
```

**Expected Output:**
```
arn:aws:iam::088317451471:role/external-dns-dev
```

## Step 2: Deploy External DNS via Helmsman

Once the IAM role is created, deploy External DNS:

```bash
cd /Users/amit.kumar1/Desktop/study/terraform-by-copilot/helmsman-deployments/aws/eci-dev/us-east-1/dev

# Dry-run first to review the plan
./deploy.sh --dry-run external-dns

# Apply the deployment
./deploy.sh --apply external-dns
```

## Step 3: Verify Deployment

### Check Helm Release
```bash
helm ls -n external-dns
```

Expected output:
```
NAME            NAMESPACE       REVISION        UPDATED                         STATUS          CHART                   APP VERSION
external-dns    external-dns    1               2026-06-17 17:14:24.xxx IST    deployed        external-dns-1.15.0     0.15.0
```

### Check Pod Status
```bash
kubectl get pods -n external-dns -o wide
```

Expected output:
```
NAME                            READY   STATUS    RESTARTS   AGE   IP              NODE
external-dns-5c85b648bf-87wfc   1/1     Running   0          5m    10.0.12.140     ip-10-0-12-250.ec2.internal
```

### Check Service Account
```bash
kubectl get sa external-dns -n external-dns -o yaml
```

Verify the annotation contains your IAM role ARN:
```yaml
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::088317451471:role/external-dns-dev
```

## Step 4: Verify IAM Permissions

Restart the pod to pick up IAM credentials and check logs:

```bash
kubectl rollout restart deploy/external-dns -n external-dns
kubectl logs -n external-dns deploy/external-dns --tail=100
```

**Expected logs:**
- Should NOT contain: `AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity`
- Should contain: `config:` with your configuration
- Should contain: Route53 and hosted zone references

## Configuration

The deployment is configured in `values/external-dns-values.yaml`:

- **Provider**: AWS (Route53)
- **Zone ID Filter**: `Z00208349B1KPAQN1J8J` (only manages records in this zone)
- **Sources**: Ingress and Service resources
- **Policy**: `sync` (creates and deletes records)
- **TXT Owner ID**: `dev-eks` (ensures External DNS owns its records)

## Usage

Once deployed, External DNS will automatically:

1. Watch for new Ingress resources in your cluster
2. Extract hostnames from Ingress rules
3. Create corresponding A records in Route53 pointing to the load balancer
4. Delete records when Ingress is removed

### Example: Create an Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: team-a
  annotations:
    alb.ingress.kubernetes.io/scheme: internal
spec:
  ingressClassName: alb
  rules:
    - host: my-app.dev.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app-service
                port:
                  number: 80
```

External DNS will automatically create a Route53 record for `my-app.dev.example.com` pointing to the ALB.

## Troubleshooting

### Pod fails to start with IAM error
**Problem**: `AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity`

**Solution**:
1. Verify IAM role `external-dns-dev` exists: `aws iam get-role --role-name external-dns-dev --profile amit`
2. Verify trust policy allows the correct OIDC provider and service account
3. Verify service account has the correct IAM role ARN annotation
4. Restart the pod: `kubectl rollout restart deploy/external-dns -n external-dns`

### No DNS records created
**Problem**: Ingress resources are created but Route53 records aren't updated

**Solution**:
1. Check logs: `kubectl logs -n external-dns deploy/external-dns --tail=200`
2. Verify zone filter matches your hosted zone ID
3. Ensure Ingress resources have proper annotations for the `alb` ingress class
4. Check IAM policy allows `route53:ChangeResourceRecordSets` on your hosted zone

### Unwanted records in Route53
**Problem**: External DNS is creating records you don't want

**Solution**:
1. Check the TXT owner ID in logs (should be `dev-eks`)
2. Only External DNS records with owner ID `dev-eks` are managed
3. Delete problematic Ingress resources and External DNS will clean up the records

## Uninstall

To remove External DNS:

```bash
cd /Users/amit.kumar1/Desktop/study/terraform-by-copilot/helmsman-deployments/aws/eci-dev/us-east-1/dev
./deploy.sh --destroy external-dns
```

To remove IAM role (optional):

```bash
# Remove inline policy
aws iam delete-role-policy --role-name external-dns-dev --policy-name external-dns-route53-inline --profile amit

# Delete role
aws iam delete-role --role-name external-dns-dev --profile amit
```

## References

- [External DNS Documentation](https://kubernetes-sigs.github.io/external-dns/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [Route53 API Reference](https://docs.aws.amazon.com/Route53/latest/APIReference/)
