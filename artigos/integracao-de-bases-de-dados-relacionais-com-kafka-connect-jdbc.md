# Integração de bases de dados relacionais com Kafka Connect JDBC

Neste artigo introduziremos os conceitos iniciais para a utilização de [Apache Kafka](https://kafka.apache.org/) com [Kafka Connect](https://docs.confluent.io/platform/current/connect/index.html) na integração de bancos de dados relacionais.

## Kafka Connect

O Kafka Connect usa a infraestrutura do Apache Kafka para transportar dados entre diversas fontes distintas, de forma simples.

Os dados são consumidos das origens por _workers_ no cluster do Kafka Connect, que executam _tasks_ do tipo _Source_. Cada _source task_ é configurada usando chaves/valores, e apontam para uma origem de dados, em um determinado formato, e para um tópico Kafka de destino. Também podem realizar pequenas transformações nos dados. Existem diversos conectores do tipo _source_, permitindo que os dados sejam obtidos de praticamente qualquer fonte (criar um novo também não é impossível). Por exemplo, usando o [JDBC Source Connector](https://docs.confluent.io/kafka-connect-jdbc/current/index.html) podemos configurar para ler uma base de dados SQL Server (o driver JDBC correto deve estar disponível) em uma determinada frequência, obter certo conjunto de dados, converter em um esquema [Apache Avro](https://avro.apache.org/), e gravar em um tópico.

Usando o mesmo cluster podemos criar _tasks_ do tipo _sink_, que consumirão as alterações no tópico e gravarão os dados em um destino externo (também com diversas tecnologias disponíveis). Por exemplo, podemos ler o tópico do exemplo acima e gravar em um banco de dados MySQL usando o [JDBC Sink Connector](https://docs.confluent.io/kafka-connect-jdbc/current/index.html).

Podemos ter múltiplos conectores gravando no tópico, inclusive produtores não ligados ao Kafka Connect, desde que respeitem o esquema. Podemos também ter vários consumidores do tópico independentes, cada qual gravando em destinos diferentes, inclusive consumidores não ligados ao Kafka Connect.

## O problema

Usar o Kafka Connect para obter e despejar dados utilizando fontes não-ACID é razoavelmente trivial. Por exemplo, podemos consumir um _stream_ de _tweets_ em JSON e gravá-lo em ElasticSearch sem grandes planejamentos.

As garantias de integridade dadas pelos bancos de dados relacionais implicam que os dados devem sempre estar de acordo com todas as regras impostas pelo seu esquema, incluíndo formato dos dados, cardinalidade e chaves primárias (muitas vezes com valores imutáveis calculados pelo SGBD).

Há conectores específicos para alguns SGBD, como SQL Server e MySQL, que não transportam os dados, e sim o _log_ de alterações executados no banco. Essa situação parece excelente para replicação, mas não para cenários onde os esquemas não são exatamente iguais entre origens e destino.

Nesse artigo usaremos a estratégia de _polling_ (consultas em intervalos pré-determinados) com conector JDBC, que permite sua utilização com virtualmente todos os bancos de dados relacionais.

Considerando cenários onde os dados da origem já pré-existam em seu esquema relacional tradicional, decisões importantes devem ser tomadas quanto à maneira de se buscar os dados. Isso é implementado na configuração do _source_, em especial na propriedade `mode`.

## Modos de consulta do JDBC Source

Cada modo difere em essência dos demais. A escolha do modo correto é imprescindível.

- Modo em massa (`mode=bulk`): a cada consulta traz todos os registros pertinentes.
- Modo incremental (`mode=incrementing`): a cada consulta traz somente os registros em que o valor de uma coluna numérica única estritamente crescente (geralmente um identificador chave-primária) seja maior do que o maior valor lido na última consulta. Esse modo permite detectar inclusões.
- Modo data/hora (`mode=timestamp`): a cada consulta traz somente os registros em que o valor de uma coluna data/hora não necessariamente única mas estritamente crescente (geralmente uma coluna com data de atualização) seja maior do que o maior valor lido na última consulta. Esse modo permite detectar alterações.
- Modo composto data/hora e incremental (`mode=timestamp+incrementing`): usa as colunas dos modos incremental e data/hora em conjunto para detectar alterações e inclusões, trazendo somente registros modificados.

Perceba que não há uma maneira trivial de se trazer em uma consulta `SELECT` os registros que foram excluídos (e muitas vezes não há maneira nenhuma). Uma saída elegante seria tratar as exclusões sempre logicamente nas tabelas de origem.

Outro ponto de atenção é a necessidade de criação de índices envolvendo as colunas indicadas, já que serão executadas com frequência. Podem ser utilizadas também tabelas-espelho ou mesmo _views_. Para cada caso avalie a melhor estratégia pesando desempenho e latência.

O intervalo de _poll_ é essencial também. Uma _query_ rápida pode permitir _polling_ mais frequente, mas consultas pesadas devem ter sua repetição ajustada para intervalos maiores, ao custo da latência aumentada.

### Modo em massa

Traz uma fotografia instantânea de um conjunto de dados.

A cada intervalo de _polling_ uma _query_ `SELECT` é executada sem a inclusão de nenhuma condição `WHERE` pelo conector. Todos os registros retornados são publicados no tópico, independentemente de já terem sido consumidos anteriormente.

Exemplo:

Considere os dados na tabela de origem:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406

Considere um conector configurado para ler todas as colunas da tabela, e utilizar a coluna `id` como chave do tópico. Após dois intervalos de consulta, o tópico conterá algo como:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406

Um consumidor de destino que consuma esse tópico deve saber necessariamente lidar com registros duplicados (por exemplo, fazendo um _upsert_ de acordo com a chave-primária).

Digamos que o segundo registro tenha sido alterado, o terceiro excluído e um quarto cadastrado, deixando a tabela assim:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Não | 2021-06-30 12:10:06.965
4 | Joaquim | Sim | 2018-06-30 12:10:07.152

Na próxima consulta o tópico conterá:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Não | 2021-06-30 12:10:06.965
4 | Joaquim | Sim | 2018-06-30 12:10:07.152

Perceba que o valor de `atualizado_em` foi gravado com valor anterior aos demais, sem prejuízo da consulta.

Um destino que monitore o tópico, tratando as entradas duplicadas, deverá ter o seguinte conteúdo:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Não | 2021-06-30 12:10:06.965
3 | Estela  | Sim | 2021-06-30 12:02:00.406
4 | Joaquim | Sim | 2018-06-30 12:10:07.152

Perceba que a exclusão física do registro de `id=3` continuará existindo. A exclusão lógica do registro de `id=2`, porém, funcionou como esperado.

Pontos de atenção:

- Esse é o modo que exige maior consumo de recursos de banda e memória. 
- Por não gerar leituras idempotentes, exige que o destino consiga tratar entradas duplicadas.
- O ajuste fino envolvendo intervalo de _polling_, tempo de retenção do tópico e otimização da _query_ é essencial.
- Use somente quando as tabelas forem muito pequenas, forem limpas frequentemente, ou como _fallback_ caso não possuam chave numérica estritamente crescente e/ou campo de data de atualização.

## Modo incremental

Traz somente registros novos, baseados em um identificador único, numérico e estritamente crescente.

A cada intervalo de _polling_ uma _query_ `SELECT` é executada com a inclusão de condição `WHERE` pelo conector, de forma a obter somente os identificadores cujos valores são maiores do que o maior obtido anteriormente. Todos os registros retornados são publicados no tópico.

Exemplo:

Considere os dados na tabela de origem:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406

Considere um conector configurado para ler todas as colunas da tabela, e utilizar a coluna `id` como chave do tópico e coluna de detecção de incremento. Após a primeira consulta, o tópico conterá algo como:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406

O tópico se manterá assim até que uma linha com `id > 3` seja encontrada.

Alguns intervalos depois, uma nova linha é inserida:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406
4 | Joaquim | Sim | 2018-06-30 12:10:07.152

O tópico consome somente a linha nova:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
4 | Joaquim  | Sim | 2018-06-30 12:10:07.152

O tópico terá algo como:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406
4 | Joaquim | Sim | 2018-06-30 12:10:07.152

Dias depois, a segunda linha é excluída, a terceira é alterada e é incluída uma quinta, deixando a tabela assim:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
3 | Estela  | Não | 2021-07-01 00:00:00.000
4 | Joaquim | Sim | 2018-06-30 12:10:07.152
5 | Tereza  | Sim | 2021-07-01 00:00:00.000

Será consumida somente a linha nova:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
5 | Tereza  | Sim | 2021-07-01 00:00:00.000

E o tópico conterá algo do tipo:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406
4 | Joaquim | Sim | 2018-06-30 12:10:07.152
5 | Tereza  | Sim | 2021-07-01 00:00:00.000

Os mesmos dados acima estarão em um destino que monitore o tópico.

Perceba que atualizações e exclusões não são capturadas nesse modo. Cada linha é lida somente uma vez, e seu estado no tópico é imutável.

Pontos de atenção:

- Esse é o modo de menor _footprint_. Exige a menor quantidade possível de processamento, memória e banda.
- Por gerar leituras idempotentes, não exige que o destino consiga tratar entradas duplicadas.
- A coluna identificadora deverá sempre ser indexada e única. De maneira geral, as chaves-primárias são as mais adequadas, pois não exigem o uso de índices adicionais.
- Use somente em situações onde a tabela de origem contém dados imutáveis e perenes, como em uma tabela de fatos.

## Modo data/hora

Traz somente registros em que uma coluna de data/hora seja estritamente maior do que o maior valor obtido anteriormente.

A cada intervalo de _polling_ uma _query_ `SELECT` é executada com a inclusão de condição `WHERE` pelo conector, de forma a obter somente os registros cujos valores na coluna indicada sejam maiores do que o maior obtido anteriormente. Todos os registros retornados são publicados no tópico.

Exemplo:

Considere os dados na tabela de origem:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406

Considere um conector configurado para ler todas as colunas da tabela, e utilizar a coluna `id` como chave do tópico, e `atualizado_em` como a coluna de data/hora. Após a primeira consulta, o tópico conterá algo como:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406

O tópico se manterá assim até que uma linha com `atualizado_em > '2021-06-30 12:02:00.406'` seja encontrada.

Algum tempo depois, a segunda linha é excluída, a terceira é alterada e é incluída uma quarta e uma quinta, deixando a tabela assim:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
3 | Estela  | Não | 2021-07-01 00:00:00.000
4 | Joaquim | Sim | 2018-06-30 12:10:07.152
5 | Tereza  | Sim | 2021-07-01 00:00:00.000

Serão consumidas as linhas:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
3 | Estela  | Não | 2021-07-01 00:00:00.000
5 | Tereza  | Sim | 2021-07-01 00:00:00.000

Perceba que a exclusão não foi detectada. A linha incluída com `id=4` não é retornada porque a coluna `atualizado_em` recebeu um valor menor ou igual ao maior valor obtido anteriormente. A linha editada com `id=3` é retornada com os valores atualizados, assim com a linha com com `id=5`, mesmo ambas tendo o mesmo valor de `atualizado_em`.

E o tópico conterá algo do tipo:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406
3 | Estela  | Não | 2021-07-01 00:00:00.000
5 | Tereza  | Sim | 2021-07-01 00:00:00.000

Em um destino que monitore o tópico, teremos:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Não | 2021-07-01 00:00:00.000
5 | Tereza  | Sim | 2021-07-01 00:00:00.000

A configuração `batch.max.rows` (padrão `100`) permite indicar quanto registro serão lidos a cada consulta efetuada na origem. Isso gera efeitos colaterais indesejados nesse modo. Observe.

Em seguida, foram adicionadas 150 linhas novas em lote, todas como mesmo valor na coluna `atualizado_em`. Uma nova linha ainda foi adicionada antes do próximo intervalo de _poll_ com `id=156`. A tabela conterá algo como:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
3 | Estela  | Não | 2021-07-01 00:00:00.000
4 | Joaquim | Sim | 2018-06-30 12:10:07.152
5 | Tereza  | Sim | 2021-07-01 00:00:00.000
6 | Astolfo | Sim | 2021-07-01 12:25:00.000
... | ...     | ... | 2021-07-01 12:25:00.000
105 | Ana     | ... | 2021-07-01 12:25:00.000
106 | Jorge   | ... | 2021-07-01 12:25:00.000
... | ...     | ... | 2021-07-01 12:25:00.000
155 | Felícia | ... | 2021-07-01 12:25:00.000
156 | Genésio | ... | 2021-07-01 12:27:35.373

Serão consumidas as próximas 100 linhas:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
6 | Astolfo | Sim | 2021-07-01 12:25:00.000
... | ...     | ... | 2021-07-01 12:25:00.000
105 | Ana     | ... | 2021-07-01 12:25:00.000

O tópico terá:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406
3 | Estela  | Não | 2021-07-01 00:00:00.000
5 | Tereza  | Sim | 2021-07-01 00:00:00.000
6 | Astolfo | Sim | 2021-07-01 12:25:00.000
... | ...     | ... | 2021-07-01 12:25:00.000
105 | Ana     | ... | 2021-07-01 12:25:00.000

No próximo _poll_, serão consumidas somente linhas com `atualizado_em > '2021-07-01 12:25:00.000'`:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
156 | Genésio | ... | 2021-07-01 12:27:35.373

No tópico teremos:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406
3 | Estela  | Não | 2021-07-01 00:00:00.000
5 | Tereza  | Sim | 2021-07-01 00:00:00.000
6 | Astolfo | Sim | 2021-07-01 12:25:00.000
... | ...     | ... | 2021-07-01 12:25:00.000
105 | Ana     | ... | 2021-07-01 12:25:00.000
156 | Genésio | ... | 2021-07-01 12:27:35.373

Perceba que as linhas com `id` entre `106` e `155` (inclusive) nunca serão consumidas.

Pontos de atenção:

- Esse é o modo que necessita de maior atenção para ser utilizado. Use com muita cautela. Se possível, não utilize.
- Por não gerar leituras idempotentes, exige que o destino consiga tratar entradas duplicadas.
- A coluna de data/hora deve ser indexada na origem, apesar de não necessitar ser necessariamente única.
- Use somente quando sua coluna de data/hora contiver a data de atualização do registro, e haja garantia de que não serão gravados valores diferentes (anteriores ou posteriores) do _timestamp_ do momento da gravação (como por exemplo, data/hora obtidos na aplicação e não no SGBD em sistemas multiprodutores de registros). Ainda assim use somente se não for possível utilizar o modo composto data/hora e incremental.

_... em breve ..._
<!-- 

- Incremental + Data de atualização
	A tabela de origem possui uma coluna com um número inteiro que seja um identificador único ascendente E uma coluna contendo data/hora da última atualização, ascendente porém não necessariamente único
	Uma alteração é identificada pela tupla (id + data atualização)
	Não identifica alterações que não alterem a data de atualização
	--- o destino não pode ter identity (fks? constraints?)
	--- a data de atualização deve ser atualizada sempre, com a maior precisão possível
	--- exclusão somente lógica, já que não é levada para o tópico pelo source

Garantir a criação de índices pelas colunas nas tabelas originais
 -->
