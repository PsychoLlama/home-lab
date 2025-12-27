terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.18"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "tailscale" {
  api_key = var.tailscale_api_key
}

provider "cloudflare" {
  api_token = var.cloudflare_api_key
}
