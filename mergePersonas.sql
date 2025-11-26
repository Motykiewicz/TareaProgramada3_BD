USE TP3_Municipalidad;
GO
-- Inserta personas nuevas por Identificacion (mergePersonas)
INSERT INTO dbo.Persona(Identificacion, Nombre)
SELECT s.Identificacion, s.Nombre
FROM dbo.st_Persona s
LEFT JOIN dbo.Persona p ON p.Identificacion = s.Identificacion
WHERE p.PersonaID IS NULL;
