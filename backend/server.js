const express = require('express');
const sql = require('mssql');
const cors = require('cors');
const path = require('path');
const dbConfig = require('./dbconfig');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());


app.use(express.static(path.join(__dirname, '../frontend')));

// - Si TODO está en la misma carpeta que server.js, usarías:
// app.use(express.static(__dirname));

// POOL ÚNICO
let poolPromise = null;
async function getPool() {
  if (!poolPromise) poolPromise = sql.connect(dbConfig);
  return poolPromise;
}

/* =======================================
   LOGIN
   ======================================= */
app.post('/api/login', async (req, res) => {
  try {
    const { username, password } = req.body || {};
    if (!username || !password)
      return res.status(400).json({ ok: false, msg: "Debe enviar usuario y contraseña." });

    const pool = await getPool();
    const result = await pool.request()
      .input("Login", sql.VarChar(50), username)
      .input("Password", sql.VarChar(100), password)
      .execute("sp_web_login");

    const row = result.recordset?.[0];
    if (!row) return res.status(401).json({ ok: false, msg: "Credenciales incorrectas." });

    return res.json({
      ok: true,
      user: {
        usuarioId: row.UsuarioID,
        personaId: row.PersonaID,
        nombre: row.Nombre,
        login: row.UsuarioLogin,
        rol: row.Rol
      }
    });
  } catch (err) {
    console.error('Error en /api/login:', err);
    return res.status(500).json({ ok: false, msg: "Error al iniciar sesión." });
  }
});

/* =======================================
   ADMIN – USUARIOS (TABLA SUPERIOR)
   ======================================= */
app.get('/api/admin/usuarios', async (req, res) => {
  try {
    const pool = await getPool();
    const result = await pool.request().execute("sp_web_admin_usuarios");

    return res.json({
      ok: true,
      usuarios: result.recordset?.map(r => ({
        usuarioId: r.UsuarioID,
        login: r.UsuarioLogin,
        rol: r.Rol,
        nombre: r.Nombre
      })) || []
    });

  } catch (err) {
    console.error('Error en /api/admin/usuarios:', err);
    return res.status(500).json({ ok: false, msg: "Error al obtener usuarios." });
  }
});

/* =======================================
   ADMIN – LISTA COMPLETA DE CLIENTES (COMBO)
   ======================================= */
app.get('/api/admin/clientes-todos', async (req, res) => {
  try {
    const pool = await getPool();
    const result = await pool.request()
      .execute('sp_web_admin_clientes_todos');

    return res.json({
      ok: true,
      clientes: (result.recordset || []).map(r => ({
        personaId: r.PersonaID,
        identificacion: r.Identificacion,
        nombre: r.NombrePersona,
        finca: r.Finca,
        usuarioId: r.UsuarioID,
        usuarioLogin: r.UsuarioLogin,
        rol: r.Rol
      }))
    });
  } catch (err) {
    console.error('Error en /api/admin/clientes-todos:', err);
    return res.status(500).json({ ok: false, msg: 'Error al listar clientes.' });
  }
});

/* =======================================
   ADMIN – BUSCAR CLIENTE (TABLA "Buscar")
   ======================================= */
app.get('/api/admin/buscar-cliente', async (req, res) => {
  const { tipo, valor } = req.query || {};
  if (!tipo || !valor) {
    return res.status(400).json({ error: "Debe indicar tipo y valor." });
  }

  try {
    const pool = await getPool();
    const result = await pool.request()
      .input("TipoBusqueda", sql.VarChar(20), String(tipo).toUpperCase())
      .input("Valor", sql.VarChar(64), valor)
      .execute("sp_web_admin_buscar_cliente");

    // El front espera directamente un array de filas
    res.json(result.recordset || []);
  } catch (err) {
    console.error('Error en /api/admin/buscar-cliente:', err);
    res.status(500).json({ error: "Error al buscar cliente." });
  }
});

/* =======================================
   ADMIN – BITÁCORA
   ======================================= */
