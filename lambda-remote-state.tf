# O repositorio das functions tem estado proprio. Ler os outputs de la evita
# repetir o ARN da function aqui, que e como esses valores divergem.
data "terraform_remote_state" "lambda" {
  backend = "s3"

  config = {
    bucket = "fiap-tech-challenge-tfstate-108337503570"
    key    = "lambda/terraform.tfstate"
    region = "us-east-1"
  }
}
