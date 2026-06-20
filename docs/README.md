# Manual Infrastructure Provisioning Guide

Step-by-step reference for manually provisioning the complete AWS EKS infrastructure defined in this repository (without Terraform/Terragrunt).

---

## Prerequisites

```bash
# Install required tools
brew install awscli terraform terragrunt kubectl helm helmsman

# Configure AWS credentials
aws configure --profile jenkins
# AWS Access Key ID, Secret, Region: us-east-1, Output: json

# Verify access
aws sts get-caller-identity --profile jenkins
```

---

## Quick Reference — Key Values

| Resource | Value |
|---|---|
| AWS Account | `088317451471` |
| Region | `us-east-1` |
| EKS Cluster | `dev-eks` |
| Kubernetes Version | `1.36` |
| Node Type | `t3.medium` (desired: 2, min: 1, max: 5) |
| VPC CIDR | `10.0.0.0/16` |
| RDS Instance | `dev-mysql` (db.t3.micro, MySQL 8.0) |
| RDS Database | `appdb` |
| Secret Path | `dev/rds/credentials` |
| Jenkins User ARN | `arn:aws:iam::088317451471:user/jenkins` |

---

## Provisioning Order

```
VPC + Subnets + IGW + NAT
        │
        ▼
    IAM Roles
        │
        ▼
   EKS Cluster
     │       │
     ▼       ▼
Node Group  RDS MySQL
     │
     ▼
Pod Identity Agent (addon — must be first)
     │
     ▼
VPC CNI + CoreDNS + kube-proxy + Metrics Server
     │
     ├── LB Controller
     ├── EBS CSI Driver
     ├── EFS CSI Driver
     ├── Cluster Autoscaler
     ├── External DNS
     ├── Secrets Store CSI
     └── Pod Identity S3 Role
              │
              ▼
   Helmsman: Monitoring + Ingress + VPA
```

---

## Phase 1 — AWS Networking (VPC)

### Step 1: Create VPC

```bash
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=dev-eks-vpc}]' \
  --region us-east-1

# Save the VPC ID
export VPC_ID=<vpc-id-from-output>
```

### Step 2: Create Subnets

```bash
# Public Subnets (with kubernetes.io/role/elb tag for ALB/NLB auto-discovery)
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=dev-public-1a},{Key=kubernetes.io/role/elb,Value=1},{Key=kubernetes.io/cluster/dev-eks,Value=shared}]'

aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone us-east-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=dev-public-1b},{Key=kubernetes.io/role/elb,Value=1},{Key=kubernetes.io/cluster/dev-eks,Value=shared}]'

# Private Subnets (with kubernetes.io/role/internal-elb tag for internal LBs)
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.11.0/24 --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=dev-private-1a},{Key=kubernetes.io/role/internal-elb,Value=1},{Key=kubernetes.io/cluster/dev-eks,Value=shared}]'

aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.12.0/24 --availability-zone us-east-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=dev-private-1b},{Key=kubernetes.io/role/internal-elb,Value=1},{Key=kubernetes.io/cluster/dev-eks,Value=shared}]'

# DB Subnets (isolated — no public route)
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.21.0/24 --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=dev-db-1a}]'

aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.22.0/24 --availability-zone us-east-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=dev-db-1b}]'
```

> **Note:** Save all subnet IDs after creation — they are required by EKS, RDS, and EFS steps.

### Step 3: Create Internet Gateway & NAT Gateway

```bash
# Internet Gateway
aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=dev-igw}]'

export IGW_ID=<igw-id>
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID

# Elastic IP for NAT Gateway
aws ec2 allocate-address --domain vpc
export EIP_ALLOC_ID=<allocation-id>

# NAT Gateway — placed in the FIRST public subnet
export PUBLIC_SUBNET_1A=<public-subnet-1a-id>
aws ec2 create-nat-gateway \
  --subnet-id $PUBLIC_SUBNET_1A \
  --allocation-id $EIP_ALLOC_ID \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=dev-nat}]'

export NAT_GW_ID=<nat-gateway-id>

# Wait ~2 minutes for NAT GW to become available
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID
```

