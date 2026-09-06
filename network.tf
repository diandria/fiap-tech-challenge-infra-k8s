data "aws_vpc" "default" {
  default = true
}

# Not every AZ offers the chosen instance type: us-east-1e has no t3.medium.
# Deriving the list from what the account actually offers avoids a node group
# that fails to come up ten minutes into the apply.
data "aws_ec2_instance_type_offerings" "node" {
  location_type = "availability-zone"

  filter {
    name   = "instance-type"
    values = [var.node_instance_type]
  }
}

data "aws_subnets" "cluster" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = data.aws_ec2_instance_type_offerings.node.locations
  }
}
