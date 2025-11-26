// backend/server.js
const express = require('express');
const cors = require('cors');

const app = express();
const PORT = 3000;

// Middlewares básicos
app.use(cors());
app.use(express.json());

// Endpoint de prueba
app.get('/api/ping', (req, res) => {
  res.json({ ok: true, msg: 'pong desde backend Tarea3' });
});

// Aquí luego vamos a ir agregando /api/login, /api/propiedades, etc.

// Arrancar servidor
app.listen(PORT, () => {
  console.log(`Backend Tarea3 escuchando en http://localhost:${PORT}`);
});
