USE TP3_Municipalidad;
GO

IF OBJECT_ID('dbo.Persona','U') IS NOT NULL DROP TABLE dbo.Persona;
CREATE TABLE dbo.Persona (
    PersonaID INT IDENTITY(1,1) PRIMARY KEY, 
    Identificacion VARCHAR(32) NOT NULL UNIQUE,
    Nombre VARCHAR(64) NOT NULL,
    Email VARCHAR(100) NULL,
    Telefono1 VARCHAR(20) NULL,
    Telefono2 VARCHAR(20) NULL
);
GO
ALTER TABLE dbo.Persona
ADD Email      VARCHAR(100) NOT NULL DEFAULT 'sin-correo@ejemplo.org',
    Telefono1  VARCHAR(20)  NOT NULL DEFAULT '0000-0000',
    Telefono2  VARCHAR(20)  NULL;

IF OBJECT_ID('dbo.Usuario','U') IS NOT NULL DROP TABLE dbo.Usuario;
CREATE TABLE dbo.Usuario (
	UsuarioID INT IDENTITY(1,1) PRIMARY KEY,
	PersonaID INT NOT NULL, 
	Rol Varchar(32) NOT NULL CHECK (Rol In ('admin', 'no-admin')),
	UsuarioLogin Varchar(50) NOT NULL UNIQUE,
	HashPassword VARBINARY(256) NULL,
	FOREIGN KEY (PERSONAID) REFERENCES Persona(PersonaID)
);
GO

IF OBJECT_ID('dbo.Propiedad','U') IS NOT NULL DROP TABLE dbo.Propiedad;
CREATE TABLE dbo.Propiedad (
	PropiedadID INT IDENTITY(1,1) PRIMARY KEY, 
	Finca VARCHAR(32) NOT NULL UNIQUE,
	Zona VARCHAR(32) NOT NULL,
	Uso VARCHAR(32) NOT NULL,
	FechaRegistro DATE NOT NULL,
	PropietarioID INT NULL,
	EstadoServicioAgua VARCHAR(32) NOT NULL DEFAULT 'ACTIVO',
	M3Acumulados DECIMAL(12,3) NOT NULL DEFAULT 0,
	M3AcumuladosUltimaFactura DECIMAL(12,3) NOT NULL DEFAULT 0,
	FOREIGN KEY (PropietarioID) REFERENCES Persona(PersonaID)
);
GO


IF OBJECT_ID('dbo.Medidor','U') IS NOT NULL DROP TABLE dbo.Medidor;
CREATE TABLE dbo.Medidor (
	MedidorID INT IDENTITY(1,1) PRIMARY KEY,
	PropiedadID INT NOT NULL, 
	Activo BIT NOT NULL DEFAULT 1,
	FOREIGN KEY (PropiedadID) REFERENCES Propiedad(PropiedadID)
);
GO

IF OBJECT_ID('dbo.MovimientoMedidor','U') IS NOT NULL DROP TABLE dbo.MovimientoMedidor;
CREATE TABLE dbo.MovimientoMedidor (
	MovID INT IDENTITY(1,1) PRIMARY KEY,
	MedidorID INT NOT NULL,
	Fecha DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
	Tipo VARCHAR(12) NOT NULL CHECK (Tipo IN ('LECTURA', 'INCREMENTO', 'DECREMENTO')),
	Valor DECIMAL(12,3) NOT NULL,
	Delta DECIMAL(12,3) NULL,
	FOREIGN KEY (MedidorID) REFERENCES Medidor(MedidorID)
);

IF OBJECT_ID('dbo.ConceptoCobro','U') IS NOT NULL DROP TABLE dbo.ConceptoCobro;
CREATE TABLE dbo.ConceptoCobro (
	ConceptoID INT IDENTITY(1,1) PRIMARY KEY,
	Codigo VARCHAR(32) NOT NULL UNIQUE,
	Descripcion NVARCHAR(128) NOT NULL,
	EsFijo BIT NOT NULL DEFAULT 0
);
GO


