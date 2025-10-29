-- Scripts de clase - Octubre 23 de 2025
-- Curso de Tópicos Avanzados de base de datos - UPB 202520
-- Juan Dario Rodas - juand.rodasm@upb.edu.co

-- Proyecto: Analisis de Temperatura en Antioquia para el año 2025
-- Motor de Base de datos: TimescaleDB - PostgreSQL 17.x
-- Version: Relacional

-- ***********************************
-- Abastecimiento de imagen en Docker
-- ***********************************

-- Descargar la imagen
docker pull timescale/timescaledb:latest-pg17

-- Crear el contenedor
docker run --name tempant_timescaledb -e POSTGRES_PASSWORD=unaClav3 -d -p 5432:5432 timescale/timescaledb:latest-pg17

-- ***********************************
-- Abastecimiento de datos
-- ***********************************

/*
Temperatura Antioquia 2025
Análisis de la temperatura para el departamento de Antioquia en el 2025, 
usando diferentes tecnologías de almacenamiento de datos.

Los datos originales fueron tomados de la Plataforma Nacional de Datos 
Abiertos de Colombia, del dataset denominado

Datos Hidrometeorológicos Crudos - Red de Estaciones IDEAM : Temperatura

https://www.datos.gov.co/Ambiente-y-Desarrollo-Sostenible/Datos-Hidrometeorol-gicos-Crudos-Red-de-Estaciones/sbwg-7ju4/about_data

Filtros aplicados:

Departamento: Antioquia
Rango fechas: Enero 1 de 2025, 12:00 am a Octubre 1 2025, 12:00 am.
Total registros iniciales antes de control de calidad: 557.166 filas.

Importante:
Los datos aqui expuestos son utilizados con fines académicos. 
Por favor acceda al recurso relacionado para conocer más información al respecto.
*/

-- ****************************************
-- Creación de base de datos y usuarios
-- ****************************************

-- Con usuario Root:

-- crear el esquema la base de datos
create database analisistemperatura_db;

-- Conectarse a la base de datos
\c analisistemperatura_db;

-- crear el usuario con el que se realizarán las acciones
create user analisistemperatura_usr with encrypted password 'unaClav3';

-- asignación de privilegios para el usuario
-- ==========================================

-- Privilegios para establecer conexiones
grant connect on database analisistemperatura_db to analisistemperatura_usr;

-- privilegios para crear tablas temporales
grant temporary on database analisistemperatura_db to analisistemperatura_usr;

-- Privilegios de uso en el esquema
grant usage on schema public to analisistemperatura_usr;

-- privilegios para crear objetos
grant create on schema public to analisistemperatura_usr;

-- Privilegios sobre tablas existentes
grant select, insert, update, delete, trigger on all tables in schema public to analisistemperatura_usr;

-- privilegios sobre secuencias existentes
grant usage, select on all sequences in schema public to analisistemperatura_usr;

-- privilegios sobre funciones existentes
grant execute on all functions in schema public to analisistemperatura_usr;

-- privilegios sobre procedimientos existentes
grant execute on all procedures in schema public to analisistemperatura_usr;

-- privilegios sobre futuras tablas y secuencias
alter default privileges in schema public grant select, insert, update, delete, trigger on tables to analisistemperatura_usr;

alter default privileges in schema public grant select, usage on sequences to analisistemperatura_usr;

-- privilegios sobre futuras funciones y procedimientos
alter default privileges in schema public grant execute on routines to analisistemperatura_usr;

--Privilegios de consulta sobre el esquema information_schema
grant usage on schema information_schema to analisistemperatura_usr;

-- Validar la existencia de la extensión de timeScale
SELECT distinct extname, extversion
FROM pg_extension
WHERE extname = 'timescaledb';

-- Si no existe, se puede instalar con esta sentencia
CREATE EXTENSION IF NOT EXISTS timescaledb;


-- =====================================
-- Creación de tablas del modelo
-- =====================================

-- Tabla: Departamentos
CREATE TABLE departamentos
(
    id              INTEGER GENERATED ALWAYS AS IDENTITY CONSTRAINT departamentos_pk PRIMARY KEY,
    nombre          TEXT NOT NULL CONSTRAINT nombre_departamento_uk UNIQUE
);

