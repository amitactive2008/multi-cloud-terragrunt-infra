terraform {
  required_version = ">= 1.10.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

data "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.this.kube_config[0].host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
  }
}

# Role assignment so the cluster can scale node pools
resource "azurerm_role_assignment" "contributor" {
  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.node_resource_group}"
  role_definition_name = "Contributor"
  principal_id         = data.azurerm_kubernetes_cluster.this.identity[0].principal_id
}

resource "helm_release" "cluster_autoscaler" {
  name             = "cluster-autoscaler"
  repository       = "https://kubernetes.github.io/autoscaler"
  chart            = "cluster-autoscaler"
  version          = var.cluster_autoscaler_version
  namespace        = var.service_account_namespace
  create_namespace = false

  set {
    name  = "cloudProvider"
    value = "azure"
  }

  set {
    name  = "azureClientID"
    value = data.azurerm_kubernetes_cluster.this.kubelet_identity[0].client_id
  }

  set {
    name  = "azureResourceGroup"
    value = var.node_resource_group
  }

  set {
    name  = "azureSubscriptionID"
    value = var.subscription_id
  }

  set {
    name  = "azureClusterName"
    value = var.cluster_name
  }

  depends_on = [azurerm_role_assignment.contributor]
}
