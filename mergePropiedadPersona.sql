USE TP3_Municipalidad;
GO

/* 
   mergePropiedadPersona.sql
    */

-- 1) Cerrar relaciones abiertas que ya no sean las vigentes
UPDATE pp
SET FechaFin = s.FechaInicio
FROM dbo.PropiedadPersona pp
JOIN dbo.Propiedad p  ON p.PropiedadID = pp.PropiedadID
LEFT JOIN dbo.st_PropiedadPersona s
    ON s.Finca = p.Finca
   AND s.Identificacion = (
            SELECT TOP (1) sp.Identificacion
            FROM dbo.st_PropiedadPersona sp
            WHERE sp.Finca = p.Finca
            ORDER BY sp.FechaInicio DESC
       )
WHERE pp.FechaFin IS NULL
  AND (
        s.Identificacion IS NULL
        OR NOT EXISTS (
              SELECT 1
              FROM dbo.PropiedadPersona x
              WHERE x.PropiedadID = pp.PropiedadID
                AND x.PersonaID   = pp.PersonaID
                AND x.FechaInicio = pp.FechaInicio
                AND x.FechaFin IS NULL
        )
      );

-- 2) Crear la relación vigente según staging (si no existe)
INSERT INTO dbo.PropiedadPersona(PropiedadID, PersonaID, FechaInicio, FechaFin)
SELECT  p.PropiedadID,
        pe.PersonaID,
        s.FechaInicio,
        s.FechaFin
FROM dbo.st_PropiedadPersona s
JOIN dbo.Propiedad p   ON p.Finca          = s.Finca
JOIN dbo.Persona  pe   ON pe.Identificacion = s.Identificacion
LEFT JOIN dbo.PropiedadPersona pp
   ON pp.PropiedadID = p.PropiedadID
  AND pp.PersonaID   = pe.PersonaID
  AND pp.FechaInicio = s.FechaInicio
WHERE pp.PropiedadID IS NULL;  -- evita duplicar la relación
GO

