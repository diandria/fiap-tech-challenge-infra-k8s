resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "default"
  node_role_arn   = data.aws_iam_role.lab.arn

  # Same subnets as the cluster: the list already excludes AZs that do not offer
  # the chosen instance type.
  subnet_ids = data.aws_subnets.cluster.ids

  instance_types = [var.node_instance_type]

  # The launch template only adjusts IMDS; instance type and AMI still come from
  # the node group and EKS.
  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  # One node out of service at a time during an update. With two nodes, taking
  # both would bring the whole observability stack down.
  update_config {
    max_unavailable = 1
  }

  timeouts {
    create = "30m"
    delete = "30m"
  }

  # Without this Terraform tries to create the nodes before the control plane
  # accepts registration, and the node group fails after minutes of waiting.
  depends_on = [aws_eks_cluster.main]
}
