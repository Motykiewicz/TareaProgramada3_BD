
-- en resumen se podria decir que los pagos del xml del 8 de julio se cargar a las tablas st, se procesan con sp_merge_pagos y sp_procesar_pagos y se 
-- aplican automaticamente a la factura pendiente mas antigua de cada finca. 
-- PRIMERO DESCOMENTAMOS LA LINEA DE ABAJO 
-- EXEC dbo.sp_merge_pagos;

USE TP3_Municipalidad;
GO

DECLARE @FechaPago DATE = '2025-10-28';   -- aquí cambiamos entre  2025-07-08 / 2025-10-22 / 2025-10-28 para hacer pruebas

-- 1. Facturas pendientes de las fincas que tienen pagos en st_Pago
SELECT p.Finca,
       f.FacturaID,
       f.Estado,
       f.Total,
       f.FechaEmision
FROM dbo.Factura f
JOIN dbo.Propiedad p ON p.PropiedadID = f.PropiedadID
WHERE p.Finca IN (SELECT DISTINCT Finca FROM st_Pago)
ORDER BY p.Finca, f.FechaEmision;


-- 2. Resumen de cuántas facturas y cuántas pendientes
SELECT p.Finca,
       COUNT(*) AS CantFacturas,
       SUM(CASE WHEN f.Estado='PENDIENTE' THEN 1 ELSE 0 END) AS Pendientes
FROM dbo.Factura f
JOIN dbo.Propiedad p ON p.PropiedadID = f.PropiedadID
WHERE p.Finca IN (SELECT DISTINCT Finca FROM st_Pago)
GROUP BY p.Finca
ORDER BY p.Finca;


-- 3. Pagos del día que estamos probando
SELECT *
FROM dbo.Pago
WHERE Fecha = @FechaPago
ORDER BY PagoID;



-- 4. Aplicación de esos pagos a facturas
SELECT pf.PagoID, pf.FacturaID, pf.MontoAplicado,
       p.Fecha, p.Referencia, pr.Finca
FROM dbo.PagoFactura pf
JOIN dbo.Pago      p  ON p.PagoID = pf.PagoID
JOIN dbo.Factura   f  ON f.FacturaID = pf.FacturaID
JOIN dbo.Propiedad pr ON pr.PropiedadID = f.PropiedadID
WHERE p.Fecha = @FechaPago
ORDER BY pf.PagoID, pf.FacturaID;



-- Estado de TODAS las facturas de las fincas que aparecieron en st_Pago
-- (sirve para comparar antes y después de aplicar los pagos)
SELECT p.Finca,
       f.FacturaID,
       f.Estado,
       f.Total,
       f.FechaEmision
FROM dbo.Factura f
JOIN dbo.Propiedad p ON p.PropiedadID = f.PropiedadID
WHERE p.Finca IN (SELECT DISTINCT Finca FROM st_Pago)
ORDER BY p.Finca, f.FechaEmision;


