#!/bin/bash

echo "shared_preload_libraries = 'citus, postgis-2.5.so'" >> $PGDATA/postgresql.conf

set -e

# Create the 'mobilitydb' extension in the mobilitydb database
echo "Loading MobilityDB extension into mobilitydb"
psql --user="$POSTGRES_USER" --dbname="postgres" <<- 'EOSQL'
	CREATE EXTENSION citus;
	CREATE EXTENSION IF NOT EXISTS mobilitydb CASCADE;
	CREATE TABLE AISInput(\
	T timestamp,\
	TypeOfMobile varchar(50),\
	MMSI integer,\
	Latitude float,\
	Longitude float,\
	navigationalStatus varchar(50),\
	ROT float,\
	SOG float,\
	COG float,\
	Heading integer,\
	IMO varchar(50),\
	Callsign varchar(50),\
	Name varchar(100),\
	ShipType varchar(50),\
	CargoType varchar(100),\
	Width float,\
	Length float,\
	TypeOfPositionFixingDevice varchar(50),\
	Draught float,\
	Destination varchar(50),\
	ETA varchar(50),\
	DataSourceType varchar(50),\
	SizeA float,\
	SizeB float,\
	SizeC float,\
	SizeD float,\
	Geom geometry(Point, 4326)\
	);

	\COPY AISInput(T, TypeOfMobile, MMSI, Latitude, Longitude, NavigationalStatus, ROT, SOG, COG, Heading, IMO, CallSign, Name, ShipType, CargoType, Width, Length,TypeOfPositionFixingDevice, Draught, Destination, ETA, DataSourceType,SizeA, SizeB, SizeC, SizeD) FROM '/usr/local/src/ais_dataset/mobility_dataset.csv' DELIMITER ',' CSV HEADER;

	UPDATE AISInput SET NavigationalStatus = CASE NavigationalStatus WHEN 'Unknown value' THEN NULL END, IMO = CASE IMO WHEN 'Unknown' THEN NULL END, ShipType = CASE ShipType WHEN 'Undefined' THEN NULL END, TypeOfPositionFixingDevice = CASE TypeOfPositionFixingDevice WHEN 'Undefined' THEN NULL END, Geom = ST_SetSRID( ST_MakePoint( Longitude, Latitude ), 4326);
	SELECT create_distributed_table('AISInput', 'mmsi');

	
EOSQL
