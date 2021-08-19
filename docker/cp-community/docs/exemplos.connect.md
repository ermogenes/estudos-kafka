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