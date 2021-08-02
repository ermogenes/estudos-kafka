# Kafka cluster

_Em breve..._

<!-- ## Apache Kafka

https://docs.confluent.io/platform/current/kafka/deployment.html#running-ak-in-production

brokers >1 ... 100s...
repl fact == 3

IO: leituras sequenciais

broker.id - inteiro único por broker
advertised.listeners - AULA SÓ DISSO
delete.topic.enable - permitir exclusão de tópico
log.dirs - lista separada por `,` com os diretórios para persistência dos logs (Kafka should have its own dedicated disk(s) or SSD(s))

uma pasta para cada broker, XFS (recomendado) ou ext4
pelo menos 100k arquivos abertos simultaneamente
ex:
```bash
echo "* hard nofile 100000
* soft nofile 100000" | tee --append /etc/security/limits.conf
```

valores padrão para novos tópicos:
num.partitions
default.replication.factor === 2 ou 3
min.insync.replicas === 2

log.retention.ms
log.retention.minutes
log.retention.hours ~1 semana
log.segment.bytes ~1gb
log.retention.check.interval.ms ~5min

zookeeper.connect=[list of ZooKeeper servers]

hostname1:port1,hostname2:port2,hostname3:port3/chroot/path

ex. z1:2181,z2:2181,z3:2181/kafka
/kafka é um chroot

zookeeper.connection.timeout.ms ~6k

auto.create.topics.enable


advertised.listeners

client               cluster
may i connect?
                      yep, use this ip: {advertised.listeners}
connection to it
                      ok!

o ip divulgado deve ser acessível pelo cliente

localhost nunca funciona fora da máquina local
os nomes automáticos da rede do compose n são expostos
no compose, só vai rodar de dentro
ou ajusta no arquivo hosts




https://github.com/yahoo/cmak


https://docs.confluent.io/platform/current/installation/system-requirements.html#system-requirements
 -->
