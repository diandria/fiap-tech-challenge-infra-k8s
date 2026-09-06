# Versions pinned on purpose: an addon that changes between applies turns
# "nothing changed in the code" into different behaviour in the cluster.
# To check compatible versions:
#   aws eks describe-addon-versions --addon-name <name> --kubernetes-version 1.34
locals {
  addons = {
    # Pod networking.
    vpc-cni    = { version = "v1.22.4-eksbuild.3", use_lab_role = false }
    kube-proxy = { version = "v1.34.6-eksbuild.21", use_lab_role = false }
    coredns    = { version = "v1.12.4-eksbuild.29", use_lab_role = false }

    # HPA prerequisite: without it the HPA sits at <unknown> and never scales.
    metrics-server = { version = "v0.9.0-eksbuild.7", use_lab_role = false }

    # Persistent volumes for Prometheus and Loki. Without it the PVCs stay
    # Pending forever and the observability stack never comes up.
    #
    # No service_account_role_arn on purpose: passing LabRole there enables
    # IRSA, which needs an OIDC provider and a trust policy, neither creatable
    # in the Learner Lab. The driver then entered CrashLoopBackOff with
    # "InvalidIdentityToken". Without IRSA the SDK falls back to the node
    # instance profile, which is already LabRole.
    aws-ebs-csi-driver = { version = "v1.65.0-eksbuild.1", use_lab_role = false }
  }
}

resource "aws_eks_addon" "main" {
  for_each = local.addons

  cluster_name  = aws_eks_cluster.main.name
  addon_name    = each.key
  addon_version = each.value.version

  service_account_role_arn = each.value.use_lab_role ? data.aws_iam_role.lab.arn : null

  # Overwrites the configuration EKS installs by default instead of failing on
  # a conflict.
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # coredns, metrics-server and the CSI controller are Deployments: with no node
  # available they stay Pending and the addon never reaches ACTIVE.
  depends_on = [aws_eks_node_group.main]
}
