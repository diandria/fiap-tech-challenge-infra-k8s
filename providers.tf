provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "car-repair-shop"
      Phase       = "3"
      ManagedBy   = "terraform"
      Repository  = "fiap-tech-challenge-infra-k8s"
      Environment = var.environment
    }
  }
}

# Autenticacao por token efemero do EKS, gerado a cada operacao. Evita gravar
# credencial de cluster em arquivo, que e o que o .gitignore ja bloqueia.
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.main.name]
  }
}
