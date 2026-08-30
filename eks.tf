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

  # Sem isto os secrets do cluster ficam apenas com a cifra padrao do disco do
  # etcd. O cluster guarda, entre outros, a senha do Grafana.
  # Habilitar e via de mao unica: nao da para remover depois.
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
    resources = ["secrets"]
  }

  vpc_config {
    subnet_ids = data.aws_subnets.cluster.ids

    # Endpoint publico e decisao consciente: o GitHub Actions roda em runner
    # hospedado e precisa alcancar o control plane para o kubectl apply do CD
    # da aplicacao. O acesso continua exigindo autenticacao IAM.
    endpoint_public_access  = true
    endpoint_private_access = true

    # Restringivel por variavel. Amplo por padrao porque os runners do GitHub
    # Actions nao tem faixa de IP estavel que caiba no limite de CIDRs do EKS.
    public_access_cidrs = var.cluster_public_access_cidrs
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
