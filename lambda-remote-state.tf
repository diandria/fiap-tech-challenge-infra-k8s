# The functions repository has its own state. Reading its outputs avoids
# repeating the function ARN here.
data "terraform_remote_state" "lambda" {
  backend = "s3"

  config = {
    bucket = "fiap-tech-challenge-tfstate-938405266463"
    key    = "lambda/terraform.tfstate"
    region = "us-east-1"
  }
}
