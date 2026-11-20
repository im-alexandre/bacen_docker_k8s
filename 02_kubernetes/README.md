# Prática de Kubernetes — Nginx

Na Aula 35, suba dois Pods de Nginx, acesse o site pelo Service e
acompanhe a reposição de um Pod e a troca da imagem.
Use o servidor K3s já [preparado com Terraform e Ansible](../README.md).

## Subir e conferir

Na EC2 `k3s-server`, entre como `ubuntu`. Abra o [nginx.yaml](nginx.yaml)
e mostre dois campos. `replicas: 2` pede dois Pods e o seletor
`app: nginx` liga o Service aos Pods.

```bash
cd ~
sudo k3s kubectl apply -f nginx.yaml
sudo k3s kubectl -n bacen-nginx get pods,svc
```

Aguarde os dois Pods aparecerem com `READY 1/1`. Repita o segundo comando
se ainda estiverem iniciando. Copie o `CLUSTER-IP` do Service e, no
mesmo terminal da EC2, teste o acesso. A resposta esperada é HTTP 200.

```bash
curl -I http://IP_DO_SERVICE
```

## Apagar um Pod

Copie o nome de um dos Pods da listagem e substitua `NOME_DO_POD`.

```bash
sudo k3s kubectl -n bacen-nginx delete pod NOME_DO_POD
sudo k3s kubectl -n bacen-nginx get pods
```

Observe o novo nome. O Deployment continua pedindo duas réplicas,
então o Kubernetes cria um Pod para repor o que foi apagado.

## Atualizar a imagem

Troque a tag do contêiner `nginx` e aguarde a atualização.

```bash
sudo k3s kubectl -n bacen-nginx set image deployment/nginx nginx=nginx:alpine
sudo k3s kubectl -n bacen-nginx rollout status deployment/nginx --timeout=120s
sudo k3s kubectl -n bacen-nginx get deployment nginx -o wide
```

Confira `nginx:alpine` na coluna `IMAGES`. Repita o `curl` no mesmo IP
do Service. O endereço continua disponível para acessar os novos Pods
após a atualização.

## Limpar

```bash
sudo k3s kubectl delete namespace bacen-nginx
```
