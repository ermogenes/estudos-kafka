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

### Modo incremental

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

### Modo data/hora

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
105 | Ana     | Sim | 2021-07-01 12:25:00.000
106 | Jorge   | Sim | 2021-07-01 12:25:00.000
... | ...     | ... | 2021-07-01 12:25:00.000
155 | Felícia | Sim | 2021-07-01 12:25:00.000
156 | Genésio | Sim | 2021-07-01 12:27:35.373

Serão consumidas as próximas 100 linhas:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
6 | Astolfo | Sim | 2021-07-01 12:25:00.000
... | ...     | ... | 2021-07-01 12:25:00.000
105 | Ana     | Sim | 2021-07-01 12:25:00.000

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
105 | Ana     | Sim | 2021-07-01 12:25:00.000

No próximo _poll_, serão consumidas somente linhas com `atualizado_em > '2021-07-01 12:25:00.000'`:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
156 | Genésio | Sim | 2021-07-01 12:27:35.373

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
105 | Ana     | Sim | 2021-07-01 12:25:00.000
156 | Genésio | Sim | 2021-07-01 12:27:35.373

Perceba que as linhas com `id` entre `106` e `155` (inclusive) nunca serão consumidas.

Em seguida, as linhas com `id` nos valores `1` e `137` são alterados para:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Não | 2021-07-01 12:29:19.736
... | ...     | ... | ...
137 | Letícia | Não | 2021-07-01 12:29:19.938
... | ...     | ... | ...

Os registros são consumidos e no tópico teremos:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406
3 | Estela  | Não | 2021-07-01 00:00:00.000
5 | Tereza  | Sim | 2021-07-01 00:00:00.000
6 | Astolfo | Sim | 2021-07-01 12:25:00.000
... | ...     | ... | 2021-07-01 12:25:00.000
105 | Ana     | Sim | 2021-07-01 12:25:00.000
156 | Genésio | Sim | 2021-07-01 12:27:35.373
1 | Maria   | Não | 2021-07-01 12:29:19.736
137 | Letícia | Não | 2021-07-01 12:29:19.938

O registro que não havia sido consumido anteriormente agora será incluído, bem como alterações em registros existentes.

Pontos de atenção:

- Esse é o modo que necessita de maior atenção para ser utilizado. Use com muita cautela. Se possível, não utilize.
- Por não gerar leituras idempotentes, exige que o destino consiga tratar entradas duplicadas.
- A coluna de data/hora deve ser indexada na origem, apesar de não necessitar ser necessariamente única.
- Não identifica alterações que não modifiquem o valor da coluna de data/hora.
- Use somente quando sua coluna de data/hora contiver a data de atualização do registro, e haja garantia de que não serão gravados valores diferentes (anteriores ou posteriores) do _timestamp_ do momento da gravação (como por exemplo, data/hora obtidos na aplicação e não no SGBD em sistemas multiprodutores de registros). Ainda assim use somente se não for possível utilizar o modo composto data/hora e incremental.

### Modo composto data/hora e incremental

Combina os filtros dos modos incremental e data/hora para detectar alterações e inserções, linha a linha.

A cada intervalo de _polling_ uma _query_ `SELECT` é executada com a inclusão de condição `WHERE` pelo conector, de forma a obter somente os identificadores cujos valores são maiores do que o maior obtido anteriormente (uma inserção), ou cujos valores na coluna indicada sejam maiores do que o maior obtido anteriormente para o mesmo identificador (uma atualização). Ou seja, detecta qualquer alteração na tupla {[_coluna identificadora ascendente única_], [_coluna data/hora ascendente_]}. Todos os registros retornados são publicados no tópico.

Exemplo:

Considere os dados na tabela de origem:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406

Considere um conector configurado para ler todas as colunas da tabela, e utilizar a coluna `id` como chave do tópico e coluna de detecção de incremento, e `atualizado_em` como a coluna de data/hora. Após a primeira consulta, o tópico conterá algo como:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406

O tópico se manterá assim até que uma linha com `id > 3` ou com `atualizado_em > '2021-06-30 12:02:00.406'` seja encontrada.

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
4 | Joaquim | Sim | 2018-06-30 12:10:07.152
5 | Tereza  | Sim | 2021-07-01 00:00:00.000

