-- tablas staging en donde cargamos los datos del xml 


USE TP3_Municipalidad;
GO


IF OBJECT_ID('dbo.st_Persona') IS NOT NULL DROP TABLE dbo.st_Persona;
CREATE TABLE dbo.st_Persona(
    Identificacion VARCHAR(32) NOT NULL,
    Nombre VARCHAR(128) NOT NULL,
    Email  VARCHAR(128) NULL,
    Telefono1 VARCHAR(20)  NULL,
    Telefono2 VARCHAR(20)  NULL
);

IF OBJECT_ID('dbo.st_Propiedad') IS NOT NULL DROP TABLE dbo.st_Propiedad;
CREATE TABLE dbo.st_Propiedad(
    Finca VARCHAR(32)  NOT NULL,
    Zona VARCHAR(32)  NOT NULL,
    Uso VARCHAR(32)  NOT NULL,
    FechaRegistro  DATE NOT NULL
);

IF OBJECT_ID('dbo.st_PropiedadPersona') IS NOT NULL DROP TABLE dbo.st_PropiedadPersona;
CREATE TABLE dbo.st_PropiedadPersona(
    Finca VARCHAR(32) NOT NULL,
    Identificacion  VARCHAR(32) NOT NULL,
    FechaInicio DATE NOT NULL,
    FechaFin DATE NULL
);

IF OBJECT_ID('dbo.st_CCPropiedad') IS NOT NULL DROP TABLE dbo.st_CCPropiedad;
CREATE TABLE dbo.st_CCPropiedad(
    Finca VARCHAR(32) NOT NULL,
    CodigoCC VARCHAR(32) NOT NULL
);

IF OBJECT_ID('dbo.st_Medidor') IS NOT NULL DROP TABLE dbo.st_Medidor;
CREATE TABLE dbo.st_Medidor(
    Finca VARCHAR(32) NOT NULL,
    NumSerie VARCHAR(64) NULL
);

IF OBJECT_ID('dbo.st_MovMedidor') IS NOT NULL DROP TABLE dbo.st_MovMedidor;
CREATE TABLE dbo.st_MovMedidor(
    Finca VARCHAR(32) NOT NULL,
    Fecha DATE NOT NULL,
    TipoMov INT NOT NULL,
    Valor DECIMAL(12,3) NOT NULL
);

IF OBJECT_ID('dbo.st_Pago') IS NOT NULL DROP TABLE dbo.st_Pago;
CREATE TABLE dbo.st_Pago(
    Finca VARCHAR(32) NOT NULL,
    Fecha DATE NOT NULL,
    Monto DECIMAL(16,2) NOT NULL,
    Medio VARCHAR(32) NOT NULL,
    Referencia VARCHAR(64) NULL
);
GO

