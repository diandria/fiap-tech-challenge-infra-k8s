# Application namespace.
#
# A namespace is environment, not application: it exists before any deploy and
# outlives all of them, which is why it belongs here.
#
# The application Service does NOT live in this repository. It follows the
# application lifecycle and sits in k8s/02-service/ of the code repository,
# alongside the Deployment, the HPA and the ConfigMap.
#
# The consequence is a provisioning order: the NLB is born from that Service and
# the gateway integration needs its listener ARN. The resources that depend on
# it live in api-gateway-routes.tf, behind var.enable_gateway_routes, and are
# applied in a second phase once the application is up.
resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = local.app_namespace
  }
}