app.get('/api/admin/bitacora', async (req, res) => {
  const { tabla, desde, hasta } = req.query || {};

  try {
    const pool = await getPool();
    const request = pool.request();
    request.input("Tabla", sql.NVarChar(128), tabla || null);
    request.input("Desde", sql.Date, desde || null);
    request.input("Hasta", sql.Date, hasta || null);

    const result = await request.execute("sp_web_admin_bitacora");
    // El front espera un array
    res.json(result.recordset || []);
  } catch (err) {
    console.error('Error en /api/admin/bitacora:', err);
    res.status(500).json({ error: "Error al cargar bitácora." });
  }
});

/* =======================================
   ADMIN – PRUEBAS MASIVAS (BOTONES)
   ======================================= */

// 1) Emitir facturación mensual
app.post('/api/admin/test/facturar', async (req, res) => {
  try {
    const pool = await getPool();
    await pool.request().execute('sp_tp3_facturar_mes');
    return res.json({ ok: true, msg: 'Facturación mensual ejecutada.' });
  } catch (err) {
    console.error('Error facturar:', err);
    return res.status(500).json({ ok: false, msg: 'Error al ejecutar facturación mensual.' });
  }
});

// 2) Procesar intereses de mora
app.post('/api/admin/test/intereses', async (req, res) => {
  try {
    const pool = await getPool();
    await pool.request().execute('sp_tp3_procesar_intereses');
    return res.json({ ok: true, msg: 'Intereses de mora procesados.' });
  } catch (err) {
    console.error('Error intereses:', err);
    return res.status(500).json({ ok: false, msg: 'Error al procesar intereses.' });
  }
});

// 3) Procesar pagos del XML de un día
app.post('/api/admin/test/pagos', async (req, res) => {
  try {
    const pool = await getPool();
    await pool.request().execute('sp_tp3_procesar_pagos_xml');
    return res.json({ ok: true, msg: 'Pagos del XML procesados.' });
  } catch (err) {
    console.error('Error pagos:', err);
    return res.status(500).json({ ok: false, msg: 'Error al procesar pagos XML.' });
  }
});

// 4) Procesar rango completo de XML
app.post('/api/admin/test/rango', async (req, res) => {
  try {
    const pool = await getPool();
    await pool.request().execute('sp_tp3_procesar_rango_xml');
    return res.json({ ok: true, msg: 'Rango completo de XML procesado.' });
  } catch (err) {
    console.error('Error rango:', err);
    return res.status(500).json({ ok: false, msg: 'Error al procesar rango XML.' });
  }
});

/* =======================================
   ADMIN – REPORTES (Morosidad, PagosXML, etc.)
   ======================================= */
app.get('/api/admin/report', async (req, res) => {
  const { tipo } = req.query || {};
  if (!tipo) {
    return res.status(400).json({ error: 'Debe indicar el tipo de reporte.' });
  }

  try {
    const pool = await getPool();
    let spName;

    // Ajusta estos nombres de SP a los que tú hayas creado en SQL
    switch (tipo) {
      case 'morosidad':
        spName = 'sp_web_admin_reporte_morosidad';
        break;
      case 'pagosxml':
        spName = 'sp_web_admin_reporte_pagos_xml';
        break;
      case 'pagosweb':
        spName = 'sp_web_admin_reporte_pagos_web';
        break;
      case 'consumo':
        spName = 'sp_web_admin_reporte_consumo';
        break;
      default:
        return res.status(400).json({ error: 'Tipo de reporte no válido.' });
    }

    const result = await pool.request().execute(spName);
    const rows = result.recordset || [];
    const columns = rows.length ? Object.keys(rows[0]) : [];

    // El front espera { columns: [...], rows: [...] }
    return res.json({ columns, rows });
  } catch (err) {
    console.error('Error en /api/admin/report:', err);
    return res.status(500).json({ error: 'Error al generar el reporte.' });
  }
});

/* =======================================
   CLIENTE – PROPIEDADES
   ======================================= */
