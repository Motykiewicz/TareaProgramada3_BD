USE TP3_Municipalidad;
GO
-----------------------------------------------------

-- 1. login del portal 
CREATE OR ALTER PROCEDURE dbo.sp_web_login
    @Login    VARCHAR(50),
    @Password VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        u.UsuarioID,
        u.UsuarioLogin,
        u.Rol,
        p.PersonaID,
        p.Nombre
    FROM dbo.Usuario u
    JOIN dbo.Persona p ON p.PersonaID = u.PersonaID
    WHERE u.UsuarioLogin = @Login
      AND u.HashPassword = HASHBYTES('SHA2_256', @Password);
END;
GO
----------------------------------------------

-- 2. listado de usuarios para el panel admin 
CREATE OR ALTER PROCEDURE dbo.sp_web_admin_usuarios
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        u.UsuarioID,
        u.UsuarioLogin,
        u.Rol,
        p.Nombre
    FROM dbo.Usuario u
    JOIN dbo.Persona p ON p.PersonaID = u.PersonaID
    ORDER BY u.UsuarioLogin;
END;
GO

--------------------------------------------------------
USE TP3_Municipalidad;
GO
-- 3.  facturas pendientes de un usuario (para que el cliente las vea) 
CREATE OR ALTER PROCEDURE dbo.sp_web_client_facturas
    @UsuarioID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PersonaID INT;

    SELECT @PersonaID = u.PersonaID
    FROM dbo.Usuario u
    WHERE u.UsuarioID = @UsuarioID;

    IF @PersonaID IS NULL
    BEGIN
        RAISERROR('Usuario no encontrado.', 16, 1);
        RETURN;
    END;

    SELECT
        f.FacturaID,
        p.Finca,
        f.FechaEmision,
        f.FechaVencimiento,
        f.Estado,
        f.Total
    FROM dbo.Factura f
    JOIN dbo.Propiedad p
           ON p.PropiedadID = f.PropiedadID
    JOIN dbo.PropiedadPersona pp
           ON pp.PropiedadID = p.PropiedadID
          AND pp.FechaFin IS NULL
    WHERE pp.PersonaID = @PersonaID
      AND f.Estado = 'PENDIENTE'
    ORDER BY f.FechaEmision, f.FacturaID;
END;
GO
--------------------------------------------------------

USE TP3_Municipalidad;
GO
-- 4. historial de pagos de un usuario 
CREATE OR ALTER PROCEDURE dbo.sp_web_client_pagos
    @UsuarioID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PersonaID INT;

    SELECT @PersonaID = u.PersonaID
    FROM dbo.Usuario u
    WHERE u.UsuarioID = @UsuarioID;

    IF @PersonaID IS NULL
    BEGIN
        RAISERROR('Usuario no encontrado.', 16, 1);
        RETURN;
    END;

    SELECT
        p.PagoID,
        p.Fecha,
        p.Monto,
        p.Medio,
        p.Referencia,
        f.FacturaID
    FROM dbo.Pago p
    JOIN dbo.PagoFactura pf ON pf.PagoID   = p.PagoID
    JOIN dbo.Factura     f ON f.FacturaID = pf.FacturaID
    JOIN dbo.Propiedad   pr ON pr.PropiedadID = f.PropiedadID
    JOIN dbo.PropiedadPersona pp
           ON pp.PropiedadID = pr.PropiedadID
          AND pp.FechaFin IS NULL
    WHERE pp.PersonaID = @PersonaID
    ORDER BY p.Fecha, p.PagoID;
END;
GO


--------------------------------------------------------

USE TP3_Municipalidad;
GO

CREATE OR ALTER PROCEDURE dbo.sp_web_pagar_factura_usuario
    @UsuarioID INT,
    @FacturaID INT,
    @Medio     VARCHAR(32),
    @Ref       VARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @PersonaID INT,
        @Finca     VARCHAR(32),
        @Total     DECIMAL(16,2);

    -- 1. Persona asociada al Usuario
    SELECT @PersonaID = u.PersonaID
    FROM dbo.Usuario u
    WHERE u.UsuarioID = @UsuarioID;

    IF @PersonaID IS NULL
    BEGIN
        RAISERROR('Usuario no encontrado.', 16, 1);
        RETURN;
    END;

    -- 2. Validar que la factura está PENDIENTE y es de una propiedad actual del usuario
    SELECT
        @Finca = p.Finca,
        @Total = f.Total
    FROM dbo.Factura f
    JOIN dbo.Propiedad p
           ON p.PropiedadID = f.PropiedadID
    JOIN dbo.PropiedadPersona pp
           ON pp.PropiedadID = p.PropiedadID
          AND pp.FechaFin IS NULL
    WHERE f.FacturaID = @FacturaID
      AND pp.PersonaID = @PersonaID
      AND f.Estado = 'PENDIENTE';

    IF @Finca IS NULL
    BEGIN
        RAISERROR('La factura no está pendiente o no pertenece al usuario.', 16, 1);
        RETURN;
    END;

    -- 3. Llamar al SP oficial de la tarea
    EXEC dbo.sp_procesar_pago
         @Finca = @Finca,
         @Fecha = CAST(GETDATE() AS DATE), 
         @Monto = @Total,
         @Medio = @Medio,
         @Ref   = @Ref;
END;
GO

------------------------------------------------------------------
-- propiedades asociadas a clientes 
USE TP3_Municipalidad;
GO

CREATE OR ALTER PROCEDURE dbo.sp_web_client_propiedades
    @UsuarioID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PersonaID INT;

    -- 1. Obtener la Persona asociada al Usuario
    SELECT @PersonaID = u.PersonaID
    FROM dbo.Usuario u
    WHERE u.UsuarioID = @UsuarioID;

    IF @PersonaID IS NULL
    BEGIN
        RAISERROR('Usuario no encontrado.', 16, 1);
        RETURN;
    END;

    /* 2. Propiedades actuales del usuario (PropiedadPersona.FechaFin IS NULL)
          + deuda total pendiente (sumando facturas PENDIENTE) */

    ;WITH PropDeuda AS (
        SELECT
            pr.PropiedadID,
            pr.Finca,
            pr.Zona,
            pr.Uso,
            pr.FechaRegistro,
            DeudaPendiente = ISNULL(
                SUM(
                    CASE 
                        WHEN f.Estado = 'PENDIENTE' THEN f.Total 
                        ELSE 0 
                    END
                ), 0
            )
        FROM dbo.Propiedad pr
        JOIN dbo.PropiedadPersona pp
             ON pp.PropiedadID = pr.PropiedadID
            AND pp.FechaFin IS NULL              -- solo relación vigente
        LEFT JOIN dbo.Factura f
             ON f.PropiedadID = pr.PropiedadID   -- facturas asociadas a la propiedad
        WHERE pp.PersonaID = @PersonaID
        GROUP BY
            pr.PropiedadID,
            pr.Finca,
            pr.Zona,
            pr.Uso,
            pr.FechaRegistro
    )
    SELECT
        PropiedadID,
        Finca,
        Zona,
        Uso,
        FechaRegistro,
        DeudaPendiente
    FROM PropDeuda
    ORDER BY Finca;
END;
GO

GRANT EXECUTE ON dbo.sp_web_client_propiedades TO tarea3_user;
GO
