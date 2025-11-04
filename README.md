# Temperatura Antioquia 2025

## Comparativo de Modelado de Bases de Datos para Series de Tiempo

## 📊 Descripción del proyecto

Este proyecto presenta un análisis comparativo de diferentes enfoques de modelado de bases de datos para el manejo de series de tiempo, desarrollado como parte del curso de Tópicos Avanzados de Bases de Datos.

El estudio evoluciona desde un modelo relacional tradicional hacia implementaciones especializadas, evaluando las consideraciones de diseño, ventajas y desventajas de cada aproximación.

Los datos originales fueron tomados de la Plataforma Nacional de Datos Abiertos de Colombia, del dataset denominado

 **Datos Hidrometeorológicos Crudos - Red de Estaciones IDEAM : Temperatura**

[https://www.datos.gov.co/Ambiente-y-Desarrollo-Sostenible/Datos-Hidrometeorol-gicos-Crudos-Red-de-Estaciones/sbwg-7ju4/about_data](https://www.datos.gov.co/Ambiente-y-Desarrollo-Sostenible/Datos-Hidrometeorol-gicos-Crudos-Red-de-Estaciones/sbwg-7ju4/about_data)

Filtros aplicados:

- **Departamento**: Antioquia
- **Rango fechas**: Enero 1 de 2025, 12:00 am a Noviembre 1 2025, 12:00 am.
- **Total registros iniciales antes de control de calidad**: 625.940 filas.

**Importante**:

Los datos aqui expuestos son utilizados con fines académicos. Por favor acceda al recurso relacionado para conocer más información al respecto.

## 🌡️ Dominio del problema

El caso de estudio se centra en un sistema de **monitoreo de temperatura ambiente** con las siguientes características:

- **Múltiples estaciones de medición** distribuidas en diferentes municipios del departamento
- **Período de análisis**: Enero - Septiembre 2025 (9 meses)
- **Frecuencia de medición**: Aproximadamente cada 15 minutos
- **Datos temporales**: Timestamps precisos para cada medición

Este dominio es ideal para evaluar bases de datos de series de tiempo debido a:

- Alto volumen de inserciones secuenciales
- Patrones de consulta basados en rangos temporales
- Necesidad de agregaciones y análisis estadísticos
- Importancia de la eficiencia en almacenamiento

## 🗄️ Tecnologías Evaluadas

### 1. PostgreSQL (Modelo Relacional)

Implementación tradicional usando un modelo relacional normalizado. Sirve como línea base para comparar el rendimiento y complejidad del diseño con las soluciones especializadas.

**Directorio**: `/postgresql`

### 2. TimescaleDB

Extensión de PostgreSQL optimizada para series de tiempo. Mantiene la compatibilidad con SQL mientras introduce capacidades específicas como hypertables y compresión automática.

**Directorio**: `/timescaledb`

### 3. MongoDB

Base de datos orientada a documentos que permite flexibilidad en el esquema y almacenamiento de datos jerárquicos. Evaluación de cómo un modelo NoSQL maneja series de tiempo.

**Directorio**: `/mongodb`

### 4. InfluxDB

Base de datos especializada en series de tiempo con un modelo de datos optimizado para métricas, eventos y análisis temporal.

**Directorio**: `/influxdb`

## 🎯 Objetivos del Proyecto

1. **Diseñar** modelos de datos apropiados para series de tiempo en cada tecnología
2. **Implementar** esquemas y consultas representativas del dominio
3. **Analizar** las consideraciones de diseño específicas de cada aproximación
4. **Comparar** rendimiento, escalabilidad y complejidad de implementación
5. **Documentar** ventajas y desventajas de cada solución

## 🔍 Aspectos Evaluados

- **Modelado de datos**: Estrategias de esquema y normalización
- **Operaciones de escritura**: Inserción masiva y rendimiento
- **Consultas temporales**: Rangos de tiempo, agregaciones, downsampling
- **Compresión y almacenamiento**: Eficiencia en el uso de espacio
- **Mantenimiento**: Particionamiento, retención de datos, optimización
- **Escalabilidad**: Comportamiento con volúmenes crecientes de datos

## 📝 Consultas Implementadas

Cada implementación incluye las siguientes consultas representativas:

1. Temperatura promedio por estación en un rango de fechas
2. Temperaturas máximas y mínimas diarias por municipio
3. Tendencias mensuales de temperatura
4. Detección de anomalías (valores fuera de rangos normales)
5. Agregaciones por ventanas de tiempo (por hora, por día)
6. Comparativas entre estaciones de diferentes municipios

## 🚀 Cómo Usar Este Repositorio

Cada subdirectorio contiene:

- Scripts de creación de esquema
- Datos de ejemplo o generadores de datos
- Consultas SQL/NoSQL de ejemplo
- README específico con instrucciones de configuración
- Análisis de consideraciones de diseño

Consulta el README de cada implementación para instrucciones detalladas de configuración y ejecución.

## 📚 Recursos Adicionales

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [TimescaleDB Documentation](https://docs.timescale.com/)
- [MongoDB Time Series Collections](https://www.mongodb.com/docs/manual/core/timeseries-collections/)
- [InfluxDB Documentation](https://docs.influxdata.com/)
