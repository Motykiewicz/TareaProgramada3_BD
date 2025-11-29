USE TP3_Municipalidad;
GO
----------------------------------------------------------------------- sp_procesar_rango_operaciones
-- aqui vamos a ejecutar todo el pipeline por decirlo asi 
-- cargamos todo desde el primer dia hasta el ultimo 
-- utilizando los demas SPs cargamos todo desde el xml, lo guardamos y le aplicamos las operaciones necesarias para que este todo listo 
CREATE OR ALTER PROCEDURE dbo.sp_procesar_rango_operaciones
    @FechaInicio DATE,
    @FechaFin    DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @FechaInicio IS NULL OR @FechaFin IS NULL
    BEGIN
        RAISERROR('Debe indicar @FechaInicio y @FechaFin.', 16, 1);
        RETURN;
    END;
    -- pequenas validaciones 
    IF @FechaFin < @FechaInicio
    BEGIN
        RAISERROR('@FechaFin no puede ser menor que @FechaInicio.', 16, 1);
        RETURN;
    END;

     DECLARE @fechaActual DATE = @FechaInicio;

    WHILE @fechaActual <= @FechaFin
    BEGIN
        PRINT '=== Procesando día ' + CONVERT(varchar(10), @fechaActual, 120) + ' ===';

        
        -- cargamos el xml de operacion para la fecha actual  
       EXEC dbo.sp_cargar_xml_operacion @dia = @fechaActual;

       
        -- aqui pasamos los datos que ingresamos a las tablas intermediarias ( staging) a las tablas finales tablas finales
        
        EXEC dbo.sp_merge_personas;
        EXEC dbo.sp_merge_propiedades;
        EXEC dbo.sp_merge_propiedad_persona;
        EXEC dbo.sp_merge_cc_impuesto;
        EXEC dbo.sp_merge_medidores;
        EXEC dbo.sp_merge_movimientos;
        EXEC dbo.sp_merge_pagos;


       
        -- luego aplicamos los procesos masivos de ese dia 
        EXEC dbo.sp_emision_mensual         @hoy = @fechaActual;
        EXEC dbo.sp_calcular_intereses_mora @hoy = @fechaActual;

        ---------------------------------------------------
        SET @fechaActual = DATEADD(DAY, 1, @fechaActual);
    END;
END;
GO

----------------------------------------------------- para correrlo 
EXEC dbo.sp_procesar_rango_operaciones
     @FechaInicio = '2025-06-01',
     @FechaFin    = '2025-10-31';


------------------------------------------- prueba 
SELECT TOP 20 * FROM Propiedad;
SELECT TOP 20 * FROM Factura ORDER BY FacturaID;
SELECT TOP 20 * FROM Pago ORDER BY PagoID;


