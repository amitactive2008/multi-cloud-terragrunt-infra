provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "--region", var.aws_region,
        "eks", "get-token",
        "--cluster-name", var.cluster_name,
        "--role", "arn:aws:iam::${var.account_id}:role/terraform",
        "--output", "json",
      ]
      env = {
        AWS_PROFILE = "jenkins"
      }
    }
  }
}

provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "--region", var.aws_region,
      "eks", "get-token",
      "--cluster-name", var.cluster_name,
      "--role", "arn:aws:iam::${var.account_id}:role/terraform",
      "--output", "json",
    ]
    env = {
      AWS_PROFILE = "jenkins"
    }
  }
}
