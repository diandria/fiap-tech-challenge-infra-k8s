# Registry for the application image.
#
# It lives here rather than in the application repository because it is
# long-lived infrastructure: the ECR repository outlives any deploy, and
# deleting it during a rollback would lose every previous tag.
resource "aws_ecr_repository" "app" {
  name = local.cluster_name

  # Immutable on purpose. With mutable tags, overwriting an already published
  # SHA would go unnoticed and two deploys of the "same" SHA would run
  # different code.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  # The environment is recreated every Learner Lab session. Without this,
  # destroy fails with "repository contains images" and leaves cost behind.
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