Perceba que a exclusão não foi detectada. As linhas incluídas com são retornadas porque a coluna `id` recebeu valores maiores que o maior valor obtido anteriormente (mesmo sendo na linha com `id=4` a data de atualização inferior ao maior valor obtido anteriormente). A linha editada com `id=3` é retornada com os valores atualizados.

E o tópico conterá algo do tipo:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406
3 | Estela  | Não | 2021-07-01 00:00:00.000
4 | Joaquim | Sim | 2018-06-30 12:10:07.152
5 | Tereza  | Sim | 2021-07-01 00:00:00.000

Em um destino que monitore o tópico, teremos:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Não | 2021-07-01 00:00:00.000
4 | Joaquim | Sim | 2018-06-30 12:10:07.152
5 | Tereza  | Sim | 2021-07-01 00:00:00.000

Perceba que ainda não são detectadas as exclusões, porém as alterações e inserções funcionam como esperado.

A questão do `batch.max.rows` também é resolvida. Como a identificação de cada registro é feita pela combinação das duas colunas, o conector consegue detectar que a alteração foi a mais recente para aquele identificador específico, incluíndo o registro no tópico. Observe a diferença.

Em seguida, foram adicionadas 150 linhas novas em lote, todas como mesmo valor na coluna `atualizado_em`. Uma nova linha ainda foi adicionada antes do próximo intervalo de _poll_ com `id=156`. A tabela conterá algo como:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
3 | Estela  | Não | 2021-07-01 00:00:00.000
4 | Joaquim | Sim | 2018-06-30 12:10:07.152
5 | Tereza  | Sim | 2021-07-01 00:00:00.000
6 | Astolfo | Sim | 2021-07-01 12:25:00.000
... | ...     | ... | 2021-07-01 12:25:00.000
105 | Ana     | Sim | 2021-07-01 12:25:00.000
106 | Jorge   | Sim | 2021-07-01 12:25:00.000
... | ...     | ... | 2021-07-01 12:25:00.000
155 | Felícia | Sim | 2021-07-01 12:25:00.000
156 | Genésio | Sim | 2021-07-01 12:27:35.373

Serão consumidas as próximas 100 linhas:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
6 | Astolfo | Sim | 2021-07-01 12:25:00.000
... | ...     | ... | 2021-07-01 12:25:00.000
105 | Ana     | Sim | 2021-07-01 12:25:00.000

No próximo _poll_ serão consumidas as linhas restantes:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
106 | Jorge   | Sim | 2021-07-01 12:25:00.000
... | ...     | ... | 2021-07-01 12:25:00.000
155 | Felícia | Sim | 2021-07-01 12:25:00.000
156 | Genésio | Sim | 2021-07-01 12:27:35.373

Teremos todos os registros no tópico, como esperado.

Em seguida, as linhas com `id` nos valores `1` e `137` são alterados para:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Não | 2021-07-01 12:29:19.736
... | ...     | ... | ...
137 | Letícia | Não | 2021-07-01 12:29:19.938
... | ...     | ... | ...

Os registros são consumidos e no tópico teremos:

id | nome | ativo | atualizado_em
--- | --- | --- | ---
1 | Maria   | Sim | 2020-12-01 16:22:15.170
2 | Antônio | Sim | 2010-02-14 04:35:04.041
3 | Estela  | Sim | 2021-06-30 12:02:00.406
3 | Estela  | Não | 2021-07-01 00:00:00.000
5 | Tereza  | Sim | 2021-07-01 00:00:00.000
6 | Astolfo | Sim | 2021-07-01 12:25:00.000
... | ...     | ... | 2021-07-01 12:25:00.000
105 | Ana     | Sim | 2021-07-01 12:25:00.000
106 | Jorge   | Sim | 2021-07-01 12:25:00.000
... | ...     | ... | 2021-07-01 12:25:00.000
155 | Felícia | Sim | 2021-07-01 12:25:00.000
156 | Genésio | Sim | 2021-07-01 12:27:35.373
1 | Maria   | Não | 2021-07-01 12:29:19.736
137 | Letícia | Não | 2021-07-01 12:29:19.938

Todas as alterações cujos identificadores sejam novos, ou cujas datas de atualização sejam superiores às anteriormente lidas para aquele registro são consumidas. Exclusões não, porém.

