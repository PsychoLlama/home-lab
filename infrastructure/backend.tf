terraform {
  backend "consul" {
    address = "consul.service.selfhosted.city:8500"
    scheme  = "http"
    path    = "terraform/home-lab"
  }
}
