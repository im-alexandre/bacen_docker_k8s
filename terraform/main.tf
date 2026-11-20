locals {
  nome = "bacen-docker-kubernetes"
  maquinas = {
    docker     = { grupo = "docker", tipo = "t3.medium" }
    k3s-server = { grupo = "k3s", tipo = "t3.medium" }
    k3s-agent  = { grupo = "k3s", tipo = "t3.medium" }
  }
}

resource "aws_key_pair" "lab" {
  key_name_prefix = "${local.nome}-"
  public_key      = trimspace(file(var.ssh_public_key_path))
}

resource "aws_instance" "lab" {
  for_each = local.maquinas

  ami                         = var.ami_id
  instance_type               = each.value.tipo
  subnet_id                   = aws_subnet.lab.id
  vpc_security_group_ids      = [aws_security_group.lab[each.value.grupo].id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.lab.key_name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted             = true
    delete_on_termination = true
    volume_type           = "gp3"
    volume_size           = 25
  }

  tags = {
    Name = "${local.nome}-${each.key}"
    Lab  = local.nome
  }

  depends_on = [aws_route_table_association.lab, aws_vpc_security_group_egress_rule.ipv4]
}
