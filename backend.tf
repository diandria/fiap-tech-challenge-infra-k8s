terraform {
  backend "s3" {
    bucket = "fiap-tech-challenge-tfstate-938405266463"
    key    = "infra-k8s/terraform.tfstate"
    region = "us-east-1"

    encrypt = true

    # Native S3 locking. dynamodb_table was deprecated by Terraform; same
    # decision as the database repository.
    use_lockfile = true
  }
}
