## Exemplo para criar no ksqldb

CREATE SOURCE CONNECTOR VolubleSourceConnectorKSqlDB WITH (
  'connector.class' = 'io.mdrogalis.voluble.VolubleSourceConnector',
  'genkp.people.with' = '#{Internet.uuid}',
  'genv.people.name.with' = '#{Name.full_name}',
  'genv.people.creditCardNumber.with' = '#{Finance.credit_card}',
  'global.throttle.ms' = '500',
  'task.max'='2',
  'key.converter'='org.apache.kafka.connect.json.JsonConverter',
  'key.converter.schemas.enable'='false',
  'value.converter'='org.apache.kafka.connect.json.JsonConverter',
  'value.converter.schemas.enable'='false'
);


## Exemplo para criar no Connect UI

name=VolubleSourceConnectorUI
connector.class=io.mdrogalis.voluble.VolubleSourceConnector
genkp.people.with='#{Internet.uuid}'
genv.people.name.with='#{Name.full_name}'
genv.people.creditCardNumber.with='#{Finance.credit_card}'
global.throttle.ms=500
task.max=2
key.converter=org.apache.kafka.connect.json.JsonConverter
key.converter.schemas.enable=false
value.converter=org.apache.kafka.connect.json.JsonConverter
value.converter.schemas.enable=false










connector.class=io.confluent.connect.jdbc.JdbcSourceConnector
timestamp.column.name=data_atualizacao
incrementing.column.name=id
transforms.createKey.type=org.apache.kafka.connect.transforms.ValueToKey
connection.password=root
catalog.pattern=organizacao
tasks.max=2
transforms=createKey,extractInt
transforms.extractInt.type=org.apache.kafka.connect.transforms.ExtractField$Key
table.whitelist=pessoa
mode=timestamp+incrementing
key.converter.schemas.enable=true
topic.prefix=mysql-orgdb-
transforms.extractInt.field=id
connection.user=root
transforms.createKey.fields=id
value.converter.schemas.enable=true
connection.url=jdbc:mysql://mysql:3306/
value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter=org.apache.kafka.connect.json.JsonConverter

name=source-mysql-orgdb-pessoa








connector.class=io.confluent.connect.jdbc.JdbcSinkConnector
table.name.format=organizacao.dbo.pessoa
connection.password=My_secret_!2#4%
topics=mysql-orgdb-pessoa
tasks.max=2
key.converter.schemas.enable=true
connection.user=sa
value.converter.schemas.enable=true
connection.url=jdbc:sqlserver://sqlserver:1433
value.converter=org.apache.kafka.connect.json.JsonConverter
insert.mode=upsert
pk.mode=record_key
key.converter=org.apache.kafka.connect.json.JsonConverter
pk.fields=id

name=sink-sqlserver-orgdb-pessoa