Pontos de atenção:

- Esse é o modo mais seguro.
- Assume que a tabela de origem possui uma coluna com um número inteiro que seja um identificador único ascendente e também uma coluna contendo data/hora da última atualização, ascendente porém não necessariamente única.
- Identifica unicamente a última versão de uma linha pela tupla formada pelas colunas citadas acima.
- Não identifica alterações que não alterem a data de atualização, ou que a altere para valores não maiores do que o anteriormente obtido para essa linha. Isso exige que esta coluna seja garantidamente mantida coesa (monotonicamente crescente) e com a maior precisão possível.
- Por não gerar leituras idempotentes, exige que o destino consiga tratar entradas duplicadas. Isso restringe o uso de colunas auto-incrementais (inclusive nas chaves-primárias) e outras _constraints_ na tabela de destino envolvendo as colunas da tupla identificadora, e potencialmente em relações com outras tabelas.
- As colunas da tupla identificadora devem constituir um índice na origem, por questões de desempenho.
- Para implementar a detecção de exclusões, use exclusão lógica (como na coluna `ativo` dos exemplos). Nesse caso, a exclusão física não acontece, somente uma atualização.

## Modos de gravação do JDBC Sink

Ao consumir os dados de um tópico, o conector _sink_ vai tentar atualizar a tabela de destino.

A primeira coisa a se configurar é a chave-primária. Isso vai indicar ao Kafka a semântica dos dados no tópico e na tabela de destino.

- `pk.mode=record_key` indica que a chave-primária está na chave do tópico.
- `pk.mode=record_value` indica que a chave-primária está no valor do tópico.
- `pk.fields` indica quais são as colunas que compõem a chave-primária, na localização indicada em `pk.mode`.

🐱‍👤 _Também é possível não indicar a chave-primária, ou deixar que o Kafka gere um identificador único. Ambas alternativas podem constituir casos de uso interessantes, mas não serão discutidas aqui._

Identificando a semântica dos valores, o Kafka Connect pode gerar as _queries_ DML para equalizar as tabelas. Serão utilizados os mesmos nomes de colunas contidos no esquema dos dados.

Devemos configurar o modo de gravação. O padrão é `insert.mode=insert`, onde todas as entradas lidas do tópico formarão uma _query_ de `INSERT`.

Esse cenário é perfeito para tabelas e tópicos de fatos, onde somente teremos inclusões, porém é bastante limitada se desejarmos espelhar alterações de registros. Além disso, o ideal é conseguir garantir que sejam feitas gravações idempotentes, permitindo a recuperação em caso de falha do processo.

Usando `insert.mode=upsert`, o Kafka Connect será capaz de gerar o comando adequado de acordo com a plataforma, para realizar a ação atomicamente. Por exemplo, em MySQL serão gerados `INSERT .. ON DUPLICATE KEY UPDATE ..` e em SQL Server `MERGE ..`.

## Exclusões físicas e DDL

Quando configurado para executar exclusões físicas, o conector de _sink_ deve receber um registro com o valor da chave desejada e com os valores dos campos nulos. Isso deve ser feito por outra ferramenta, já que o conector _source_ não tem essa capacidade.

Há a possibilidade de se configurar a _task_ para gerar os comandos DDL implementando auto criação e auto evolução das tabelas. Isso exige permissão adequada no usuário de login do conector.

## Exemplos de uso

