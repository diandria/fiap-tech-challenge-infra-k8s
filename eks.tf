# O Learner Lab nao permite criar role de IAM. Cluster e nos assumem a LabRole
# existente. Isso invalida a maior parte dos exemplos de EKS com Terraform da
# internet, que criam roles dedicadas.
data "aws_iam_role" "lab" {
  name = "LabRole"
}

#trivy:ignore:AVD-AWS-0040
#trivy:ignore:AVD-AWS-0041
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = data.aws_iam_role.lab.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids = data.aws_subnets.cluster.ids

    # Endpoint publico e decisao consciente: o GitHub Actions roda em runner
    # hospedado e precisa alcancar o control plane para o kubectl apply do CD
    # da aplicacao. O acesso continua exigindo autenticacao IAM.
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"

    # Quem cria o cluster recebe admin. Sem isso, o proprio Terraform nao
    # conseguiria instalar os addons e os charts das tarefas seguintes.
    bootstrap_cluster_creator_admin_permissions = true
  }

  timeouts {
    create = "30m"
    delete = "30m"
  }
}
