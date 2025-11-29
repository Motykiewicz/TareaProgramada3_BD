USE TP3_Municipalidad;
GO


--------------------------------------- merge personas
CREATE OR ALTER PROCEDURE dbo.sp_merge_personas
AS
BEGIN
    SET NOCOUNT ON;

    -- 1) Insertar personas NUEVAS
    INSERT INTO dbo.Persona(Identificacion, Nombre, Email, Telefono1, Telefono2)
    SELECT
        s.Identificacion,
        s.Nombre,
        s.Email,
        s.Telefono1,
        NULL   -- nadie viene con segundo telefono entonces siempre NULL
    FROM dbo.st_Persona s LEFT JOIN dbo.Persona p ON p.Identificacion = s.Identificacion
    WHERE p.PersonaID IS NULL;

    -- 2) Actualizamos las personas ya existentes 
    UPDATE p
    SET
        p.Nombre = s.Nombre,
        p.Email = s.Email,
        p.Telefono1 = s.Telefono1
    FROM dbo.Persona p JOIN dbo.st_Persona s ON p.Identificacion = s.Identificacion;
END;
GO




--------------------------------------- merge propiedades
USE TP3_Municipalidad;
GO

CREATE OR ALTER PROCEDURE dbo.sp_merge_propiedades
AS
BEGIN
    SET NOCOUNT ON;

    -- Inserta propiedades nuevas por Finca
    INSERT INTO dbo.Propiedad(Finca, Zona, Uso, FechaRegistro, EstadoServicioAgua, M3Acumulados, M3AcumuladosUltimaFactura)
    SELECT s.Finca, s.Zona, s.Uso, s.FechaRegistro, 'ACTIVO', 0, 0
    FROM dbo.st_Propiedad s LEFT JOIN dbo.Propiedad p ON p.Finca = s.Finca
    WHERE p.PropiedadID IS NULL;

    -- Actualizamos los datos si ya existían
    UPDATE p
    SET p.Zona = s.Zona,
        p.Uso  = s.Uso,
        p.FechaRegistro = s.FechaRegistro
    FROM dbo.Propiedad p
    JOIN dbo.st_Propiedad s ON s.Finca = p.Finca;
END;
GO




--------------------------------------- merge propiedad - persona
USE TP3_Municipalidad;
GO

CREATE OR ALTER PROCEDURE dbo.sp_merge_propiedad_persona
AS
BEGIN
    SET NOCOUNT ON;

    -- empezamos cerrando las relaciones abiertas
    UPDATE pp
    SET FechaFin = s.FechaInicio
    FROM dbo.PropiedadPersona pp JOIN dbo.Propiedad p  ON p.PropiedadID = pp.PropiedadID
    LEFT JOIN dbo.st_PropiedadPersona s ON s.Finca = p.Finca AND s.Identificacion = (
            SELECT TOP (1) sp.Identificacion
            FROM dbo.st_PropiedadPersona sp
            WHERE sp.Finca = p.Finca
            ORDER BY sp.FechaInicio DESC
           )
    WHERE pp.FechaFin IS NULL  AND (s.Identificacion IS NULL OR NOT EXISTS (
          SELECT 1 FROM dbo.PropiedadPersona x
          WHERE x.PropiedadID = pp.PropiedadID AND x.PersonaID = pp.PersonaID 
          AND x.FechaInicio = pp.FechaInicio
          AND x.FechaFin IS NULL
            )
          );

    -- creamos la relacion vigente segun las tablas intermediarias (staging) 
    INSERT INTO dbo.PropiedadPersona(PropiedadID, PersonaID, FechaInicio, FechaFin)
    SELECT  p.PropiedadID,
            pe.PersonaID,
            s.FechaInicio,
            s.FechaFin
    FROM dbo.st_PropiedadPersona s
    JOIN dbo.Propiedad p   ON p.Finca           = s.Finca
    JOIN dbo.Persona  pe   ON pe.Identificacion = s.Identificacion
    LEFT JOIN dbo.PropiedadPersona pp
       ON pp.PropiedadID = p.PropiedadID
      AND pp.PersonaID   = pe.PersonaID
      AND pp.FechaInicio = s.FechaInicio
    WHERE pp.PropiedadID IS NULL;  -- evita duplicar la relación
END;
GO



--------------------------------------- merge conceptocobro - impuesto 
USE TP3_Municipalidad;
GO

CREATE OR ALTER PROCEDURE dbo.sp_merge_cc_impuesto
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.PropiedadConceptoCobro(PropiedadID,ConceptoID,Activo)
    SELECT p.PropiedadID, cc.ConceptoID, 1
    FROM st_CCPropiedad s
    JOIN dbo.Propiedad p ON p.Finca = s.Finca
    JOIN dbo.ConceptoCobro cc ON cc.Codigo = s.CodigoCC
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.PropiedadConceptoCobro pc
        WHERE pc.PropiedadID = p.PropiedadID
          AND pc.ConceptoID  = cc.ConceptoID
    );
END;
GO




--------------------------------------- merge medidores
USE TP3_Municipalidad;
GO

CREATE OR ALTER PROCEDURE dbo.sp_merge_medidores
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Medidor(PropiedadID, Activo)
    SELECT p.PropiedadID, 1
    FROM dbo.Propiedad p
    LEFT JOIN dbo.Medidor m   ON m.PropiedadID = p.PropiedadID
    JOIN dbo.st_Medidor sm    ON sm.Finca      = p.Finca
    WHERE m.MedidorID IS NULL;
