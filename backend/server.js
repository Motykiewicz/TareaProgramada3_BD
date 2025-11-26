// backend/server.js
const express = require('express');
const cors = require('cors');
const sql = require('mssql');
const path = require('path');
const dbConfig = require('./dbconfig');   // <- tu config de SQL Server

const app = express();
const PORT = 3000;

// Middlewares básicos
app.use(cors());
app.use(express.json());

// Servir archivos estáticos del frontend
// (carpeta Tarea3BD/frontend)
app.use(express.static(path.join(__dirname, '../frontend')));

// Endpoint de prueba
app.get('/api/ping', (req, res) => {
  res.json({ ok: true, msg: 'pong desde backend Tarea3' });
});

// LOGIN: recibe { username, password } y valida contra la BD
app.post('/api/login', async (req, res) => {
  const { username, password } = req.body;

  // Validación simple de entrada
  if (!username || !password) {
    return res.status(400).json({
      ok: false,
      msg: 'Debe enviar usuario y contraseña'
    });
  }

  try {
    const pool = await sql.connect(dbConfig);

    const result = await pool.request()
      .input('login', sql.VarChar(50), username)
      .input('pass', sql.VarChar(128), password)
      .query(`
        SELECT 
          u.UsuarioID,
          u.Rol,
          u.UsuarioLogin,
          p.Nombre
        FROM dbo.Usuario u
        JOIN dbo.Persona p ON p.PersonaID = u.PersonaID
        WHERE u.UsuarioLogin = @login
          AND u.HashPassword = HASHBYTES('SHA2_256', @pass);
      `);

    if (result.recordset.length === 0) {
      // Usuario o contraseña no coinciden
      return res.status(401).json({
        ok: false,
        msg: 'Usuario o contraseña incorrectos'
      });
    }

    const user = result.recordset[0];

    // Devolvemos solo lo necesario
    res.json({
      ok: true,
      user: {
        id: user.UsuarioID,
        rol: user.Rol,           // 'admin' o 'no-admin'
        login: user.UsuarioLogin,
        nombre: user.Nombre
      }
    });
  } catch (err) {
    console.error('Error en /api/login:', err);
    res.status(500).json({
      ok: false,
      msg: 'Error en el servidor',
      error: err.message
    });
  }
});

// Arrancar servidor
app.listen(PORT, () => {
  console.log(`Backend Tarea3 escuchando en http://localhost:${PORT}`);
});


//    Admin: 
//    Usuario: admin / Clave: admin123 
//
//    No-Admin: 
//    Usuario: user_f0007 / Clave: user123 
