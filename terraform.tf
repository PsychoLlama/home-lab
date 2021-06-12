terraform {
  required_providers {
    kubernetes = {
      version = "~> 2.2.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}
