# Dicas de Kafka no Windows com WSL2

Pré-requisitos:

- Windows com WSL versão 2.
- Uma instância de Linux no WSL (eu usei Ubuntu-20.04 da Microsoft Store).

## Instalando o Kafka

Em sua instância Linux, instale o OpenJDK 8:

```
sudo apt-get install openjdk-8-jdk
```

Encontre o link de um _mirror_ dos binários do Kafka na [página oficial de downloads](https://kafka.apache.org/downloads).

Exemplo (versão 2.8):
```
wget https://mirror.nbtelecom.com.br/apache/kafka/2.8.0/kafka_2.13-2.8.0.tgz
```

Descompacte o arquivo baixado.

```
tar -xzvf kafka_2.13-2.8.0.tgz
```

Crie diretórios para os dados do Zookeeper e do Kafka.

```
cd kafka_2.13-2.8.0
mkdir data
mkdir data/kafka
mkdir data/zookeeper
```

Aponte os diretórios nos arquivos de configuração.

Edite:

```
nano config/zookeeper.properties
```

Altere:

```
dataDir=/your/path/to/data/zookeeper
```

Edite:

```
nano config/server.properties
```

Altere:

```
log.dirs=/your/path/to/data/kafka
```

## Iniciando o servidor

```
bin/zookeeper-server-start.sh config/zookeeper.properties
bin/kafka-server-start.sh config/server.properties
```

## Endereçamento do servidor

Em um terminal do WSL, obtenha o IP ao qual a máquina virtual responde:

```
ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
```

Ele deve ser liberado em `config/server.properties`:

```
listeners=PLAINTEXT://<ip-encontrado-acima>:9092
```

Esse IP deve ser usado para acessar externamente e internamente, na configuração `bootstrap-server`, em qualquer tipo de _consumer_.

Não há necessidade de se fazer [_port forwarding_](https://docs.microsoft.com/en-us/windows/wsl/compare-versions#accessing-a-wsl-2-distribution-from-your-local-area-network-lan).

Exemplo:

Veja que no Windows não há redirecionamento:

```
c:\>netsh interface portproxy show v4tov4


c:\>
```

Na instância WSL podemos obter o IP:

```
➜  ~ ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
172.25.145.150
➜  ~
```

E acessá-lo:

```
c:\>ping 172.25.145.150 -n 1

Disparando 172.25.145.150 com 32 bytes de dados:
Resposta de 172.25.145.150: bytes=32 tempo=1ms TTL=64

(...)

c:\>
```

Podemos consumir normalmente agora via terminal:

```
➜  kafka_2.13-2.8.0 bin/kafka-console-consumer.sh --bootstrap-server 172.25.145.150:9092 --topic first_topic
hello world
^CProcessed a total of 1 messages
➜  kafka_2.13-2.8.0
```

Em uma [aplicação Java](https://github.com/ermogenes/kafka-producer-java-hello-world) rodando no Windows usamos `ProducerConfig.BOOTSTRAP_SERVERS_CONFIG` com o valor `172.25.145.150:9092` pra produzir a mensagem `hello world` acima.