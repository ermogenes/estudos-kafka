Streams, tables, joins
Encoding
Manipulation
Enrichment
Time based window
Geospatial data
User Defined Functions
Load balancing
Horizontal scaling

Confluent CLI
confluent status
confluent local services ksqldb start

Docker
https://docs.confluent.io/platform/current/quickstart/cos-docker-quickstart.html
curl --silent --output docker-compose.yml https://raw.githubusercontent.com/confluentinc/cp-all-in-one/6.2.0-post/cp-all-in-one-community/docker-compose.yml
docker-compose up -d
docker compose exec ksqldb-cli ksql http://ksqldb-server:8088


docker compose exec broker kafka-topics --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic users
docker compose exec broker kafka-console-producer --bootstrap-server localhost:9092 --topic users
docker compose exec broker kafka-console-consumer --from-beginning --bootstrap-server localhost:9092 --topic users

ksql CLI --- https://cnfl.io/queries

list topics;
print 'TOPICO';
print 'TOPICO' from beginning;
print 'TOPICO' from beginning interval 2 limit 2;
create stream users_stream (name VARCHAR, uf VARCHAR) WITH (KAFKA_TOPIC='users', VALUE_FORMAT='DELIMITED');
list streams;
select name, uf from users_stream emit changes;
set 'auto.offset.reset'='earliest';
unset 'auto.offset.reset';
select uf, count(*) as qtd from users_stream group by uf emit changes;
drop stream if exists users_stream;
drop stream if exists users_stream delete topic;


docker compose exec broker kafka-topics --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic user_profile
docker compose exec broker kafka-console-producer --bootstrap-server localhost:9092 --topic user_profile

{"userid":1000,"firstname":"Alison","lastname":"Smith","countrycode":"GB","rating":4.7}
{"userid":1001,"firstname":"Bob","lastname":"Smith","countrycode":"US","rating":4.2}

docker compose exec broker kafka-console-consumer --from-beginning --bootstrap-server localhost:9092 --topic user_profile --from-beginning

list streams;
create stream up (userid int, firstname varchar, lastname varchar, countrycode varchar, rating double) with (VALUE_FORMAT='JSON', KAFKA_TOPIC='user_profile');
describe up;



docker compose exec broker kafka-topics --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic userprofile
docker cp ./userprofile.avro ksql-datagen:/userprofile.avro
docker compose exec ksql-datagen ksql-datagen schema=/userprofile.avro format=json topic=userprofile key=userid msgRate=2 iterations=100 printRows=true
// https://github.com/confluentinc/ksql/issues/3654

print userprofile;
print userprofile interval 5;

select timestamptostring(rowtime, 'YYYY-MM-dd hh:mm:ss') as rowtime_fmt, * from up emit changes;
select firstname + ' ' + ucase(lastname) fullname from up emit changes;

