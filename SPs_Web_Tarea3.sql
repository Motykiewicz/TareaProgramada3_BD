USE TP3_Municipalidad;
GO

   
 ----------------------------------------------------- sp_web_login
 -- Login del portal
CREATE OR ALTER PROCEDURE dbo.sp_web_login
    @Login    VARCHAR(50),
    @Password VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        u.UsuarioID,u.UsuarioLogin, u.Rol, p.PersonaID, p.Nombre
    FROM dbo.Usuario u
    JOIN dbo.Persona p ON p.PersonaID = u.PersonaID
    WHERE u.UsuarioLogin = @Login
      AND u.HashPassword = HASHBYTES('SHA2_256', @Password);
END;
GO



 ----------------------------------------------------- sp_web_admin_usuarios
 -- listado de usuarios para el panel de admin
CREATE OR ALTER PROCEDURE dbo.sp_web_admin_usuarios
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        u.UsuarioID,u.UsuarioLogin,u.Rol,p.Nombre
    FROM dbo.Usuario u
    JOIN dbo.Persona p ON p.PersonaID = u.PersonaID
    ORDER BY u.UsuarioLogin;
END;
GO



-------------------------------------------------------- sp_web_client_facturas
-- facturas pendientes de un usuario desde la vista cliente 
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
        RAISERROR(N'Usuario no encontrado.', 16, 1);
        RETURN;
    END;

    SELECT
        f.FacturaID,p.Finca,f.FechaEmision, f.FechaVencimiento,f.Estado,f.Total,
        -- Texto de periodo para mostrar en la tabla del cliente
        CONVERT(varchar(7), f.FechaEmision, 126) AS PeriodoTexto, -- yyyy-MM
        -- Servicio por ahora fijo
        CAST('Servicios municipales' AS varchar(64)) AS Servicio
    FROM dbo.Factura f
    JOIN dbo.Propiedad p
           ON p.PropiedadID = f.PropiedadID
    JOIN dbo.PropiedadPersona pp
           ON pp.PropiedadID = p.PropiedadID
          AND pp.FechaFin   IS NULL
    WHERE pp.PersonaID = @PersonaID
      AND f.Estado     = 'PENDIENTE'
    ORDER BY f.FechaEmision, f.FacturaID;
END;
GO



 ----------------------------------------------------- sp_web_client_pagos
 -- historial de pagos de un usuario vista de cliente
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
        RAISERROR(N'Usuario no encontrado.', 16, 1);
        RETURN;
    END;

    SELECT
        p.PagoID,p.Fecha,p.Monto, p.Medio,p.Referencia,f.FacturaID,pr.Finca
    FROM dbo.Pago p
    JOIN dbo.PagoFactura pf ON pf.PagoID = p.PagoID
    JOIN dbo.Factura f  ON f.FacturaID = pf.FacturaID
    JOIN dbo.Propiedad pr ON pr.PropiedadID = f.PropiedadID
    JOIN dbo.PropiedadPersona pp ON pp.PropiedadID = pr.PropiedadID
    AND pp.FechaFin    IS NULL
    WHERE pp.PersonaID = @PersonaID
    ORDER BY p.Fecha, p.PagoID;
END;
GO


 ----------------------------------------------------- sp_web_pagar_factura_usuario
 -- pago de una factura desde el portal web 
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
        RAISERROR(N'Usuario no encontrado.', 16, 1);
        RETURN;
    END;

    -- 2. Validar que la factura está PENDIENTE y es de una propiedad actual del usuario
    SELECT
        @Finca = p.Finca,
        @Total = f.Total
    FROM dbo.Factura f
    JOIN dbo.Propiedad p ON p.PropiedadID = f.PropiedadID
    JOIN dbo.PropiedadPersona pp ON pp.PropiedadID = p.PropiedadID
    AND pp.FechaFin    IS NULL
    WHERE f.FacturaID = @FacturaID
      AND pp.PersonaID = @PersonaID
      AND f.Estado= 'PENDIENTE';

    IF @Finca IS NULL
    BEGIN
        RAISERROR(N'La factura no está pendiente o no pertenece al usuario.', 16, 1);
        RETURN;
    END;

    -- 3. Llamar al SP oficial que hace todo el proceso atómico
    EXEC dbo.sp_procesar_pago
         @Finca = @Finca,
         @Fecha = CONVERT(date, GETDATE()),  
         @Monto = @Total,
         @Medio = @Medio,
         @Ref   = @Ref;
END;
GO




 -- propiedades asociadas al usuario con deuda pendiente
 ----------------------------------------------------- sp_web_client_propiedades
CREATE OR ALTER PROCEDURE dbo.sp_web_client_propiedades
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
        RAISERROR(N'Usuario no encontrado.', 16, 1);
        RETURN;
    END;

    ;WITH PropDeuda AS (
        SELECT
            pr.PropiedadID, pr.Finca,pr.Zona,pr.Uso,pr.FechaRegistro,DeudaPendiente = ISNULL(
                SUM(CASE WHEN f.Estado = 'PENDIENTE' THEN f.Total ELSE 0 END), 0)
        FROM dbo.Propiedad pr
        JOIN dbo.PropiedadPersona pp ON pp.PropiedadID = pr.PropiedadID
        AND pp.FechaFin    IS NULL
        LEFT JOIN dbo.Factura f ON f.PropiedadID  = pr.PropiedadID
        WHERE pp.PersonaID = @PersonaID
        GROUP BY
            pr.PropiedadID,pr.Finca, pr.Zona, pr.Uso,pr.FechaRegistro
        )
    SELECT
        PropiedadID, Finca,Zona,Uso,FechaRegistro,DeudaPendiente
    FROM PropDeuda
    ORDER BY Finca;
