USE TP3_Municipalidad;
GO
   ----------------------------------------------------------------------------- sp_emision_mensual
   -- tenemos una factura por propiedad y dia 
   -- calculamos entonces el consumo de agua desde la ultima factura hasta hoy 
   -- le aplicamos el monto minimo de agua 
   -- y por ultimo le agremaos los cc de impuesto, basura y parques si aplican 
 
CREATE OR ALTER PROCEDURE dbo.sp_emision_mensual
  @hoy DATE
AS
BEGIN
  SET NOCOUNT ON;

  -- usamos los parametros de parametrosistema 
  DECLARE @diasVenc INT =
      (SELECT ValorEntero  FROM dbo.ParametroSistema WHERE Clave = 'DIAS_VENCIMIENTO');

  DECLARE @valorM3  DECIMAL(16,4) =
      ISNULL((SELECT ValorDecimal FROM dbo.ParametroSistema WHERE Clave = 'VALOR_M3'), 0);

  DECLARE @minAgua  DECIMAL(16,4) =
      ISNULL((SELECT ValorDecimal FROM dbo.ParametroSistema WHERE Clave = 'MONTO_MINIMO_AGUA'), 0);

  
  -- determinamos que propiedades facturan hoy 
  -- entonces si se registran un 14 del mes se facturan cada 14
  -- tomamos en cuenta los dias que son 30 y 31 para los meses de febrero si aplican que pasarian a ser el ultimo dia del mes 
  DECLARE @diaObjetivo INT = DAY(@hoy);

  DECLARE @P TABLE(PropiedadID INT PRIMARY KEY);

  INSERT INTO @P(PropiedadID)
  SELECT PropiedadID
  FROM dbo.Propiedad
  WHERE DAY(FechaRegistro) = @diaObjetivo;

  IF NOT EXISTS (SELECT 1 FROM @P)
    RETURN; 

  BEGIN TRY
    BEGIN TRAN;

    -- creamos encabezados de la factura 
    INSERT INTO dbo.Factura(PropiedadID, FechaEmision, FechaVencimiento, Estado, Total)
    SELECT
      p.PropiedadID,
      @hoy,
      DATEADD(DAY, @diasVenc, @hoy),
      'PENDIENTE',
      0
    FROM @P p LEFT JOIN dbo.Factura f ON f.PropiedadID  = p.PropiedadID AND f.FechaEmision = @hoy
    WHERE f.FacturaID IS NULL; 

    -- 3) Calcular consumo de agua desde la última factura hasta @hoy
    -- ahora calculamos el consumo de agua desde la ultima factura hasta hoy
    ;WITH Ult AS (
      SELECT PropiedadID, MAX(FechaEmision) AS UltFecha FROM dbo.Factura WHERE FechaEmision < @hoy
      GROUP BY PropiedadID),
    Mov AS (SELECT pr.PropiedadID, SUM(CASE mm.Tipo
             WHEN 'LECTURA'    THEN mm.Valor
             WHEN 'INCREMENTO' THEN mm.Valor
             WHEN 'DECREMENTO' THEN -mm.Valor
          END) AS m3
      FROM dbo.Propiedad pr
      JOIN dbo.Medidor md ON md.PropiedadID = pr.PropiedadID
      JOIN dbo.MovimientoMedidor mm ON mm.MedidorID  = md.MedidorID
      LEFT JOIN Ult u ON u.PropiedadID = pr.PropiedadID
      WHERE pr.PropiedadID IN (SELECT PropiedadID FROM @P)
        AND mm.Fecha >  ISNULL(u.UltFecha, '19000101')  -- la ultima factura
        AND mm.Fecha <= @hoy                             -- hoy
      GROUP BY pr.PropiedadID)
    
    -- insertamos el dellate de agua
    INSERT INTO dbo.DetalleFactura(FacturaID, ConceptoID, Cantidad, PrecioUnitario)
    SELECT
      f.FacturaID, cc.ConceptoID,1, CASE
        WHEN ISNULL(m.m3, 0) * @valorM3 < @minAgua THEN @minAgua
        ELSE ISNULL(m.m3, 0) * @valorM3
      END
    FROM dbo.Factura f JOIN @P p ON p.PropiedadID = f.PropiedadID
    JOIN dbo.ConceptoCobro cc ON cc.Codigo = 'AGUA'
    LEFT JOIN Mov m ON m.PropiedadID = f.PropiedadID
    WHERE f.FechaEmision = @hoy
      AND EXISTS (SELECT 1 FROM dbo.Medidor md WHERE md.PropiedadID = f.PropiedadID);


    -- insertamos los cc si aplican
    INSERT INTO dbo.DetalleFactura(FacturaID, ConceptoID, Cantidad, PrecioUnitario)
    SELECT
      f.FacturaID,
      pcc.ConceptoID,
      1,
      0
    FROM dbo.Factura f JOIN @P p ON p.PropiedadID = f.PropiedadID
    JOIN dbo.PropiedadConceptoCobro pcc ON pcc.PropiedadID = f.PropiedadID AND pcc.Activo = 1
    JOIN dbo.ConceptoCobro cc ON cc.ConceptoID = pcc.ConceptoID AND cc.Codigo IN ('IMPUESTO','BASURA','PARQUES')
    WHERE f.FechaEmision = @hoy;

    

    -- recalculamos el total de las facturas emitidas hoy
    ;WITH Totales AS (
      SELECT df.FacturaID, SUM(df.Subtotal) AS TotalNuevo FROM dbo.DetalleFactura df
      JOIN dbo.Factura f ON f.FacturaID = df.FacturaID WHERE f.FechaEmision = @hoy
      GROUP BY df.FacturaID)
    UPDATE f SET f.Total = t.TotalNuevo FROM dbo.Factura f
    JOIN Totales t ON t.FacturaID = f.FacturaID 
    WHERE f.FechaEmision = @hoy;

    COMMIT TRAN;
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW; 
  END CATCH;
