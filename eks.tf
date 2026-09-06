# The Learner Lab does not allow creating IAM roles. Cluster and nodes assume
# the existing LabRole, which invalidates most EKS Terraform examples online,
# since they create dedicated roles.
data "aws_iam_role" "lab" {
  name = "LabRole"
}

#trivy:ignore:AVD-AWS-0040
#trivy:ignore:AVD-AWS-0041
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = data.aws_iam_role.lab.arn
  version  = var.cluster_version

  # Without this the cluster secrets only get the default etcd disk encryption.
  # The cluster holds the Grafana password among others. Enabling it is one-way:
  # it cannot be removed later.
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
    resources = ["secrets"]
  }

  vpc_config {
    subnet_ids = data.aws_subnets.cluster.ids

    # A public endpoint is a deliberate choice: GitHub Actions runs on a hosted
    # runner and needs to reach the control plane for the application CD's
    # kubectl apply. Access still requires IAM authentication.
    endpoint_public_access  = true
    endpoint_private_access = true

    # Restrictable by variable. Broad by default because GitHub Actions runners
    # have no stable IP range that fits the EKS CIDR limit.
    public_access_cidrs = var.cluster_public_access_cidrs
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"

    # Whoever creates the cluster gets admin. Without it Terraform itself could
    # not install the addons and charts that follow.
    bootstrap_cluster_creator_admin_permissions = true
  }

  timeouts {
    create = "30m"
    delete = "30m"
  }
}
