console.log('script.js cargado ✅');

const BASE_URL = 'http://localhost:3000';

// Se ejecuta en TODAS las páginas que incluyan script.js
document.addEventListener('DOMContentLoaded', () => {
  // 1) Login
  const loginForm = document.getElementById('login-form');
  if (loginForm) {
    console.log('Login JS cargado y listener registrado ✅');
    loginForm.addEventListener('submit', handleLogin);
  }

  // ----- PANEL ADMIN: mostrar usuario y logout -----
  const adminChip = document.getElementById('admin-username');
  if (adminChip) {
    const rawUser = localStorage.getItem('t3bd_user');
    if (rawUser) {
      try {
        const user = JSON.parse(rawUser);
        adminChip.textContent = `Usuario Administrador ${user.login}`;
      } catch (e) {
        console.warn('No se pudo leer t3bd_user para admin:', e);
      }
    }

    const logoutBtn = document.getElementById('btn-logout');
    if (logoutBtn) {
      logoutBtn.addEventListener('click', () => {
        localStorage.removeItem('t3bd_user');
        window.location.href = 'login.html';
      });
    }
  }

  // ----- VISTA CLIENTE: nombre + botón header -----
  const btnClienteHeader = document.getElementById('btnClienteHeader');
  const clienteLabel = document.getElementById('cliente-username');

  if (btnClienteHeader && clienteLabel) {
    const rawUser = localStorage.getItem('t3bd_user');
    if (rawUser) {
      try {
        const user = JSON.parse(rawUser);
        clienteLabel.textContent = `Cliente: ${user.login}`;
      } catch (e) {
        console.warn('No se pudo leer t3bd_user para cliente:', e);
      }
    }

    // Por defecto: usuario normal → botón "Cerrar sesión"
    btnClienteHeader.textContent = 'Cerrar sesión';
    btnClienteHeader.onclick = () => {
      localStorage.removeItem('t3bd_user');
      window.location.href = 'login.html';
    };

    // Si en el futuro navegas como admin a esta vista con ?from=admin
    // ej: dashboard_cliente.html?from=admin
    const params = new URLSearchParams(window.location.search);
    if (params.get('from') === 'admin') {
      btnClienteHeader.textContent = '← Volver al panel administrador';
      btnClienteHeader.onclick = () => {
        window.location.href = 'dashboard_admin.html';
      };
    }
  }
});
// ------------------ Helpers de usuario ------------------ //

function getUserFromStorage() {
  try {
    const raw = localStorage.getItem('userActual');
    if (!raw) return null;
    return JSON.parse(raw);
  } catch (err) {
    console.error('Error leyendo userActual de localStorage', err);
    return null;
  }
}

function initUserHeader() {
  const user = getUserFromStorage();
  if (!user) return;

  const adminUserEl = document.getElementById('admin-username');
  const clienteUserEl = document.getElementById('cliente-username');

  if (adminUserEl) {
    adminUserEl.textContent = `Usuario Administrador ${user.login}`;
  }

  if (clienteUserEl) {
    clienteUserEl.textContent = `Cliente: ${user.login}`;
  }
}

function initNavigationButtons() {
  const btnLogout = document.getElementById('btn-logout');
  if (btnLogout) {
    btnLogout.addEventListener('click', () => {
      localStorage.removeItem('userActual');
      window.location.href = 'login.html';
    });
  }

  const btnBackAdmin = document.getElementById('btn-back-admin');
  if (btnBackAdmin) {
    btnBackAdmin.addEventListener('click', () => {
      window.location.href = 'dashboard_admin.html';
    });
  }
}

// ------------------ LOGIN ------------------ //

async function handleLogin(event) {
  event.preventDefault();

  const usernameInput = document.getElementById('username');
  const passwordInput = document.getElementById('password');
  const errorDiv = document.getElementById('login-error');

  const username = usernameInput.value.trim();
  const password = passwordInput.value.trim();

  if (!username || !password) {
    showError(errorDiv, 'Debe ingresar usuario y contraseña');
    return;
  }

  showError(errorDiv, '');

  try {
    const resp = await fetch(`${BASE_URL}/api/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username,
        password,
      }),
    });

    if (!resp.ok) {
      const errBody = await resp.json().catch(() => null);
      const msg =
        errBody && errBody.msg ? errBody.msg : 'Error en autenticación';
      showError(errorDiv, msg);
      return;
    }

    const data = await resp.json();
    console.log('Respuesta /api/login', data);

    if (!data.ok || !data.user) {
      showError(errorDiv, 'Respuesta inesperada del servidor');
      return;
    }

    // Guardar usuario en localStorage
    localStorage.setItem('userActual', JSON.stringify(data.user));

    // Redirección según rol
    if (data.user.rol === 'admin') {
      window.location.href = 'dashboard_admin.html';
    } else {
      window.location.href = 'dashboard_cliente.html';
    }
  } catch (err) {
    console.error('Error llamando a /api/login', err);
    showError(errorDiv, 'No se pudo conectar con el servidor');
  }
}

// ------------------ Mensajes ------------------ //

function showError(div, message) {
  if (!div) return;
  if (!message) {
    div.style.display = 'none';
    div.textContent = '';
  } else {
    div.style.display = 'block';
    div.textContent = message;
  }
}

// ==========================
//  Botón header en vista de cliente
// ==========================
document.addEventListener('DOMContentLoaded', () => {
  const btnClienteHeader = document.getElementById('btnClienteHeader');
  if (!btnClienteHeader) return; // No estamos en la página de cliente

  // ¿Vino desde el panel admin? Ej: cliente.html?from=admin
  const params = new URLSearchParams(window.location.search);
  const fromAdmin = params.get('from') === 'admin';

  if (fromAdmin) {
    // Caso: admin impersonando a un usuario
    btnClienteHeader.textContent = '← Volver al panel administrador';
    btnClienteHeader.addEventListener('click', () => {
      window.location.href = 'dashboard_admin.html'; // usa el nombre real de tu HTML de admin
    });
  } else {
    // Caso: usuario normal que solo ve su cuenta
    btnClienteHeader.textContent = 'Cerrar sesión';
    btnClienteHeader.addEventListener('click', () => {
      window.location.href = 'login.html'; // vuelve a la pantalla de login
    });
  }
});