END;
GO



----------------------------------------------------------------------------- sp_calcular_intereses_mora
-- recalculamos los intereses para todas las facturas pendientes vencidas antes de hoy
-- el interes es basemonto * tasainteres * meses vencidos

USE TP3_Municipalidad;
GO

CREATE OR ALTER PROCEDURE dbo.sp_calcular_intereses_mora
  @hoy DATE
AS
BEGIN
  SET NOCOUNT ON;

  -- Tasa desde ParametroSistema; si no existe, usamos 2%
  DECLARE @tasa DECIMAL(16,4) = 0.02;

  SELECT @tasa = ISNULL(ValorDecimal, @tasa)
  FROM dbo.ParametroSistema
  WHERE Clave = 'TASA_MORA_MENSUAL';

 
  --  Buscar concepto de cobro para INTERES_MORA
  DECLARE @ccIntereses INT;

  SELECT @ccIntereses = ConceptoID
  FROM dbo.ConceptoCobro
  WHERE Codigo = 'INTERES_MORA';

  IF @ccIntereses IS NULL
  BEGIN
    RAISERROR('No existe el concepto de cobro INTERES_MORA.', 16, 1);
    RETURN;
  END;

  
  -- Calcular meses vencidos y monto base
  DECLARE @calc TABLE (
    FacturaID INT PRIMARY KEY,
    MesesVenc INT,
    BaseMonto DECIMAL(16,2),
    MontoInteres DECIMAL(16,2)
  );

  INSERT INTO @calc(FacturaID, MesesVenc, BaseMonto, MontoInteres)
  SELECT 
      f.FacturaID,
      MesesVenc = DATEDIFF(MONTH, f.FechaVencimiento, @hoy),
      BaseMonto = SUM(
          CASE WHEN df.ConceptoID != @ccIntereses 
               THEN df.Subtotal 
               ELSE 0 
          END
      ),
      MontoInteres = 0
  FROM dbo.Factura f
  JOIN dbo.DetalleFactura df ON df.FacturaID = f.FacturaID
  WHERE f.Estado = 'PENDIENTE'
    AND f.FechaVencimiento < @hoy
  GROUP BY f.FacturaID, f.FechaVencimiento
  HAVING DATEDIFF(MONTH, f.FechaVencimiento, @hoy) > 0;

  -- Calcular interés = base * tasa * meses
  UPDATE c
    SET MontoInteres = ROUND(c.BaseMonto * @tasa * c.MesesVenc, 2)
  FROM @calc c;

  -- Eliminar filas con 0 de interés
  DELETE FROM @calc WHERE MontoInteres <= 0;

  IF NOT EXISTS (SELECT 1 FROM @calc)
    RETURN;


  -- Reemplazar intereses viejos y actualizar total
  BEGIN TRY
    BEGIN TRAN;

    -- Borrar intereses anteriores
    DELETE df
    FROM dbo.DetalleFactura df
    JOIN @calc c ON c.FacturaID = df.FacturaID
    WHERE df.ConceptoID = @ccIntereses;

    -- Insertar intereses nuevos
    INSERT INTO dbo.DetalleFactura(FacturaID, ConceptoID, Cantidad, PrecioUnitario)
    SELECT FacturaID, @ccIntereses, 1, MontoInteres
    FROM @calc;

    -- Recalcular totales
    ;WITH Totales AS (
      SELECT 
          f.FacturaID, 
          TotalNuevo = SUM(df.Subtotal)
      FROM dbo.Factura f
      JOIN dbo.DetalleFactura df ON df.FacturaID = f.FacturaID
      WHERE f.FacturaID IN (SELECT FacturaID FROM @calc)
      GROUP BY f.FacturaID
    )
    UPDATE f
      SET f.Total = t.TotalNuevo
    FROM dbo.Factura f
    JOIN Totales t ON t.FacturaID = f.FacturaID;

    COMMIT TRAN;
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;

    DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@msg, 16, 1);
  END CATCH;
END;
GO

