-- ETL01
SELECT * FROM teste_kafka.origem;
SELECT * FROM teste_kafka.destino1;
INSERT INTO teste_kafka.origem VALUES (NULL, 'Gerado no MySQL');

-- ETL02
SELECT * FROM teste_kafka.destino2;