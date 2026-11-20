# Prática de Kubernetes — Nginx

Na Aula 35, demonstre como o Kubernetes executa dois Pods de Nginx,
mantém essa quantidade e oferece um endereço para acessar o site.
Faça a [preparação com Terraform e Ansible](../README.md) antes de gravar.

## 1. Entrar no servidor

**O que fazer** — No Ubuntu local, substitua `IP_PUBLICO_K3S` pelo IP
público de `k3s-server` informado pelo Terraform e entre por SSH.

```bash
ssh -i ~/.ssh/bacen-dk ubuntu@IP_PUBLICO_K3S
```

Execute os passos seguintes dentro dessa sessão, na EC2.

**O que falar** — “O cluster já está pronto. O K3s é a distribuição de
Kubernetes que usamos e já inclui o `kubectl`. Vou usar `sudo k3s kubectl` na
EC2 para ler a configuração de acesso ao cluster e enviar os comandos.”

## 2. Apresentar o manifesto

**O que fazer** — Abra o [nginx.yaml](nginx.yaml) que o Ansible copiou
para a pasta pessoal do usuário `ubuntu`. Mostre `replicas: 2`, a imagem
`nginx:stable-alpine` e o seletor `app: nginx` do Service.

```bash
cd ~
cat nginx.yaml
```

**O que falar** — “O Namespace dá um espaço próprio para os recursos
da aula. O Deployment declara que queremos dois Pods executando Nginx.
Cada Pod recebe a etiqueta `app: nginx`. O Service usa essa etiqueta
para encontrar os Pods e oferece um endereço interno na porta 80.”

## 3. Aplicar e conferir

**O que fazer** — Aplique o arquivo e liste os Pods e o Service.
Se os Pods ainda estiverem iniciando, repita a listagem até os dois
mostrarem `1/1` na coluna `READY`.

```bash
sudo k3s kubectl apply -f nginx.yaml
sudo k3s kubectl -n bacen-nginx get pods,svc
```

**O que falar** — “O `apply` enviou ao Kubernetes os três objetos do
arquivo. O Deployment mantém a quantidade de Pods que declaramos.
Aqui temos dois Pods, cada um com seu único contêiner pronto. Na linha
do Service, a coluna `CLUSTER-IP` mostra o endereço que vamos usar.”

## 4. Testar o Service com curl

**O que fazer** — Copie o `CLUSTER-IP` do Service `nginx` e substitua
`IP_DO_SERVICE` no comando. Rode na mesma sessão da EC2. Mostre o
status HTTP 200.

```bash
curl -I http://IP_DO_SERVICE
```

**O que falar** — “O `curl -I` mostra os cabeçalhos da resposta.
O HTTP 200 confirma que o Nginx respondeu pelo endereço do Service.
Esse endereço é interno ao cluster e vamos usar o mesmo IP depois da
atualização.”

## 5. Apagar um Pod e observar a reposição

**O que fazer** — Liste os Pods e copie o nome de um deles. Use-o no
lugar de `NOME_DO_POD`. A opção `--wait=false` libera o terminal assim
que a exclusão é solicitada. Use `--watch` para acompanhar a lista
até o novo Pod ficar pronto. Encerre a observação com Ctrl+C.

```bash
sudo k3s kubectl -n bacen-nginx get pods
sudo k3s kubectl -n bacen-nginx delete pod NOME_DO_POD --wait=false
sudo k3s kubectl -n bacen-nginx get pods --watch
```

**O que falar** — “Apaguei um Pod, mas o Deployment continua pedindo
dois. O Kubernetes percebe a diferença e cria outro. O nome mudou,
e a quantidade voltou a ser dois.”

## 6. Atualizar a imagem

**O que fazer** — Troque a imagem no Deployment e aguarde o
`rollout status` concluir. Na última saída, mostre `nginx:alpine`
na coluna `IMAGES`.

```bash
sudo k3s kubectl -n bacen-nginx set image deployment/nginx nginx=nginx:alpine
sudo k3s kubectl -n bacen-nginx rollout status deployment/nginx --timeout=120s
sudo k3s kubectl -n bacen-nginx get deployment nginx -o wide
```

Use o mesmo IP do passo 4 para confirmar que o site responde depois
da atualização.

```bash
curl -I http://IP_DO_SERVICE
```

**O que falar** — “Mudei a imagem que o Deployment declara, de
`nginx:stable-alpine` para `nginx:alpine`. Essa mudança faz o
Kubernetes substituir os Pods. O Service ainda seleciona a etiqueta
`app: nginx`, então o endereço para acessar o site é o mesmo.”

## 7. Encerrar a demonstração

**O que fazer** — Apague o namespace da aula e aguarde a confirmação.

```bash
sudo k3s kubectl delete namespace bacen-nginx
```

**O que falar** — “Ao remover o namespace da aula, o Kubernetes remove
os recursos que criamos nele. Vimos o Deployment manter duas réplicas
e o Service manter o endereço de acesso enquanto os Pods mudavam.”
