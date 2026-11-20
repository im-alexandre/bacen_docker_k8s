# Prática de Docker e Compose na EC2

Use a EC2 `docker` já [preparada com Terraform e Ansible](../README.md).
No Ubuntu local, substitua `IP_PUBLICO_DOCKER` pelo IP público da EC2.
Depois de entrar, rode também os testes com `curl` na própria EC2.

```bash
ssh -i ~/.ssh/bacen-dk ubuntu@IP_PUBLICO_DOCKER
```

## 1. Ciclo de vida de um contêiner

### Subir e testar

**O que fazer** — Na Aula 37, suba o Nginx e mostre o HTTP 200.
Se o Nginx ainda estiver iniciando, repita o `curl`.

```bash
sudo docker run -d --name bacen-ciclo -p 127.0.0.1:8085:80 nginx:stable-alpine
curl -I http://127.0.0.1:8085/
```

**O que falar** — “O Docker cria um contêiner a partir da imagem do
Nginx. A porta 8085 da EC2 encaminha a requisição para a porta 80 do
contêiner.”

### Parar, iniciar e remover

**O que fazer** — Observe os logs, pare o contêiner e compare o ID
exibido antes e depois de iniciar novamente. Por fim, remova o contêiner.

```bash
sudo docker logs --tail 5 bacen-ciclo
sudo docker stop bacen-ciclo
sudo docker ps -a --filter name=bacen-ciclo
sudo docker start bacen-ciclo
sudo docker ps --filter name=bacen-ciclo
sudo docker rm -f bacen-ciclo
```

**O que falar** — “Parar interrompe o Nginx. Iniciar usa o mesmo
contêiner, com o mesmo ID. Remover apaga esse contêiner. A imagem
continua disponível para criar outros.”

## 2. Subir a aplicação com Compose

### Iniciar os serviços e gravar um valor

**O que fazer** — Na Aula 33, abra o [compose.yaml](compose/compose.yaml)
e aponte os serviços `app` e `proxy` e o volume `dados`. Suba os
serviços, incremente o contador e anote o valor retornado.

```bash
cd ~/bacen-dk/01_docker/compose
sudo docker compose -p bacen-dk up -d --build --wait
sudo docker compose -p bacen-dk ps
curl -fsS -X POST http://127.0.0.1:8086/counter
```

**O que falar** — “O Compose sobe a aplicação e o proxy juntos. A
requisição entra pela porta 8086 no proxy, que encaminha para o serviço
`app`. O contador é gravado no volume `dados`.”

### Recriar os serviços e conferir o volume

**O que fazer** — Remova e recrie os contêineres. Consulte o contador
com GET e mostre que o valor é o mesmo. Depois remova o projeto e o
volume da prática.

```bash
sudo docker compose -p bacen-dk down
sudo docker compose -p bacen-dk up -d --wait
curl -fsS http://127.0.0.1:8086/counter
sudo docker compose -p bacen-dk down --volumes
```

**O que falar** — “O primeiro `down` removeu os contêineres e preservou
o volume. Quando subi os serviços de novo, a aplicação leu o mesmo
contador. No fim, `down --volumes` também remove os dados da prática.”
