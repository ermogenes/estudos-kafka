# Kafka com podman no Windows

Pré-requisitos:

- Windows com WSL versão 2 (com a versão 1 não funcionará).
- Uma instância de Linux no WSL (eu usei Ubuntu-20.04 da Microsoft Store).

## Instalando o podman

Rode todos os comandos abaixo, um a um.

```
. /etc/os-release
sudo sh -c "echo 'deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/x${NAME}_${VERSION_ID}/ /' > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list"
wget -nv https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/x${NAME}_${VERSION_ID}/Release.key -O Release.key
sudo apt-key add - < Release.key
sudo apt-get update -qq
sudo apt-get -qq -y install podman
sudo mkdir -p /etc/containers
echo -e "[registries.search]\nregistries = ['docker.io', 'quay.io']" | sudo tee /etc/containers/registries.conf
```

Para verificar se foi instalado com sucesso, use `podman info`.

## Configurando o podman

Edite `/etc/containers/containers.conf`, descomentando/alterando as seguintes configurações:

* de `cgroup_manager = "systemd"` para `cgroup_manager = "cgroupfs"`;
* de `events_logger = "journald"` para `events_logger = "file"`.

## Criando containers com a stack do Apache Kafka

Usaremos os [containers da Confluent no Docker Hub](https://hub.docker.com/r/confluent/kafka/), bem como tentaremos usar as configurações semelhantes à sua documentação.

Começaremos definindo uma variável de ambiente com o IP interno da instância do WSL:

```
WSL_eth0_IP=$(ifconfig eth0 | perl -ne 'print $1 if /inet\s.*?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b/')
```

Crie o primeiro container para o zookeeper, habilitando as portas para todos os serviços:

```
podman run -dt --name zookeeper -p 2181:2181,9092:9092,8081:8081,8082:8082 confluent/zookeeper
```

Crie os demais containers reaproveitando a rede do container do Zookeeper. O broker do Kafka deverá ser configurado para devolver o IP interno do WSL em vez de `localhost`.

```
podman run -dt --name broker --network=container:zookeeper --env KAFKA_ADVERTISED_HOST_NAME="$WSL_eth0_IP" --env KAFKA_ADVERTISED_PORT=9092 confluent/kafka
podman run -dt --name schema-registry --network=container:zookeeper confluent/schema-registry
podman run -dt --name rest-proxy --network=container:zookeeper confluent/rest-proxy
```

## Verificando os logs

Podemos verificar os logs de cada container:

```
podman logs zookeeper
podman logs broker
podman logs schema-registry
podman logs rest-proxy
```

## Executando um terminal no container

Podemos logar no container onde se encontra o Kafka:

```
podman exec -it broker /bin/bash
```

No terminal interno, podemos listar os tópicos:

```
/usr/bin/kafka-topics --list --zookeeper localhost:2181
```

E criar outros tópicos:

```
/usr/bin/kafka-topics --create --zookeeper localhost:2181 --replication-factor 1 --part
itions 1 --topic meu-topico-de-teste
```

## Testando

Podemos agora chamar os serviços usando REST.

Listar os tópicos:

```
curl -X GET http://localhost:8082/topics
```

Listar o conteúdo de um tópico:

```
curl -X GET http://localhost:8082/topics/meu-topico-de-teste
```

---

**Referências:**

* https://www.redhat.com/sysadmin/podman-windows-wsl2
* https://hub.docker.com/r/confluent/kafka/
* https://developers.redhat.com/blog/2019/01/15/podman-managing-containers-pods/
* https://developers.redhat.com/blog/2019/02/21/podman-and-buildah-for-docker-users/
* https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/building_running_and_managing_containers/index
* https://www.confluent.io/blog/kafka-listeners-explained/
* https://www.confluent.io/blog/kafka-client-cannot-connect-to-broker-on-aws-on-docker-etc/
* https://kafka-tutorials.confluent.io/kafka-console-consumer-producer-basics/kafka.html