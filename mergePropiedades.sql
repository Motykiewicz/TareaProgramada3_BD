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


USE TP3_Municipalidad;
GO

DECLARE @PersonaID INT = 2;   -- <<< PON AQUÍ el PersonaID del dueño que elegiste

IF EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioLogin = 'user_f0007')
BEGIN
    UPDATE u
    SET u.PersonaID    = @PersonaID,
        u.Rol          = 'no-admin',
        u.HashPassword = HASHBYTES('SHA2_256', 'user123')  -- clave: user123
    FROM dbo.Usuario u
    WHERE u.UsuarioLogin = 'user_f0007';
END
ELSE
BEGIN
    INSERT INTO dbo.Usuario (PersonaID, Rol, UsuarioLogin, HashPassword)
    VALUES (
      @PersonaID,
      'no-admin',
      'user_f0007',
      HASHBYTES('SHA2_256', 'user123')
    );
END;

-- Ver cómo quedó
SELECT UsuarioID, PersonaID, Rol, UsuarioLogin
FROM dbo.Usuario
WHERE UsuarioLogin = 'user_f0007';


USE TP3_Municipalidad;
GO

SELECT * FROM dbo.ParametroSistema;
