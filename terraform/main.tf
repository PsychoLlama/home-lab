terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.18"
    }
  }
}

provider "tailscale" {}
