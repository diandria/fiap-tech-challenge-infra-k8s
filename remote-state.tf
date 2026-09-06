# The database lives in another repository with its own state. Reading its
# outputs avoids repeating the endpoint and parameter name in two places.
data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = "fiap-tech-challenge-tfstate-108337503570"
    key    = "infra-db/terraform.tfstate"
    region = "us-east-1"
  }
}