Será utilizado o banco de dados de exemplo [organizacao-db](https://github.com/ermogenes/organizacao-db), com os dados no MySQL sendo transportados para o SQL Server.

Para baixar e subir o ambiente contendo Kafka Connect, MySQL e SQL Server, faça:

```
git clone https://github.com/ermogenes/organizacao-db.git
cd organizacao-db
docker compose --file dc-mysql-com-dados-kafka.yml up
```

Acesse o Kafka UI em [http://localhost:3030](http://localhost:3030) e crie as _tasks_.

Todos os exemplos assumem exclusão lógica (exclusões físicas não são tratadas).

### Modo data/hora e incremento

Os dados da tabela `pessoa` serão sincronizados com _upserts_, baseados na chave-primária e na data de atualização.

[_*Source*_](integracao-de-bases-de-dados-relacionais-com-kafka-connect-jdbc/01-pessoa-source-mysql.properties)

```ini
name=source-mysql-orgdb-pessoa
connector.class=io.confluent.connect.jdbc.JdbcSourceConnector
connection.url=jdbc:mysql://mysql:3306/
connection.user=root
connection.password=root
mode=timestamp+incrementing
catalog.pattern=organizacao
table.whitelist=pessoa
incrementing.column.name=id
timestamp.column.name=data_atualizacao
topic.prefix=mysql-orgdb-
transforms=createKey,extractInt
transforms.createKey.type=org.apache.kafka.connect.transforms.ValueToKey
transforms.createKey.fields=id
transforms.extractInt.type=org.apache.kafka.connect.transforms.ExtractField$Key
transforms.extractInt.field=id
tasks.max=1
```

[_*Sink*_](integracao-de-bases-de-dados-relacionais-com-kafka-connect-jdbc/02-pessoa-sink-sqlserver.properties)

```ini
name=sink-sqlserver-orgdb-pessoa
connector.class=io.confluent.connect.jdbc.JdbcSinkConnector
topics=mysql-orgdb-pessoa
connection.url=jdbc:sqlserver://sqlserver:1433
connection.user=sa
connection.password=My_secret_!2#4%
table.name.format=organizacao.dbo.pessoa
insert.mode=upsert
pk.mode=record_key
pk.fields=id
tasks.max=1
```

### Modo incremento

Os dados da tabela `evento` serão sincronizados com _inserts_, baseados na chave-primária.

[_*Source*_](integracao-de-bases-de-dados-relacionais-com-kafka-connect-jdbc/03-evento-source-mysql.properties)

```ini
name=source-mysql-orgdb-evento
connector.class=io.confluent.connect.jdbc.JdbcSourceConnector
connection.url=jdbc:mysql://mysql:3306/
connection.user=root
connection.password=root
mode=incrementing
catalog.pattern=organizacao
table.whitelist=evento
incrementing.column.name=id
topic.prefix=mysql-orgdb-
transforms=createKey,extractInt
transforms.createKey.type=org.apache.kafka.connect.transforms.ValueToKey
transforms.createKey.fields=id
transforms.extractInt.type=org.apache.kafka.connect.transforms.ExtractField$Key
transforms.extractInt.field=id
tasks.max=1
```

[_*Sink*_](integracao-de-bases-de-dados-relacionais-com-kafka-connect-jdbc/04-evento-sink-sqlserver.properties)

```ini
name=sink-sqlserver-orgdb-evento
connector.class=io.confluent.connect.jdbc.JdbcSinkConnector
topics=mysql-orgdb-evento
connection.url=jdbc:sqlserver://sqlserver:1433
connection.user=sa
connection.password=My_secret_!2#4%
table.name.format=organizacao.dbo.evento
insert.mode=insert
pk.mode=record_key
pk.fields=id
tasks.max=1
```

### Modo em massa

Os dados da tabela `papel` serão sincronizados em massa.

[_*Source*_](integracao-de-bases-de-dados-relacionais-com-kafka-connect-jdbc/05-papel-source-mysql.properties)

```ini
name=source-mysql-orgdb-papel
connector.class=io.confluent.connect.jdbc.JdbcSourceConnector
connection.url=jdbc:mysql://mysql:3306/
connection.user=root
connection.password=root
mode=bulk
poll.interval.ms=60000
catalog.pattern=organizacao
table.whitelist=papel
topic.prefix=mysql-orgdb-
transforms=createKey,extractInt
transforms.createKey.type=org.apache.kafka.connect.transforms.ValueToKey
transforms.createKey.fields=id
transforms.extractInt.type=org.apache.kafka.connect.transforms.ExtractField$Key
transforms.extractInt.field=id
tasks.max=1
```

[_*Sink*_](integracao-de-bases-de-dados-relacionais-com-kafka-connect-jdbc/06-papel-sink-sqlserver.properties)

```ini
name=sink-sqlserver-orgdb-papel
connector.class=io.confluent.connect.jdbc.JdbcSinkConnector
topics=mysql-orgdb-papel
connection.url=jdbc:sqlserver://sqlserver:1433
connection.user=sa
connection.password=My_secret_!2#4%
table.name.format=organizacao.dbo.papel
insert.mode=upsert
pk.mode=record_key
pk.fields=id
tasks.max=1
```


