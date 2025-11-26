USE TP3_Municipalidad;
GO
-- Inserta propiedades nuevas por Finca (mergePropiedades) 
INSERT INTO dbo.Propiedad(Finca, Zona, Uso, FechaRegistro, EstadoServicioAgua, M3Acumulados, M3AcumuladosUltimaFactura)
SELECT s.Finca, s.Zona, s.Uso, s.FechaRegistro, 'ACTIVO', 0, 0
FROM dbo.st_Propiedad s
LEFT JOIN dbo.Propiedad p ON p.Finca = s.Finca
WHERE p.PropiedadID IS NULL;

-- (opcional) Ajusta Zona/Uso/Fecha si ya existían y cambiaron
UPDATE p
SET p.Zona = s.Zona,
    p.Uso  = s.Uso,
    p.FechaRegistro = s.FechaRegistro
FROM dbo.Propiedad p
JOIN dbo.st_Propiedad s ON s.Finca = p.Finca;


