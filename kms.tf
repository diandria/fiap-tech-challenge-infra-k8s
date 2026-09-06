# Encrypts cluster secrets at rest in etcd. Without it trivy raises AWS-0039
# (HIGH), and rightly so: the cluster holds the Grafana password among others.
#
# Once enabled the encryption cannot be removed. Acceptable here because the
# environment is ephemeral and recreated every cycle.
resource "aws_kms_key" "eks_secrets" {
  description             = "Encryption for the car-repair-shop EKS secrets"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${local.cluster_name}-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}
