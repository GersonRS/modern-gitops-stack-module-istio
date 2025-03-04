terraform {
  required_providers {
    argocd = {
      source  = "argoproj-labs/argocd"
      version = ">= 6"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2"
    }
    utils = {
      source  = "cloudposse/utils"
      version = ">= 1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3"
    }
  }
}
