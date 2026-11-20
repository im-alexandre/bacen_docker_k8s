# Práticas de Docker e Kubernetes na AWS

O Terraform cria a rede e três EC2 Ubuntu Server 24.04 amd64. O Ansible
instala as ferramentas e publica os arquivos. As demonstrações usam os comandos de Docker, Compose e
Kubernetes nos terminais das VMs.

| Máquina | Tipo | Papel |
|---|---|---|
| `docker` | `t3.medium` | Docker Engine, Compose e build das imagens da aplicação |
| `k3s-server` | `t3.medium` | Plano de controle Kubernetes e execução de Pods |
| `k3s-agent` | `t3.medium` | Worker Kubernetes |

- [Docker e Compose](01_docker/README.md) — Aulas 33 e 37. O Dockerfile também serve à Aula 31.
- [Kubernetes](02_kubernetes/README.md) — Aula 35. A topologia também serve à Aula 34.

As duas práticas compartilham o state e o pacote. As VMs recebem IPv4 público
para SSH e downloads. Só a porta 22 aceita conexões do IPv4 do instrutor.
A API e o tráfego entre nós do K3s usam a rede privada. O teste HTTP do
Kubernetes é feito na própria EC2 do K3s. O laboratório usa uma VPC própria e pode gerar cobranças
por EC2, EBS, IPv4 público e tráfego.

## Preparar antes da gravação

Use o Bash em um Ubuntu 24.04 LTS nativo como máquina de controle.
Execute os blocos deste roteiro a partir desta pasta, na mesma sessão Bash.
Instale o Terraform (1.10 ou superior, da série 1.x) e a AWS CLI v2 para Linux.
[Instalação do Terraform](https://developer.hashicorp.com/terraform/install#linux) · [Instalação da AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

```bash
sudo apt update && sudo apt install ansible-core openssh-client curl
terraform version
aws --version
ansible-playbook --version
```

Prepare a chave SSH. Ao gerar a chave, proteja-a com uma frase secreta.
A chave privada fica em `~/.ssh`; o Terraform lê a cópia da chave pública
em `.execucao/`.

```bash
install -d -m 700 "$HOME/.ssh" .execucao
chave="$HOME/.ssh/bacen-dk"
if [[ ! -e "$chave" && ! -e "$chave.pub" ]]; then
    ssh-keygen -t ed25519 -f "$chave"
fi
chmod 600 "$chave" && ssh-keygen -l -f "$chave.pub" &&
    install -m 644 "$chave.pub" .execucao/bacen-dk.pub
```

Use uma conta AWS de laboratório. Configure o perfil no Ubuntu e, se ele
usar SSO, autentique-se com `aws sso login --profile laboratorio` antes
das consultas. Ajuste o nome do perfil e a região conforme seu ambiente.

```bash
export AWS_PROFILE='laboratorio'
regiao='sa-east-1'
aws sts get-caller-identity --region "$regiao" --query Account --output text
aws ssm get-parameter --region "$regiao" \
    --name '/aws/service/canonical/ubuntu/server/noble/stable/current/amd64/hvm/ebs-gp3/ami-id' \
    --query Parameter.Value --output text
if [[ ! -e terraform/terraform.tfvars ]]; then
    cp terraform/terraform.tfvars.example terraform/terraform.tfvars
fi
```

Preencha `terraform/terraform.tfvars` com a conta autorizada, a região
de `$regiao`, a AMI consultada e seu IPv4 público com sufixo `/32`.

## 1. Provisionar

Abra [main.tf](terraform/main.tf) e [rede.tf](terraform/rede.tf). Mostre o
mapa das três VMs, a sub-rede com rota à internet e os grupos de segurança.
As portas 6443/TCP, 8472/UDP e 10250/TCP são restritas ao grupo dos nós K3s.
O intervalo da VPC (`10.44.0.0/16`) fica fora das redes padrão de Pods e
Services do K3s (`10.42.0.0/16` e `10.43.0.0/16`).
Use as etapas a seguir durante o ensaio e mostre o plano na gravação.

```bash
terraform -chdir=terraform init
terraform -chdir=terraform fmt -check
terraform -chdir=terraform validate
terraform -chdir=terraform plan -out=lab.tfplan
```

Confira as três instâncias, a VPC, a sub-rede, a chave, a rota e os grupos
e regras de segurança. Revise a conta e a região antes da aplicação.

```bash
terraform -chdir=terraform apply lab.tfplan &&
    terraform -chdir=terraform output maquinas &&
    inventario=$(terraform -chdir=terraform output -raw inventario_ansible) &&
    printf '%s\n' "$inventario" > .execucao/inventory.ini
```

## 2. Configurar as máquinas

No terminal de controle, carregue a chave no `ssh-agent`.

```bash
eval "$(ssh-agent -s)"
ssh-add "$HOME/.ssh/bacen-dk"
```

Conecte às três VMs como `ubuntu`, usando os IPv4 públicos
do output e `ssh -i ~/.ssh/bacen-dk ubuntu@IP_PUBLICO`. Confira as impressões
digitais das chaves de host nos logs de inicialização das EC2 na primeira
conexão. Encerre cada sessão para voltar ao terminal de controle.

```bash
ansible-inventory -i .execucao/inventory.ini --graph
ansible-playbook -i .execucao/inventory.ini ansible/docker.yml
ansible-playbook -i .execucao/inventory.ini ansible/k3s.yml
```

O K3s usa o canal estável na primeira instalação e o worker usa a mesma
versão do servidor. Para repetir o ensaio com versão fixa em VMs novas,
passe `-e k3s_version=VERSAO_DO_ENSAIO` a `ansible/k3s.yml`. Os nós K3s
baixam a imagem Nginx no primeiro uso. O inventário usa os IPs públicos
para SSH, e o token de ingresso fica oculto no Ansible.

## 3. Gravar e encerrar

Faça as tomadas conforme os dois roteiros. No ensaio, confirme acesso HTTP,
persistência ao recriar o Compose, reposição do Pod e atualização da imagem
do Nginx no K3s.
Registre as versões efetivas dos programas e os tempos de
espera para decidir onde cortar inicializações na edição.

Depois de completar as duas práticas, volte ao terminal de controle
e revise a destruição na mesma pasta, conta e região do provisionamento.

```bash
terraform -chdir=terraform plan -destroy -out=limpeza.tfplan
```

Depois de revisar o plano, aplique-o e confira o state e as instâncias.

```bash
terraform -chdir=terraform apply limpeza.tfplan
terraform -chdir=terraform state list
aws ec2 describe-instances --region "$regiao" \
    --filters 'Name=tag:Lab,Values=bacen-docker-kubernetes' \
              'Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down' \
    --query 'Reservations[].Instances[].InstanceId'
```

O state deve ficar vazio. Aguarde a AWS terminar as três VMs. Arquivos
gerados em `.execucao/`, planos e state são locais ao ensaio.

## Estado de validação

Configuração e plano simulado do Terraform, sintaxe dos playbooks,
configuração do Compose e YAML dos manifestos conferidos localmente.
O provisionamento e o ensaio de ponta a ponta nas EC2 estão pendentes.

## Referências

- [AMI oficial do Ubuntu no Parameter Store](https://ubuntu.com/aws/docs/aws-how-to/instances/find-ubuntu-images/)
- [Docker Engine no Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [Requisitos e portas do K3s](https://docs.k3s.io/installation/requirements)
