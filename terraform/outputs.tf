output "maquinas" {
  value = {
    for nome, vm in aws_instance.lab : nome => {
      ip_publico = vm.public_ip
      ip_privado = vm.private_ip
    }
  }
}

output "inventario_ansible" {
  value = <<-EOT
    [docker_hosts]
    docker ansible_host=${aws_instance.lab["docker"].public_ip}

    [k3s_server]
    k3s-server ansible_host=${aws_instance.lab["k3s-server"].public_ip} k3s_ip=${aws_instance.lab["k3s-server"].private_ip}

    [k3s_agent]
    k3s-agent ansible_host=${aws_instance.lab["k3s-agent"].public_ip} k3s_ip=${aws_instance.lab["k3s-agent"].private_ip}

    [k3s:children]
    k3s_server
    k3s_agent

    [all:vars]
    ansible_user=ubuntu
    ansible_ssh_private_key_file=~/.ssh/bacen-dk
  EOT
}
