# Prática de Kubernetes com K3s na AWS

Na [preparação comum](../README.md), Terraform cria duas EC2 para o
cluster e Ansible instala o K3s e importa as imagens `v1` e `v2` nos
dois nós. O roteiro usa a API do Kubernetes pelo `kubectl` incluído
no K3s. Abra o terminal da EC2 `k3s-server` como `ubuntu`.

## Preparar antes da gravação

```bash
cd ~/bacen-dk
k() { sudo k3s kubectl "$@"; }
ns=bacen-lab
k get nodes -o wide
k get pods -A
sudo k3s ctr images ls | grep 'bacen-lab-web'
```

Espere os dois nós em `Ready`. Confira a segunda EC2 por SSH e
verifique as duas tags também nela. A política `Never` do Deployment
pressupõe que as imagens já estejam disponíveis localmente.

## 1. Aplicar namespace, Deployment e Service

Leia [namespace.yaml](namespace.yaml) e [deployment-basico.yaml](deployment-basico.yaml).
Relacione a imagem, as duas réplicas, as labels e o seletor. Mostre o
ReplicaSet e os Pods criados pelo controlador.

```bash
k apply -f namespace.yaml -f deployment-basico.yaml
k -n "$ns" rollout status deployment/bacen-web --timeout=120s
k -n "$ns" get deploy,rs,pods -o wide
```

Leia [service.yaml](service.yaml). O Service seleciona Pods pela label
`app=bacen-web` e encaminha de 80 para a porta nomeada `http` em 8080.
Teste o DNS e uma requisição ao Service de dentro de um Pod.

```bash
k apply -f service.yaml
k -n "$ns" get svc,endpointslice
k -n "$ns" exec deploy/bacen-web -- python -c \
  'from urllib.request import urlopen; print(urlopen("http://bacen-web/info", timeout=5).read().decode())'
```

Para mostrar a página no computador do instrutor, abra outro terminal
WSL e use o túnel abaixo com o IP público de `k3s-server`. O comando
remoto cria um port-forward no loopback da EC2. Em um terceiro
terminal WSL, consulte `curl -fsS http://127.0.0.1:8087/info`.

```bash
ssh -i ~/.ssh/bacen-dk -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:8087:127.0.0.1:8087 ubuntu@IP_K3S_SERVER \
  'sudo k3s kubectl -n bacen-lab port-forward --address 127.0.0.1 svc/bacen-web 8087:80'
```

O port-forward atende por um Pod selecionado. Encerre-o com Ctrl+C
antes de remover Pods ou trocar a versão. Para observar a reconciliação,
apague um Pod da demonstração e acompanhe o substituto.

```bash
pod=$(k -n "$ns" get pods -l app=bacen-web -o jsonpath='{.items[0].metadata.name}')
k -n "$ns" delete pod "$pod"
k -n "$ns" rollout status deployment/bacen-web --timeout=120s
k -n "$ns" get pods -l app=bacen-web -o wide
```

## 2. Aplicar configuração e probes

Mostre as referências no [Deployment com probes](deployment-probes.yaml).
O [ConfigMap](configmap.yaml) fornece a mensagem. O
[Secret](secret-ficticio.yaml) contém um valor didático. A rota `/info`
indica a presença do valor sem exibi-lo. Cada Pod tem seu `emptyDir`
para o contador, que sobrevive ao reinício do contêiner no mesmo Pod.

```bash
k apply -f configmap.yaml -f secret-ficticio.yaml -f deployment-probes.yaml
k -n "$ns" rollout status deployment/bacen-web --timeout=120s
k -n "$ns" exec deploy/bacen-web -- python -c \
  'from urllib.request import urlopen; print(urlopen("http://bacen-web/info", timeout=5).read().decode())'
```

## 3. Comparar readiness e liveness

Force a falha de readiness em um Pod. Observe a condição do Pod e o
EndpointSlice. O endpoint pode continuar listado, com `ready: false`.
Remova a falha e aguarde o retorno a `Ready`.

```bash
pod=$(k -n "$ns" get pods -l app=bacen-web -o jsonpath='{.items[0].metadata.name}')
k -n "$ns" exec "$pod" -- touch /tmp/force-unready
k -n "$ns" wait --for=condition=Ready=false pod/"$pod" --timeout=30s
k -n "$ns" get pods
k -n "$ns" get endpointslice -l kubernetes.io/service-name=bacen-web -o yaml
k -n "$ns" exec "$pod" -- rm /tmp/force-unready
k -n "$ns" wait --for=condition=Ready pod/"$pod" --timeout=30s
```

Em seguida, force a falha de liveness. Espere o incremento de
`restartCount` e compare o UID do Pod. O kubelet reinicia o
contêiner, e o arquivo em `/tmp` some com a camada gravável anterior.

```bash
uid=$(k -n "$ns" get pod "$pod" -o jsonpath='{.metadata.uid}')
reinicios=$(k -n "$ns" get pod "$pod" -o jsonpath='{.status.containerStatuses[0].restartCount}')
k -n "$ns" exec "$pod" -- touch /tmp/force-unhealthy
k -n "$ns" wait --for="jsonpath={.status.containerStatuses[0].restartCount}=$((reinicios + 1))" \
  pod/"$pod" --timeout=90s
k -n "$ns" wait --for=condition=Ready pod/"$pod" --timeout=60s
test "$uid" = "$(k -n "$ns" get pod "$pod" -o jsonpath='{.metadata.uid}')" && echo "Mesmo Pod"
k -n "$ns" describe pod "$pod"
```

## 4. Atualizar e reverter

Troque a versão do contêiner `web`. Observe os ReplicaSets e a versão
no Deployment. Depois reverta e confira o retorno à `v1`.

```bash
k -n "$ns" set image deployment/bacen-web web=bacen-lab-web:v2
k -n "$ns" rollout status deployment/bacen-web --timeout=120s
k -n "$ns" get rs
k -n "$ns" rollout history deployment/bacen-web
k -n "$ns" get deployment/bacen-web -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
k -n "$ns" rollout undo deployment/bacen-web
k -n "$ns" rollout status deployment/bacen-web --timeout=120s
k -n "$ns" get deployment/bacen-web -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Se quiser mostrar a mudança na página ou em `/info`, abra um novo
port-forward após a conclusão de cada rollout.

## 5. Encerrar esta parte

Feche o túnel e remova o namespace com os recursos da demonstração.
Se a Aula 35 já foi gravada e a 36 é a próxima tomada, preserve os
objetos até terminar a Aula 36. A destruição das EC2 segue o
[roteiro comum](../README.md#3-gravar-e-encerrar).

```bash
k delete namespace "$ns" --ignore-not-found --timeout=120s
k get namespaces
```

## Sequência sugerida para a tomada

- **Aula 35, Parte 1** — nós, namespace, Deployment e ReplicaSet.
- **Aula 35, Parte 2** — Service, DNS, acesso HTTP e reposição de Pod.
- **Aula 36, Parte 1** — ConfigMap, Secret fictício e manifesto com probes.
- **Aula 36, Parte 2** — endpoints, reinício do contêiner, rollout, rollback e limpeza.
