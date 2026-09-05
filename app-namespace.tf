# Namespace da aplicacao.
#
# O namespace e ambiente, e nao aplicacao: ele existe antes de qualquer deploy
# e sobrevive a todos eles. Por isso fica aqui.
#
# O Service da aplicacao **nao** mora neste repositorio. Ele acompanha o ciclo
# de vida da aplicacao e esta em k8s/02-service/ no repositorio do codigo,
# junto do Deployment, do HPA e do ConfigMap.
#
# A consequencia e uma ordem de provisionamento: o NLB nasce daquele Service, e
# a integracao do gateway precisa do ARN do listener dele. Os recursos que
# dependem disso estao separados em api-gateway-routes.tf e sao aplicados numa
# segunda fase, depois que a aplicacao subiu.
resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = local.app_namespace
  }
}
