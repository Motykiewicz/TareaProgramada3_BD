USE TP3_Municipalidad;
GO

IF OBJECT_ID('dbo.st_Persona','U') IS NOT NULL DROP TABLE dbo.st_Persona;
CREATE TABLE dbo.st_Persona(
  Identificacion VARCHAR(32) NOT NULL,
  Nombre         VARCHAR(128) NOT NULL
);
GO

IF OBJECT_ID('dbo.st_Propiedad','U') IS NOT NULL DROP TABLE dbo.st_Propiedad;
CREATE TABLE dbo.st_Propiedad(
  Finca         VARCHAR(32)  NOT NULL,
  Zona          VARCHAR(32)  NOT NULL,
  Uso           VARCHAR(32)  NOT NULL,
  FechaRegistro DATE         NOT NULL
);
GO

IF OBJECT_ID('dbo.st_Persona','U') IS NOT NULL DROP TABLE dbo.st_Persona;
CREATE TABLE dbo.st_Persona(
  Identificacion VARCHAR(32) NOT NULL,
  Nombre         VARCHAR(128) NOT NULL,
  Email          VARCHAR(100) NULL,
  Telefono1      VARCHAR(20)  NULL,
  Telefono2      VARCHAR(20)  NULL
);
GO

IF OBJECT_ID('dbo.st_CCPropiedad','U') IS NOT NULL DROP TABLE dbo.st_CCPropiedad;
CREATE TABLE dbo.st_CCPropiedad(
  Finca    VARCHAR(32) NOT NULL,
  CodigoCC VARCHAR(32) NOT NULL   -- del XML: normalmente solo IMPUESTO
);
GO

IF OBJECT_ID('dbo.st_Medidor','U') IS NOT NULL DROP TABLE dbo.st_Medidor;
CREATE TABLE dbo.st_Medidor(
  Finca    VARCHAR(32) NOT NULL,
  NumSerie VARCHAR(64) NULL
);
GO

IF OBJECT_ID('dbo.st_MovMedidor','U') IS NOT NULL DROP TABLE dbo.st_MovMedidor;
CREATE TABLE dbo.st_MovMedidor(
  Finca   VARCHAR(32)  NOT NULL,
  Fecha   DATE         NOT NULL,
  TipoMov INT          NOT NULL,   -- 1=LECTURA, 2=INCREMENTO (débito), 3=DECREMENTO (crédito)
  Valor   DECIMAL(12,3) NOT NULL
);
GO

IF OBJECT_ID('dbo.st_Pago','U') IS NOT NULL DROP TABLE dbo.st_Pago;
CREATE TABLE dbo.st_Pago(
  Finca      VARCHAR(32)   NOT NULL,
  Fecha      DATE          NOT NULL,
  Monto      DECIMAL(16,2) NOT NULL,
  Medio      VARCHAR(32)   NULL,
  Referencia VARCHAR(64)   NULL
);
GO

