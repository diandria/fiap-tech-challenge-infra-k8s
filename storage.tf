# A StorageClass que o EKS cria por padrao usa o provisionador in-tree
# `kubernetes.io/aws-ebs`, removido do Kubernetes ha varias versoes e mantido
# so por traducao automatica. Prometheus e Loki dependem de volume, entao vale
# uma classe explicita apontando para o driver CSI de verdade.
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"

    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true

  # Espera o pod ser agendado para criar o volume na AZ certa. Sem isso, o
  # volume pode nascer numa AZ onde o pod nao cabe, e ficar preso.
  volume_binding_mode = "WaitForFirstConsumer"

  parameters = {
    type = "gp3"
    # Volume cifrado em repouso; gp3 tambem e mais barato que gp2.
    encrypted = "true"
  }

  depends_on = [aws_eks_addon.main]
}