END;
GO

GRANT EXECUTE ON dbo.sp_web_client_propiedades TO tarea3_user;
GO



 ----------------------------------------------------- sp_web_admin_buscar_cliente
    -- Búsqueda de cliente en panel admin
USE TP3_Municipalidad;
GO

CREATE OR ALTER PROCEDURE dbo.sp_web_admin_buscar_cliente
  @TipoBusqueda VARCHAR(20),   -- 'FINCA' o 'IDENTIFICACION'
  @Valor        VARCHAR(64)
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @tipo VARCHAR(20) = UPPER(@TipoBusqueda);

  IF @tipo = 'FINCA'
  BEGIN

    SELECT DISTINCT
      u.UsuarioID, u.UsuarioLogin,p.Nombre AS NombrePersona, p.Identificacion,pr.Finca
    FROM dbo.Propiedad pr
    JOIN dbo.PropiedadPersona pp ON pp.PropiedadID = pr.PropiedadID
        AND pp.FechaFin IS NULL           -- relación vigente
    JOIN dbo.Persona p ON p.PersonaID = pp.PersonaID
    JOIN dbo.Usuario u ON u.PersonaID = p.PersonaID
    WHERE pr.Finca = @Valor;
  END
  ELSE
  BEGIN

    SELECT DISTINCT
      u.UsuarioID, u.UsuarioLogin, p.Nombre AS NombrePersona, p.Identificacion, pr.Finca
    FROM dbo.Persona p
    JOIN dbo.Usuario u ON u.PersonaID = p.PersonaID
    LEFT JOIN dbo.PropiedadPersona pp ON pp.PersonaID = p.PersonaID
        AND pp.FechaFin IS NULL
    LEFT JOIN dbo.Propiedad pr ON pr.PropiedadID = pp.PropiedadID
    WHERE p.Identificacion = @Valor;
  END
END;
GO

----------------------------------------------------------------- sp_web_admin_clientes_todos
IF OBJECT_ID('dbo.sp_web_admin_clientes_todos', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_web_admin_clientes_todos;
GO

CREATE PROCEDURE dbo.sp_web_admin_clientes_todos
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
        U.UsuarioID,
        U.UsuarioLogin,
        P.Nombre           AS NombrePersona,
        P.Identificacion,
        PR.Finca
    FROM dbo.Usuario U
    JOIN dbo.Persona P
        ON U.PersonaID = P.PersonaID
    -- Relación Persona–Propiedad (solo relaciones abiertas)
    JOIN dbo.PropiedadPersona PP
        ON P.PersonaID = PP.PersonaID
       AND PP.FechaFin IS NULL
    JOIN dbo.Propiedad PR
        ON PP.PropiedadID = PR.PropiedadID
    WHERE U.Rol != 'admin'
    ORDER BY
        U.UsuarioLogin,
        PR.Finca;
END;
GO


--------------------------------------------------------------------- sp_web_admin_buscar_cliente
ALTER PROC dbo.sp_web_admin_buscar_cliente
    @TipoBusqueda   VARCHAR(20),   -- 'FINCA' o 'IDENTIFICACION'
    @Valor          VARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @tipo VARCHAR(20) = UPPER(LTRIM(RTRIM(@TipoBusqueda)));
    DECLARE @v    VARCHAR(64) = LTRIM(RTRIM(@Valor));

    SELECT DISTINCT
        u.UsuarioID,
        u.UsuarioLogin,
        p.Nombre       AS NombrePersona,
        p.Identificacion,
        pr.Finca
    FROM dbo.Usuario u
    INNER JOIN dbo.Persona p
        ON p.PersonaID = u.PersonaID
    INNER JOIN dbo.UsuarioPropiedad up
        ON up.UsuarioID = u.UsuarioID
    INNER JOIN dbo.Propiedad pr
        ON pr.PropiedadID = up.PropiedadID
    WHERE
        (@tipo = 'FINCA'AND pr.Finca = @v)
        OR
        (@tipo = 'IDENTIFICACION'AND p.Identificacion = @v);
END;
GO

--------------------------------------------------------------------- sp_web_admin_bitacora
USE TP3_Municipalidad;
GO

CREATE OR ALTER PROCEDURE dbo.sp_web_admin_bitacora
    @Tabla NVARCHAR(128) = NULL,
    @Desde DATE = NULL,
    @Hasta DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        b.Fecha,
        b.Tabla,
        b.PK,
        b.Usuario,
        b.IP,
        b.Accion,
        b.JsonAntes,
        b.JsonDespues
    FROM ADM.Bitacora AS b               
    WHERE (@Tabla IS NULL OR b.Tabla = @Tabla)
      AND (@Desde IS NULL OR CONVERT(date, b.Fecha) >= @Desde)
      AND (@Hasta IS NULL OR CONVERT(date, b.Fecha) <= @Hasta)
    ORDER BY
        b.Fecha DESC,
        b.Tabla,
        b.PK;
END;
GO

----------------------------------

-- Ver propiedades
SELECT PropiedadID, Finca, Zona, Uso
FROM dbo.Propiedad
ORDER BY Finca;

-- ver facturas de la finca F0007 la que se ve en el front 
SELECT FacturaID, PropiedadID, FechaEmision, FechaVencimiento,
       Total, Estado
FROM dbo.Factura
WHERE PropiedadID = (SELECT PropiedadID FROM Propiedad WHERE Finca = 'F-0007')
ORDER BY FacturaID DESC;
