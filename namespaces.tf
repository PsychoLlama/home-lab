resource "kubernetes_namespace" "prod" {
  metadata {
    name = "prod"
  }
}
