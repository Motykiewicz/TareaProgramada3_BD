// server.js
const express = require('express');
const sql = require('mssql');
const cors = require('cors');
const path = require('path');
const dbConfig = require('./dbconfig'); // mismo archivo que ya tienes

const app = express();
const PORT = 3000;

// Middlewares
app.use(cors());
app.use(express.json());

// Servir frontend estático
app.use(express.static(path.join(__dirname, '../frontend')));

/* =========================================================
   Helper para obtener / reutilizar el pool de conexión
   ========================================================= */
async function getPool() {
  // sql.connect reutiliza el pool si ya está creado
  const pool = await sql.connect(dbConfig);
  return pool;
}

/* =========================================================
   POST /api/login
   Llama a: dbo.sp_web_login (@Login, @Password)
   ========================================================= */
app.post('/api/login', async (req, res) => {
  try {
    const { username, password } = req.body || {};

    if (!username || !password) {
      return res
        .status(400)
        .json({ ok: false, msg: 'Debe enviar usuario y contraseña.' });
    }

    const pool = await getPool();
    const result = await pool
      .request()
      .input('Login', sql.VarChar(50), username)
      .input('Password', sql.VarChar(100), password)
      .execute('sp_web_login');

    const rows = result.recordset || [];

    if (rows.length === 0) {
      return res
        .status(401)
        .json({ ok: false, msg: 'Usuario o contraseña incorrectos.' });
    }

    const row = rows[0];

    const user = {
      usuarioId: row.UsuarioID,
      personaId: row.PersonaID,
      nombre: row.Nombre,
      login: row.UsuarioLogin,
      rol: row.Rol
    };

    return res.json({ ok: true, user });
  } catch (err) {
    console.error('Error en /api/login:', err);
    return res
      .status(500)
      .json({ ok: false, msg: 'Error al iniciar sesión.' });
  }
});

/* =========================================================
   GET /api/admin/usuarios
   Llama a: dbo.sp_web_admin_usuarios
   ========================================================= */
app.get('/api/admin/usuarios', async (req, res) => {
  try {
    const pool = await getPool();
    const result = await pool.request().execute('sp_web_admin_usuarios');

    const usuarios = (result.recordset || []).map((row) => ({
      usuarioId: row.UsuarioID,
      login: row.UsuarioLogin,
      rol: row.Rol,
      nombre: row.Nombre
    }));

    return res.json({ ok: true, usuarios });
  } catch (err) {
    console.error('Error en /api/admin/usuarios:', err);
    return res
      .status(500)
      .json({ ok: false, msg: 'Error al obtener usuarios.' });
  }
});

/* =========================================================
   GET /api/client/propiedades
   Llama a: dbo.sp_web_client_propiedades
   Query: ?usuarioId=#
   ========================================================= */
app.get('/api/client/propiedades', async (req, res) => {
  try {
    const usuarioId = parseInt(req.query.usuarioId, 10);

    if (!usuarioId || Number.isNaN(usuarioId)) {
      return res
        .status(400)
        .json({ ok: false, msg: 'Debe indicar un usuarioId válido.' });
    }

    const pool = await getPool();
    const result = await pool
      .request()
      .input('UsuarioID', sql.Int, usuarioId)
      .execute('sp_web_client_propiedades');

    const propiedades = (result.recordset || []).map((row) => ({
      propiedadId: row.PropiedadID,
      finca: row.Finca,
      zona: row.Zona,
      uso: row.Uso,
      fechaRegistro: row.FechaRegistro,
      deudaPendiente: row.DeudaPendiente
    }));

    return res.json({ ok: true, propiedades });
  } catch (err) {
    console.error('Error en /api/client/propiedades:', err);
    return res
      .status(500)
      .json({ ok: false, msg: 'Error al obtener propiedades del cliente.' });
  }
});

/* =========================================================
   GET /api/client/facturas
   Llama a: dbo.sp_web_client_facturas
   Query: ?usuarioId=#
   ========================================================= */
