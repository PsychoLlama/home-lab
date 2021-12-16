terraform {
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 1.4.15"
    }
  }

  backend "consul" {
    address = "tron.selfhosted.city:8500"
    scheme  = "http"
    path    = "terraform/home-lab"
  }
}

provider "nomad" {
  address = "http://tron.selfhosted.city:4646"
}
