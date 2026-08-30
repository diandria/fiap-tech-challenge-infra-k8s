terraform {
  backend "s3" {
    bucket = "fiap-tech-challenge-tfstate-108337503570"
    key    = "infra-k8s/terraform.tfstate"
    region = "us-east-1"

    encrypt = true

    # Trava nativa do S3. O dynamodb_table foi deprecado pelo Terraform;
    # mesma decisao tomada no repositorio do banco.
    use_lockfile = true
  }
}
