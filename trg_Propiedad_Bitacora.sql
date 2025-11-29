USE TP3_Municipalidad;
GO

-- Trigger para la bitacora donde guarda cada insert update o delete 
IF OBJECT_ID('dbo.BitacoraCambios','U') IS NULL
BEGIN
CREATE TABLE dbo.BitacoraCambios (
  id INT IDENTITY(1,1) PRIMARY KEY,
  IdEntityType INT NOT NULL,  -- 1 Propiedad, 2 Propietario, 3 User, 4 Propiedad-Propietario, 5 Propiedad-Usuario, 6 PropietarioJuridico, 7 CC
  EntityId INT NOT NULL,  -- ID de la entidad siendo actualizada 
  jsonAntes VARCHAR(500) NULL,
  jsonDespues VARCHAR(500) NULL,
  insertedAt DATETIME NOT NULL DEFAULT SYSDATETIME(),-- estampa de tiempo cuando se hizo la actualizacion 
  insertedBy INT NULL,    -- usuario persona que hizo la actualización 
  insertedIn VARCHAR(20) NULL     -- IP desde donde se hizo la actualización, NO la IP del servidor, sino la del usuario que debe capturarse en capa lógica. 
);
END
GO


EXEC sys.sp_set_session_context @key='app_user_id', @value=1;           -- UsuarioID admin logueado
EXEC sys.sp_set_session_context @key='client_ip',   @value='190.10.20.30';


GO
CREATE OR ALTER TRIGGER dbo.trg_Propiedad_Bitacora
ON dbo.Propiedad
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @usr INT        = TRY_CONVERT(INT, SESSION_CONTEXT(N'app_user_id'));
  DECLARE @ip  VARCHAR(20)= TRY_CONVERT(VARCHAR(20), SESSION_CONTEXT(N'client_ip'));

  -- INSERT
  INSERT dbo.BitacoraCambios (IdEntityType, EntityId, jsonAntes, jsonDespues, insertedBy, insertedIn)
  SELECT 1, i.PropiedadID, NULL,
         (SELECT i.PropiedadID, i.Finca, i.Zona, i.Uso, i.FechaRegistro
          FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
         @usr, @ip
  FROM inserted i
  LEFT JOIN deleted d ON d.PropiedadID=i.PropiedadID
  WHERE d.PropiedadID IS NULL;

  -- DELETE
  INSERT dbo.BitacoraCambios (IdEntityType, EntityId, jsonAntes, jsonDespues, insertedBy, insertedIn)
  SELECT 1, d.PropiedadID,
         (SELECT d.PropiedadID, d.Finca, d.Zona, d.Uso, d.FechaRegistro
          FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
         NULL,
         @usr, @ip
  FROM deleted d
  LEFT JOIN inserted i ON i.PropiedadID=d.PropiedadID
  WHERE i.PropiedadID IS NULL;

  -- UPDATE
  INSERT dbo.BitacoraCambios (IdEntityType, EntityId, jsonAntes, jsonDespues, insertedBy, insertedIn)
  SELECT 1, i.PropiedadID,
         (SELECT d.PropiedadID, d.Finca, d.Zona, d.Uso, d.FechaRegistro
          FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
         (SELECT i.PropiedadID, i.Finca, i.Zona, i.Uso, i.FechaRegistro
          FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
         @usr, @ip
  FROM inserted i
  JOIN deleted  d ON d.PropiedadID=i.PropiedadID;
END
GO



