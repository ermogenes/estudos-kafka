# Conceitos básicos

## Introdução

O [Apache Kafka](https://kafka.apache.org/) é um sistema distribuído em software livre que implementa a arquitetura de fluxo de eventos, e que na prática permite a base tecnológica para a criação e integração de sistemas de alta disponibilidade em tempo real.

A gama de casos de uso possíveis é bem vasta, porém bastante específica. Certifique-se de que o Kafka é a ferramenta correta para o seu problema antes de utilizá-lo.

Este material é autoral, fruto de estudos informais. Refira-se à [documentação oficial](https://kafka.apache.org/documentation/) sempre que necessário e ao sentir algum estranhamento em relação ao que foi escrito.

## Infraestrutura

Pode ser instalado no Windows ou Mac, mas preferencialmente em Linux. Consiste em dois softwares principais, o Kafka e o ZooKeeper, bem como diversas outras ferramentas de apoio.

- **Apache Kafka** faz toda a mágica acontecer.
- **ZooKeeper** faz a gestão e coordenação das instâncias.

É possível utilizar clientes em praticamente todas as plataformas populares de desenvolvimento.

### _Brokers_ e _clusters_

Cada instância de servidor Kafka é chamada de _broker_. É responsável por todas as ações de persistência e leitura.

Pode ser organizado em conjuntos de _brokers_ chamados _clusters_, idealmente com 3 ou mais instâncias, podendo alcançar 100 (ou mais) em grandes projetos.

Em um _cluster_, cada _broker_ é identificado por um número identificador inteiro. Os metadados são conhecidos por todos os _brokers_ igualmente, de forma que não há um endereço de _cluster_ e qualquer um deles ao ser endereçado atua como _bootstrap server_ provendo acesso ao _cluster_ como um todo. Nenhum _broker_ possui todos os dados, pois eles ficam distribuídos.

Pode-se conseguir alta disponibilidade utilizando replicação. O fator de replicação expressa quantas réplicas serão mantidas dos dados, em _brokers_ diferentes. Assim, o fator de replicação varia entre 1 e o número de _brokers_ do _cluster_. Um _cluster_ com `N` _brokers_ é tolerante a falhas em `N-1` deles simultaneamente. Por exemplo, com 3 _brokers_ podemos ter um com falha, um em atualização e um terceiro mantendo o sistema disponível.

A coordenação é feita automaticamente pelo ZooKeeper. Um dos _brokers_ será eleito o líder e será responsável por receber e entregar os dados. Os demais atuarão como réplicas, mantendo os dados sincronizados (_in-sync replica_ ou ISR). Essa gestão é feita para cada partição  em cada tópico, portanto a carga pode ser balanceada adequadamente.

Além de gerenciar os _brokers_ em um _cluster_ e coordenar a liderança de partição, o ZooKeeper também notifica os _brokers_ sobre mudanças na estrutura, mantendo os metadados atualizados em todos os servidores. Com tantas atribuições, o ZooKeeper é obrigatório, mesmo que haja somente um _broker_.

O próprio ZooKeeper deve ser preferencialmente mantido em um _cluster_, sempre com número ímpar de servidores. Eles elegem um líder, que trata as entradas (_write_), com os demais seguidores efetuando as saídas (_read_).

O ZooKeeper é transparente aos consumidores e produtores, e acessado somente pelo Kafka.

## Modelo de armazenamento

Podemos pensar no Kafka como um grande _log_, onde dados em fluxo são armazenados em uma sequência temporal imutável, para serem consumidos ordenadamente. Dados de mesma natureza são agrupados em _tópicos_, e os tópicos são gravados em arquivos físicos distribuídos entre os _brokers_ chamados _partições_.

Os dados são retidos por um tempo finito no Kafka (ex. 1 semana), portanto não são indefinidamente persistentes. Considere casos de uso de dados em movimento, e não de dados em repouso.

### Tópicos

Os tópicos são agrupamentos de dados de mesma categoria. Atuam como tabelas em um banco relacional, porém sem as _constraints_. Outra diferença importante é a impossibilidade de alteração dos dados: os dados são imutáveis. Podem-se criar quantos tópicos forem necessários, e cada tópico pode receber dados de múltiplas origens e entregar dados para múltiplos destinos.

Ao criar um tópico definimos um nome identificador, a quantidade de partições desejadas, e a quantidade de réplicas que estarão disponíveis.

Ao se produzir uma mensagem (ou seja, gravar um mensagem em um tópico) o Kafka verifica se o tópico existe (cria com a configuração padrão se não existir), lê os seus metadados com as partições e configurações de replicação, e efetua a gravação. Após a gravação, a mensagem estará disponível para todos os consumidores interessados no tópico.

### Partições

Os dados de um tópico são gravados em arquivos físicos de dados, chamados partições. As partições são numeradas sequencialmente, a partir de `0`. Ter mais de uma partição permite que os dados e a carga sejam distribuídos, aumentando a tolerância a falhas e a disponibilidade.

Caso estejamos em um _cluster_, elas serão distribuídas entre os _brokers_ disponíveis, a critério do Kafka.

Exemplo:

Em um _cluster_ com 3 _brokers_ `1`, `2` e `3`, são criados os tópicos `A` com 3 partições, `B` com 4 partições, `C` com 2 partições, e `D` com 1 partição.

- O tópico `A` terá suas partições divididas igualmente entre os _brokers_, possivelmente um em cada;
- O tópico `B` terá suas partições divididas igualmente entre os _brokers_ com um _broker_ que recebendo mais de uma partição desse tópico;
- O tópico `C` terá suas partições divididas entre os _brokers_, com algum _broker_ não recebendo nenhuma partição;
- O tópico `D` terá sua única partição alocada em um único _broker_.

Uma possível configuração final seria:

- _Broker_ `1`
  - Tópico `A` Partição `1`
  - Tópico `B` Partição `2`
  - Tópico `C` Partição `0`
  - Tópico `D` Partição `0`
- _Broker_ `2`
  - Tópico `A` Partição `0`
  - Tópico `B` Partição `1`
  - Tópico `B` Partição `3`
- _Broker_ `3`
  - Tópico `A` Partição `2`
  - Tópico `B` Partição `0`
  - Tópico `C` Partição `1`

Em uma visão por tópico:

- Tópico `A`
  - Partição `0` no _Broker_ `2`
  - Partição `1` no _Broker_ `1`
  - Partição `2` no _Broker_ `3`
- Tópico `B`
  - Partição `0` no _Broker_ `3`
  - Partição `1` no _Broker_ `2`
  - Partição `2` no _Broker_ `1`
  - Partição `3` no _Broker_ `2`
- Tópico `C`
  - Partição `0` no _Broker_ `1`
  - Partição `1` no _Broker_ `3`
- Tópico `D`
  - Partição `0` no _Broker_ `1`

### Replicação

Em um tópico criado com o fator de replicação padrão `1`, cada partição contém dados distintos, de forma que cada dado está em uma e somente uma partição. Se definirmos um número maior de replicação, haverão cópias físicas da partição (chamadas _in-sync replicas_ ou _ISRs_) distribuídas necessariamente em _brokers_ diferentes, inativas e sincronizadas para assumir em caso de falha da partição ativa (chamada de partição líder).

O fator de replicação, portanto, é definido entre 1 e a quantidade de _brokers_ existentes no _cluster_.

Sempre haverá uma partição líder eleita entre as réplicas, que atenderá toda a carga. As demais se manterão como cópias estáticas sincronizadas, podendo assumir a liderança eventualmente a critério do Kafka.

### Dados, produtores e consumidores

Os são mantidos nos tópicos, após derem recebidos como _payloads_ da mensagens enviadas pelas aplicações com o papel de produtores, e sob demanda entregues às aplicações com o papel de consumidores.

Os dados são armazenados e transportados em forma binária em _arrays_ de _bytes_. Assim, devemos tratar nos produtores e consumidores a serialização dos dados apropriada ao caso de uso. As bibliotecas costumam incluir diversos serializadores para formatos comuns.

#### Produção

Os produtores escrevem dados nos tópicos. Não é necessário saber qual a partição ou qual _broker_ acessar, mas somente o endereço de um dos _brokers_ do _cluster_ e o nome do tópico. Toda a resolução é feita pelo Kafka, garantindo a estabilidade durante as indisponibilidades.

Os dados são empacotados em registros ou mensagens contendo um cabeçalho, uma chave opcional e o valor do dado propriamente dito. São enviados em lotes com um ou mais registros, com seu próprio cabeçalho, em um processo chamado _flush_.

O produtor pode solicitar três tipos de confirmação de recebimento após envio:

- `acks=0` não aguarda confirmação. É mais rápido, mas não garante a entrega.
- `acks=1` aguarda confirmação do líder, com possível perda de dados em caso de falha no líder entre a confirmação e a replicação.
- `acks=all` aguarda o líder e a replicação, portanto não há perdas, ao custo de latência.

🍌 A confirmação `acks=all` ainda assim pode tolerar alguma indisponibilidade nas réplicas. Isso pode ser ajustado pela combinação do fator de replicação do tópico com a configuração `min.insync.replicas` (quantidade mínima de _brokers_ - incluíndo o líder - que devem responder positivamente antes da confirmação) no _broker_ ou no tópico. Por exemplo, com fator de replicação 5 e mínimo _in sync_ de 3, a confirmação virá mesmo com dois _brokers_ fora, apesar do `acks=all`.

O Kafka decide em qual partição o dado será gravado. A quantidade de mensagens já gravadas não influencia na decisão, portanto não há divisão igualitária de espaço ocupado ou de quantidade de dados armazenados.

O dado recebe um identificador único incremental naquela partição, chamado _offset_, independente das demais partições. Ou seja, podemos ter o _offset_ `1` na partição `0` e também na partição `1`, porém com dados diferentes sem nenhuma relação além de estarem no mesmo tópico. A ordem cronológica dos dados é garantida dentro de uma partição, ou seja, o dado de _offset_ `17` certamente chegou antes do dado de _offset_ `18`. Porém, não é possível garantir ordenação entre diferentes partições, assim o dado de _offset_ `17` em uma partição pode ser anterior ao o dado de _offset_ `5` em outra.

Exemplo:

Foram enviados os dados 🍌, 🥑, 🍉, 🍓 e 🍇 ao tópico `frutas` que possui duas partições, nessa sequência. O Kafka decidiu armazenar da seguinte forma:

- Partição `0` = [🍉, 🍓]
  - Offset `1` = 🍉
  - Offset `2` = 🍓
- Partição `1` = [🍌, 🥑, 🍇]
  - Offset `1` = 🍌
  - Offset `2` = 🥑
  - Offset `3` = 🍇

Perceba que garantimos que 🍓 chegou ao tópico após 🍉, e que 🍌 chegou antes de 🍇, mas nada podemos falar sobre a relação temporal entre 🍉 e 🥑.

Qualquer outra sequência seria válida, desde que os _offsets_ na mesma partição garantam a sequência interna.

##### Retentativas e produtores idempotentes

Em caso de exceções no envio, o erro pode ser tratado pelo desenvolvedor, ou automaticamente pelo produtor.

Os produtores podem usar a configuração `retries` para fazer a retentativa automática, e esse é inclusive o comportamento padrão do Kafka nas versões >= 2.1. As configurações importantes em relação a retentativas automáticas são:

- `retries` indica quantas tentativas serão feitas em caso de exceção (`0` = nenhuma);
- `retry.backoff.ms` indica o tempo entre as retentativas;
- `delivery.timeout.ms` indica o limite de tempo para retentativas (padrão é 2 minutos);
- `max.in.flight.requests.per.connection` indica o número máximo de requisições em paralelo provenientes de uma mesma conexão. Caso seja maior do que um (padrão é `5`), pode gerar gravações fora de ordem em uma retentativa. O valor `1` garante o sequenciamento dentro da mesma conexão, mas bloqueia o paralelismo.

A solução mais simples para habilitar as retentativas e garantir a ordenação dentro da conexão é usar produtores idempotentes. Isso é feito ativando a configuração do produtor `enable.idempotence=true`. Isso exige `acks=all`, `max.in.flight.requests.per.connection=5` e `retries=Integer.MAX_VALUE` (ou seja, ou valores padrão). Há uma explicação detalhada do algoritmo usado [aqui](https://issues.apache.org/jira/browse/KAFKA-5494).

Em resumo, podemos criar um produtor seguro usando `enable.idempotence=true` associado a `min.insync.replicas=2` no tópico ou no _broker_.

##### Desempenho

Algo que melhoria substancialmente o desempenho, contraintuitivamente, é a uso de compactação na produção de mensagens, usando a configuração `compression.type`. [Escolha um dos algoritmos de compactação](https://blog.cloudflare.com/squeezing-the-firehose/), por exemplo `lz4`, `snappy` ou `zstd` e os lotes de mensagens serão compactados, reduzindo a latência, o tráfego e o espaço de armazenamento. Podemos controlar a formação dos lotes usando `linger.ms` (intervalo a aguardar antes de enviar, permitindo assim a formação de lotes maiores -- o padrão é `0`) e `batch.size` (tamanho máximo em bytes de um lote -- o padrão é 16KB).

Uma boa configuração para começar a testar é `compression.type=snappy`, `linger.ms=20` e `batch.size=32768` (32 * 1024 bytes = 32KB).

#### Consumo

Consumidores lêem dados de tópicos. Não é necessário saber qual a partição ou qual _broker_ acessar, mas somente o endereço de um dos _brokers_ do _cluster_ e o nome do tópico. Toda a resolução é feita pelo Kafka, garantindo a estabilidade durante as indisponibilidades.

Os dados serão lidos ordenadamente dentro de cada partição, porém as partições serão tratadas paralelamente. Ou seja, não há garantia de entrega na ordem em que os dados chegaram no tópico, mas somente dentro de cada partição.

Por exemplo, considerando o tópico `frutas` no estado definido acima, um consumidor pode receber [🍌, 🥑, 🍉, 🍓, 🍇] conforme a sequência enviada, porém seria uma coincidência. São igualmente válidas e possível quaisquer combinações em que 🍉 venha antes de 🍓, e que 🍇 venha depois de 🥑 que por sua vez venha depois de 🍌.

Ilustrando casos válidos:

- [🍉, 🍓, 🍌, 🥑, 🍇], em que se consumiu a partição `0` e depois a `1`;
- [🍌, 🥑, 🍇, 🍉, 🍓], em que se consumiu a partição `1` e depois a `0`;
- [🍌, 🥑, 🍉, 🍓, 🍇], em que se consumiu alternadamente, mantendo a sequencia original por coincidência;
- [🍌, 🥑, 🍉, 🍇, 🍓], em que se consumiu alternadamente, não mantendo a sequencia original mas mantendo a sequência entre partições;
- [🍉, 🍌, 🥑, 🍓, 🍇], como acima, mas em outra combinação.

Os _offsets_ atuais de cada consumidor indicam o ponto atual de leitura de um consumidor em um tópico, por partição, e permitem continuar do mesmo ponto ao retomar o consumo. Ficam armazenados no tópico `__consumer_offsets` e são mantidos automaticamente. Na entrega o consumidor terá o seu registro de _offsets_ atual alterado pelo Kafka, de forma que ele não o receberá em duplicidade, de acordo com a semântica de entrega estabelecida.

O consumidor pode utilizar uma entre três semânticas de entrega:

- `at most once`: mensagens podem ser perdidas, mas nunca são reenviadas em duplicidade. O _offset_ é ajustado ao realizar a leitura, e em caso de erro no processamento das mensagens pelo consumidor, ao reiniciar as mensagem não serão reentregues, pois a confirmação já foi dada.
- `at least once`: mensagens nunca são perdidas, mas podem ser reenviadas em duplicidade. O _offset_ é ajustado somente ao final do processo, e em caso de erro na alteração do _offset_ ou erro no processamento pelo consumidor, a entrega pode reiniciar de onde começou na última vez, potencialmente repetindo dados já processados. Para implementar isso, faça o _commit_ de _offset_ manualmente, e garanta a idempotência do procedimento. É o método preferido.
- `exactly once`: onde é garantida a entrega uma e somente uma vez, porém é restrita a processos internos do Kafka.

💡 Podemos implementar idempotência definindo chaves únicas para cada registro recebido ao consumir. Caso o dado não possua uma chave única intrínseca, uma maneira bem simples é utilizar uma chave no mecanismo de persistência que combine o nome do tópico, a partição e o _offset_, combinação essa única em uma instalação Kafka.

O modelo de consumo é o _poll_ (e não _push_). Assim, em intervalos de tempo o consumidor requisita novos registros, em vez de ser estimulado pelo Kafka. Isso permite maior controle pelos consumidores da frequência e do volume desejados para receber os dados.

🐱‍👤 Podemos especificar o tamanho mínimo em bytes de um pacote a ser recebido usando `fetch.min.bytes` (o padrão é `1`), criando lotes de transmissão e reduzindo o tráfego ao custo da latência (o máximo é controlado por `fetch.max.bytes` com o padrão de 50MB). Podemos também controlar o tamanho máximo do lote de registros usando `max.poll.records` (o padrão é `500`), aumentando a quantidade em caso de mensagens pequenas ou de alta quantidade de RAM disponível. O tamanho máximo em bytes por partição pode ser controlado por `max.partitions.fetch.bytes` (o padrão é 1MB). Só altere essas configurações em casos extremos de problemas de desempenho.

##### Retenção e repetição

Espera-se que um consumidor (ou grupo de consumidores) faça leituras contínuas. Em caso de falha ou inatividade por um período prolongado (maior do que o período de retenção) seu _offset_ se tornará inválido ou descartado.

Nesses casos, há três opções para o consumidor:

- com `auto.offset.reset=latest` serão lidos somente os novos dados, a partir da retomada do consumo.
- com `auto.offset.reset=earliest` serão lidos todos os dados disponíveis novamente, desde o início.
- com `auto.offset.reset=none` será gerada uma exceção caso não haja nenhum _offset_.

Pode-se ajustar o tempo de retenção por _broker_ usando `offset.retention.minutes` (o padrão é uma semana).

Para repetir o consumo de um tópico (receber novamente os dados a partir de um _offset_) em um grupo de consumidores, use `kafka-consumers-groups` com a opção `--reset-offsets --execute --to-earliest` e reinicie os consumidores. Atente ao fato de que eles devem ser idempotentes.

Além do _thread_ de _poll_ os consumidores em um grupo possuem um _thread_ de _heartbeat_ com o _broker_ coordenador do grupo. Ele serve para indicar que o consumidor ainda está ativo. Como os _threads_ são independentes, a realização de _polls_ muito espaçados pode gerar problemas.

- `session.timeout.ms` (padrão 10s) indica o tempo máximo de espera entre _heartbeats_ antes que o consumidor seja considerado morto. Diminuir esse valor causará rebalanceamentos mais frequentes.
- `heartbeat.interval.ms` (padrão 3s) indica o tempo de espera entre envios de _heartbeats_ pelo consumidor. É recomendado 1/3 do `timeout`.
- `max.poll.interval.ms` (padrão 5min) indica o máximo tempo decorrido entre dois _polls_ antes de declarar o consumidor morto. Esse tempo deve ser ajustado caso o tempo de processamento seja muito alto e não possa ser reduzido.

#### Chaves em mensagens

Em alguns casos de uso podemos necessitar de algum controle sobre o ordenamento das mensagens. Para isso, podemos enviar junto aos dados uma chave. O Kafka garante que dados enviados com a mesma chave serão gravados na mesma partição, desde que o número de partições se mantenha inalterado. Dessa maneira, temos a garantia do sequenciamento para mensagens com chaves semelhantes, já que estarão na mesma partição. Você ainda não poderá escolher em qual partição a primeira mensagem daquela chave irá ficar.

Um caso de uso comum seria o recebimento de posições GPS de diversos veículos onde queremos garantir as leituras na sequência para cada um deles. Poderíamos obter essa garantia enviado o identificador do veículo na chave, por exemplo. Isso forçaria as leituras a ficarem na mesma partição, onde a ordem é garantida.

As chaves, assim como os dados, são armazenados e transportados em forma binária em _arrays_ de _bytes_, e podem ser serializados e desserializados pelos clientes conforme a necessidade.

🤯 A seleção da partição é feita através do cálculo do resto da divisão de um inteiro calculado através do [hash não criptográfico Murmur2](https://en.wikipedia.org/wiki/MurmurHash) do valor da chave pelo número de partições disponíveis. Isso claramente distribui as entradas de forma dependente da quantidade de partições, de forma que a alteração nessa quantidade gera uma distribuição diferente nas próximas gravações.

#### Grupos de consumidores

Para conseguirmos paralelizar o consumo sem repetir a leitura de um dado entre as instâncias consumidoras, precisamos criar uma afinidade entre elas. Fazemos isso criando grupos de consumidores, que nada mais são do que indicadores de que eles compartilham o mesmo _offset_ em cada partição.

Um grupo de consumidores é definido por um nome, e representa geralmente um _cluster_ de consumidores de uma única aplicação.

Em um grupo, uma partição sempre será lida pelo mesmo consumidor, garantindo a ordenação. Essa coordenação é feita automaticamente pelo Kafka.

Caso hajam mais consumidores do que partições, eles ficarão inativos. Ainda assim podem ser úteis, pois serão acionados assim que um dos consumidores fique indisponível.
