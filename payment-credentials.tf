# Credentials of the Billing Service at the payment service: the OAuth client
# it exchanges for a token, and the secret that signs payment notifications.
#
# Generated once here and published to SSM. The CDs of both services read the
# same parameters, so the provider and the merchant can never disagree on a
# value, and nothing is copied by hand.
resource "random_id" "payment_client_id" {
  byte_length = 8
}

resource "random_password" "payment_client_secret" {
  length  = 40
  special = false
}

resource "random_password" "payment_webhook_secret" {
  length  = 40
  special = false
}

resource "aws_ssm_parameter" "payment_client_id" {
  name        = "/car-repair-shop/payment/client-id"
  description = "OAuth client id of the Billing Service at the payment service."
  type        = "String"
  value       = "billing-${random_id.payment_client_id.hex}"
}

resource "aws_ssm_parameter" "payment_client_secret" {
  name        = "/car-repair-shop/payment/client-secret"
  description = "OAuth client secret of the Billing Service at the payment service."
  type        = "SecureString"
  value       = random_password.payment_client_secret.result
}

resource "aws_ssm_parameter" "payment_webhook_secret" {
  name        = "/car-repair-shop/payment/webhook-secret"
  description = "Signs the payment notifications the payment service sends to the Billing Service."
  type        = "SecureString"
  value       = random_password.payment_webhook_secret.result
}
