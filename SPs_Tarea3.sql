USE TP3_Municipalidad;
GO
CREATE OR ALTER PROCEDURE dbo.sp_emision_mensual
  @hoy DATE
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @diasVenc INT = (SELECT ValorEntero  FROM ParametroSistema WHERE Clave='DIAS_VENCIMIENTO');
  DECLARE @valorM3  DECIMAL(16,4)= ISNULL((SELECT ValorDecimal FROM ParametroSistema WHERE Clave='VALOR_M3'),0);
  DECLARE @minAgua  DECIMAL(16,4)= ISNULL((SELECT ValorDecimal FROM ParametroSistema WHERE Clave='MONTO_MINIMO_AGUA'),0);

    -- para el dia objetivo
    DECLARE @diaObjetivo INT = CASE
        WHEN DAY(@hoy) > DAY(EOMONTH(@hoy)) THEN DAY(EOMONTH(@hoy))
        ELSE DAY(@hoy) END;

    -- P para las propiedades que facturan hoy
    DECLARE @P TABLE (PropiedadID INT PRIMARY KEY);
    INSERT INTO @P(PropiedadID)
    SELECT PropiedadID
    FROM dbo.Propiedad
    WHERE DAY(FechaRegistro) = @diaObjetivo;

    BEGIN TRY
       BEGIN TRAN;

    -- si la propiedad factura hoy, creamos la cabecera de la factura 
    INSERT INTO dbo.Factura(PropiedadID, FechaEmision, FechaVencimiento, Estado, Total)
    SELECT p.PropiedadID, @hoy, DATEADD(DAY,@diasVenc,@hoy), 'PENDIENTE', 0
    FROM @P p;

    --  calculamos el consumo de agua del periodo desde última factura (exclusiva) hasta hoy (inclusiva)
    ;WITH Ult AS (
      SELECT PropiedadID, MAX(FechaEmision) AS UltFecha
      FROM Factura
      WHERE FechaEmision < @hoy
      GROUP BY PropiedadID
    ),

    Mov AS (
          SELECT pr.PropiedadID,
                 SUM(CASE mm.Tipo
                       WHEN 'LECTURA'    THEN mm.Valor
                       WHEN 'INCREMENTO' THEN mm.Valor
                       WHEN 'DECREMENTO' THEN -mm.Valor
                     END) AS m3
          FROM dbo.Propiedad pr
          JOIN dbo.Medidor md ON md.PropiedadID = pr.PropiedadID
          JOIN dbo.MovimientoMedidor mm ON mm.MedidorID = md.MedidorID
          LEFT JOIN Ult u ON u.PropiedadID = pr.PropiedadID
          WHERE pr.PropiedadID IN (SELECT PropiedadID FROM @P)
            AND mm.Fecha > ISNULL(u.UltFecha, '19000101')
            AND mm.Fecha <= @hoy
          GROUP BY pr.PropiedadID
        )

    -- Insertamos en la factura todo los del agua, precio y cantidad 
        INSERT INTO dbo.DetalleFactura(FacturaID, ConceptoID, Cantidad, PrecioUnitario)
    SELECT f.FacturaID, cc.ConceptoID, 1,
           CASE WHEN ISNULL(m.m3,0)*@valorM3 < @minAgua
                THEN @minAgua
                ELSE ISNULL(m.m3,0)*@valorM3
           END

    FROM dbo.Factura f
    JOIN @P p ON p.PropiedadID = f.PropiedadID
    JOIN dbo.ConceptoCobro cc ON cc.Codigo='AGUA'
    LEFT JOIN Mov m ON m.PropiedadID = f.PropiedadID
    WHERE f.FechaEmision = @hoy
        AND EXISTS (SELECT 1 FROM dbo.Medidor md WHERE md.PropiedadID = f.PropiedadID);


    --  Luego agregamos los otros conceptos con PrecioUnitario=0 por ahora (impuesto, basura y parques) 
    INSERT INTO dbo.DetalleFactura(FacturaID, ConceptoID, Cantidad, PrecioUnitario)
    SELECT f.FacturaID, pcc.ConceptoID, 1, 0
    FROM dbo.Factura f
    JOIN @P p ON p.PropiedadID = f.PropiedadID
    JOIN dbo.PropiedadConceptoCobro pcc ON pcc.PropiedadID=f.PropiedadID AND pcc.Activo=1
    JOIN dbo.ConceptoCobro cc ON cc.ConceptoID=pcc.ConceptoID AND cc.Codigo IN ('IMPUESTO','BASURA','PARQUES')
    WHERE f.FechaEmision = @hoy;


    -- recalculamos el total de la factura 
    UPDATE f
      SET f.Total = dt.SumSubtotal
    FROM dbo.Factura f
    JOIN (SELECT FacturaID, SUM(Subtotal) AS SumSubtotal
          FROM dbo.DetalleFactura GROUP BY FacturaID) dt
      ON dt.FacturaID = f.FacturaID
    WHERE f.FechaEmision = @hoy;

    COMMIT;

END TRY
BEGIN CATCH
  IF @@TRANCOUNT > 0 ROLLBACK;  
  THROW;                        
END CATCH

END
GO

-- pequena prueba a ver si todo sirve
SELECT PropiedadID, Finca, FechaRegistro, DAY(FechaRegistro) Dia FROM Propiedad;

EXEC dbo.sp_emision_mensual @hoy = '2025-06-13';

SELECT TOP 20 * FROM Factura ORDER BY FacturaID DESC;
SELECT TOP 50 * FROM DetalleFactura ORDER BY DetalleID DESC;

SELECT p.PropiedadID, p.Finca, m.MedidorID
FROM Propiedad p
LEFT JOIN Medidor m ON m.PropiedadID = p.PropiedadID
WHERE p.Finca IN ('FincaRuralAgricola','FincaUrbanaResidencial');

-- ver si se adjunto agua
SELECT f.FacturaID, p.Finca, cc.Codigo, d.PrecioUnitario, d.Subtotal
FROM Factura f
JOIN Propiedad p ON p.PropiedadID=f.PropiedadID
JOIN DetalleFactura d ON d.FacturaID=f.FacturaID
JOIN ConceptoCobro cc ON cc.ConceptoID=d.ConceptoID
WHERE f.FechaEmision='2025-06-13'
ORDER BY f.FacturaID, d.DetalleID;