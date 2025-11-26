USE TP3_Municipalidad;
GO
-- Crea medidor si no existe y la propiedad está en st_Medidor (o por política de uso)
INSERT INTO dbo.Medidor(PropiedadID, Activo)
SELECT p.PropiedadID, 1
FROM dbo.Propiedad p
LEFT JOIN dbo.Medidor m ON m.PropiedadID=p.PropiedadID
LEFT JOIN dbo.st_Medidor sm ON sm.Finca=p.Finca
WHERE m.MedidorID IS NULL
  AND (
       sm.Finca IS NOT NULL
       OR LOWER(p.Uso) IN ('residencial','industrial','comercial')  -- política
      );
