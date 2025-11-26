USE TP3_Municipalidad;
GO

-- JULIO
DECLARE @d DATE = '2025-07-01';
WHILE @d <= '2025-07-31'
BEGIN
    EXEC dbo.sp_emision_mensual @hoy = @d;
    SET @d = DATEADD(DAY, 1, @d);
END;

-- AGOSTO
SET @d = '2025-08-01';
WHILE @d <= '2025-08-31'
BEGIN
    EXEC dbo.sp_emision_mensual @hoy = @d;
    SET @d = DATEADD(DAY, 1, @d);
END;

-- SEPTIEMBRE
SET @d = '2025-09-01';
WHILE @d <= '2025-09-30'
BEGIN
    EXEC dbo.sp_emision_mensual @hoy = @d;
    SET @d = DATEADD(DAY, 1, @d);
END;

-- OCTUBRE
SET @d = '2025-10-01';
WHILE @d <= '2025-10-31'
BEGIN
    EXEC dbo.sp_emision_mensual @hoy = @d;
    SET @d = DATEADD(DAY, 1, @d);
END;
