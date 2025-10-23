-- Scripts de clase - Octubre 10 de 2025
-- Curso de Tópicos Avanzados de base de datos - UPB 202520
-- Juan Dario Rodas - juand.rodasm@upb.edu.co

-- Proyecto: Analisis de Temperatura en Antioquia para el año 2025
-- Motor de Base de datos: PostgreSQL 17.x
-- Version: Relacional

-- *******************************************************
-- Consultas SQL con enfoque en la perspectiva temporal
-- *******************************************************

-- ********************************************************
-- Superbásicas:
-- ********************************************************

-- ------------------------------------------------------------------------------------------
-- ¿Hay datos duplicados?
-- R/. Si, 70.820 para ser más precisos. Se identificaron con la siguiente consulta
-- ------------------------------------------------------------------------------------------

select distinct
    codigoestacion,
    codigosensor,
    valorobservado,
    nombreestacion,
    municipio,
    zonahidrografica,
    unidadmedida,
    fechaobservacion,
    count(valorobservado) total
from datos_provisionales
group by
    codigoestacion,
    codigosensor,
    valorobservado,
    nombreestacion,
    municipio,
    zonahidrografica,
    unidadmedida,
    fechaobservacion
having count(valorobservado) > 1
order by total desc;

-- ------------------------------------------------------------------------------------------
-- ¿Hay días sin mediciones?
-- R/. Si, de 273 días que tiene 2025 a septiembre 30, 38 días no tenían 
-- ninguna medición en alguna estación
-- ------------------------------------------------------------------------------------------

WITH
    -- Genera todas las fechas de 2024
fechas_2025 AS (
     SELECT generate_series(
        '2025-01-01'::date,
        '2025-10-01'::date,
        '1 day'::interval
    )::date AS fecha
    ),
    -- Fechas donde hay al menos una observación
    fechas_con_observaciones AS (
    SELECT DISTINCT DATE(fecha) AS fecha
    FROM observaciones
    WHERE EXTRACT(YEAR FROM fecha) = 2025
    )
SELECT
    f.fecha AS fecha_sin_observaciones
FROM fechas_2025 f
LEFT JOIN fechas_con_observaciones fco ON f.fecha = fco.fecha
WHERE fco.fecha IS NULL
ORDER BY f.fecha;

-- ------------------------------------------------------------------------------------------
-- ¿Hay horas sin mediciones?
-- R/. Si, de 24 horas del día:
--      entre las 8 y 9 pm se hace la menor cantidad de mediciones
--      La mayor cantidad de mediciones se hace entre las 0 am y las 3 am.

WITH horas_por_dia AS (
    -- Genera todas las horas del día (0-23)
    SELECT generate_series(0, 23) AS hora
),
conteo_por_hora AS (
    -- Cuenta observaciones por hora
    SELECT 
        EXTRACT(HOUR FROM fecha) AS hora,
        COUNT(id) AS total_observaciones,
        COUNT(DISTINCT estacion_id) AS total_estaciones
    FROM observaciones
    WHERE EXTRACT(YEAR FROM fecha) = 2025
    GROUP BY EXTRACT(HOUR FROM fecha)
)
SELECT 
    h.hora,
    COALESCE(c.total_observaciones, 0) AS numero_observaciones,
    COALESCE(c.total_estaciones, 0) AS numero_estaciones,
    ROUND(COALESCE(c.total_observaciones, 0)::numeric / 
          (SELECT SUM(total_observaciones) FROM conteo_por_hora) * 100, 2) AS porcentaje_del_total
FROM horas_por_dia h
LEFT JOIN conteo_por_hora c ON h.hora = c.hora
ORDER BY porcentaje_del_total;

-- ------------------------------------------------------------------------------------------
-- ¿Hay Outliers?
-- R/. Si, El outlier bajo más frecuentes están por debajo de 10°C


WITH estadisticas_por_mes_estacion AS (
    -- Calcula estadísticas por mes y estación
    SELECT
        estacion_id,
        EXTRACT(MONTH FROM fecha) AS mes,
        AVG(valor) AS promedio,
        STDDEV(valor) AS desviacion_estandar,
        MIN(valor) AS minimo,
        MAX(valor) AS maximo,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY valor) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY valor) AS q3
    FROM observaciones
    WHERE EXTRACT(YEAR FROM fecha) = 2024
    GROUP BY estacion_id, EXTRACT(MONTH FROM fecha)
),
outliers AS (
    -- Identifica valores atípicos usando el método del rango intercuartílico (IQR)
    SELECT
        o.id observacion_id,
        o.estacion_id,
        e.nombre AS estacion_nombre,
        o.sensor_id,
        s.nombre AS sensor_nombre,
        o.fecha,
        o.valor,
        o.unidad_medida,
        est.promedio,
        est.desviacion_estandar,
        est.q1,
        est.q3,
        est.q3 - est.q1 AS iqr,
        est.q1 - 1.5 * (est.q3 - est.q1) AS limite_inferior,
        est.q3 + 1.5 * (est.q3 - est.q1) AS limite_superior,
        CASE
            WHEN o.valor < est.q1 - 1.5 * (est.q3 - est.q1) THEN 'Outlier bajo'
            WHEN o.valor > est.q3 + 1.5 * (est.q3 - est.q1) THEN 'Outlier alto'
            ELSE 'Normal'
        END AS tipo_outlier
    FROM observaciones o
    JOIN estaciones e ON o.estacion_id = e.id
    JOIN sensores s ON o.sensor_id = s.id
    JOIN estadisticas_por_mes_estacion est ON
        o.estacion_id = est.estacion_id AND
        EXTRACT(MONTH FROM o.fecha) = est.mes
)
SELECT
    observacion_id,
    estacion_id,
    estacion_nombre,
    sensor_id,
    sensor_nombre,
    fecha,
    valor,
    unidad_medida,
    tipo_outlier,
    round(limite_inferior::numeric,3) limite_inferior,
    round(promedio::numeric,3) promedio,
    round(limite_superior::numeric,3) limite_superior,
    q1 percentil_25,
    q3 percentil_75,
    desviacion_estandar
