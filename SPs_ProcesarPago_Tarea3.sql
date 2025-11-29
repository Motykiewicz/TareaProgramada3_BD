USE TP3_Municipalidad;
GO

CREATE OR ALTER PROCEDURE dbo.sp_procesar_pago
    @Finca      VARCHAR(32),      -- numero de finca
    @Fecha      DATE,             -- fecha del pago (día de operación)
    @Monto      DECIMAL(16,2),    -- monto enviado (0 es que ya pagó todo)
    @Medio      VARCHAR(32) = NULL,
    @Ref        VARCHAR(64) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE 
        @PropiedadID      INT,
        @FacturaID        INT,
        @FechaVencimiento DATE,
        @TotalFactura     DECIMAL(16,2),
        @PagoID           INT,
        @MontoPago        DECIMAL(16,2),
        @msg              NVARCHAR(400);

    
    -- validamos la finca y optenemos el id de la propiedad 
    SELECT @PropiedadID = PropiedadID
    FROM dbo.Propiedad
    WHERE Finca = @Finca;

    IF @PropiedadID IS NULL
    BEGIN
        SET @msg = 'No existe la finca ' + ISNULL(@Finca, '(NULL)'); 
        RAISERROR(@msg, 16, 1);
        RETURN;
    END;

   
    -- buscamos la factura pendiente mas vieja de la propiedad 
    SELECT TOP (1)
        @FacturaID        = f.FacturaID,
        @FechaVencimiento = f.FechaVencimiento,
        @TotalFactura     = f.Total
    FROM dbo.Factura f
    WHERE f.PropiedadID = @PropiedadID
      AND f.Estado      = 'PENDIENTE'
    ORDER BY f.FechaEmision;  -- la mas vieja

    IF @FacturaID IS NULL
    BEGIN
        SET @msg = 'La finca ' + ISNULL(@Finca, '(NULL)') 
                 + ' no tiene facturas pendientes.';
        RAISERROR(@msg, 16, 1);
        RETURN;
    END;

    
    -- ajustamos el monto:
    --  si viene NULL o <= 0  se interpreta como "pagar todo".
    --    y tampoco No se permiten pagos parciales (monto < total).
   
    SET @MontoPago = ISNULL(@Monto, 0);

    IF @MontoPago <= 0
        SET @MontoPago = @TotalFactura;   -- pagar el total de la factura

    IF @MontoPago < @TotalFactura
    BEGIN
        SET @msg = 'El monto enviado (' 
                 + CONVERT(varchar(30), @MontoPago) + ') es menor que el total de la factura (' + CONVERT(varchar(30), @TotalFactura) + '). No se admiten pagos parciales.';
        RAISERROR(@msg, 16, 1);
        RETURN;
    END;

    
    -- registramos el pago y lo aplicamos a la factura 
    BEGIN TRY
        BEGIN TRAN;

        -- Valores por defecto seguros para medio y referencia
        SET @Medio = LEFT(ISNULL(@Medio, 'SIN_MEDIO'), 32);
        SET @Ref   = LEFT(ISNULL(@Ref,   'SIN_REFERENCIA'), 64);

        INSERT INTO dbo.Pago (Fecha, Monto, Medio, Referencia)
        VALUES (@Fecha, @MontoPago, @Medio, @Ref);

        SET @PagoID = SCOPE_IDENTITY();

        INSERT INTO dbo.PagoFactura (PagoID, FacturaID, MontoAplicado)
        VALUES (@PagoID, @FacturaID, @TotalFactura);

        UPDATE dbo.Factura
        SET Estado = 'PAGADA'
        WHERE FacturaID = @FacturaID;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        SET @msg = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
        RETURN;
    END CATCH;
END;
GO
