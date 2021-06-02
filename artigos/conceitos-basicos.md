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

O próprio Zookeper deve ser preferencialmente mantido em um _cluster_, sempre com número ímpar de servidores. Eles elegem um líder, que trata as entradas (_write_), com os demais seguidores efetuando as saídas (_read_).

O Zookeeper é transparente aos consumidores e produtores, e acessado somente pelo Kafka.

## Modelo de armazenamento

_em breve..._

<!-- Tópicos
	Um fluxo de dados, chamados mensagens
	Como uma tabela, sem constraints
	Pode criar quantos quiser
	Dividido em partições
	As mensagens são imutáveis
#Partições
	Um arquivo de dados
	Partições distribuídas: cada broker recebe algumas partições, ninguém possui todos os dados
	Numeradas e ordenadas, zero-based
	A seleção de partição é feita aleatoriamente, a menos que se use chaves
	Cada mensagem uma partição recebe um id incremental, o offset
	O número de mensagens em cada partição é independente
	Os offsets são únicos em cada partição
	A ordem das mensagens em uma partição é garantida pelo offset
	Não é possível garantir ordenação entre diferentes partições
	Os dados são mantidos por pouco tempo no Kafka (def. 1 semana)
Criação das partições de tópicos nos brokers
	São criadas N partições, divididas igualmente entre os brokers, com possivelmente algum broker com menos partições
		Ex. b1, b2 e b3; t1 com p0, p1 e p2; t2 com p0 e p1:
			b1{t1.p0, t2.p1}, b2{t1.p2, t2.p0}, b3{t1.p1}
	Com replicação, a réplica sempre vai para outro broker
		Ex. b1, b2 e b3; t1 com p0 e p1, rf=2
			b1{t1.p0l}, b2{t1.p0r, t1.p1l}, b3{t1.p1r} -->

## Integração

_em breve..._

<!-- Produtores
	Escrever mensagens nos tópicos
	Não é necessário saber qual o broker e qual a partição
	Não é necessário saber se o broker está online
	Pode solicitar confirmação:
		acks=0 não aguarda confirmação, pode perder dados
		acks=1 aguarda confirmação do líder, possível perda limitada
		acks=all aguarda líder e todas as réplicas, não há perda
Chaves de mensagens
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