COMMENT ON TABLE departamentos IS 'Departamentos de Colombia';
COMMENT ON COLUMN departamentos.id IS 'Id del departamento';
COMMENT ON COLUMN departamentos.nombre IS 'Nombre del departamento';


-- Tabla: Zonas
CREATE TABLE zonas
(
    id              INTEGER GENERATED ALWAYS AS IDENTITY CONSTRAINT zonas_pk PRIMARY KEY,
    nombre          TEXT NOT NULL CONSTRAINT nombre_zona_uk UNIQUE
);

COMMENT ON TABLE zonas IS 'Zonas Hidrográficas de Colombia';
COMMENT ON COLUMN zonas.id IS 'Id de la zona';
COMMENT ON COLUMN zonas.nombre IS 'Nombre de la zona';


-- Tabla: Municipios
CREATE TABLE municipios
(
    id              INTEGER GENERATED ALWAYS AS IDENTITY CONSTRAINT municipios_pk PRIMARY KEY,
    nombre          TEXT NOT NULL,
    departamento_id INTEGER NOT NULL CONSTRAINT municipios_departamentos_fk REFERENCES departamentos,
    zona_id         INTEGER NOT NULL CONSTRAINT municipios_zonas_fk REFERENCES zonas (id),
    CONSTRAINT nombre_municipio_en_departamento_uk UNIQUE (nombre, departamento_id)
);

COMMENT ON TABLE municipios IS 'Municipios de Colombia ubicados en departamentos y zonas hidrográficas';
COMMENT ON COLUMN municipios.id IS 'Id del municipio';
COMMENT ON COLUMN municipios.nombre IS 'nombre del municipio';
COMMENT ON COLUMN municipios.departamento_id IS 'Id del departamento al que pertenece el municipio';
COMMENT ON COLUMN municipios.zona_id IS 'Id de la zona hidrográfica donde está ubicado el municipio';


-- Tabla: Estaciones
CREATE TABLE estaciones
(
    id              TEXT NOT NULL CONSTRAINT estaciones_pk PRIMARY KEY,
    nombre          TEXT NOT NULL,
    municipio_id    INTEGER NOT NULL CONSTRAINT estaciones_municipios_fk REFERENCES municipios,
    latitud         FLOAT NOT NULL,
    longitud        FLOAT NOT NULL,
    CONSTRAINT ubicacion_estacion_uk UNIQUE (latitud, longitud)
);

COMMENT ON TABLE estaciones IS 'Estaciones de Medición de Temperatura';
COMMENT ON COLUMN estaciones.id IS 'Id de la estación';
COMMENT ON COLUMN estaciones.nombre IS 'nombre de la estación';
COMMENT ON COLUMN estaciones.municipio_id IS 'Id del municipio donde está la estación';
COMMENT ON COLUMN estaciones.latitud IS 'Latitud donde está ubicada la estación';
COMMENT ON COLUMN estaciones.longitud IS 'Longitud donde está ubicada la estación';


-- Tabla: Sensores
CREATE TABLE sensores
(
    id              TEXT NOT NULL CONSTRAINT sensores_pk PRIMARY KEY,
    nombre          TEXT NOT NULL CONSTRAINT nombre_sensor_uk UNIQUE
);

COMMENT ON TABLE sensores IS 'Sensores de temperatura utilizados para las observaciones de temperatura';
COMMENT ON COLUMN sensores.id IS 'Id del sensor';
COMMENT ON COLUMN sensores.nombre IS 'Nombre del sensor';


-- ====================================================
-- Tabla: Observaciones (Optimizada para TimescaleDB)
-- ====================================================

CREATE TABLE observaciones
(
    estacion_id     TEXT NOT NULL,
    sensor_id       TEXT NOT NULL,
    fecha           TIMESTAMP WITH TIME ZONE NOT NULL,
    valor           FLOAT NOT NULL,
    unidad_medida   TEXT NOT NULL,
    PRIMARY KEY (estacion_id, sensor_id, fecha),
    CONSTRAINT observaciones_estaciones_fk FOREIGN KEY (estacion_id) REFERENCES estaciones(id),
    CONSTRAINT observaciones_sensores_fk FOREIGN KEY (sensor_id) REFERENCES sensores(id)
);

