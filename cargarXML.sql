
USE TP3_Municipalidad;
GO

--------------------------------------------------------------------- sp_cargar_xml_operacion
CREATE OR ALTER PROCEDURE dbo.sp_cargar_xml_operacion
    @dia DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @x XML;
    DECLARE @d XML;

    --------------------------------------------------------------------
    -- 1. Cargar xmlUltimo.xml
    --------------------------------------------------------------------
    SELECT @x = TRY_CONVERT(XML, X.BulkColumn)
    FROM OPENROWSET(
        BULK 'C:\Users\XPC\OneDrive\Desktop\Tarea3BD\xmlUltimo.xml',
        SINGLE_CLOB
    ) AS X;

    IF @x IS NULL
    BEGIN
        RAISERROR('No se pudo cargar xmlUltimo.xml', 16, 1);
        RETURN;
    END;

    --------------------------------------------------------------------
    -- 2. Extraer solo el bloque del día indicado
    --------------------------------------------------------------------
    SELECT @d = @x.query('/Operaciones/FechaOperacion[@fecha=sql:variable("@dia")]');

    IF @d IS NULL OR @d.exist('/FechaOperacion') = 0
    BEGIN
        RAISERROR('No existe bloque FechaOperacion para la fecha indicada.', 16, 1);
        RETURN;
    END;

  
    -- 3. Limpiar tablas staging
    DELETE FROM dbo.st_Pago;
    DELETE FROM dbo.st_MovMedidor;
    DELETE FROM dbo.st_Medidor;
    DELETE FROM dbo.st_CCPropiedad;
    DELETE FROM dbo.st_PropiedadPersona;
    DELETE FROM dbo.st_Propiedad;
    DELETE FROM dbo.st_Persona;

    --------------------------------------------------------------------
    -- 4. PERSONAS
    --------------------------------------------------------------------
    INSERT INTO dbo.st_Persona (Identificacion, Nombre, Email, Telefono1, Telefono2)
    SELECT
        P.value('@valorDocumento','varchar(32)'),
        P.value('@nombre','varchar(128)'),
        P.value('@email','varchar(100)'),
        P.value('@telefono','varchar(20)'),
        NULL
    FROM @d.nodes('/FechaOperacion/Personas/Persona') AS T(P);

    --------------------------------------------------------------------
    -- 5. PROPIEDADES
    --------------------------------------------------------------------
    INSERT INTO dbo.st_Propiedad (Finca, Zona, Uso, FechaRegistro)
    SELECT
        P.value('@numeroFinca','varchar(32)'),
        P.value('@tipoZonaId','varchar(32)'),
        P.value('@tipoUsoId','varchar(32)'),
        P.value('@fechaRegistro','date')
    FROM @d.nodes('/FechaOperacion/Propiedades/Propiedad') AS T(P);

    --------------------------------------------------------------------
    -- 6. PROPIEDAD–PERSONA
    --------------------------------------------------------------------
    INSERT INTO dbo.st_PropiedadPersona (Finca, Identificacion, FechaInicio, FechaFin)
    SELECT
        M.value('@numeroFinca','varchar(32)'),
        M.value('@valorDocumento','varchar(32)'),
        @dia,
        CASE WHEN M.value('@tipoAsociacionId','int') = 2 THEN @dia ELSE NULL END
    FROM @d.nodes('/FechaOperacion/PropiedadPersona/Movimiento') AS T(M)
    WHERE M.value('@tipoAsociacionId','int') IN (1,2);

    --------------------------------------------------------------------
    -- 7. CC PROPIEDAD
    --------------------------------------------------------------------
    INSERT INTO dbo.st_CCPropiedad (Finca, CodigoCC)
    SELECT
        M.value('@numeroFinca','varchar(32)'),
        M.value('@idCC','varchar(32)')
    FROM @d.nodes('/FechaOperacion/CCPropiedad/Movimiento') AS T(M)
    WHERE M.value('@tipoAsociacionId','int') = 1;

       --------------------------------------------------------------------
    -- 8. MEDIDORES  (usando las lecturas para mapear finca  medidor)
    --------------------------------------------------------------------
    INSERT INTO dbo.st_Medidor (Finca, NumSerie)
    SELECT DISTINCT
        X.numeroFinca,
        L.value('@numeroMedidor','varchar(64)') AS NumSerie
    FROM @d.nodes('/FechaOperacion/LecturasMedidor/Lectura') AS L(L)
    OUTER APPLY (
        SELECT P.value('@numeroFinca','varchar(32)') AS numeroFinca
        FROM @d.nodes('/FechaOperacion/Propiedades/Propiedad') AS P(P)
        WHERE P.value('@numeroMedidor','varchar(64)')
              = L.value('@numeroMedidor','varchar(64)')
    ) AS X
    WHERE X.numeroFinca IS NOT NULL;


    --------------------------------------------------------------------
    -- 9. MOVIMIENTOS DE MEDIDOR (LECTURAS)
    --------------------------------------------------------------------
    INSERT INTO dbo.st_MovMedidor (Finca, Fecha, TipoMov, Valor)
    SELECT
        X.numeroFinca,
        @dia AS Fecha,
        L.value('@tipoMovimientoId', 'int')      AS TipoMov,
        L.value('@valor', 'decimal(12,3)')       AS Valor
    FROM @d.nodes('/FechaOperacion/LecturasMedidor/Lectura') AS L(L)
    OUTER APPLY (
        SELECT P.value('@numeroFinca','varchar(32)') AS numeroFinca
        FROM @d.nodes('/FechaOperacion/Propiedades/Propiedad') AS P(P)
        WHERE P.value('@numeroMedidor','varchar(64)')
              = L.value('@numeroMedidor','varchar(64)')
    ) AS X
    WHERE X.numeroFinca IS NOT NULL;

    --------------------------------------------------------------------
    -- 10. PAGOS
    --------------------------------------------------------------------
    INSERT INTO dbo.st_Pago (Finca, Fecha, Monto, Medio, Referencia)
    SELECT
        Pg.value('@numeroFinca','varchar(32)'),
        @dia,
        0.00,
        Pg.value('@tipoMedioPagoId','varchar(32)'),
        Pg.value('@numeroReferencia','varchar(64)')
    FROM @d.nodes('/FechaOperacion/Pagos/Pago') AS T(Pg);
