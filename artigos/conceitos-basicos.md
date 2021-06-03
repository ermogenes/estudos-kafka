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
- `acks=1` aguarda confirmação do líder, com possível perda em caso de falha.
- `acks=all` aguarda o líder e todas as demais réplicas, portanto não há perdas, ao custo de performance.

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

O consumidor pode selecionar uma entre três semânticas de entrega:

- `at most once`, onde o _offset_ é ajustado ao realizar a leitura, e em caso de erro na transmissão a mensagem não será mais lida;
- `at least once`: onde o _offset_ é ajustado somente ao final do processo, e em caso de erro na alteração do _offset_ a mensagem será enviada novamente. É o método preferido, porém deve-se garantir a idempotência no lado do consumidor;
- `exactly once`: onde é garantida a entrega uma e somente uma vez, porém é restrita a processos internos do Kafka .

#### Chaves em mensagens

Em alguns casos de uso podemos necessitar de algum controle sobre o ordenamento das mensagens. Para isso, podemos enviar junto aos dados uma chave. O Kafka garante que dados enviados com a mesma chave serão gravados na mesma partição, desde que o número de partições se mantenha inalterado. Dessa maneira, temos a garantia do sequenciamento para mensagens com chaves semelhantes, já que estarão na mesma partição. Você ainda não poderá escolher em qual partição a primeira mensagem daquela chave irá ficar.

Um caso de uso comum seria o recebimento de posições GPS de diversos veículos onde queremos garantir as leituras na sequência para cada um deles. Poderíamos obter essa garantia enviado o identificador do veículo na chave, por exemplo. Isso forçaria as leituras a ficarem na mesma partição, onde a ordem é garantida.

As chaves, assim como os dados, são armazenados e transportados em forma binária em _arrays_ de _bytes_, e podem ser serializados e desserializados pelos clientes conforme a necessidade.

#### Grupos de consumidores

Para conseguirmos paralelizar o consumo sem repetir a leitura de um dado entre as instâncias consumidoras, precisamos criar uma afinidade entre elas. Fazemos isso criando grupos de consumidores, que nada mais são do que indicadores de que eles compartilham o mesmo _offset_ em cada partição.

Um grupo de consumidores é definido por um nome, e representa geralmente um _cluster_ de consumidores de uma única aplicação.

Em um grupo, uma partição sempre será lida pelo mesmo consumidor, garantindo a ordenação. Essa coordenação é feita automaticamente pelo Kafka.

Caso hajam mais consumidores do que partições, eles ficarão inativos. Ainda assim podem ser úteis, pois serão acionados assim que um dos consumidores fique indisponível.
 