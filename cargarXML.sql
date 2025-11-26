USE TP3_Municipalidad;
GO

/* 
   cargarXML_por_dia.sql 
   aqui vamos a cargar, para un @dia específico, los datos del archivo xmlUltimo.xml a las tablas st_*.
*/

DECLARE @dia date = '2025-06-01';   -- aqui podemos cambiar el dia a procesar (2025-07-08) para pagos (2025-06-01) para personas y propiedades
DECLARE @x   xml;
DECLARE @d   xml;

-- 1) Cargar el XML completo en @x
SELECT @x = TRY_CONVERT(xml, X.BulkColumn)
FROM OPENROWSET(
  BULK 'C:\Users\XPC\OneDrive\Desktop\Tarea3BD\xmlUltimo.xml',
  SINGLE_CLOB
) AS X;

IF @x IS NULL
BEGIN
  RAISERROR('No se pudo cargar xmlUltimo.xml.', 16, 1);
  RETURN;
END;

-- extraer SOLO el bloque de ese día
SELECT @d = @x.query('/Operaciones/FechaOperacion[@fecha=sql:variable("@dia")]');

IF @d IS NULL OR @d.exist('/FechaOperacion') = 0
BEGIN
  RAISERROR('No hay bloque <FechaOperacion> para la fecha indicada en el XML.', 16, 1);
  RETURN;
END;

-- revisar que debería ser 1
SELECT COUNT(*) AS BloquesEseDia
FROM   @d.nodes('/FechaOperacion') AS T(B);

--  Limpiar tablas st
DELETE FROM st_Pago;
DELETE FROM st_MovMedidor;
DELETE FROM st_Medidor;
DELETE FROM st_CCPropiedad;
DELETE FROM st_PropiedadPersona;
DELETE FROM st_Propiedad;
DELETE FROM st_Persona;

-- Cargar tablas st desde @d ( las rutas alineadas al XML 



-- Personas: valorDocumento, nombre, email y telefono
INSERT INTO st_Persona (Identificacion, Nombre, Email, Telefono1, Telefono2)
SELECT
    P.value('@valorDocumento', 'varchar(32)'),
    P.value('@nombre',         'varchar(128)'),
    P.value('@email',          'varchar(100)'),
    P.value('@telefono',       'varchar(20)'),
    NULL  -- no sale un segundo telefono en el xml asi que se queda null 
FROM @d.nodes('/FechaOperacion/Personas/Persona') AS T(P);


-- Propiedades: numeroFinca, tipoZonaId, tipoUsoId, fechaRegistro
INSERT INTO st_Propiedad (Finca, Zona, Uso, FechaRegistro)
SELECT P.value('@numeroFinca',   'varchar(32)'),
       P.value('@tipoZonaId',    'varchar(32)'),   -- de momento guardamos el id
       P.value('@tipoUsoId',     'varchar(32)'),   -- idem, luego puedes mapearlo a texto
       P.value('@fechaRegistro', 'date')
FROM   @d.nodes('/FechaOperacion/Propiedades/Propiedad') AS T(P);

-- Relación Propiedad–Persona:
-- Movimiento valorDocumento + numeroFinca, usamos @dia como FechaInicio
INSERT INTO st_PropiedadPersona (Finca, Identificacion, FechaInicio, FechaFin)
SELECT M.value('@numeroFinca',    'varchar(32)'),
       M.value('@valorDocumento', 'varchar(32)'),
       @dia,
       NULL
FROM   @d.nodes('/FechaOperacion/PropiedadPersona/Movimiento') AS T(M)
WHERE  M.value('@tipoAsociacionId','int') = 1;  -- solo Asociar en staging

-- Conceptos de cobro explícitos en XML (ej. IMPUESTO)
INSERT INTO st_CCPropiedad (Finca, CodigoCC)
SELECT M.value('@numeroFinca', 'varchar(32)'),
       M.value('@idCC',        'varchar(32)')
FROM   @d.nodes('/FechaOperacion/CCPropiedad/Movimiento') AS T(M)
WHERE  M.value('@tipoAsociacionId','int') = 1;  -- Asociar

-- Medidores: los sacamos de Propiedades (numeroFinca + numeroMedidor)
INSERT INTO st_Medidor (Finca, NumSerie)
SELECT P.value('@numeroFinca',   'varchar(32)'),
       P.value('@numeroMedidor', 'varchar(64)')
FROM   @d.nodes('/FechaOperacion/Propiedades/Propiedad') AS T(P)
WHERE  P.value('@numeroMedidor','varchar(64)') IS NOT NULL;

-- Movimientos de medidor:
-- Lectura solo trae numeroMedidor, la finca se obtiene cruzando con Propiedades
INSERT INTO st_MovMedidor (Finca, Fecha, TipoMov, Valor)
SELECT P.value('@numeroFinca',          'varchar(32)') AS Finca,
       @dia                              AS Fecha,
       L.value('@tipoMovimientoId',     'int')         AS TipoMov,
       L.value('@valor',                'decimal(12,3)') AS Valor
FROM   @d.nodes('/FechaOperacion/LecturasMedidor/Lectura') AS L(L)
CROSS APPLY @d.nodes('/FechaOperacion/Propiedades/Propiedad') AS P(P)
WHERE  P.value('@numeroMedidor','varchar(32)') = L.value('@numeroMedidor','varchar(32)');

-- Pagos: numeroFinca, tipoMedioPagoId, numeroReferencia
-- como el XML no trae monto ponemos un monto 0 de momento
INSERT INTO st_Pago (Finca, Fecha, Monto, Medio, Referencia)
SELECT Pg.value('@numeroFinca',      'varchar(32)'),
       @dia,
       0.00,  -- monto dummy; luego en sp_procesar_pago puedes interpretar 0 como "pagar todo"
       Pg.value('@tipoMedioPagoId',  'varchar(32)'),
       Pg.value('@numeroReferencia', 'varchar(64)')
FROM   @d.nodes('/FechaOperacion/Pagos/Pago') AS T(Pg);

SELECT TOP 10 * FROM st_Persona;