END;
GO

------------------------------------------------------------------------------------------------------------------ sp_cargar_xml_catalogos
-- para cargar todo lo de catalogos a la bd 

USE TP3_Municipalidad;
GO

CREATE OR ALTER PROCEDURE dbo.sp_cargar_xml_catalogos
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @c XML;

    -- Cargar el XML de catálogos
    SELECT @c = TRY_CONVERT(XML, X.BulkColumn)
    FROM OPENROWSET(
        BULK 'C:\Users\XPC\OneDrive\Desktop\Tarea3BD\catalogosV3.xml',
        SINGLE_CLOB
    ) AS X;

    IF @c IS NULL
    BEGIN
        RAISERROR('No se pudo cargar catalogosV3.xml', 16, 1);
        RETURN;
    END;

    ---------------------------
    -- 1. PARAMETROS SISTEMA --
    ---------------------------
    DELETE FROM dbo.ParametroSistema;

    INSERT INTO dbo.ParametroSistema (Clave, ValorEntero, ValorDecimal, ValorTexto)
    SELECT 'DIAS_VENCIMIENTO',
           @c.value('(/Catalogos/ParametrosSistema/DiasVencimientoFactura/text())[1]','int'),
           NULL,
           NULL
    UNION ALL
    SELECT 'DIAS_GRACIA',
           @c.value('(/Catalogos/ParametrosSistema/DiasGraciaCorta/text())[1]','int'),
           NULL,
           NULL
    UNION ALL
    SELECT 'VALOR_M3',
           NULL,
           1000.00,
           NULL
    UNION ALL
    SELECT 'MONTO_MINIMO_AGUA',
           NULL,
           5000.00,
           NULL
    UNION ALL
    SELECT 'CARGO_RECONEXION',
           NULL,
           5000.00,
           NULL;

    -----------------------
    -- 2. CONCEPTO COBRO --
    -----------------------

    -- Tabla temporal con lo que viene del XML
    DECLARE @CC TABLE (
        Codigo       VARCHAR(50),
        Descripcion  VARCHAR(128),
        EsFijo       BIT
    );

    INSERT INTO @CC (Codigo, Descripcion, EsFijo)
    SELECT
        CASE C.value('@nombre','varchar(50)')
            WHEN 'ConsumoAgua'          THEN 'AGUA'
            WHEN 'RecoleccionBasura'    THEN 'BASURA'
            WHEN 'ImpuestoPropiedad'    THEN 'IMPUESTO'
            WHEN 'MantenimientoParques' THEN 'PARQUES'
            WHEN 'ReconexionAgua'       THEN 'RECONEXION'
            WHEN 'InteresesMoratorios'  THEN 'INTERES_MORA'
            WHEN 'PatenteComercial'     THEN 'PatenteComercial'
            ELSE C.value('@nombre','varchar(50)')
        END AS Codigo,
        C.value('@nombre','varchar(128)') AS Descripcion,
        CASE WHEN C.value('@TipoMontoCC','int') = 1 THEN 1 ELSE 0 END AS EsFijo
    FROM @c.nodes('/Catalogos/CCs/CC') AS X(C);

    -- Actualizar conceptos que ya existen
    UPDATE cc
    SET
        cc.Descripcion = x.Descripcion,
        cc.EsFijo      = x.EsFijo
    FROM dbo.ConceptoCobro cc
    JOIN @CC x ON x.Codigo = cc.Codigo;

    --  Insertar conceptos nuevos
    INSERT INTO dbo.ConceptoCobro (Codigo, Descripcion, EsFijo)
    SELECT x.Codigo, x.Descripcion, x.EsFijo
    FROM @CC x
    WHERE NOT EXISTS (SELECT 1 FROM dbo.ConceptoCobro cc WHERE cc.Codigo = x.Codigo
    );

END;
GO
----