### Step 4: Create Route Tables

```bash
# Public Route Table — routes 0.0.0.0/0 to Internet Gateway
aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=dev-public-rt}]'
export PUBLIC_RT=<route-table-id>

aws ec2 create-route --route-table-id $PUBLIC_RT \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID

aws ec2 associate-route-table --route-table-id $PUBLIC_RT --subnet-id $PUBLIC_SUBNET_1A
aws ec2 associate-route-table --route-table-id $PUBLIC_RT --subnet-id <public-subnet-1b-id>

# Private Route Table — routes 0.0.0.0/0 to NAT Gateway
aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=dev-private-rt}]'
export PRIVATE_RT=<route-table-id>

aws ec2 create-route --route-table-id $PRIVATE_RT \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GW_ID

# Associate all private and DB subnets to private route table
aws ec2 associate-route-table --route-table-id $PRIVATE_RT --subnet-id <private-subnet-1a-id>
aws ec2 associate-route-table --route-table-id $PRIVATE_RT --subnet-id <private-subnet-1b-id>
aws ec2 associate-route-table --route-table-id $PRIVATE_RT --subnet-id <db-subnet-1a-id>
aws ec2 associate-route-table --route-table-id $PRIVATE_RT --subnet-id <db-subnet-1b-id>
```

---

## Phase 2 — IAM Roles

### Step 5: Create EKS Cluster IAM Role

```bash
cat > eks-cluster-trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "eks.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role \
  --role-name dev-eks-cluster-role \
  --assume-role-policy-document file://eks-cluster-trust.json

aws iam attach-role-policy \
  --role-name dev-eks-cluster-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
```

### Step 6: Create EKS Node IAM Role

```bash
cat > eks-node-trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "ec2.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role \
  --role-name dev-eks-node-role \
  --assume-role-policy-document file://eks-node-trust.json

aws iam attach-role-policy --role-name dev-eks-node-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam attach-role-policy --role-name dev-eks-node-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
aws iam attach-role-policy --role-name dev-eks-node-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
```

---

## Phase 3 — EKS Cluster

### Step 7: Create Security Groups

```bash
# Cluster Security Group
aws ec2 create-security-group \
  --group-name dev-eks-cluster-sg \
  --description "EKS Cluster Security Group" \
  --vpc-id $VPC_ID

export CLUSTER_SG_ID=<cluster-sg-id>

# Node Security Group
aws ec2 create-security-group \
  --group-name dev-eks-node-sg \
  --description "EKS Node Security Group" \
  --vpc-id $VPC_ID

export NODE_SG_ID=<node-sg-id>

# Allow all traffic within the node group
aws ec2 authorize-security-group-ingress \
  --group-id $NODE_SG_ID \
  --protocol all \
  --source-group $NODE_SG_ID

# Allow cluster → node communication (ephemeral port range)
aws ec2 authorize-security-group-ingress \
  --group-id $NODE_SG_ID \
  --protocol tcp --port 1025-65535 \
  --source-group $CLUSTER_SG_ID
```

### Step 8: Create EKS Cluster

```bash
aws eks create-cluster \
  --name dev-eks \
  --kubernetes-version 1.36 \
  --role-arn arn:aws:iam::088317451471:role/dev-eks-cluster-role \
  --resources-vpc-config \
    subnetIds=<private-1a-id>,<private-1b-id>,<public-1a-id>,<public-1b-id>,securityGroupIds=$CLUSTER_SG_ID,endpointPublicAccess=true,endpointPrivateAccess=true \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}' \
  --region us-east-1

# Wait for cluster to become ACTIVE (~10-15 min)
aws eks wait cluster-active --name dev-eks --region us-east-1
```

### Step 9: Create Node Group

