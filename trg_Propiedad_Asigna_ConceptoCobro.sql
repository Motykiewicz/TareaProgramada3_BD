USE TP3_Municipalidad;
GO
------------------------------------------------------------------ trg_Propiedad_Asigna_ConceptoCobro
CREATE OR ALTER TRIGGER dbo.trg_Propiedad_Asigna_ConceptoCobro
ON dbo.Propiedad
AFTER INSERT
AS
BEGIN
  SET NOCOUNT ON;

  -- Conceptos  
  DECLARE @ccIMP INT = (SELECT ConceptoID FROM dbo.ConceptoCobro WHERE Codigo = 'IMPUESTO');
  DECLARE @ccAGU INT = (SELECT ConceptoID FROM dbo.ConceptoCobro WHERE Codigo = 'AGUA');
  DECLARE @ccBAS INT = (SELECT ConceptoID FROM dbo.ConceptoCobro WHERE Codigo = 'BASURA');
  DECLARE @ccPAR INT = (SELECT ConceptoID FROM dbo.ConceptoCobro WHERE Codigo = 'PARQUES');

  /* Copia de las filas insertadas  */
  DECLARE @props TABLE(PropiedadID INT PRIMARY KEY, Uso VARCHAR(32) NULL);
  INSERT INTO @props(PropiedadID, Uso)
  SELECT DISTINCT PropiedadID, Uso
  FROM inserted;

  /* IMPUESTO:  */
  INSERT INTO dbo.PropiedadConceptoCobro(PropiedadID, ConceptoID, Activo)
  SELECT p.PropiedadID, @ccIMP, 1
  FROM @props p
  WHERE NOT EXISTS (
    SELECT 1 FROM dbo.PropiedadConceptoCobro pc
    WHERE pc.PropiedadID = p.PropiedadID AND pc.ConceptoID = @ccIMP
  );

  /* AGUA */
  INSERT INTO dbo.PropiedadConceptoCobro(PropiedadID, ConceptoID, Activo)
  SELECT p.PropiedadID, @ccAGU, 1
  FROM @props p
  WHERE p.Uso IN ('residencial','industrial','comercial')
    AND NOT EXISTS (
      SELECT 1 FROM dbo.PropiedadConceptoCobro pc
      WHERE pc.PropiedadID = p.PropiedadID AND pc.ConceptoID = @ccAGU
    );

  /* BASURA: */
  INSERT INTO dbo.PropiedadConceptoCobro(PropiedadID, ConceptoID, Activo)
  SELECT p.PropiedadID, @ccBAS, 1
  FROM @props p
  WHERE (p.Uso IS NULL OR p.Uso NOT IN ('agricola'))
    AND NOT EXISTS (
      SELECT 1 FROM dbo.PropiedadConceptoCobro pc
      WHERE pc.PropiedadID = p.PropiedadID AND pc.ConceptoID = @ccBAS
    );

  /* PARQUES */
  INSERT INTO dbo.PropiedadConceptoCobro(PropiedadID, ConceptoID, Activo)
  SELECT p.PropiedadID, @ccPAR, 1
  FROM @props p
  WHERE p.Uso IN ('residencial','comercial')
    AND NOT EXISTS (
      SELECT 1 FROM dbo.PropiedadConceptoCobro pc
      WHERE pc.PropiedadID = p.PropiedadID AND pc.ConceptoID = @ccPAR
    );
END
GO




-------------------------------------------- trg_Propiedad_Bitacora
USE TP3_Municipalidad;
GO

CREATE OR ALTER TRIGGER dbo.trg_Propiedad_Bitacora
ON dbo.Propiedad
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @usr NVARCHAR(128) = TRY_CONVERT(NVARCHAR(128), SESSION_CONTEXT('app_user_id'));
  DECLARE @ip  NVARCHAR(20)  = TRY_CONVERT(NVARCHAR(20),  SESSION_CONTEXT('client_ip'));

  IF @usr IS NULL SET @usr = '(desconocido)';
  IF @ip  IS NULL SET @ip  = '(sin-ip)';

  -- INSERTS
  INSERT dbo.Bitacora (Tabla, PK, Usuario, IP, Fecha, JsonAntes, JsonDespues, Accion)
  SELECT
      N'Propiedad' AS Tabla, CAST(i.PropiedadID AS NVARCHAR(50)) AS PK, @usr AS Usuario, @ip AS IP, SYSDATETIME() AS Fecha, NULL AS JsonAntes,
      (SELECT i.PropiedadID, i.Finca, i.Zona, i.Uso, i.FechaRegistro
       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS JsonDespues,
      N'INSERT'   AS Accion
  FROM inserted i
  LEFT JOIN deleted d ON d.PropiedadID = i.PropiedadID
  WHERE d.PropiedadID IS NULL;

  -- DELETES 
  INSERT dbo.Bitacora (Tabla, PK, Usuario, IP, Fecha, JsonAntes, JsonDespues, Accion)
  SELECT
      'Propiedad', CAST(d.PropiedadID AS NVARCHAR(50)), @usr, @ip, SYSDATETIME(),
      (SELECT d.PropiedadID, d.Finca, d.Zona, d.Uso, d.FechaRegistro
       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
      NULL,
      'DELETE'
  FROM deleted d
  LEFT JOIN inserted i ON i.PropiedadID = d.PropiedadID
  WHERE i.PropiedadID IS NULL;

  -- UPDATES 
  INSERT dbo.Bitacora (Tabla, PK, Usuario, IP, Fecha, JsonAntes, JsonDespues, Accion)
  SELECT
      'Propiedad', CAST(i.PropiedadID AS NVARCHAR(50)), @usr, @ip,
      SYSDATETIME(),
      (SELECT d.PropiedadID, d.Finca, d.Zona, d.Uso, d.FechaRegistro
       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
      (SELECT i.PropiedadID, i.Finca, i.Zona, i.Uso, i.FechaRegistro
       FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
      'UPDATE'
  FROM inserted i
  JOIN deleted  d ON d.PropiedadID = i.PropiedadID;
END;
GO

