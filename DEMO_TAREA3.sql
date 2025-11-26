USE TP3_Municipalidad;
GO

-- 1. Cargar día 2025-06-01 desde XML a staging
-- (aquí llamas al contenido de cargarXML.sql con @dia = '2025-06-01')

-- 2. Ejecutar MERGEs para ese día
-- (EXEC o simplemente incluir los scripts en orden)

-- 3. Ejecutar emisión de junio
EXEC dbo.sp_emision_mensual @hoy = '2025-06-13';

-- 4. Cargar y procesar pagos del 8 de julio
-- 4.1 cargar @dia = '2025-07-08' a st_*
-- 4.2 EXEC dbo.sp_merge_pagos;

-- 5. Repetir para 22 y 28 de octubre

-- 6. Ejecutar validacionesMorosidad.sql
