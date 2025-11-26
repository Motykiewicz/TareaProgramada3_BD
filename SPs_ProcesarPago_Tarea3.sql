USE TP3_Municipalidad;
GO

CREATE OR ALTER PROCEDURE dbo.sp_procesar_pago
    @Finca      VARCHAR(32),
    @Fecha      DATE,
    @Monto      DECIMAL(16,2),
    @Medio      VARCHAR(32) = NULL,
    @Ref        VARCHAR(64) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PropiedadID        INT;
    DECLARE @FacturaID          INT;
    DECLARE @FechaVencimiento   DATE;
    DECLARE @TotalFactura       DECIMAL(16,2);
    DECLARE @PagoID             INT;

    DECLARE @ConceptoInteresID  INT;
    DECLARE @MontoBase          DECIMAL(16,2);
    DECLARE @MesesAtraso        INT;
    DECLARE @InteresMensual     DECIMAL(16,2);
    DECLARE @InteresTotal       DECIMAL(16,2);
    DECLARE @TasaInteres        DECIMAL(9,4);

    -- Tasa de interés: desde ParametroSistema o 2% por defecto
    
    SELECT @TasaInteres = ValorDecimal
    FROM dbo.ParametroSistema
    WHERE Clave = 'TASA_INTERES_MENSUAL';

    IF @TasaInteres IS NULL
        SET @TasaInteres = 0.02;   -- 2% mensual


    
    -- Buscamos la propiedad por número de finca
    SELECT @PropiedadID = PropiedadID
    FROM dbo.Propiedad
    WHERE Finca = @Finca;

    IF @PropiedadID IS NULL
    BEGIN
        PRINT 'No existe la finca ' + ISNULL(@Finca, '(NULL)');
        RETURN;
    END;

    
    -- 3) Buscamos la factura PENDIENTE más vieja de esa propiedad
    SELECT TOP (1)
        @FacturaID        = f.FacturaID,
        @FechaVencimiento = f.FechaVencimiento,
        @TotalFactura     = f.Total
    FROM dbo.Factura f
    WHERE f.PropiedadID = @PropiedadID
      AND f.Estado      = 'PENDIENTE'
    ORDER BY f.FechaEmision;  -- la más antigua

    IF @FacturaID IS NULL
    BEGIN
        PRINT 'La finca ' + @Finca + ' no tiene facturas pendientes.';
        RETURN;
    END;

    -- Si la factura está vencida, calcular intereses moratorios
    -- Interés = MontoBase * Tasa * MesesAtraso
    
    IF @Fecha > @FechaVencimiento
    BEGIN
        -- Meses de atraso (al menos 1 si ya se paso de la fecha)
        SET @MesesAtraso = DATEDIFF(MONTH, @FechaVencimiento, @Fecha);
        IF @MesesAtraso < 1 SET @MesesAtraso = 1;

        -- Monto base: suma de todos los conceptos que NO son INTERESES
        SELECT @MontoBase = SUM(df.Subtotal)
        FROM dbo.DetalleFactura df
        JOIN dbo.ConceptoCobro cc ON cc.ConceptoID = df.ConceptoID
        WHERE df.FacturaID = @FacturaID
          AND cc.Codigo != 'INTERESES';   -- excluimos intereses

        IF @MontoBase IS NULL SET @MontoBase = 0;

        IF @MontoBase > 0
        BEGIN
            -- Buscar el ConceptoID para INTERESES
            SELECT @ConceptoInteresID = ConceptoID
            FROM dbo.ConceptoCobro
            WHERE Codigo = 'INTERESES';

            IF @ConceptoInteresID IS NULL
            BEGIN
                PRINT 'No existe el concepto de cobro INTERESES; no se calcularon intereses.';
            END
            ELSE
            BEGIN
                -- Interés mensual sobre el monto base
                SET @InteresMensual = ROUND(@MontoBase * @TasaInteres, 2);
                -- Interés total según meses de atraso
                SET @InteresTotal   = @InteresMensual * @MesesAtraso;

                -- Insertar detalle de intereses: cantidad = meses de atraso,
                -- precio unitario = interés mensual.
                INSERT INTO dbo.DetalleFactura(FacturaID, ConceptoID, Cantidad, PrecioUnitario)
                VALUES(@FacturaID, @ConceptoInteresID, @MesesAtraso, @InteresMensual);

                -- Recalcular el total de la factura según todos los detalles
                SELECT @TotalFactura = SUM(Subtotal)
                FROM dbo.DetalleFactura
                WHERE FacturaID = @FacturaID;

                UPDATE dbo.Factura
                SET Total = @TotalFactura
                WHERE FacturaID = @FacturaID;
            END
        END
    END

    -- Registramos el pago en la tabla Pago
    
    INSERT INTO dbo.Pago(Fecha, Monto, Medio, Referencia)
    VALUES(@Fecha, @Monto, @Medio, @Ref);

    SET @PagoID = SCOPE_IDENTITY();

    --  Aplicamos el pago a la factura
    --  asumimos que @Monto >= @TotalFactura
    INSERT INTO dbo.PagoFactura(PagoID, FacturaID, MontoAplicado)
    VALUES(@PagoID, @FacturaID, @TotalFactura);


    -- por ultimo marcamos la factura como pagada
    UPDATE dbo.Factura
    SET Estado = 'PAGADO'
    WHERE FacturaID = @FacturaID;
END
GO

USE TP3_Municipalidad;
GO

-- 1. Buscar una factura PENDIENTE ya emitida, de cualquier finca de pruebas
SELECT TOP 1
       f.FacturaID, p.Finca, f.Total, f.FechaEmision, f.FechaVencimiento, f.Estado
FROM dbo.Factura f
JOIN dbo.Propiedad p ON p.PropiedadID = f.PropiedadID
WHERE f.Estado = 'PENDIENTE'
ORDER BY f.FechaEmision;


EXEC dbo.sp_procesar_pago
    @Finca = 'F-0002',        -- la finca que te salió
    @Fecha = '2025-10-22',    -- fecha de pago bien posterior a la vencida
    @Monto = 0,               -- 0 = que pague todo el saldo
    @Medio = '1',
    @Ref   = 'TEST-INTERES';

SELECT f.FacturaID, p.Finca, f.FechaEmision, f.FechaVencimiento,
       df.Cantidad, df.PrecioUnitario, df.Subtotal AS InteresCobrado,
       f.Total
FROM dbo.Factura f
JOIN dbo.Propiedad p      ON p.PropiedadID = f.PropiedadID
JOIN dbo.DetalleFactura df ON df.FacturaID = f.FacturaID
JOIN dbo.ConceptoCobro cc ON cc.ConceptoID = df.ConceptoID
WHERE cc.Codigo = 'INTERESES'
ORDER BY f.FechaEmision;
