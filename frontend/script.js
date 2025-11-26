// frontend/script.js

// --- LOGIN ---
const loginForm = document.getElementById('loginForm');

if (loginForm) {
  loginForm.addEventListener('submit', async (event) => {
    event.preventDefault(); // no recargar la página

    const username = document.getElementById('username').value.trim();
    const password = document.getElementById('password').value.trim();
    const errorBox = document.getElementById('loginError');

    errorBox.textContent = '';

    try {
      const resp = await fetch('/api/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ username, password })
      });

      const data = await resp.json();

      if (!data.ok) {
        errorBox.textContent = data.msg || 'Error al iniciar sesión';
        return;
      }

      // Guardamos la info del usuario en localStorage para usarla en otras páginas
      localStorage.setItem('usuario_tarea3', JSON.stringify(data.user));

      // Redirigir según el rol
      if (data.user.rol === 'admin') {
        window.location.href = 'dashboard_admin.html';   // cuando la tengas
      } else {
        window.location.href = 'dashboard_cliente.html'; // ya tienes una
      }
    } catch (err) {
      console.error(err);
      errorBox.textContent = 'No se pudo conectar con el servidor.';
    }
  });
}

// --- UTILIDAD: mostrar quién está logueado en las otras páginas ---
function mostrarUsuarioConectado() {
  const userJson = localStorage.getItem('usuario_tarea3');
  const banner = document.getElementById('usuarioConectado');

  if (!banner || !userJson) return;

  const user = JSON.parse(userJson);
  banner.textContent = `Estás conectado como ${user.login} (${user.rol})`;
}

mostrarUsuarioConectado();
