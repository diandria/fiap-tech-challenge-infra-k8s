resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "default"
  node_role_arn   = data.aws_iam_role.lab.arn

  # Mesmas subnets do cluster: a lista ja exclui as AZs que nao oferecem o tipo
  # de instancia escolhido.
  subnet_ids = data.aws_subnets.cluster.ids

  instance_types = [var.node_instance_type]

  # O launch template so ajusta o IMDS; tipo de instancia e AMI continuam
  # vindo do node group e do EKS.
  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  # Um no por vez fora de servico durante atualizacao. Com dois nos, tirar os
  # dois juntos derrubaria a observabilidade inteira.
  update_config {
    max_unavailable = 1
  }

  timeouts {
    create = "30m"
    delete = "30m"
  }

  # Sem isso o Terraform tenta criar os nos antes do control plane aceitar
  # registro, e o node group falha depois de varios minutos esperando.
  depends_on = [aws_eks_cluster.main]
}
