terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.24"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.15"
    }
  }
}

provider "tailscale" {
  api_key = var.tailscale_api_key
}

provider "cloudflare" {
  api_token = var.cloudflare_api_key
}

variable "cloudflare_api_key" {
  type      = string
  sensitive = true
}

variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare account ID for Zero Trust resources"
}

variable "tailscale_api_key" {
  type      = string
  sensitive = true
}