```bash
aws eks create-nodegroup \
  --cluster-name dev-eks \
  --nodegroup-name general \
  --node-role arn:aws:iam::088317451471:role/dev-eks-node-role \
  --subnets <private-1a-id> <private-1b-id> \
  --instance-types t3.medium \
  --scaling-config minSize=1,maxSize=5,desiredSize=2 \
  --disk-size 50 \
  --capacity-type ON_DEMAND \
  --ami-type AL2023_x86_64_STANDARD \
  --labels role=general \
  --region us-east-1

# Wait for node group to become ACTIVE (~5-10 min)
aws eks wait nodegroup-active --cluster-name dev-eks --nodegroup-name general
```

### Step 10: Configure kubectl

```bash
aws eks update-kubeconfig \
  --name dev-eks \
  --region us-east-1 \
  --profile jenkins

# Verify 2 nodes are Ready
kubectl get nodes
```

### Step 11: Grant Admin Access (Jenkins user + devops group)

```bash
kubectl edit configmap aws-auth -n kube-system
```

Add the following entries:

```yaml
# Under mapUsers:
- userarn: arn:aws:iam::088317451471:user/jenkins
  username: jenkins
  groups:
    - system:masters

# Under mapRoles (for devops assumable role):
- rolearn: arn:aws:iam::088317451471:role/devops-role
  username: devops
  groups:
    - system:masters
```

---

## Phase 4 — RDS MySQL

### Step 12: Create RDS Security Group

```bash
aws ec2 create-security-group \
  --group-name dev-rds-sg \
  --description "RDS MySQL Security Group" \
  --vpc-id $VPC_ID

export RDS_SG_ID=<rds-sg-id>

# Allow MySQL (3306) from EKS nodes only
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG_ID \
  --protocol tcp --port 3306 \
  --source-group $NODE_SG_ID
```

### Step 13: Create RDS Subnet Group

```bash
aws rds create-db-subnet-group \
  --db-subnet-group-name dev-mysql-subnet-group \
  --db-subnet-group-description "Dev MySQL Subnet Group" \
  --subnet-ids <db-subnet-1a-id> <db-subnet-1b-id>
```

### Step 14: Create RDS MySQL Instance

```bash
# Generate a secure password
export DB_PASSWORD=$(openssl rand -base64 18)

aws rds create-db-instance \
  --db-instance-identifier dev-mysql \
  --db-instance-class db.t3.micro \
  --engine mysql \
  --engine-version 8.0 \
  --master-username admin \
  --master-user-password "$DB_PASSWORD" \
  --db-name appdb \
  --allocated-storage 20 \
  --max-allocated-storage 100 \
  --storage-type gp3 \
  --storage-encrypted \
  --no-multi-az \
  --backup-retention-period 7 \
  --preferred-backup-window "03:00-04:00" \
  --preferred-maintenance-window "mon:04:00-mon:05:00" \
  --vpc-security-group-ids $RDS_SG_ID \
  --db-subnet-group-name dev-mysql-subnet-group \
  --no-deletion-protection \
  --region us-east-1

# Wait for DB to become available (~10-15 min)
aws rds wait db-instance-available --db-instance-identifier dev-mysql
```

### Step 15: Store Credentials in Secrets Manager

```bash
export RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier dev-mysql \
  --query 'DBInstances[0].Endpoint.Address' --output text)

aws secretsmanager create-secret \
  --name "dev/rds/credentials" \
  --description "RDS credentials for dev environment" \
  --secret-string "{\"username\":\"admin\",\"password\":\"$DB_PASSWORD\",\"host\":\"$RDS_ENDPOINT\",\"port\":\"3306\",\"dbname\":\"appdb\"}" \
  --region us-east-1
```

---

## Phase 5 — EKS Core Add-ons

### Step 16: Install Pod Identity Agent (must be first)

> The EKS Pod Identity Agent must be installed before all other add-ons that use Pod Identity.

