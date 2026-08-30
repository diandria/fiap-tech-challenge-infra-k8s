# Registro da imagem da aplicacao.
#
# Mora neste repositorio, e nao no da aplicacao, porque e infraestrutura de
# longa duracao: o repositorio ECR sobrevive a qualquer deploy, e apaga-lo
# junto com um rollback de aplicacao perderia todas as tags anteriores --
# inclusive a que se quer voltar.
resource "aws_ecr_repository" "app" {
  name = local.cluster_name

  # Imutavel de proposito. Com tags mutaveis, `sobrescrever` a tag de um SHA
  # ja publicado passaria despercebido, e dois deploys do "mesmo" SHA rodariam
  # codigo diferente. E o tipo de divergencia que so aparece sob pressao.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  # O ambiente e efemero e recriado a cada sessao do Learner Lab. Sem isto, o
  # destroy falharia com "repository contains images" e deixaria custo para
  # tras justamente na hora em que se quer derrubar tudo.
  force_delete = true
}

# Sem expiracao, cada deploy acumula uma imagem de ~200 MB para sempre. Dez
# imagens cobrem qualquer rollback plausivel neste projeto.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Mantem as 10 imagens mais recentes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      },
    ]
  })
}
