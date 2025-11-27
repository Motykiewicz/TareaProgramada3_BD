const config = {
  user: 'tarea3_user',
  password: 'TuPass_Tarea3_2025',
  server: 'localhost',     // como lo teníamos
  port: 1433,              // o el puerto que hayas puesto antess
  database: 'TP3_Municipalidad',
  options: {
    encrypt: false,
    trustServerCertificate: true
  }
};

module.exports = config;
