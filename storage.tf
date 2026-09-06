# The StorageClass EKS creates by default uses the in-tree provisioner
# `kubernetes.io/aws-ebs`, removed from Kubernetes several versions ago and kept
# only by automatic translation. Prometheus and Loki need volumes, so an
# explicit class pointing at the real CSI driver is worth it.
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"

    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true

  # Waits for the pod to be scheduled so the volume is created in the right AZ.
  # Otherwise it can land in an AZ where the pod does not fit and get stuck.
  volume_binding_mode = "WaitForFirstConsumer"

  parameters = {
    type = "gp3"
    # Encrypted at rest; gp3 is also cheaper than gp2.
    encrypted = "true"
  }

  depends_on = [aws_eks_addon.main]
}
