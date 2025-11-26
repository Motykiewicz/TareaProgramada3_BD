USE TP3_Municipalidad;
GO

-- 1. Conceptos de Cobro (ConceptoCobro)

-- AGUA
IF EXISTS (SELECT 1 FROM dbo.ConceptoCobro WHERE Codigo = 'AGUA')
    UPDATE dbo.ConceptoCobro
       SET Descripcion = N'Consumo de agua',
           EsFijo      = 0
     WHERE Codigo = 'AGUA';
ELSE
    INSERT INTO dbo.ConceptoCobro(Codigo, Descripcion, EsFijo)
    VALUES('AGUA', N'Consumo de agua', 0);

-- IMPUESTO
IF EXISTS (SELECT 1 FROM dbo.ConceptoCobro WHERE Codigo = 'IMPUESTO')
    UPDATE dbo.ConceptoCobro
       SET Descripcion = N'Impuesto a la propiedad',
           EsFijo      = 0
     WHERE Codigo = 'IMPUESTO';
ELSE
    INSERT INTO dbo.ConceptoCobro(Codigo, Descripcion, EsFijo)
    VALUES('IMPUESTO', N'Impuesto a la propiedad', 0);

-- BASURA
IF EXISTS (SELECT 1 FROM dbo.ConceptoCobro WHERE Codigo = 'BASURA')
    UPDATE dbo.ConceptoCobro
       SET Descripcion = N'Recolección de basura',
           EsFijo      = 0
     WHERE Codigo = 'BASURA';
ELSE
    INSERT INTO dbo.ConceptoCobro(Codigo, Descripcion, EsFijo)
    VALUES('BASURA', N'Recolección de basura', 0);

-- PARQUES
IF EXISTS (SELECT 1 FROM dbo.ConceptoCobro WHERE Codigo = 'PARQUES')
    UPDATE dbo.ConceptoCobro
       SET Descripcion = N'Mantenimiento de parques',
           EsFijo      = 0
     WHERE Codigo = 'PARQUES';
ELSE
    INSERT INTO dbo.ConceptoCobro(Codigo, Descripcion, EsFijo)
    VALUES('PARQUES', N'Mantenimiento de parques', 0);

-- RECONEXION
IF EXISTS (SELECT 1 FROM dbo.ConceptoCobro WHERE Codigo = 'RECONEXION')
    UPDATE dbo.ConceptoCobro
       SET Descripcion = N'Cargo por reconexión',
           EsFijo      = 1
     WHERE Codigo = 'RECONEXION';
ELSE
    INSERT INTO dbo.ConceptoCobro(Codigo, Descripcion, EsFijo)
    VALUES('RECONEXION', N'Cargo por reconexión', 1);



-- 2. Parámetros del sistema 
--    Ajustados al catálogo nuevo: Consumo de agua
--    Valor mínimo = 5000, valor por m3 = 1000


-- VALOR_M3  1000 colones por m3
IF EXISTS (SELECT 1 FROM dbo.ParametroSistema WHERE Clave = 'VALOR_M3')
    UPDATE dbo.ParametroSistema
       SET ValorDecimal = CAST(1000.00 AS DECIMAL(14,4)),
           ValorEntero  = NULL,
           ValorTexto   = NULL
     WHERE Clave = 'VALOR_M3';
ELSE
    INSERT INTO dbo.ParametroSistema(Clave, ValorDecimal, ValorEntero, ValorTexto)
    VALUES('VALOR_M3', CAST(1000.00 AS DECIMAL(14,4)), NULL, NULL);

-- MONTO_MINIMO_AGUA  5000 colones mínimo
IF EXISTS (SELECT 1 FROM dbo.ParametroSistema WHERE Clave = 'MONTO_MINIMO_AGUA')
    UPDATE dbo.ParametroSistema
       SET ValorDecimal = CAST(5000.00 AS DECIMAL(14,4)),
           ValorEntero  = NULL,
           ValorTexto   = NULL
     WHERE Clave = 'MONTO_MINIMO_AGUA';
ELSE
    INSERT INTO dbo.ParametroSistema(Clave, ValorDecimal, ValorEntero, ValorTexto)
    VALUES('MONTO_MINIMO_AGUA', CAST(5000.00 AS DECIMAL(14,4)), NULL, NULL);

-- DIAS_VENCIMIENTO 15 días
IF EXISTS (SELECT 1 FROM dbo.ParametroSistema WHERE Clave = 'DIAS_VENCIMIENTO')
    UPDATE dbo.ParametroSistema
       SET ValorDecimal = NULL,
           ValorEntero  = 15,
           ValorTexto   = NULL
     WHERE Clave = 'DIAS_VENCIMIENTO';
ELSE
    INSERT INTO dbo.ParametroSistema(Clave, ValorDecimal, ValorEntero, ValorTexto)
    VALUES('DIAS_VENCIMIENTO', NULL, 15, NULL);

-- CARGO_RECONEXION
IF EXISTS (SELECT 1 FROM dbo.ParametroSistema WHERE Clave = 'CARGO_RECONEXION')
    UPDATE dbo.ParametroSistema
       SET ValorDecimal = CAST(5000.00 AS DECIMAL(14,4)),
           ValorEntero  = NULL,
           ValorTexto   = NULL
     WHERE Clave = 'CARGO_RECONEXION';
ELSE
    INSERT INTO dbo.ParametroSistema(Clave, ValorDecimal, ValorEntero, ValorTexto)
    VALUES('CARGO_RECONEXION', CAST(5000.00 AS DECIMAL(14,4)), NULL, NULL);



-- 3. Verificación rápida
SELECT * FROM dbo.ConceptoCobro ORDER BY Codigo;
SELECT * FROM dbo.ParametroSistema ORDER BY Clave;
