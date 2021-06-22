-- ETL01
SELECT * FROM teste_kafka.dbo.destino1;

-- ETL02
SELECT * FROM teste_kafka.dbo.origem;
SELECT * FROM teste_kafka.dbo.destino2;
INSERT INTO teste_kafka.dbo.origem VALUES ('Gerado no SQL Server');