app.get('/api/client/facturas', async (req, res) => {
  try {
    const usuarioId = parseInt(req.query.usuarioId, 10);

    if (!usuarioId || Number.isNaN(usuarioId)) {
      return res
        .status(400)
        .json({ ok: false, msg: 'Debe indicar un usuarioId válido.' });
    }

    const pool = await getPool();
    const result = await pool
      .request()
      .input('UsuarioID', sql.Int, usuarioId)
      .execute('sp_web_client_facturas');

    const facturas = (result.recordset || []).map((row, idx) => ({
      id: row.FacturaID,
      facturaId: row.FacturaID,
      numero: row.FacturaID ?? row.numero ?? `#${idx + 1}`,
      finca: row.Finca,
      fechaEmision: row.FechaEmision,
      fechaVencimiento: row.FechaVencimiento,
      periodoTexto: row.PeriodoTexto || null, // si luego lo agregás al SP
      servicio: row.Servicio || 'Servicios municipales',
      montoColones: row.Total ?? row.montoColones ?? 0,
      estado: row.Estado ?? 'PENDIENTE'
    }));

    return res.json({ ok: true, facturas });
  } catch (err) {
    console.error('Error en /api/client/facturas:', err);
    return res
      .status(500)
      .json({ ok: false, msg: 'Error al obtener facturas del cliente.' });
  }
});

/* =========================================================
   GET /api/client/pagos
   Llama a: dbo.sp_web_client_pagos
   Query: ?usuarioId=#
   ========================================================= */
app.get('/api/client/pagos', async (req, res) => {
  try {
    const usuarioId = parseInt(req.query.usuarioId, 10);

    if (!usuarioId || Number.isNaN(usuarioId)) {
      return res
        .status(400)
        .json({ ok: false, msg: 'Debe indicar un usuarioId válido.' });
    }

    const pool = await getPool();
    const result = await pool
      .request()
      .input('UsuarioID', sql.Int, usuarioId)
      .execute('sp_web_client_pagos');

    const pagos = (result.recordset || []).map((row) => ({
      pagoId: row.PagoID,
      fecha: row.Fecha,
      facturaId: row.FacturaID,
      detalle: row.Referencia,
      montoColones: row.Monto,
      medio: row.Medio
    }));

    return res.json({ ok: true, pagos });
  } catch (err) {
    console.error('Error en /api/client/pagos:', err);
    return res
      .status(500)
      .json({ ok: false, msg: 'Error al obtener pagos del cliente.' });
  }
});

/* =========================================================
   POST /api/client/pagar
   Llama a: dbo.sp_web_pagar_factura_usuario
   Body: { usuarioId, facturaId, medio, referencia }
   ========================================================= */
app.post('/api/client/pagar', async (req, res) => {
  try {
    const { usuarioId, facturaId, medio, referencia } = req.body || {};

    const usuarioIdNum = parseInt(usuarioId, 10);
    const facturaIdNum = parseInt(facturaId, 10);

    if (!usuarioIdNum || Number.isNaN(usuarioIdNum)) {
      return res
        .status(400)
        .json({ ok: false, msg: 'usuarioId inválido.' });
    }

    if (!facturaIdNum || Number.isNaN(facturaIdNum)) {
      return res
        .status(400)
        .json({ ok: false, msg: 'facturaId inválido.' });
    }

    const medioPago = (medio || 'WEB').substring(0, 32);
    const refPago = (referencia || 'PAGO_PORTAL_WEB').substring(0, 64);

    const pool = await getPool();

    try {
      await pool
        .request()
        .input('UsuarioID', sql.Int, usuarioIdNum)
        .input('FacturaID', sql.Int, facturaIdNum)
        .input('Medio', sql.VarChar(32), medioPago)
        .input('Ref', sql.VarChar(64), refPago)
        .execute('sp_web_pagar_factura_usuario');
    } catch (sqlError) {
      // Si el SP hace RAISERROR con severidad >= 11, cae aquí
      console.error('RAISERROR desde SQL en /api/client/pagar:', sqlError);

      const msg =
        sqlError && sqlError.message
          ? sqlError.message
          : 'No se pudo procesar el pago.';

      return res.status(400).json({ ok: false, msg });
    }

    return res.json({
      ok: true,
      msg: 'Pago realizado correctamente.'
    });
  } catch (err) {
    console.error('Error general en /api/client/pagar:', err);
    return res
      .status(500)
      .json({ ok: false, msg: 'Error inesperado al procesar el pago.' });
  }
});

/* =========================================================
   Middleware de error genérico
   ========================================================= */
app.use((err, req, res, next) => {
  console.error('Error no controlado:', err);
  res
    .status(500)
    .json({ ok: false, msg: 'Error inesperado en el servidor.' });
});

app.listen(PORT, () => {
  console.log(`Servidor escuchando en http://localhost:${PORT}`);
});
