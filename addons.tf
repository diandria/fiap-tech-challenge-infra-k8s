# Versoes fixadas de proposito: addon que muda sozinho entre um apply e outro
# transforma "nada mudou no codigo" em comportamento diferente no cluster.
# Para conferir as compativeis:
#   aws eks describe-addon-versions --addon-name <nome> --kubernetes-version 1.34
locals {
  addons = {
    # Rede dos pods.
    vpc-cni    = { version = "v1.22.4-eksbuild.3", use_lab_role = false }
    kube-proxy = { version = "v1.34.6-eksbuild.21", use_lab_role = false }
    coredns    = { version = "v1.12.4-eksbuild.29", use_lab_role = false }

    # Pre-requisito do HPA: sem ele o HPA fica em <unknown> e nunca escala.
    metrics-server = { version = "v0.9.0-eksbuild.7", use_lab_role = false }

    # Volumes persistentes do Prometheus e do Loki. Sem ele os PVCs ficam
    # Pending para sempre, e a stack de observabilidade nao sobe.
    #
    # Sem service_account_role_arn de proposito. Passar a LabRole ali ativa
    # IRSA, que exige um provedor OIDC registrado no IAM e uma trust policy na
    # role -- nenhum dos dois e criavel no Learner Lab. O driver entrava em
    # CrashLoopBackOff com "InvalidIdentityToken: The web identity token
    # provided could not be validated".
    # Sem IRSA, o SDK cai no perfil de instancia do no, que ja e a LabRole e
    # tem as permissoes de EC2 necessarias.
    aws-ebs-csi-driver = { version = "v1.65.0-eksbuild.1", use_lab_role = false }
  }
}

resource "aws_eks_addon" "main" {
  for_each = local.addons

  cluster_name  = aws_eks_cluster.main.name
  addon_name    = each.key
  addon_version = each.value.version

  service_account_role_arn = each.value.use_lab_role ? data.aws_iam_role.lab.arn : null

  # Sobrescreve a configuracao que o EKS instala por padrao, em vez de falhar
  # com conflito.
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # coredns, metrics-server e o controller do CSI sao Deployments: sem no
  # disponivel ficam Pending e o addon nunca chega a ACTIVE.
  depends_on = [aws_eks_node_group.main]
}
