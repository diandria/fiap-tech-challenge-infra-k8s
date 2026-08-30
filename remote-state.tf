# O banco vive em outro repositorio, com estado proprio. Ler os outputs de la
# evita repetir endpoint e nome de parametro em dois lugares, que e como esses
# valores divergem.
data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = "fiap-tech-challenge-tfstate-108337503570"
    key    = "infra-db/terraform.tfstate"
    region = "us-east-1"
  }
}
