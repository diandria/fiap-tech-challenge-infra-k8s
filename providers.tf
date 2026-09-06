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

# Authentication with an ephemeral EKS token, generated per operation. Avoids
# writing cluster credentials to a file.
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.main.name]
  }
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.main.name]
    }
  }
}
