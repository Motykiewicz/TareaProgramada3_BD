# Diagrama de ambiente (Mermaid)

Copia del diagrama en formato Mermaid. Puedes abrirlo en VS Code con la extensión "Markdown Preview Mermaid Support" o usar la vista previa Mermaid para ver el diagrama.

```mermaid
erDiagram
    PERSONA {
        int PersonaID PK
        string Identificacion
        string Nombre
        string Email
        string Telefono1
        string Telefono2
    }

    USUARIO {
        int UsuarioID PK
        int PersonaID FK
        string Rol
        string UsuarioLogin
    }

    PROPIEDAD {
        int PropiedadID PK
        string Finca
        string Zona
        string Uso
        date   FechaRegistro
        int    PropietarioID FK
    }

    PROPIEDADPERSONA {
        int PropiedadID FK
        int PersonaID   FK
        date FechaInicio
        date FechaFin
    }

    USUARIOPROPIEDAD {
        int UsuarioID   FK
        int PropiedadID FK
    }

    MEDIDOR {
        int MedidorID PK
        int PropiedadID FK
        bit Activo
    }

    MOVIMIENTOMEDIDOR {
        int MovID PK
        int MedidorID FK
        datetime Fecha
        string Tipo
        decimal Valor
        decimal Delta
    }

    CONCEPTOCOBRO {
        int ConceptoID PK
        string Codigo
        string Descripcion
        bit EsFijo
    }

    PROPIEDADCONCEPTOCOBRO {
        int PropiedadID FK
        int ConceptoID  FK
        bit Activo
    }

    FACTURA {
        int FacturaID PK
        int PropiedadID FK
        date FechaEmision
        date FechaVencimiento
        string Estado
        decimal Total
    }

    DETALLEFACTURA {
        int DetalleID PK
        int FacturaID  FK
        int ConceptoID FK
        decimal Cantidad
        decimal PrecioUnitario
    }

    PAGO {
        int PagoID PK
        datetime Fecha
        decimal Monto
        string Medio
        string Referencia
    }

    PAGOSFACTURA {
        int PagoID    FK
        int FacturaID FK
        decimal MontoAplicado
    }

    ORDEN {
        int OrdenID PK
        int PropiedadID FK
        string Tipo
        datetime Fecha
        string Estado
    }

    PARAMETROSISTEMA {
        string Clave PK
        decimal ValorDecimal
        int ValorEntero
        string ValorTexto
    }

    BITACORA {
        int BitacoraID PK
        string Tabla
        string PKRegistro
        string Usuario
        string IP
        datetime Fecha
        string JsonAntes
        string JsonDespues
        string Accion
    }

    %% RELACIONES

    PERSONA ||--o{ USUARIO : "tiene"
    PERSONA ||--o{ PROPIEDADPERSONA : "es propietario de"
    PROPIEDAD ||--o{ PROPIEDADPERSONA : "tiene"
    USUARIO  ||--o{ USUARIOPROPIEDAD : "consulta"
    PROPIEDAD||--o{ USUARIOPROPIEDAD : "es visible para"

    PROPIEDAD ||--o{ MEDIDOR : "tiene"
    MEDIDOR   ||--o{ MOVIMIENTOMEDIDOR : "registra"

    PROPIEDAD ||--o{ PROPIEDADCONCEPTOCOBRO : "asocia"
    CONCEPTOCOBRO ||--o{ PROPIEDADCONCEPTOCOBRO : "se aplica a"

    PROPIEDAD ||--o{ FACTURA : "genera"
    FACTURA   ||--o{ DETALLEFACTURA : "incluye"
    CONCEPTOCOBRO ||--o{ DETALLEFACTURA : "detalle"

    PAGO ||--o{ PAGOSFACTURA : "aplica"
    FACTURA ||--o{ PAGOSFACTURA : "recibe pago"

    PROPIEDAD ||--o{ ORDEN : "genera orden"
```
