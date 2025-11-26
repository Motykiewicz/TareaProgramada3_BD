USE TP3_Municipalidad;
GO
-- Limpieza simple 
DELETE FROM st_Pago; DELETE FROM st_MovMedidor; DELETE FROM st_Medidor;
DELETE FROM st_CCPropiedad; DELETE FROM st_PropiedadPersona;
DELETE FROM st_Propiedad; DELETE FROM st_Persona;

-- PERSONAS 
INSERT INTO st_Persona(Identificacion,Nombre) VALUES
('10101010','Ana Solís'),
('20202020','Luis Mora');

-- PROPIEDADES (incluye las que pide el profe para validar)
INSERT INTO st_Propiedad(Finca,Zona,Uso,FechaRegistro) VALUES
('F-0007','urbana','residencial','2025-06-13'),
('F-0021','urbana','comercial','2025-07-03'),
('F-0048','rural','residencial','2025-08-05'),
('F-0013','urbana','industrial','2025-10-01'),
('F-0034','urbana','residencial','2025-10-03');

-- RELACIÓN PROPIEDAD–PERSONA (vigencia)
INSERT INTO st_PropiedadPersona(Finca,Identificacion,FechaInicio,FechaFin) VALUES
('F-0007','10101010','2025-06-13',NULL),
('F-0021','20202020','2025-07-03',NULL),
('F-0048','10101010','2025-08-05',NULL),
('F-0013','20202020','2025-10-01',NULL),
('F-0034','10101010','2025-10-03',NULL);

-- CC IMPUESTO explícito (opcional si ya viene del XML)
INSERT INTO st_CCPropiedad(Finca,CodigoCC) VALUES
('F-0007','IMPUESTO'),('F-0021','IMPUESTO'),
('F-0048','IMPUESTO'),('F-0013','IMPUESTO'),('F-0034','IMPUESTO');

-- MEDIDOR (si no sabes el número, deja NULL)
INSERT INTO st_Medidor(Finca,NumSerie) VALUES
('F-0007',NULL),('F-0021',NULL),('F-0048',NULL),('F-0013',NULL),('F-0034',NULL);

-- MOVIMIENTOS (lecturas ~3 días antes del corte; ajusta si tu XML dice otra cosa)
-- 1=LECTURA, 2=INCREMENTO (débito), 3=DECREMENTO (crédito)
INSERT INTO st_MovMedidor(Finca,Fecha,TipoMov,Valor) VALUES
('F-0007','2025-06-10',1,10.0),('F-0007','2025-07-10',1,9.5),('F-0007','2025-08-10',1,8.2),('F-0007','2025-09-10',1,7.9),('F-0007','2025-10-10',1,7.0),
('F-0021','2025-09-10',1,6.0),('F-0021','2025-10-10',1,5.0),
('F-0048','2025-08-10',1,5.5),('F-0048','2025-09-10',1,4.3),('F-0048','2025-10-10',1,3.1),
('F-0013','2025-10-10',1,4.0),
('F-0034','2025-10-10',1,3.0);

-- PAGOS (deja varios **sin pago** para que existan vencidas)
INSERT INTO st_Pago(Finca,Fecha,Monto,Medio,Referencia) VALUES
('F-0007','2025-06-28',2000,'Caja','P-0007-1'),
('F-0021','2025-10-28',1500,'SINPE','P-0021-1');