FROM outliers
WHERE tipo_outlier IN ('Outlier bajo', 'Outlier alto');

-- Esta consulta se convirtió en Vista Materializada y luego con esta consulta identificamos
-- Los outliers más frecuentes
select distinct tipo_outlier, valor, count(*) total
from mv_estadisticas_outliers
group by tipo_outlier, valor
order by total desc;



-- ********************************************************
-- Ahora si, las consultas interesantes
-- ********************************************************

-- ------------------------------------------------------------------------------------------
-- Análisis de patrones cíclicos de temperatura por día de la semana y hora
-- ¿Existen patrones cíclicos en las temperaturas según el día de la semana 
-- y la hora del día, y cómo varían entre las diferentes zonas hidrográficas?

WITH observaciones_horarias AS (
    SELECT 
        z.id AS zona_id,
        z.nombre AS zona_nombre,
        EXTRACT(DOW FROM o.fecha) AS dia_semana,
        EXTRACT(HOUR FROM o.fecha) AS hora,
        AVG(o.valor) AS temperatura_promedio,
        COUNT(*) AS num_observaciones
    FROM observaciones o
    JOIN estaciones e ON o.estacion_id = e.id
    JOIN municipios m ON e.municipio_id = m.id
    JOIN zonas z ON m.zona_id = z.id
    GROUP BY z.id, z.nombre, EXTRACT(DOW FROM o.fecha), EXTRACT(HOUR FROM o.fecha)
),
estadisticas_zona AS (
    SELECT 
        zona_id,
        zona_nombre,
        AVG(temperatura_promedio) AS promedio_general,
        STDDEV(temperatura_promedio) AS stddev_general
    FROM observaciones_horarias
    GROUP BY zona_id, zona_nombre
)
SELECT 
    o.zona_nombre,
    o.dia_semana,
    o.hora,
    o.temperatura_promedio,
    o.num_observaciones,
    e.promedio_general,
    o.temperatura_promedio - e.promedio_general AS diferencia_promedio,
    (o.temperatura_promedio - e.promedio_general) / NULLIF(e.stddev_general, 0) AS z_score,
    AVG(o.temperatura_promedio) OVER (
        PARTITION BY o.zona_id, o.hora 
        ORDER BY o.dia_semana 
        ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) AS promedio_movil_dia,
    AVG(o.temperatura_promedio) OVER (
        PARTITION BY o.zona_id, o.dia_semana 
        ORDER BY o.hora 
        ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) AS promedio_movil_hora
FROM observaciones_horarias o
JOIN estadisticas_zona e ON o.zona_id = e.zona_id
ORDER BY o.zona_nombre, o.dia_semana, o.hora;

-- ------------------------------------------------------------------------------------------
-- ¿Cómo ha evolucionado la temperatura promedio mensual durante 2025 en la zona hidrográfica 
-- de Nechí en Antioquia, y cuál es la tendencia respecto al mes anterior?

WITH temperatura_mensual_zona AS (
    SELECT
        z.id AS zona_id,
        z.nombre AS zona_nombre,
        EXTRACT(YEAR FROM o.fecha) AS año,
        EXTRACT(MONTH FROM o.fecha) AS mes,
        TO_CHAR(DATE_TRUNC('month', o.fecha), 'Month') AS nombre_mes,
        AVG(o.valor) AS temperatura_promedio,
        COUNT(*) AS num_observaciones,
        COUNT(DISTINCT o.estacion_id) AS num_estaciones
    FROM observaciones o
    JOIN estaciones e ON o.estacion_id = e.id
    JOIN municipios m ON e.municipio_id = m.id
    JOIN zonas z ON m.zona_id = z.id
    JOIN departamentos d ON m.departamento_id = d.id
    WHERE
        upper(d.nombre) = 'ANTIOQUIA' AND
        EXTRACT(YEAR FROM o.fecha) = 2025
    GROUP BY z.id, z.nombre, EXTRACT(YEAR FROM o.fecha), EXTRACT(MONTH FROM o.fecha),
             TO_CHAR(DATE_TRUNC('month', o.fecha), 'Month')
)
SELECT
    zona_nombre,
    año,
    mes,
    nombre_mes,
    round(temperatura_promedio::numeric,3) temperatura_promedio,
    num_observaciones,
    num_estaciones,
    round((LAG(temperatura_promedio) OVER (PARTITION BY zona_id ORDER BY año, mes))::numeric,3) AS temperatura_mes_anterior,
    round((temperatura_promedio - LAG(temperatura_promedio) OVER (PARTITION BY zona_id ORDER BY año, mes))::numeric,3) AS variacion_mensual,
    CASE
        WHEN temperatura_promedio > LAG(temperatura_promedio) OVER (PARTITION BY zona_id ORDER BY año, mes) THEN '↑'
        WHEN temperatura_promedio < LAG(temperatura_promedio) OVER (PARTITION BY zona_id ORDER BY año, mes) THEN '↓'
        ELSE '→'
    END AS tendencia
FROM temperatura_mensual_zona
where upper(zona_nombre)= 'NECHÍ'
ORDER BY zona_nombre, año, mes;