alter table public.observaciones rename constraint observaciones_pkey to observaciones_pk;

COMMENT ON TABLE observaciones IS 'Observaciones de temperatura realizadas por las estaciones - Hypertable de TimescaleDB';
COMMENT ON COLUMN observaciones.estacion_id IS 'Id de la estación que hizo la observación';
COMMENT ON COLUMN observaciones.sensor_id IS 'Id del sensor con el que se hizo la observación';
COMMENT ON COLUMN observaciones.fecha IS 'Fecha y hora en la que se realizó la observación de temperatura (con zona horaria)';
COMMENT ON COLUMN observaciones.valor IS 'Valor de temperatura obtenido en la observación';
COMMENT ON COLUMN observaciones.unidad_medida IS 'Unidad de medida de la temperatura observada';

-- Eliminar registros superiores a Septiembre 30 de 2025
-- 39 filas afectadas

delete from observaciones
where fecha >= to_timestamp('2025-10-01','YYYY-MM-DD');

-- =========================================
-- Convertir a Hypertable de TimescaleDB
-- =========================================
SELECT create_hypertable(
    'observaciones',
    'fecha',
    chunk_time_interval => INTERVAL '1 week',
    if_not_exists => TRUE,
    migrate_data => TRUE
);


-- =====================================
-- Creación de indices
-- =====================================

-- Índice para consultas por estación ordenadas por fecha (descendente)
-- Útil para: "últimas observaciones de una estación"
CREATE INDEX observacion_estacion_fecha_ix
ON observaciones (estacion_id, fecha DESC);

-- Índice para consultas por sensor ordenadas por fecha (descendente)
-- Útil para: "últimas lecturas de un sensor específico"
CREATE INDEX observacion_sensor_fecha_ix
ON observaciones (sensor_id, fecha DESC);

-- Índice compuesto para consultas de rangos de temperatura
-- Útil para: "observaciones con temperaturas extremas en un periodo"
CREATE INDEX observacion_fecha_valor_ix 
ON observaciones (fecha DESC, valor);

COMMENT ON INDEX observacion_estacion_fecha_ix IS 'Optimiza consultas de observaciones por estación ordenadas por fecha';
COMMENT ON INDEX observacion_sensor_fecha_ix IS 'Optimiza consultas de observaciones por sensor ordenadas por fecha';
COMMENT ON INDEX observacion_fecha_valor_ix IS 'Optimiza consultas de rangos de temperatura por fecha';

-- =====================================
-- Configuración de compresión
-- =====================================

-- Habilitar compresión en la hypertable
-- segmentby: agrupa por estación y sensor (datos similares se comprimen juntos)
-- orderby: ordena por fecha descendente para mejor compresión
ALTER TABLE observaciones SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'estacion_id, sensor_id',
    timescaledb.compress_orderby = 'fecha DESC'
);

-- Política automática: comprimir chunks con datos mayores a 7 días
-- Esto significa que los últimos 7 días quedan sin comprimir (rápido acceso)
-- y los datos más antiguos se comprimen automáticamente
SELECT add_compression_policy('observaciones', INTERVAL '7 days');

-- =====================================
-- Política de retención de datos
-- =====================================

-- Retener solo los últimos 3 años de datos
-- Los datos más antiguos se eliminarán automáticamente
-- AJUSTA este intervalo según tus necesidades de negocio
SELECT add_retention_policy('observaciones', INTERVAL '3 years');

-- ============================================================
-- Información sobre los chunks
-- ============================================================

    -- Información detallada de todos los chunks
SELECT 
    chunk_name,
    range_start,
    range_end,
    is_compressed,
    chunk_schema,
    chunk_tablespace
FROM timescaledb_information.chunks
WHERE hypertable_name = 'observaciones'
ORDER BY range_start DESC;


-- Vista general de la hypertable
SELECT * FROM timescaledb_information.hypertables
WHERE hypertable_name = 'observaciones';

