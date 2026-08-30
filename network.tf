data "aws_vpc" "default" {
  default = true
}

# Nem toda AZ oferece o tipo de instancia escolhido: us-east-1e nao tem
# t3.medium. Derivar a lista do que a conta realmente oferece evita um node
# group que falha ao subir, dez minutos depois do apply comecar.
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
