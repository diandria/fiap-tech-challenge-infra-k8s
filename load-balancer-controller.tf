# Versao fixada: chart sem versao fixa muda embaixo do projeto entre um apply e
# outro, e a diferenca so aparece em producao.
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

  # Sem IRSA, de novo. O Learner Lab nao permite criar provedor OIDC nem
  # alterar a trust policy da LabRole, entao o controller usa a credencial da
  # instancia -- que so chega ate ele porque o launch template do node group
  # abriu o hop limit do IMDS para 2.
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  # Duas replicas por padrao no chart; com dois nos, uma basta e economiza
  # memoria para a observabilidade.
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

  # O controller precisa dos addons de rede de pe para conseguir falar com a
  # API da AWS e com o control plane.
  depends_on = [
    aws_eks_addon.main,
    aws_eks_node_group.main,
  ]
}
