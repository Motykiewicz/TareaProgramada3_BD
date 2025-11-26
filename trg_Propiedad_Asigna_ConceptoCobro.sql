USE TP3_Municipalidad;
GO

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
