USE TP3_Municipalidad;
GO
-- Emite el día 13 de cada mes (ajusta si tu día objetivo es otro según FechaRegistro)
EXEC dbo.sp_emision_mensual @hoy='2025-06-13';
EXEC dbo.sp_emision_mensual @hoy='2025-07-13';
EXEC dbo.sp_emision_mensual @hoy='2025-08-13';
EXEC dbo.sp_emision_mensual @hoy='2025-09-13';
EXEC dbo.sp_emision_mensual @hoy='2025-10-13';

-- Revisa
SELECT TOP 20 * FROM dbo.Factura ORDER BY FacturaID DESC;
SELECT TOP 50 * FROM dbo.DetalleFactura ORDER BY DetalleID DESC;