IF OBJECT_ID('dbo.PropiedadConceptoCobro','U') IS NOT NULL DROP TABLE dbo.PropiedadConceptoCobro;
CREATE TABLE dbo.PropiedadConceptoCobro(
	PropiedadID INT NOT NULL,
	ConceptoID INT NOT NULL,
	Activo BIT NOT NULL DEFAULT 1,
	PRIMARY KEY (PropiedadID, ConceptoID),
	FOREIGN KEY (PropiedadID) REFERENCES Propiedad(PropiedadID),
	FOREIGN KEY (ConceptoID) REFERENCES ConceptoCobro(ConceptoID),
);
GO

IF OBJECT_ID('dbo.Factura','U') IS NOT NULL DROP TABLE dbo.Factura;
CREATE TABLE dbo.Factura (
	FacturaID INT IDENTITY(1,1) PRIMARY KEY,
	PropiedadID INT NOT NULL,
	FechaEmision DATE NOT NULL,
	FechaVencimiento Date NOT NULL,
	Estado Varchar(32) NOT NULL DEFAULT 'PENDIENTE', -- O PAGADO 
	Total DECIMAL(16,2) NOT NULL DEFAULT 0, 
	FOREIGN KEY (PropiedadID) REFERENCES Propiedad(PropiedadID)
);

IF OBJECT_ID('dbo.DetalleFactura','U') IS NOT NULL DROP TABLE dbo.DetalleFactura;
CREATE TABLE dbo.DetalleFactura ( 
	DetalleID INT IDENTITY(1,1) PRIMARY KEY,
	FacturaID INT NOT NULL,
	ConceptoID INT NOT NULL,
	Cantidad DECIMAL(12,3) NOT NULL DEFAULT 1,
	PrecioUnitario DECIMAL(16,2) NOT NULL DEFAULT 0,
	Subtotal AS (Cantidad * PrecioUnitario) PERSISTED, 
	FOREIGN KEY (FacturaID) REFERENCES Factura(FacturaID),
	FOREIGN KEY (ConceptoID) REFERENCES ConceptoCobro(ConceptoID)
);
GO

IF OBJECT_ID('dbo.Pago','U') IS NOT NULL DROP TABLE dbo.Pago;
CREATE TABLE dbo.Pago (
	PagoID INT IDENTITY(1,1) PRIMARY KEY,
	Fecha DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
	Monto DECIMAL (16,2) NOT NULL,
	Medio VARCHAR(32) NULL,
	Referencia VARCHAR(64) NULL
);
GO

IF OBJECT_ID('dbo.PagoFactura','U') IS NOT NULL DROP TABLE dbo.PagoFactura;
CREATE TABLE dbo.PagoFactura (
	PagoID INT NOT NULL,
	FacturaID INT NOT NULL,
	MontoAplicado Decimal(16,2) NOT NULL,
	PRIMARY KEY (PagoID, FacturaID),
	FOREIGN KEY (PagoID) REFERENCES Pago(PagoID),
	FOREIGN KEY (FacturaID) REFERENCES Factura(FacturaID)
);
GO

IF OBJECT_ID('dbo.Orden','U') IS NOT NULL DROP TABLE dbo.Orden;
CREATE TABLE dbo.Orden (
	OrdenID INT IDENTITY(1,1) PRIMARY KEY, 
	PropiedadID INT NOT NULL,
	Tipo VARCHAR(16) NOT NULL CHECK (Tipo IN ('CORTE', 'RECONEXION')),
	Fecha DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
	Estado VARCHAR(15) NOT NULL DEFAULT 'ABIERTA', -- O CERRADA
	FOREIGN KEY (PropiedadID) REFERENCES Propiedad(PropiedadID)
);
GO


IF OBJECT_ID('dbo.ParametroSistema','U') IS NOT NULL DROP TABLE dbo.ParametroSistema;
CREATE TABLE dbo.ParametroSistema (
	Clave VARCHAR(64) PRIMARY KEY,
	ValorDecimal DECIMAL(16,2) NULL,
	ValorEntero INT NULL,
	ValorTexto NVARCHAR(128) NULL
);
GO


