# Kafka cluster

## ZooKeeper

Sistema de coordenação para aplicações distribuídas de alta disponibilidade, extremamente confiável e estável, utilizado em grandes projetos como o Kafka e o Hadoop.

Serviços providos:
- Gestão de configuração distribuída;
- Eleição/liderança por consenso;
- Coordenação e sincronização;
- Armazenamento chave/valor para configurações.

Para mais detalhes, consulte a [documentação oficial](https://zookeeper.apache.org/doc/current/zookeeperOver.html).

Em um cluster Kafka, o ZooKeeper é mandatório. Algumas de suas responsabilidades são:
- Armazenamento do _id_ do cluster, gerado na primeira inicialização;
- Registro e manutenção de lista dos _brokers_ disponíveis, utilizando chamadas de _heartbeat_;
- Armazenamento externo das configurações dos tópicos (partições, fator de replicação, etc.) e suas réplicas (ISR);
- Eleição de líder caso algum _broker_ se torne indisponível;
- Armazenamento das listas de controle de acesso (ACL) e quotas.

### Quórum

Dada a natureza da eleição ser a **maioria estrita**, devemos sempre utilizar `2n+1` servidores em nosso cluster (ou seja, números inteiros ímpares, como 1, 3, 5, ...). Nessa estrutura, `n` servidores indisponíveis são tolerados. Por exemplo, um cluster com 7 servidores (`n=3`) pode tolerar 3 servidores fora ao mesmo tempo. São necessário, portanto, 3 servidores para que se possa tolerar um servidor indisponível.

Uma instância única de ZooKeeper pode ser utilizada para ambientes de desenvolvimento, mas não garante nenhuma resiliência, além de não ser distribuído. Três instâncias devem ser suficientes para a maioria das instalações. Cinco instâncias exigem equipamentos e conexões de alto desempenho, maiores decisões estruturais, e são utilizados em grandes serviços como LinkedIn e Netflix. Um maior número de instâncias exigiria uma configuração com ajustes finos especializada.

8GB de disco é o mínimo recomendado para uma máquina com Linux e ZooKeeper, sendo mais comum algo entre 25 e 50GB para produção.

### Configuração

Normalmente salva em um arquivo chamado `zookeeper.properties`:

```ini
tickTime=2000
dataDir=/var/lib/zookeeper/
clientPort=2181
initLimit=5
syncLimit=2
server.1=zoo1:2888:3888
server.2=zoo2:2888:3888
server.3=zoo3:2888:3888
```

As portas `2181`, `2888` e `3888` devem estar disponíveis para todos no cluster, instâncias ZooKeeper e Kafka. A porta `2181` também pode ser aberta para outros possíveis clientes.

Veja todos os parâmetros [aqui](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_configuration).