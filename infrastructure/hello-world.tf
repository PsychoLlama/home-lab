resource "nomad_job" "hello-world" {
  jobspec = file("./hello-world.nomad")
}
