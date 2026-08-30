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

variable "node_desired_size" {
  description = "Quantidade de nos em regime normal."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimo de nos. Dois para tolerar a perda de um sem derrubar a observabilidade."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Teto de nos, com folga para o HPA da aplicacao escalar."
  type        = number
  default     = 4
}

variable "cluster_public_access_cidrs" {
  description = <<-TXT
    Origens autorizadas a alcancar o endpoint publico do control plane.

    Amplo por padrao porque o CD roda em runner hospedado do GitHub, cuja faixa
    de IP muda e nao cabe no limite de CIDRs do EKS. Restringir aqui e o jeito
    de fechar quando houver runner com IP fixo.
  TXT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cors_allowed_origins" {
  description = "Origens autorizadas pelo CORS do gateway."
  type        = list(string)
  default     = ["*"]
}

variable "throttling_rate_limit" {
  description = "Requisicoes por segundo em regime. Dimensionado para o cluster de dois nos."
  type        = number
  default     = 100
}

variable "throttling_burst_limit" {
  description = "Pico instantaneo tolerado acima do regime."
  type        = number
  default     = 200
}

variable "public_routes" {
  description = <<-TXT
    Rotas que o gateway encaminha para o cluster.

    Lista explicita em vez de curinga: o que nao esta aqui devolve 404 sem
    alcancar a aplicacao. E assim que a restricao do M7 -- "o endpoint interno
    de lookup nao e exposto no API Gateway" -- se torna verdadeira na
    infraestrutura, e nao apenas na intencao.

    Cada prefixo aparece duas vezes de proposito: "/customers" casa a colecao,
    "/customers/{proxy+}" casa os itens abaixo dela. Uma forma nao cobre a
    outra.

    Fora da lista de proposito:
      /auth/customers/lookup  interno, consumido so pela function
      /metrics                raspado pelo Prometheus de dentro do cluster
  TXT
  type        = list(string)

  default = [
    "POST /auth/login",
    "POST /auth/register",

    "ANY /customers",
    "ANY /customers/{proxy+}",
    "ANY /vehicles",
    "ANY /vehicles/{proxy+}",
    "ANY /services",
    "ANY /services/{proxy+}",
    "ANY /items",
    "ANY /items/{proxy+}",
    "ANY /service-orders",
    "ANY /service-orders/{proxy+}",

    # Documentacao da API, exigida pela fase.
    "GET /docs",
    "GET /docs/{proxy+}",

    # Sondas: uteis para conferir o caminho de fora sem depender de dado.
    "GET /health",
    "GET /ready",
  ]
}
