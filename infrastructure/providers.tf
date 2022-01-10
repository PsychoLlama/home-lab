terraform {
  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 1.4.15"
    }
  }
}

provider "nomad" {
  address = "http://nomad.service.lab.selfhosted.city:4646"
}
