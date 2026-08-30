# Cifra dos secrets do cluster em repouso no etcd. O trivy acusa AWS-0039
# (HIGH) sem isto, e a acusacao procede: o cluster guarda, entre outros, a
# senha do Grafana.
#
# Uma vez habilitada no cluster, a cifra nao pode ser removida -- e uma via de
# mao unica. Aceitavel aqui porque o ambiente e efemero e recriado a cada
# ciclo.
resource "aws_kms_key" "eks_secrets" {
  description             = "Cifra dos secrets do EKS do car-repair-shop"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${local.cluster_name}-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}
