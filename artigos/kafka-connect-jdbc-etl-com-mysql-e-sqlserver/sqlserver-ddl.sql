create database teste_kafka;
GO

use teste_kafka;

create table origem (
	id int identity primary key,
	data varchar(50)
);

create table destino1 (
	id int primary key,
	data varchar(50)
);

create table destino2 (
	id int primary key,
	data varchar(50)
);
