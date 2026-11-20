# Práticas de Docker e Kubernetes na AWS

O Terraform cria a rede e três EC2 Ubuntu Server 24.04 amd64. O Ansible
instala as ferramentas, publica os arquivos e distribui duas versões da
mesma imagem. As demonstrações usam os comandos de Docker, Compose e
Kubernetes nos terminais das VMs.

| Máquina | Tipo | Papel |
|---|---|---|
| `docker` | `t3.medium` | Docker Engine, Compose e build das imagens da aplicação |
| `k3s-server` | `t3.medium` | Plano de controle Kubernetes e execução de Pods |
| `k3s-agent` | `t3.medium` | Worker Kubernetes |

- [Docker e Compose](01_docker/README.md) — Aulas 33 e 37. O Dockerfile também serve à Aula 31.
- [Kubernetes](02_kubernetes/README.md) — Aulas 35 e 36. A topologia também serve à Aula 34.

As duas práticas compartilham o state e o pacote. As VMs recebem IPv4 público
para SSH e downloads. Só a porta 22 aceita conexões do IPv4 do instrutor.
A API e o tráfego entre nós do K3s usam a rede privada. O instrutor acessa
HTTP por túnel SSH. O laboratório usa uma VPC própria e pode gerar cobranças
por EC2, EBS, IPv4 público e tráfego.

## Preparar antes da gravação

Use PowerShell 7 com Terraform e AWS CLI e um Ubuntu no WSL com
`ansible-core` 2.15 ou superior e OpenSSH. Os comandos abaixo pressupõem que a
distribuição WSL se chama `Ubuntu`. Use uma conta AWS de laboratório e
execute os blocos PowerShell a partir desta pasta.

Se o WSL ainda estiver sem Ansible, instale `ansible-core` pelo gerenciador
do Ubuntu na preparação do ambiente (`sudo apt update && sudo apt install ansible-core`).

```powershell
wsl -d Ubuntu -- ansible-playbook --version
wsl -d Ubuntu -- sh -lc 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && if [ ! -e ~/.ssh/bacen-dk ] && [ ! -e ~/.ssh/bacen-dk.pub ]; then ssh-keygen -t ed25519 -f ~/.ssh/bacen-dk; fi'
New-Item -Type Directory -Path .execucao -Force | Out-Null
$chavePublica = wsl -d Ubuntu -- sh -lc 'cat ~/.ssh/bacen-dk.pub'
if ($LASTEXITCODE -ne 0 -or $chavePublica -notmatch '^ssh-ed25519 [A-Za-z0-9+/=]+(?: .*)?$') {
    throw 'Confira a chave pública do laboratório no WSL.'
}
$chavePublica | Set-Content -Encoding ascii .execucao/bacen-dk.pub

$env:AWS_PROFILE = 'SEU_PERFIL_DE_LABORATORIO'
$regiao = 'us-east-1'
aws sts get-caller-identity --query Account --output text
aws ssm get-parameter --region $regiao --name '/aws/service/canonical/ubuntu/server/noble/stable/current/amd64/hvm/ebs-gp3/ami-id' --query Parameter.Value --output text
if (!(Test-Path terraform/terraform.tfvars)) {
    Copy-Item terraform/terraform.tfvars.example terraform/terraform.tfvars
}
```

Mantenha a chave privada no WSL com permissões restritas e proteja-a com
frase secreta. Preencha `terraform/terraform.tfvars` com a conta autorizada,
a região, a AMI consultada e seu IPv4 público com sufixo `/32`. Autentique o
perfil antes das consultas, usando `aws sso login` se necessário.
Use a mesma região no arquivo e em `$regiao` para a conferência final.

## 1. Provisionar

Abra [main.tf](terraform/main.tf) e [rede.tf](terraform/rede.tf). Mostre o
mapa das três VMs, a sub-rede com rota à internet e os grupos de segurança.
As portas 6443/TCP, 8472/UDP e 10250/TCP são restritas ao grupo dos nós K3s.
O intervalo da VPC (`10.44.0.0/16`) fica fora das redes padrão de Pods e
Services do K3s (`10.42.0.0/16` e `10.43.0.0/16`).
Use as etapas a seguir durante o ensaio e mostre o plano na gravação.

```powershell
terraform -chdir=terraform init
terraform -chdir=terraform fmt -check
terraform -chdir=terraform validate
terraform -chdir=terraform plan -out=lab.tfplan
```

Confira as três instâncias, a VPC, a sub-rede, a chave, a rota e os grupos
e regras de segurança. Revise a conta e a região antes da aplicação.

```powershell
terraform -chdir=terraform apply lab.tfplan
terraform -chdir=terraform output maquinas
terraform -chdir=terraform output -raw inventario_ansible |
    Set-Content -Encoding utf8NoBOM .execucao/inventory.ini
wsl -d Ubuntu
```

## 2. Configurar as máquinas

No terminal Ubuntu aberto na pasta do pacote, carregue a chave no
`ssh-agent`. Conecte às três VMs como `ubuntu`, usando os IPv4 públicos
do output e `ssh -i ~/.ssh/bacen-dk ubuntu@IP_PUBLICO`. Confira as impressões
digitais das chaves de host nos logs de inicialização das EC2 na primeira
conexão. Encerre cada sessão para voltar ao terminal de controle.

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/bacen-dk
ansible-inventory -i .execucao/inventory.ini --graph
ansible-playbook -i .execucao/inventory.ini ansible/docker.yml
ansible-playbook -i .execucao/inventory.ini ansible/k3s.yml
ansible-playbook -i .execucao/inventory.ini ansible/imagens.yml
```

O K3s usa o canal estável na primeira instalação e o worker usa a mesma
versão do servidor. Para repetir o ensaio com versão fixa em VMs novas,
passe `-e k3s_version=VERSAO_DO_ENSAIO` a `ansible/k3s.yml`. O playbook de
imagens constrói `v1` e `v2` no Docker, transfere o arquivo pelo controlador
Ansible e importa no containerd dos dois nós. O output de inventário usa
os IPs públicos para SSH, e o token de ingresso fica oculto no Ansible.

## 3. Gravar e encerrar

Faça as tomadas conforme os dois roteiros. No ensaio, confirme acesso HTTP,
persistência ao recriar o Compose, registro do worker, probes, rollout e
rollback. Registre as versões efetivas dos programas e os tempos de
espera para decidir onde cortar inicializações na edição.

Depois de completar as duas práticas, volte ao PowerShell e revise a
destruição na mesma pasta, conta e região do provisionamento.

```powershell
terraform -chdir=terraform plan -destroy -out=limpeza.tfplan
terraform -chdir=terraform apply limpeza.tfplan
terraform -chdir=terraform state list
aws ec2 describe-instances --region $regiao --filters 'Name=tag:Lab,Values=bacen-docker-kubernetes' 'Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down' --query 'Reservations[].Instances[].InstanceId'
```

O state deve ficar vazio. Aguarde a AWS terminar as três VMs. Arquivos
gerados em `.execucao/`, planos e state são locais ao ensaio.

## Estado de validação

Configuração e plano simulado do Terraform, sintaxe dos playbooks,
configuração do Compose e YAML dos manifestos conferidos localmente.
O provisionamento e o ensaio de ponta a ponta nas EC2 estão pendentes.

## Referências

- [Docker Engine no Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [Requisitos e portas do K3s](https://docs.k3s.io/installation/requirements)
- [Importação de imagens no K3s](https://docs.k3s.io/add-ons/import-images)
