USE TP3_Municipalidad;
GO

-- 1) Insertar personas NUEVAS
INSERT INTO dbo.Persona(Identificacion, Nombre, Email, Telefono1, Telefono2)
SELECT
    s.Identificacion,
    s.Nombre,
    s.Email,
    s.Telefono1,
    NULL   -- Tel2 siempre NULL
FROM dbo.st_Persona s
LEFT JOIN dbo.Persona p
       ON p.Identificacion = s.Identificacion
WHERE p.PersonaID IS NULL;

-- 2) Actualizar personas EXISTENTES
UPDATE p
SET
    p.Nombre    = s.Nombre,
    p.Email     = s.Email,
    p.Telefono1 = s.Telefono1
    -- NO tocamos Telefono2
FROM dbo.Persona p
JOIN dbo.st_Persona s
  ON p.Identificacion = s.Identificacion;




SELECT TOP 15 PersonaID, Identificacion, Nombre, Email, Telefono1, Telefono2
FROM dbo.Persona
ORDER BY PersonaID;