app.get('/api/client/propiedades', async (req, res) => {
  const usuarioId = parseInt(req.query.usuarioId, 10);
  if (!usuarioId) return res.status(400).json({ ok: false, msg: "usuarioId requerido" });

  try {
    const pool = await getPool();
    const result = await pool.request()
      .input("UsuarioID", sql.Int, usuarioId)
      .execute("sp_web_client_propiedades");

    return res.json({
      ok: true,
      propiedades: result.recordset?.map(r => ({
        propiedadId: r.PropiedadID,
        finca: r.Finca,
        zona: r.Zona,
        uso: r.Uso,
        fechaRegistro: r.FechaRegistro,
        deudaPendiente: r.DeudaPendiente
      })) || []
    });

  } catch (err) {
    console.error('Error en /api/client/propiedades:', err);
    return res.status(500).json({ ok: false, msg: "Error al obtener propiedades" });
  }
});

/* =======================================
   CLIENTE – FACTURAS
   ======================================= */
app.get('/api/client/facturas', async (req, res) => {
  const usuarioId = parseInt(req.query.usuarioId, 10);
  if (!usuarioId) return res.status(400).json({ ok: false, msg: "usuarioId requerido" });

  try {
    const pool = await getPool();
    const result = await pool.request()
      .input("UsuarioID", sql.Int, usuarioId)
      .execute("sp_web_client_facturas");

    return res.json({
      ok: true,
      facturas: result.recordset?.map(r => ({
        facturaId: r.FacturaID,
        numero: r.FacturaID,
        finca: r.Finca,
        periodoTexto: r.PeriodoTexto,
        fechaEmision: r.FechaEmision,
        fechaVencimiento: r.FechaVencimiento,
        servicio: r.Servicio,
        montoColones: r.Total,
        estado: r.Estado
      })) || []
    });

  } catch (err) {
    console.error('Error en /api/client/facturas:', err);
    return res.status(500).json({ ok: false, msg: "Error al obtener facturas" });
  }
});

/* =======================================
   CLIENTE – PAGOS
   ======================================= */
app.get('/api/client/pagos', async (req, res) => {
  const usuarioId = parseInt(req.query.usuarioId, 10);
  if (!usuarioId) return res.status(400).json({ ok: false, msg: "usuarioId requerido" });

  try {
    const pool = await getPool();
    const result = await pool.request()
      .input("UsuarioID", sql.Int, usuarioId)
      .execute("sp_web_client_pagos");

    return res.json({
      ok: true,
      pagos: result.recordset?.map(r => ({
        pagoId: r.PagoID,
        fecha: r.Fecha,
        facturaId: r.FacturaID,
        detalle: r.Referencia,
        montoColones: r.Monto,
        medio: r.Medio
      })) || []
    });

  } catch (err) {
    console.error('Error en /api/client/pagos:', err);
    return res.status(500).json({ ok: false, msg: "Error al obtener pagos" });
  }
});

/* =======================================
   CLIENTE – PAGAR FACTURA DESDE PORTAL
   ======================================= */
app.post('/api/client/pagar', async (req, res) => {
  const { usuarioId, facturaId, medio, referencia } = req.body || {};
  const u = parseInt(usuarioId);
  const f = parseInt(facturaId);

  if (!u || !f) return res.status(400).json({ ok: false, msg: "Datos inválidos" });

  try {
    const pool = await getPool();

    await pool.request()
      .input("UsuarioID", sql.Int, u)
      .input("FacturaID", sql.Int, f)
      .input("Medio", sql.VarChar(32), medio || "WEB")
      .input("Ref", sql.VarChar(64), referencia || "PAGO_PORTAL_WEB")
      .execute("sp_web_pagar_factura_usuario");

    res.json({ ok: true, msg: "Pago realizado correctamente." });

  } catch (err) {
    console.error('Error en /api/client/pagar:', err);
    return res.status(400).json({ ok: false, msg: err.message });
  }
});

/* =======================================
   ERROR GLOBAL
   ======================================= */
app.use((err, req, res, next) => {
  console.error('Middleware error global:', err);
  res.status(500).json({ ok: false, msg: "Error inesperado en el servidor." });
});

/* =======================================
   SERVIDOR
   ======================================= */
app.listen(PORT, () => {
  console.log(`Servidor en http://localhost:${PORT}`);
});
