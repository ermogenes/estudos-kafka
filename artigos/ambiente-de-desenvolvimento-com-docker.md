# Ambiente de desenvolvimento com Docker

Como criar ambientes de desenvolvimento contendo clusters de Kafka usando Docker e imagens mantidas pela comunidade.

## Confluent Platform Community

A Confluent disponibiliza um _compose file_ que inicia toda a família de aplicações do ecossistema Kafka cujo uso é [liberado para a comunidade](https://www.confluent.io/confluent-community-license-faq/).

Ele iniciará os seguintes serviços: ZooKeeper, Kafka, Schema Registry, REST Proxy, Connect, ksqlDB e ksql-datagen.

Ref.: https://docs.confluent.io/platform/current/quickstart/cos-docker-quickstart.html

### Passo-a-passo

Baixe [este _compose file_](https://raw.githubusercontent.com/confluentinc/cp-all-in-one/6.2.0-post/cp-all-in-one-community/docker-compose.yml).

Caso possua alguma versão de curl (como de CygWin ou GoW), pode usar:

```
curl --silent --output docker-compose.yml https://raw.githubusercontent.com/confluentinc/cp-all-in-one/6.2.0-post/cp-all-in-one-community/docker-compose.yml
```

Agora suba todos os containers usando:

```
docker-compose up -d
```

Ele vai baixar todas as imagens e executar todos os serviços. Ao terminar, verifique se todos os serviços estão com `State` indicando `Up`, usando:

```
docker-compose ps
```

Para parar os serviços todos de uma vez, use:

```
docker-compose stop
```

### Executando comandos CLI

Podemos agora utilizar os utilitários CLI do Kafka constantes no container `broker`.

Isso pode ser feito de duas maneiras:

#### Logando no container

```
docker exec -it broker bash
```

Uma vez logado no broker:

```
kafka-topics --list --bootstrap-server localhost:9092
```

#### Usando `docker-compose exec`

```
docker-compose exec broker kafka-topics --list --bootstrap-server localhost:9092
```

## Alternativas

- [_Compose files_ da Conduktor](https://github.com/conduktor/kafka-stack-docker-compose);
- [Imagem `fast-data-dev` da Landoop](https://hub.docker.com/r/landoop/fast-data-dev).
