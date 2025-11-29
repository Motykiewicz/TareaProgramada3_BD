-- Morosidad (ve cuantas estan vencidas) con fecha de vencimiento y un corte de fecha 11-01 
SELECT Finca, COUNT(*) AS Vencidas
FROM dbo.Factura f
JOIN dbo.Propiedad p ON p.PropiedadID=f.PropiedadID
WHERE f.Estado='PENDIENTE' AND f.FechaVencimiento < CAST('2025-11-01' AS DATE)
  AND Finca IN ('F-0007','F-0021','F-0048','F-0013','F-0034')
GROUP BY Finca
ORDER BY Finca;

------------------------------------
USE TP3_Municipalidad;
GO

-- Resumen de morosidad por finca (cantidad de facturas y pendientes por finca) 
SELECT  p.Finca,
        COUNT(*) AS CantFacturas,
        SUM(CASE WHEN f.Estado = 'PENDIENTE' THEN 1 ELSE 0 END) AS FactPendientes
FROM dbo.Factura f
JOIN dbo.Propiedad p ON p.PropiedadID = f.PropiedadID
GROUP BY p.Finca
HAVING SUM(CASE WHEN f.Estado = 'PENDIENTE' THEN 1 ELSE 0 END) > 0
ORDER BY p.Finca;

------- fincas solicitadas por el profe 07,21, 48,13,34 aqui damos un detalle de las fincas solicitadas 
SELECT  p.Finca,
        f.FacturaID,
        f.Estado,
        f.Total,
        f.FechaEmision
FROM dbo.Factura f
JOIN dbo.Propiedad p ON p.PropiedadID = f.PropiedadID
WHERE p.Finca IN ('F-0007','F-0021','F-0048','F-0013','F-0034')
ORDER BY p.Finca, f.FechaEmision;

----------------------------------------

