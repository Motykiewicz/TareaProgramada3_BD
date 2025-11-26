// backend/server.js
const express = require('express');
const cors = require('cors');
const sql = require('mssql');
const dbConfig = require('./dbconfig');

const app = express();
const PORT = 3000;

// 🔹 Middlewares
app.use(cors());
app.use(express.json());                      // JSON del fetch
app.use(express.urlencoded({ extended: true })); // por si algún form manda x-www-form-urlencoded


// Servir archivos estáticos del frontend
// (carpeta Tarea3BD/frontend)
app.use(express.static(path.join(__dirname, '../frontend')));

// Endpoint de prueba
app.get('/api/ping', (req, res) => {
  res.json({ ok: true, msg: 'pong desde backend Tarea3' });
});

// LOGIN: recibe { username, password } y valida contra la BD
app.post('/api/login', async (req, res) => {
  try {
    const body = req.body || {};
    const userLogin =
      body.login || body.username || body.usuario || body.user || null;
    const userPassword =
      body.password || body.pass || body.contrasena || null;

    if (!userLogin || !userPassword) {
      return res
        .status(400)
        .json({ ok: false, msg: 'Debe enviar usuario y contraseña' });
    }

    const pool = await sql.connect(dbConfig);

    const result = await pool.request()
      .input('login', sql.VarChar(50), userLogin)
      .input('password', sql.VarChar(100), userPassword)
      .query(`
        SELECT TOP 1
          u.UsuarioID,
          u.UsuarioLogin,
          u.Rol,
          p.PersonaID,
          p.Nombre
        FROM dbo.Usuario u
        JOIN dbo.Persona p ON p.PersonaID = u.PersonaID
        WHERE u.UsuarioLogin = @login
          AND u.HashPassword = HASHBYTES('SHA2_256', @password);
      `);

    if (result.recordset.length === 0) {
      return res
        .status(401)
        .json({ ok: false, msg: 'Usuario o contraseña incorrectos' });
    }

    const user = result.recordset[0];

    return res.json({
      ok: true,
      user: {
        id: user.UsuarioID,
        login: user.UsuarioLogin,
        rol: user.Rol,
        nombre: user.Nombre,
      },
    });
  } catch (err) {
    console.error('Error en /api/login', err);
    return res
      .status(500)
      .json({ ok: false, msg: 'Error en el servidor' });
  }
});

//    Admin: 
//    Usuario: admin / Clave: admin123 
//
//    No-Admin: 
//    Usuario: user_f0007 / Clave: user123 
