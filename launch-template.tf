# Existe por um motivo especifico: sem ele os nos sobem com
# HttpPutResponseHopLimit = 1, e nessa configuracao a resposta do IMDS nao
# atravessa o salto extra da rede do pod para o host. Qualquer pod que dependa
# da credencial da instancia falha com "no EC2 IMDS role found".
#
# Isso derruba o driver do EBS CSI, e derrubaria tambem o controller do load
# balancer -- os dois precisam chamar a API da AWS e, no Learner Lab, nao ha
# IRSA disponivel (nao da para criar provedor OIDC nem alterar a trust policy
# da LabRole).
resource "aws_launch_template" "node" {
  name_prefix = "${local.cluster_name}-node-"
  description = "Nos do EKS com IMDS alcancavel pelos pods"

  metadata_options {
    http_endpoint = "enabled"

    # IMDSv2 obrigatorio. Hop limit 2 e o minimo para o pod alcancar; manter
    # em 2, e nao mais, limita o alcance a um salto de container.
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # AMI de proposito ausente: sem ela o EKS usa a imagem otimizada que
  # corresponde a versao do cluster, e continua atualizando junto.

  lifecycle {
    create_before_destroy = true
  }
}
