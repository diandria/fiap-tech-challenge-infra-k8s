# O AWS Load Balancer Controller descobre onde colocar o NLB pelas tags das
# subnets. O EKS marca sozinho apenas as subnets que ele proprio cria; as da
# VPC default chegam sem tag nenhuma, e o controller falha com
# "unable to resolve at least one subnet. Evaluated 0 subnets".
#
# aws_ec2_tag adiciona a tag sem assumir a posse da subnet, que e de outro
# dono: o Terraform aqui nao gerencia a VPC default.
resource "aws_ec2_tag" "subnet_internal_elb" {
  for_each = toset(data.aws_subnets.cluster.ids)

  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

# Marca as subnets como compartilhadas com este cluster. "shared", e nao
# "owned", porque a VPC default nao pertence a este repositorio e outros
# recursos a usam.
resource "aws_ec2_tag" "subnet_cluster" {
  for_each = toset(data.aws_subnets.cluster.ids)

  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.cluster_name}"
  value       = "shared"
}
