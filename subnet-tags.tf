# The AWS Load Balancer Controller finds where to place the NLB through subnet
# tags. EKS tags only the subnets it creates itself; the default VPC ones arrive
# untagged and the controller fails with
# "unable to resolve at least one subnet. Evaluated 0 subnets".
#
# aws_ec2_tag adds the tag without taking ownership of the subnet, which belongs
# to someone else: this Terraform does not manage the default VPC.
resource "aws_ec2_tag" "subnet_internal_elb" {
  for_each = toset(data.aws_subnets.cluster.ids)

  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

# Marks the subnets as shared with this cluster. "shared", not "owned", because
# the default VPC does not belong to this repository and other resources use it.
resource "aws_ec2_tag" "subnet_cluster" {
  for_each = toset(data.aws_subnets.cluster.ids)

  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.cluster_name}"
  value       = "shared"
}
