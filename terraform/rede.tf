resource "aws_vpc" "lab" {
  cidr_block           = "10.44.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = local.nome }
}

resource "aws_subnet" "lab" {
  vpc_id     = aws_vpc.lab.id
  cidr_block = "10.44.1.0/24"
  tags       = { Name = "${local.nome}-publica" }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id
}

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }
}

resource "aws_route_table_association" "lab" {
  subnet_id      = aws_subnet.lab.id
  route_table_id = aws_route_table.publica.id
}

resource "aws_security_group" "lab" {
  for_each = toset(["docker", "k3s"])

  name_prefix = "${local.nome}-${each.key}-"
  vpc_id      = aws_vpc.lab.id
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = aws_security_group.lab

  security_group_id = each.value.id
  cidr_ipv4         = var.instructor_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "k3s" {
  for_each = {
    api     = { port = 6443, protocol = "tcp" }
    flannel = { port = 8472, protocol = "udp" }
    kubelet = { port = 10250, protocol = "tcp" }
  }

  security_group_id            = aws_security_group.lab["k3s"].id
  referenced_security_group_id = aws_security_group.lab["k3s"].id
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.port
  to_port                      = each.value.port
}

resource "aws_vpc_security_group_egress_rule" "ipv4" {
  for_each = aws_security_group.lab

  security_group_id = each.value.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
