USE TP3_Municipalidad;
GO

CREATE OR ALTER PROCEDURE dbo.sp_merge_pagos
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Pend TABLE(
      RowN INT IDENTITY(1,1) PRIMARY KEY,
      Finca      VARCHAR(32),
      Fecha      DATE,
      Monto      DECIMAL(16,2),
      Medio      VARCHAR(32),
      Referencia VARCHAR(64)
    );

    INSERT INTO @Pend(Finca, Fecha, Monto, Medio, Referencia)
    SELECT Finca, Fecha, Monto, Medio, Referencia
    FROM dbo.st_Pago
    ORDER BY Fecha, Finca, Referencia;

    DECLARE
      @i      INT = 1,
      @maxRow INT,
      @Finca  VARCHAR(32),
      @Fecha  DATE,
      @Monto  DECIMAL(16,2),
      @Medio  VARCHAR(32),
      @Ref    VARCHAR(64);

    SELECT @maxRow = MAX(RowN) FROM @Pend;

    WHILE @i IS NOT NULL AND @i <= ISNULL(@maxRow,0)
    BEGIN
      SELECT
        @Finca = Finca,
        @Fecha = Fecha,
        @Monto = Monto,
        @Medio = Medio,
        @Ref   = Referencia
      FROM @Pend
      WHERE RowN = @i;

      EXEC dbo.sp_procesar_pago
           @Finca = @Finca,
           @Fecha = @Fecha,
           @Monto = @Monto,
           @Medio = @Medio,
           @Ref   = @Ref;

      SET @i += 1;
    END;

    DECLARE @diaProceso DATE;
    SELECT @diaProceso = MIN(Fecha) FROM dbo.st_Pago;

    PRINT 'Pagos registrados en dbo.Pago para el día procesado:';
    SELECT p.PagoID, p.Fecha, p.Monto, p.Medio, p.Referencia
    FROM dbo.Pago p
    WHERE p.Fecha = @diaProceso
    ORDER BY p.PagoID;

    PRINT 'Aplicación de pagos a facturas (PagoFactura) para el día procesado:';
    SELECT pf.PagoID, pf.FacturaID, pf.MontoAplicado,
           p.Fecha, p.Referencia, pr.Finca
    FROM dbo.PagoFactura pf
    JOIN dbo.Pago      p  ON p.PagoID      = pf.PagoID
    JOIN dbo.Factura   f  ON f.FacturaID   = pf.FacturaID
    JOIN dbo.Propiedad pr ON pr.PropiedadID = f.PropiedadID
    WHERE p.Fecha = @diaProceso
    ORDER BY pf.PagoID, pf.FacturaID;
END
GO