```bash
aws eks create-addon \
  --cluster-name dev-eks \
  --addon-name eks-pod-identity-agent \
  --region us-east-1

aws eks wait addon-active --cluster-name dev-eks --addon-name eks-pod-identity-agent
```

### Step 17: Install Core EKS Managed Add-ons

```bash
# VPC CNI — AWS-managed pod networking
aws eks create-addon --cluster-name dev-eks --addon-name vpc-cni \
  --addon-version v1.21.1-eksbuild.8 --resolve-conflicts OVERWRITE

# kube-proxy
aws eks create-addon --cluster-name dev-eks --addon-name kube-proxy \
  --addon-version v1.36.0-eksbuild.2 --resolve-conflicts OVERWRITE

# CoreDNS — cluster DNS
aws eks create-addon --cluster-name dev-eks --addon-name coredns \
  --addon-version v1.14.2-eksbuild.4 --resolve-conflicts OVERWRITE
```

### Step 18: Install Metrics Server

```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

helm install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --version 3.12.2
```

---

## Phase 6 — AWS Load Balancer Controller

### Step 19: Create IAM Policy & Role

```bash
# Download the official policy document
curl -o lb-controller-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name dev-eks-lb-controller-policy \
  --policy-document file://lb-controller-policy.json

aws iam create-role \
  --role-name dev-eks-lb-controller-role \
  --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[{
      "Effect":"Allow",
      "Principal":{"Service":"pods.eks.amazonaws.com"},
      "Action":["sts:AssumeRole","sts:TagSession"]
    }]
  }'

aws iam attach-role-policy \
  --role-name dev-eks-lb-controller-role \
  --policy-arn arn:aws:iam::088317451471:policy/dev-eks-lb-controller-policy
```

### Step 20: Create Pod Identity Association & Install

```bash
kubectl create serviceaccount aws-load-balancer-controller -n kube-system

aws eks create-pod-identity-association \
  --cluster-name dev-eks \
  --namespace kube-system \
  --service-account aws-load-balancer-controller \
  --role-arn arn:aws:iam::088317451471:role/dev-eks-lb-controller-role

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName=dev-eks \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1 \
  --set vpcId=$VPC_ID
```

---

## Phase 7 — EBS CSI Driver

### Step 21: Create IAM Role & Install Add-on

```bash
aws iam create-role \
  --role-name dev-eks-ebs-csi-role \
  --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[{
      "Effect":"Allow",
      "Principal":{"Service":"pods.eks.amazonaws.com"},
      "Action":["sts:AssumeRole","sts:TagSession"]
    }]
  }'

aws iam attach-role-policy \
  --role-name dev-eks-ebs-csi-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy

kubectl create serviceaccount ebs-csi-controller-sa -n kube-system

aws eks create-pod-identity-association \
  --cluster-name dev-eks \
  --namespace kube-system \
  --service-account ebs-csi-controller-sa \
  --role-arn arn:aws:iam::088317451471:role/dev-eks-ebs-csi-role

aws eks create-addon \
  --cluster-name dev-eks \
  --addon-name aws-ebs-csi-driver \
  --resolve-conflicts OVERWRITE
```

### Create Default gp3 StorageClass

```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
parameters:
  type: gp3
EOF
```

---

## Phase 8 — EFS CSI Driver

### Step 22: Create EFS Filesystem & Install Add-on

