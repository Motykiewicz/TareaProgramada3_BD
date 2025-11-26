USE TP3_Municipalidad;
GO
-- Inserta movimientos en orden por fecha
INSERT INTO dbo.MovimientoMedidor(MedidorID, Fecha, Tipo, Valor, Delta)
SELECT m.MedidorID,
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
  ON ya.MedidorID=m.MedidorID AND ya.Fecha=s.Fecha
WHERE ya.MovID IS NULL
ORDER BY s.Fecha;


