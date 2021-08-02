# Apache ZooKeeper

Sistema de coordenação para aplicações distribuídas de alta disponibilidade, extremamente confiável e estável, utilizado em grandes projetos como o Kafka e o Hadoop.

Serviços providos:
- Gestão de configuração distribuída;
- Eleição/liderança por consenso;
- Coordenação e sincronização;
- Armazenamento chave/valor para configurações.

Para mais detalhes, consulte a [documentação oficial](https://zookeeper.apache.org/doc/current/zookeeperOver.html).

Em um cluster Kafka, o ZooKeeper é mandatório. Algumas de suas responsabilidades são:
- Armazenamento do _id_ do quórum, gerado na primeira inicialização;
- Registro e manutenção de lista dos _brokers_ disponíveis, utilizando chamadas de _heartbeat_;
- Armazenamento externo das configurações dos tópicos (partições, fator de replicação, etc.) e suas réplicas (ISR);
- Eleição de líder caso algum _broker_ se torne indisponível;
- Armazenamento das listas de controle de acesso (ACL) e quotas.

## Quórum

Dada a natureza da eleição ser a **maioria estrita**, devemos sempre utilizar `2n+1` servidores em nosso quórum (ou seja, números inteiros ímpares, como 1, 3, 5, ...). Nessa estrutura, `n` servidores indisponíveis são tolerados. Por exemplo, um quórum com 7 servidores (`n=3`) pode tolerar 3 servidores fora ao mesmo tempo. São necessário, portanto, 3 servidores para que se possa tolerar um servidor indisponível.

Uma instância única de ZooKeeper pode ser utilizada para ambientes de desenvolvimento, mas não garante nenhuma resiliência, além de não ser distribuído. Três instâncias devem ser suficientes para a maioria das instalações. Cinco instâncias exigem equipamentos e conexões de alto desempenho, maiores decisões estruturais, e são utilizados em grandes serviços como LinkedIn e Netflix. Um maior número de instâncias exigiria uma configuração com ajustes finos especializada.

8GB de disco é o mínimo recomendado para uma máquina com Linux e ZooKeeper, sendo mais comum algo entre 25 e 50GB para produção.

## Configuração

Normalmente salva em um arquivo chamado `zookeeper.properties`. Um arquivo comum contém algo como:

```ini
dataDir=/data/zookeeper
clientPort=2181
maxClientCnxns=0
tickTime=2000
initLimit=10
syncLimit=5
```

Veja todos os parâmetros [aqui](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_configuration).

As portas `2181`, `2888` e `3888` devem estar disponíveis para todos no cluster, instâncias ZooKeeper e Kafka. A porta `2181` também pode ser aberta para outros possíveis clientes.

É possível também expôr alguns _endpoints_ HTTP usando o recurso _AdminServer_, disponibilizando-os no _endpoint_ `/commands`.

Ferramentas de gestão:
- [Netflix Exhibitor](https://github.com/soabase/exhibitor)
- [ZooKeeper UI (web)](https://github.com/DeemOpen/zkui)
- [ZooKeeper GUI (desktop)](https://github.com/echoma/zkui)
- [ZooNavigator](https://github.com/elkozmon/zoonavigator)

## Interagindo

Iniciando em primeiro plano:
```bash
# bin/zookeeper-server-start.sh config/zookeeper.properties
```

Iniciando como _daemon_:
```bash
# bin/zookeeper-server-start.sh -daemon config/zookeeper.properties
```

Verificando a execução:
```bash
nc -vz localhost 2181
echo srvr | nc localhost 2181 ; echo
```

Abrindo o _shell_ (uma vez logado, use `help` para visualizar as opções):
```bash
bin/zookeeper-shell.sh localhost:2181
```

- `ls /` lista os nós da raiz (uma árvore, semelhante ao sistema de arquivos);
- `create /xyz "abc"` cria o nó `/xyz` com os dados `abc`;
- `get /xyz` retorna os dados do nó `/xyz`;
- `get /xyz true` monitora os dados do nó `/xyz`, criando um _watcher_;
- `set /xyz "pqr"` grava `pqr` no nó `/xyz`;
- `rmr /xyz ` remove o nó `/xyz ` e todos os seus filhos, recursivamente. 

Monitorando o log:
```bash
tail -F logs/zookeeper.out
```

### 4LW ("_four letter words_")

Você pode interagir com o quórum enviando comando de quatro letras para qualquer um dos nós.

Exemplo usando o utilitário `nc` (substitua `abcd` por um dos comandos válidos):
```bash
echo abcd | nc localhost 2181 ; echo
```

- `conf` retorna detalhes da configuração;
- `cons` retorna detalhes das sessões abertas;
  - `crst` reseta as estatísticas das sessões abertas;
- `dirs`  retorna o espaço total utilizado pelo ZooKeeper, em bytes;
- `envi`  retorna detalhes do ambiente;
- `ruok` retorna `imok` caso o servidor esteja rodando sem erros.
- `srvr` retorna detalhes do servidor;
- `stat` retorna estatísticas do servidor e dos clientes conectados;
  - `srst` reseta as estatísticas do servidor;
- `mntr` retorna variáveis para monitoramento e _health check_.

Lista completa [aqui](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_zkCommands).

Toda a interação com o ZooKeeper será feita pelo Kafka, sem que precisemos interagir diretamente, a não ser para depuração ou ajustes finos.

## Armazenamento

Todos os arquivos contidos em `dataDir` serão mantidos indefinidamente. Caso seja necessário fazer um expurgo, copie-os para outra instalação e faça experimentos, seguindo as recomendações da documentação oficial.

Faça backups dessa pasta e também dos logs, em `logs/zookeeper.out`, encontrado no diretório de instalação do Kafka.

## Desempenho

Os principais fatores de desempenhos são:

- Latência de rede: baixa latência é o principal fator de desempenho. Na nuvem, deixe cada servidor em uma zona de disponibilidade, mas todos na mesma região.
- Velocidade de acesso a disco: segundo item mais impactante.
- RAM _swap_: não use _swap_ em produção.
- Dados e logs em discos separados: ajuda, mas não é essencial.
- Número de servidores: adicionar muitos servidores (5+) sobrecarrega o quórum.
- Isolamento: não execute outros processos junto com o ZooKeeper.