```bash
# Create EFS security group
aws ec2 create-security-group \
  --group-name dev-efs-sg \
  --description "EFS Security Group" \
  --vpc-id $VPC_ID

export EFS_SG_ID=<efs-sg-id>

# Allow NFS (2049) from EKS nodes
aws ec2 authorize-security-group-ingress \
  --group-id $EFS_SG_ID \
  --protocol tcp --port 2049 \
  --source-group $NODE_SG_ID

# Create EFS filesystem
aws efs create-file-system \
  --encrypted \
  --tags Key=Name,Value=dev-efs \
  --region us-east-1

export EFS_ID=<fs-id>

# Create mount targets in each private subnet
aws efs create-mount-target \
  --file-system-id $EFS_ID \
  --subnet-id <private-1a-id> \
  --security-groups $EFS_SG_ID

aws efs create-mount-target \
  --file-system-id $EFS_ID \
  --subnet-id <private-1b-id> \
  --security-groups $EFS_SG_ID

# IAM Role for EFS CSI
aws iam create-role \
  --role-name dev-eks-efs-csi-role \
  --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[{
      "Effect":"Allow",
      "Principal":{"Service":"pods.eks.amazonaws.com"},
      "Action":["sts:AssumeRole","sts:TagSession"]
    }]
  }'

aws iam attach-role-policy \
  --role-name dev-eks-efs-csi-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy

kubectl create serviceaccount efs-csi-controller-sa -n kube-system

aws eks create-pod-identity-association \
  --cluster-name dev-eks \
  --namespace kube-system \
  --service-account efs-csi-controller-sa \
  --role-arn arn:aws:iam::088317451471:role/dev-eks-efs-csi-role

aws eks create-addon \
  --cluster-name dev-eks \
  --addon-name aws-efs-csi-driver \
  --resolve-conflicts OVERWRITE
```

---

## Phase 9 — Cluster Autoscaler

### Step 23: Create IAM Policy & Install

```bash
cat > cluster-autoscaler-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeInstanceTypes"
    ],
    "Resource": "*"
  }]
}
EOF

aws iam create-policy \
  --policy-name dev-eks-cluster-autoscaler-policy \
  --policy-document file://cluster-autoscaler-policy.json

aws iam create-role \
  --role-name dev-eks-cluster-autoscaler-role \
  --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[{
      "Effect":"Allow",
      "Principal":{"Service":"pods.eks.amazonaws.com"},
      "Action":["sts:AssumeRole","sts:TagSession"]
    }]
  }'

aws iam attach-role-policy \
  --role-name dev-eks-cluster-autoscaler-role \
  --policy-arn arn:aws:iam::088317451471:policy/dev-eks-cluster-autoscaler-policy

kubectl create serviceaccount cluster-autoscaler -n kube-system

aws eks create-pod-identity-association \
  --cluster-name dev-eks \
  --namespace kube-system \
  --service-account cluster-autoscaler \
  --role-arn arn:aws:iam::088317451471:role/dev-eks-cluster-autoscaler-role

helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update

helm install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set autoDiscovery.clusterName=dev-eks \
  --set awsRegion=us-east-1 \
  --set rbac.serviceAccount.create=false \
  --set rbac.serviceAccount.name=cluster-autoscaler
```

---

## Phase 10 — External DNS

### Step 24: Create IAM Policy & Install

```bash
cat > external-dns-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["route53:ChangeResourceRecordSets"],
      "Resource": "arn:aws:route53:::hostedzone/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets",
        "route53:ListTagsForResource"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name dev-eks-external-dns-policy \
  --policy-document file://external-dns-policy.json

aws iam create-role \
  --role-name dev-eks-external-dns-role \
  --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[{
      "Effect":"Allow",
      "Principal":{"Service":"pods.eks.amazonaws.com"},
      "Action":["sts:AssumeRole","sts:TagSession"]
    }]
  }'

aws iam attach-role-policy \
  --role-name dev-eks-external-dns-role \
  --policy-arn arn:aws:iam::088317451471:policy/dev-eks-external-dns-policy

kubectl create namespace external-dns
kubectl create serviceaccount external-dns -n external-dns

aws eks create-pod-identity-association \
  --cluster-name dev-eks \
  --namespace external-dns \
  --service-account external-dns \
  --role-arn arn:aws:iam::088317451471:role/dev-eks-external-dns-role

helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm install external-dns external-dns/external-dns \
  --namespace external-dns \
  --set serviceAccount.create=false \
  --set serviceAccount.name=external-dns \
  --set provider=aws \
  --set aws.region=us-east-1
```

---

## Phase 11 — Secrets Store CSI Driver

