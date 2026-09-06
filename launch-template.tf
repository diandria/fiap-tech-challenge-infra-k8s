# Exists for one specific reason: without it the nodes come up with
# HttpPutResponseHopLimit = 1, and the IMDS response does not cross the extra
# hop from the pod network to the host. Any pod relying on the instance
# credential fails with "no EC2 IMDS role found".
#
# That breaks the EBS CSI driver and would break the load balancer controller
# too: both call the AWS API, and the Learner Lab offers no IRSA.
resource "aws_launch_template" "node" {
  name_prefix = "${local.cluster_name}-node-"
  description = "EKS nodes with IMDS reachable from the pods"

  metadata_options {
    http_endpoint = "enabled"

    # IMDSv2 required. Hop limit 2 is the minimum for a pod to reach it, and
    # keeping it at 2 limits the reach to a single container hop.
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # AMI deliberately omitted: without it EKS uses the optimised image matching
  # the cluster version and keeps it updated.

  lifecycle {
    create_before_destroy = true
  }
}
