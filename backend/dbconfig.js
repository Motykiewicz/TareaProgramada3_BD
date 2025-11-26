const config = {
  user: 'tarea3_user',
  password: 'Tarea3_Segura123',
  server: 'localhost',     // como lo teníamos
  port: 1433,              // o el puerto que hayas puesto antes
  database: 'TP3_Municipalidad',
  options: {
    encrypt: false,
    trustServerCertificate: true
  }
};

module.exports = config;
