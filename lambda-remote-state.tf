# The functions repository has its own state. Reading its outputs avoids
# repeating the function ARN here.
#
# Only read when the gateway routes are enabled: during the first phase of a
# from-scratch provision that state does not exist yet, because the functions
# need this cluster's gateway URL first, and reading a missing remote state
# fails the plan. See var.enable_gateway_routes.
data "terraform_remote_state" "lambda" {
  count = var.enable_gateway_routes ? 1 : 0

  backend = "s3"

  config = {
    bucket = "fiap-tech-challenge-tfstate-938405266463"
    key    = "lambda/terraform.tfstate"
    region = "us-east-1"
  }
}
