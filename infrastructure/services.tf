resource "nomad_job" "registry" {
  jobspec = file("./docker-registry.nomad")

  hcl2 {
    enabled = true
  }
}

resource "nomad_job" "private_ingress" {
  jobspec = file("./private-ingress.nomad")

  hcl2 {
    enabled = true
  }
}