IF OBJECT_ID('dbo.Bitacora','U') IS NOT NULL DROP TABLE dbo.Bitacora;
CREATE TABLE dbo.Bitacora ( 
	BitacoraID INT IDENTITY(1,1) PRIMARY KEY, 
	Tabla NVARCHAR(128) NOT NULL,
	PK NVARCHAR(128) NOT NULL,
	Usuario NVARCHAR(64) NULL,
	IP NVARCHAR(64) NULL,
	Fecha DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
	JsonAntes NVARCHAR(MAX) NULL,
	JsonDespues NVARCHAR(MAX) NULL,
	Accion Varchar(16) NOT NULL CHECK (Accion IN ('INSERT', 'UPDATE', 'DELETE'))
);
GO

IF OBJECT_ID('dbo.PropiedadPersona','U') IS NOT NULL DROP TABLE dbo.PropiedadPersona;
CREATE TABLE dbo.PropiedadPersona (
	PropiedadID INT NOT NULL,
    PersonaID   INT NOT NULL,
    FechaInicio DATE NOT NULL,
    FechaFin    DATE NULL,
    CONSTRAINT PK_PropiedadPersona PRIMARY KEY (PropiedadID, PersonaID, FechaInicio),
    CONSTRAINT FK_PropiedadPersona_Propiedad FOREIGN KEY (PropiedadID) REFERENCES dbo.Propiedad(PropiedadID),
    CONSTRAINT FK_PropiedadPersona_Persona   FOREIGN KEY (PersonaID)   REFERENCES dbo.Persona(PersonaID),
    CONSTRAINT CK_PropiedadPersona_Fechas CHECK (FechaFin IS NULL OR FechaFin > FechaInicio)
  );
GO


IF OBJECT_ID('dbo.UsuarioPropiedad','U') IS NOT NULL DROP TABLE dbo.UsuarioPropiedad;
CREATE TABLE dbo.UsuarioPropiedad (
	UsuarioID   INT NOT NULL,
    PropiedadID INT NOT NULL,
    CONSTRAINT PK_UsuarioPropiedad PRIMARY KEY (UsuarioID, PropiedadID),
    CONSTRAINT FK_UsuarioPropiedad_Usuario   FOREIGN KEY (UsuarioID)   REFERENCES dbo.Usuario(UsuarioID),
    CONSTRAINT FK_UsuarioPropiedad_Propiedad FOREIGN KEY (PropiedadID) REFERENCES dbo.Propiedad(PropiedadID)
  );
GO



IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_Factura_Propiedad_Fecha' AND object_id = OBJECT_ID('dbo.Factura'))
BEGIN
  CREATE UNIQUE INDEX UX_Factura_Propiedad_Fecha
    ON dbo.Factura(PropiedadID, FechaEmision);
END
GO




IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_PagoFactura_Factura' AND object_id = OBJECT_ID('dbo.PagoFactura'))
  CREATE INDEX IX_PagoFactura_Factura ON dbo.PagoFactura(FacturaID);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Propiedad_Finca' AND object_id = OBJECT_ID('dbo.Propiedad'))
  CREATE INDEX IX_Propiedad_Finca ON dbo.Propiedad(Finca);

IF NOT EXISTS (SELECT 1 FROM sys.indexes  WHERE name='UX_PropiedadPersona_Abierta' AND object_id=OBJECT_ID('dbo.PropiedadPersona'))
  CREATE UNIQUE INDEX UX_PropiedadPersona_Abierta ON dbo.PropiedadPersona (PropiedadID, PersonaID) WHERE FechaFin IS NULL;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_PropiedadPersona_Persona_Abierta' AND object_id=OBJECT_ID('dbo.PropiedadPersona'))
  CREATE INDEX IX_PropiedadPersona_Persona_Abierta ON dbo.PropiedadPersona(PersonaID) WHERE FechaFin IS NULL;

-- para joins de pagos 
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_PagoFactura_Pago' AND object_id=OBJECT_ID('dbo.PagoFactura'))
  CREATE INDEX IX_PagoFactura_Pago ON dbo.PagoFactura(PagoID);
GO


