variable "aws_region" {
  description = "Regiao AWS. O Learner Lab so libera us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Nome do ambiente, usado em tags e nomes de recursos."
  type        = string
  default     = "production"
}

variable "cluster_version" {
  description = <<-TXT
    Versao do Kubernetes no EKS.

    1.34, e nao a 1.31 de versoes anteriores deste plano: 1.31, 1.32 e 1.33
    entraram em suporte estendido, que a AWS cobra a USD 0,60 por hora contra
    USD 0,10 do suporte padrao. Seis vezes mais caro pelo mesmo cluster.
    Conferir com: aws eks describe-cluster-versions
  TXT
  type        = string
  default     = "1.34"
}

variable "node_instance_type" {
  description = <<-TXT
    Tipo das instancias do node group.

    t3.medium, e nao t3.small: com dois t3.small o alocavel fica em ~3,2 GB, e
    so os pods de sistema (CNI, kube-proxy, CoreDNS, metrics-server, CSI driver
    e o controller do load balancer) consomem ~1 GB. A stack de observabilidade
    pede outros ~2 GB, e nao sobraria memoria para a aplicacao.
  TXT
  type        = string
  default     = "t3.medium"
}
