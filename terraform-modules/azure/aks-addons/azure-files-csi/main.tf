terraform {
  required_version = ">= 1.10.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.27, < 3.0"
    }
  }
}

locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Cluster     = var.cluster_name
  })
}

# ── AKS cluster data (provides kube_config for Kubernetes provider) ───────────

data "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.this.kube_config[0].host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
}

# ── Azure Storage Account for Azure Files ─────────────────────────────────────

resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type

  # Enable large file shares (up to 100 TiB) for SMB
  large_file_share_enabled = true

  # Enable secure transfer (HTTPS and SMB encryption)
  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"

  # Enable NFS v4.1 support when the Premium + NFS class is requested
  is_hns_enabled = false

  tags = merge(local.common_tags, { Component = "azure-files-csi" })
}

# ── Role Assignment: kubelet identity → Storage File Data SMB Share Contributor ─

resource "azurerm_role_assignment" "smb_share_contributor" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = var.kubelet_identity_object_id
}

# ── Kubernetes Secret: SMB credentials for static PV provisioning ─────────────

resource "kubernetes_secret" "azurefile_smb" {
  metadata {
    name      = "azure-files-smb-secret"
    namespace = "kube-system"
  }

  type = "Opaque"

  data = {
    azurestorageaccountname = azurerm_storage_account.this.name
    azurestorageaccountkey  = azurerm_storage_account.this.primary_access_key
  }
}

# ── SMB StorageClass (dynamic provisioning) ───────────────────────────────────

resource "kubernetes_storage_class" "azurefile_smb" {
  metadata {
    name = var.smb_storage_class_name
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
  }

  storage_provisioner    = "file.csi.azure.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = true

  parameters = {
    skuName = "${var.storage_account_tier}_${var.storage_account_replication_type}"
    # Provision shares in the dedicated storage account
    storageAccount = azurerm_storage_account.this.name
    resourceGroup  = var.resource_group_name
    protocol       = "smb"
  }

  mount_options = ["dir_mode=0777", "file_mode=0777", "uid=1000", "gid=1000", "mfsymlinks", "cache=strict"]
}

# ── NFS StorageClass (dynamic provisioning, requires Premium tier) ────────────

resource "kubernetes_storage_class" "azurefile_nfs" {
  count = var.enable_nfs_storage_class ? 1 : 0

  metadata {
    name = var.nfs_storage_class_name
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
  }

  storage_provisioner    = "file.csi.azure.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = true

  parameters = {
    skuName       = "Premium_LRS"
    protocol      = "nfs"
    resourceGroup = var.resource_group_name
  }
}
