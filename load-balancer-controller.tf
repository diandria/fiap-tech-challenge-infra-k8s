# Pinned version: an unpinned chart changes between applies and the difference
# only surfaces in production.
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "3.5.0"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = data.aws_vpc.default.id
  }

  # No IRSA again. The Learner Lab allows neither an OIDC provider nor changes
  # to the LabRole trust policy, so the controller uses the instance credential,
  # which only reaches it because the launch template raised the IMDS hop limit.
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  # The chart defaults to two replicas; with two nodes, one is enough and leaves
  # memory for the observability stack.
  set {
    name  = "replicaCount"
    value = "1"
  }

  set {
    name  = "resources.requests.memory"
    value = "96Mi"
  }

  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }

  # The controller needs the networking addons up to reach the AWS API and the
  # control plane.
  depends_on = [
    aws_eks_addon.main,
    aws_eks_node_group.main,
  ]
}