END;
GO






--------------------------------------- merge movimientos
USE TP3_Municipalidad;
GO

CREATE OR ALTER PROCEDURE dbo.sp_merge_movimientos
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.MovimientoMedidor(MedidorID, Fecha, Tipo, Valor, Delta)
    SELECT 
        m.MedidorID,
        s.Fecha,
        CASE s.TipoMov
            WHEN 1 THEN 'LECTURA'
            WHEN 2 THEN 'INCREMENTO'
            WHEN 3 THEN 'DECREMENTO'
        END,
        s.Valor,
        NULL
    FROM dbo.st_MovMedidor s
    JOIN dbo.Propiedad p ON p.Finca = s.Finca
    JOIN dbo.Medidor   m ON m.PropiedadID = p.PropiedadID
    LEFT JOIN dbo.MovimientoMedidor ya 
        ON ya.MedidorID = m.MedidorID
       AND CONVERT(date, ya.Fecha) = s.Fecha
    WHERE ya.MovID IS NULL
    ORDER BY s.Fecha;
END;
GO





------------------------------------------------------------- merge pagos
USE TP3_Municipalidad;
GO

CREATE OR ALTER PROCEDURE dbo.sp_merge_pagos
AS
BEGIN
    SET NOCOUNT ON;

    -- Si no hay nada en st_Pago, no hacemos nada
    IF NOT EXISTS (SELECT 1 FROM dbo.st_Pago)
        RETURN;

    -- si si hay datos entonces primero cargamos los datos de st_pago a una la tabla temporal
    DECLARE @Pend TABLE(
        RowN INT IDENTITY(1,1) PRIMARY KEY,
        Finca VARCHAR(32),
        Fecha DATE,
        Monto DECIMAL(16,2),
        Medio VARCHAR(32),
        Referencia VARCHAR(64)
    );

    INSERT INTO @Pend(Finca, Fecha, Monto, Medio, Referencia)
    SELECT s.Finca,
           s.Fecha,
           s.Monto,
           s.Medio,
           s.Referencia
    FROM dbo.st_Pago s

    -- Evitar reprocesar el mismo pago si ya existe un Pago con misma finca+fecha+ref+monto
    LEFT JOIN dbo.Pago p ON p.Fecha = s.Fecha
          AND p.Monto = s.Monto
          AND p.Referencia = s.Referencia
    WHERE p.PagoID IS NULL     
    ORDER BY s.Fecha, s.Finca, s.Referencia;

    DECLARE
        @i      INT,
        @maxRow INT,
        @Finca  VARCHAR(32),
        @Fecha  DATE,
        @Monto  DECIMAL(16,2),
        @Medio  VARCHAR(32),
        @Ref    VARCHAR(64);

    SELECT @maxRow = MAX(RowN) FROM @Pend;
    SET @i = 1;

    -- ok ya que tenemos eso podemos ir recorriendo uno por uno aumentanto @i y llamando sp_procesar_pago 
    WHILE @i IS NOT NULL AND @i <= ISNULL(@maxRow, 0)
    BEGIN
        SELECT
            @Finca = Finca,
            @Fecha = Fecha,
            @Monto = Monto,
            @Medio = Medio,
            @Ref   = Referencia
        FROM @Pend
        WHERE RowN = @i;

        BEGIN TRY
            EXEC dbo.sp_procesar_pago
                 @Finca = @Finca,
                 @Fecha = @Fecha,
                 @Monto = @Monto,
                 @Medio = @Medio,
                 @Ref   = @Ref;
        END TRY
        BEGIN CATCH
            -- Si algo falla con un pago, lo reportamos y seguimos con el siguiente para no quedarnos estancados
            PRINT 'Error procesando pago XML: Finca=' + ISNULL(@Finca,'(NULL)')
                + ' Fecha=' + CONVERT(varchar(10), @Fecha, 120)
                + ' Ref=' + ISNULL(@Ref,'(NULL)')
                + ' Msg=' + ERROR_MESSAGE();
        END CATCH;

        SET @i += 1; -- vamos con el siguiente 
    END;

    -- finalmente generamos el resumen del final del dia
    DECLARE @diaProceso DATE;
    SELECT @diaProceso = MIN(Fecha) FROM dbo.st_Pago;

    IF @diaProceso IS NOT NULL
    BEGIN
        PRINT 'Pagos registrados en dbo.Pago para el día procesado:';
        SELECT p.PagoID, p.Fecha, p.Monto, p.Medio, p.Referencia
        FROM dbo.Pago p WHERE p.Fecha = @diaProceso
        ORDER BY p.PagoID;

        PRINT 'Aplicación de pagos a facturas (PagoFactura) para el día procesado:';
        SELECT pf.PagoID, pf.FacturaID, pf.MontoAplicado, p.Fecha, p.Referencia, pr.Finca
        FROM dbo.PagoFactura pf
        JOIN dbo.Pago p ON p.PagoID = pf.PagoID
        JOIN dbo.Factura f ON f.FacturaID = pf.FacturaID
        JOIN dbo.Propiedad pr ON pr.PropiedadID = f.PropiedadID
        WHERE p.Fecha = @diaProceso
        ORDER BY pf.PagoID, pf.FacturaID;
    END;
END;
GO