### Step 25: Install Secrets Store CSI + AWS Provider

```bash
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo add aws-secrets-manager https://aws.github.io/secrets-store-csi-driver-provider-aws
helm repo update

# Core driver (enables secret rotation + K8s Secret sync)
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace kube-system \
  --set syncSecret.enabled=true \
  --set enableSecretRotation=true

# AWS Secrets Manager provider
helm install secrets-provider-aws aws-secrets-manager/secrets-store-csi-driver-provider-aws \
  --namespace kube-system
```

---

## Phase 12 — Pod Identity for S3

### Step 26: Create S3 IAM Role & Service Account

```bash
export BUCKET_NAME=<your-app-bucket-name>

cat > s3-access-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject","s3:PutObject","s3:DeleteObject"],
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::${BUCKET_NAME}"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name dev-eks-s3-access-policy \
  --policy-document file://s3-access-policy.json

aws iam create-role \
  --role-name dev-eks-s3-access-role \
  --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[{
      "Effect":"Allow",
      "Principal":{"Service":"pods.eks.amazonaws.com"},
      "Action":["sts:AssumeRole","sts:TagSession"]
    }]
  }'

aws iam attach-role-policy \
  --role-name dev-eks-s3-access-role \
  --policy-arn arn:aws:iam::088317451471:policy/dev-eks-s3-access-policy

# Create service account in your application namespace
kubectl create namespace <your-app-namespace>
kubectl create serviceaccount s3-access-sa -n <your-app-namespace>

aws eks create-pod-identity-association \
  --cluster-name dev-eks \
  --namespace <your-app-namespace> \
  --service-account s3-access-sa \
  --role-arn arn:aws:iam::088317451471:role/dev-eks-s3-access-role
```

---

## Phase 13 — Helm Application Deployments

### Step 27: Install Monitoring Stack (Prometheus + Grafana + Alertmanager)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.enabled=true \
  --set grafana.enabled=true \
  --set alertmanager.enabled=true
```

### Step 28: Install Ingress NGINX Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.ingressClassResource.default=true
```

### Step 29: Install Vertical Pod Autoscaler (VPA)

```bash
helm repo add fairwinds-stable https://charts.fairwinds.com/stable
helm repo update

helm install vpa fairwinds-stable/vpa \
  --namespace kube-system
```

---

## Verification Checklist

After completing all phases, run the following to confirm everything is healthy:

```bash
# Nodes
kubectl get nodes

# All system pods
kubectl get pods -A

# EKS add-ons
aws eks list-addons --cluster-name dev-eks --region us-east-1

# LB Controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Cluster Autoscaler
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-cluster-autoscaler

# External DNS
kubectl get pods -n external-dns

# Secrets Store CSI
kubectl get pods -n kube-system -l app=secrets-store-csi-driver

# Monitoring
kubectl get pods -n monitoring

# RDS connectivity from a pod
kubectl run mysql-test --image=mysql:8.0 --restart=Never -it --rm \
  -- mysql -h $RDS_ENDPOINT -u admin -p"$DB_PASSWORD" appdb -e "SELECT 1;"
```

---

## Subnet CIDR Reference

| Subnet | CIDR | AZ | Purpose |
|---|---|---|---|
| dev-public-1a | `10.0.1.0/24` | us-east-1a | Public / ALB |
| dev-public-1b | `10.0.2.0/24` | us-east-1b | Public / ALB |
| dev-private-1a | `10.0.11.0/24` | us-east-1a | EKS nodes |
| dev-private-1b | `10.0.12.0/24` | us-east-1b | EKS nodes |
| dev-db-1a | `10.0.21.0/24` | us-east-1a | RDS |
| dev-db-1b | `10.0.22.0/24` | us-east-1b | RDS |
| dev-es-1a | `10.0.31.0/24` | us-east-1a | Elasticsearch (reserved) |
| dev-es-1b | `10.0.32.0/24` | us-east-1b | Elasticsearch (reserved) |
