# Prática de Docker e Compose na EC2

Na [preparação comum](../README.md), Terraform provisiona a EC2
`docker` e Ansible instala o Engine, os plugins e publica os arquivos.
Abra uma sessão SSH na máquina Docker e execute os comandos abaixo em Bash.
Use `sudo` para acessar o daemon. Abra o túnel abaixo em um terminal Bash
do Ubuntu local. Substitua `IP_DOCKER` pelo IPv4 público do output `maquinas`.
Deixe o túnel aberto durante a demonstração e execute os comandos HTTP
em outro terminal do Ubuntu local.

```bash
ssh -i ~/.ssh/bacen-dk -N -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:8085:127.0.0.1:8085 \
  -L 127.0.0.1:8086:127.0.0.1:8086 ubuntu@IP_DOCKER
```

Antes da tomada, confira as portas locais e preaqueça as imagens. Leia o
[Dockerfile](../app/Dockerfile) e compare a construção da imagem com a
execução de um contêiner.

```bash
cd ~/bacen-dk
sudo docker version
sudo docker compose version
sudo docker pull nginx:stable-alpine
sudo docker compose -p bacen-dk -f 01_docker/compose/compose.yaml config --quiet
```

## 1. Ciclo de vida de um contêiner

Confira se o nome `bacen-ciclo` está livre. Rode o NGINX e leia o
mapeamento de portas, o estado e os logs.

```bash
sudo docker ps -a --filter 'name=^/bacen-ciclo$'
sudo docker run --pull=never -d --name bacen-ciclo -p 127.0.0.1:8085:80 nginx:stable-alpine
sudo docker port bacen-ciclo
sudo docker inspect bacen-ciclo --format '{{.Id}} {{.Config.Image}} {{.State.Status}}'
```

No terminal do Ubuntu local, com o túnel ativo, execute
`curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8085/`.
Espere HTTP 200. Volte à EC2 para observar o processo.

```bash
sudo docker logs --tail 20 bacen-ciclo
sudo docker stats --no-stream bacen-ciclo
sudo docker exec bacen-ciclo nginx -v

id_antes=$(sudo docker inspect bacen-ciclo --format '{{.Id}}')
sudo docker stop bacen-ciclo
sudo docker ps -a --filter 'name=^/bacen-ciclo$'
sudo docker start bacen-ciclo
id_depois=$(sudo docker inspect bacen-ciclo --format '{{.Id}}')
test "$id_antes" = "$id_depois" && echo "Mesmo contêiner"
```

Repita a consulta HTTP. Para encerrar esta parte, pare e remova somente
o contêiner da prática. Compare a lista de contêineres com a de imagens.

```bash
sudo docker stop bacen-ciclo
sudo docker rm bacen-ciclo
sudo docker ps -a --filter 'name=^/bacen-ciclo$'
sudo docker image ls nginx:stable-alpine
```

## 2. Subir a aplicação com Compose

Na EC2, entre em `~/bacen-dk/01_docker/compose`. Leia o
[compose.yaml](compose/compose.yaml). Siga o caminho da requisição
HTTP do túnel ao proxy e do proxy ao serviço `app`, nome resolvido
na rede do projeto. O SQLite usa um volume nomeado.

```bash
cd ~/bacen-dk/01_docker/compose
sudo docker compose -p bacen-dk config --quiet
sudo docker compose -p bacen-dk ps --all
sudo docker compose -p bacen-dk build
sudo docker compose -p bacen-dk up -d --wait --wait-timeout 90
sudo docker compose -p bacen-dk ps
sudo docker compose -p bacen-dk exec -T proxy wget -qO- http://app:8080/info
```

No Ubuntu local, com o túnel ativo, leia a versão e incremente o contador.
Anote a resposta do `GET /counter`.

```bash
curl -fsS http://127.0.0.1:8086/info
curl -fsS -X POST http://127.0.0.1:8086/counter
curl -fsS http://127.0.0.1:8086/counter
```

Na EC2, recrie os serviços. O primeiro `down` preserva o volume.

```bash
sudo docker compose -p bacen-dk down
sudo docker volume inspect bacen-dk_dados --format '{{.Name}}'
sudo docker compose -p bacen-dk up -d --wait --wait-timeout 90
sudo docker compose -p bacen-dk logs --tail 15
```

Repita o `GET /counter`. Espera-se o mesmo valor, pois o volume reaparece
na montagem do novo contêiner. Compare o healthcheck HTTP com
`depends_on: condition: service_healthy` na partida do proxy.

## 3. Encerrar esta parte

Na EC2, remova os serviços e os dados gerados da prática. Feche o
túnel com Ctrl+C no terminal que o executa.

```bash
sudo docker compose -p bacen-dk down --volumes
sudo docker compose -p bacen-dk ps --all
sudo docker volume ls --filter label=com.docker.compose.project=bacen-dk
```

## Sequência sugerida para a tomada

- **Aula 33** — YAML, build, serviços saudáveis, acesso via proxy e contador após a recriação.
- **Aula 37** — imagem e execução, HTTP, logs e métricas, mesmo ID após reiniciar e remoção.
