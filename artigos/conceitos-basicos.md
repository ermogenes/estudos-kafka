# Conceitos básicos

## Introdução

_em breve..._

## Infraestrutura

Pode ser instalado no Windows ou Mac, mas preferencialmente em Linux. Consiste em dois softwares principais, o Kafka e o Zookeeper, bem como diversas outras ferramentas de apoio.

- **Apache Kafka** faz toda a mágica acontecer.
- **Zookeeper** faz a gestão e coordenação das instâncias.

### _Brokers_ e _clusters_

Cada instância de servidor Kafka é chamada de _broker_. É responsável por todas as ações de persistência e leitura.

Pode ser organizado em conjuntos de _brokers_ chamados _clusters_, idealmente com 3 ou mais instâncias, podendo alcançar 100 (ou mais) em grandes projetos.

Em um _cluster_, cada _broker_ é identificado por um número identificador inteiro. Os metadados são conhecidos por todos os _brokers_ igualmente, de forma que não há um endereço de _cluster_ e qualquer um deles ao ser endereçado atua como _bootstrap server_ provendo acesso ao _cluster_ como um todo. Nenhum _broker_ possui todos os dados, pois eles ficam distribuídos.

Pode-se conseguir alta disponibilidade utilizando replicação. O fator de replicação expressa quantas réplicas serão mantidas dos dados, em _brokers_ diferentes. Assim, o fator de replicação varia entre 1 e o número de _brokers_ do _cluster_. Um _cluster_ com `N` _brokers_ é tolerante a falhas em `N-1` deles simultaneamente. Por exemplo, com 3 _brokers_ podemos ter um com falha, um em atualização e um terceiro mantendo o sistema disponível.

A coordenação é feita automaticamente pelo Zookeeper. Um dos _brokers_ será eleito o líder e será responsável por receber e entregar os dados. Os demais atuarão como réplicas, mantendo os dados sincronizados (_in-sync replica_ ou ISR). Essa gestão é feita para cada partição  em cada tópico, portanto a carga pode ser balanceada adequadamente.

Além de gerenciar os _brokers_ em um _cluster_ e coordenar a liderança de partição, o Zookeeper também notifica os _brokers_ sobre mudanças na estrutura, mantendo os metadados atualizados em todos os servidores. Com tantas atribuições, o Zookeeper é obrigatório, mesmo que haja somente um _broker_.

O próprio Zookeeper deve ser preferencialmente mantido em um _cluster_, sempre com número ímpar de servidores. Eles elegem um líder, que trata as entradas (_write_), com os demais seguidores efetuando as saídas (_read_).

O Zookeeper é transparente aos consumidores e produtores, e acessado somente pelo Kafka.

## Modelo de armazenamento

Podemos pensar no Kafka como um grande _log_, onde dados em fluxo são armazenados em uma sequência temporal imutável, para serem consumidos ordenadamente. Dados de mesma natureza são agrupados em _tópicos_, e os tópicos são gravados em arquivos físicos distribuídos entre os _brokers_ chamados _partições_.

<!-- Os dados são mantidos por pouco tempo no Kafka (def. 1 semana) -->

### Tópicos

Os tópicos são agrupamentos de dados de mesma categoria. Atuam como tabelas em um banco relacional, porém sem as _contraints_. Outra diferença importante é a impossibilidade de alteração dos dados: os dados são imutáveis. Podem-se criar quantos tópicos forem necessários, e cada tópico pode receber dados de múltiplas origens e entregar dados para múltiplos destinos.

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

#### Replicação

Em um tópico criado com o fator de replicação padrão `1`, cada partição contém dados distintos, de forma que cada dado está em uma e somente uma partição. Se definirmos um número maior de replicação, haverão cópias físicas da partição (chamadas _in-sync replicas_ ou _ISRs_) distribuídas necessariamente em _brokers_ diferentes, inativas e sincronizadas para assumir em caso de falha da partição ativa (chamada de partição líder).

O fator de replicação, portanto, é definido entre 1 e a quantidade de _brokers_ existentes no _cluster_.

Sempre haverá uma partição líder eleita entre as réplicas, que atenderá toda a carga. As demais se manterão como cópias estáticas sincronizadas, podendo assumir a liderança eventualmente a critério do Kafka.

### Dados, produtores e consumidores

_em breve..._

<!--
As mensagens são os dados mantidos no tópicos, recebidos como _payloads_ .


	Cada mensagem uma partição recebe um id incremental, o offset
	O número de mensagens em cada partição é independente
	Os offsets são únicos em cada partição
	A ordem das mensagens em uma partição é garantida pelo offset
	Não é possível garantir ordenação entre diferentes partições
 -->

<!-- Produtores
	Escrever mensagens nos tópicos
	Não é necessário saber qual o broker e qual a partição
	Não é necessário saber se o broker está online
	Pode solicitar confirmação:
		acks=0 não aguarda confirmação, pode perder dados
		acks=1 aguarda confirmação do líder, possível perda limitada
		acks=all aguarda líder e todas as réplicas, não há perda
Chaves de mensagens
	A seleção de partição é feita aleatoriamente, a menos que se use chaves
	Permite a garantia de ordenação temporal das mensagens por essa chave
	Se nula, as mensagens serão distribuídas entre as partições, round-robin
	Se enviada, todas as mensagens com a mesma chave ficarão na mesma partição
	Você não pode escolher a partição
	Não garantido se o número de partições mudar
Consumidores
	Ler dados de um tópico
	Não é necessário saber qual o broker e qual a partição
	Não é necessário saber se o broker está online
	Os dados são lidos em ordem, dentro de cada partição
		Paralelo entre partições, serial dentro de cada partição
Grupos de consumidores
	Permite paralelizar o consumo
	Representa uma aplicação, com seu cluster de consumidores
	Uma partição será sempre lida pelo mesmo consumidor no grupo
	Coordenação de grupo transparente
	Se houver mais consumidores que partições, eles ficarão inativos
Offsets
	ficam no tópico __consumer_offsets
	Indica o ponto atual de leitura de um grupo e permite continuar do mesmo ponto
	Semânticas de entrega (alteração do offset):
		at most once:
			ao ler (caso der erro, não receberá novamente)
		at least once (preferido):
			após processar (caso der erro, recebe duas vezes -- deve ser idempotente)
		exactly once:
			uma vez, garantido, mas somente interno do Kafka -->
