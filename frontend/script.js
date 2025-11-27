console.log('script.js cargado ✅');

const BASE_URL = 'http://localhost:3000';
const STORAGE_KEY = 't3bd_user';
const IMPERSONATE_KEY = 't3bd_impersonated';

// Se ejecuta en TODAS las páginas
document.addEventListener('DOMContentLoaded', () => {
  initLogin();
  initAdminPage();
  initClientePage();
});

/* ==========================
   Helpers de usuario / sesión
   ========================== */

function getLoggedUser() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function setLoggedUser(user) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(user));
}

function clearLoggedUser() {
  localStorage.removeItem(STORAGE_KEY);
}

function getImpersonatedUser() {
  try {
    const raw = localStorage.getItem(IMPERSONATE_KEY);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function setImpersonatedUser(user) {
  if (!user) {
    localStorage.removeItem(IMPERSONATE_KEY);
  } else {
    localStorage.setItem(IMPERSONATE_KEY, JSON.stringify(user));
  }
}

function getQueryParams() {
  return new URLSearchParams(window.location.search);
}

/* ==========================
   Helpers visuales
   ========================== */

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

function ensureToastContainer() {
  let c = document.getElementById('toast-container');
  if (!c) {
    c = document.createElement('div');
    c.id = 'toast-container';
    document.body.appendChild(c);
  }
  return c;
}

function showToast(message, type = 'info') {
  const container = ensureToastContainer();
  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.textContent = message;

  container.appendChild(toast);

  // Animación de entrada
  setTimeout(() => {
    toast.classList.add('show');
  }, 10);

  // Desaparecer después de 3s
  setTimeout(() => {
    toast.classList.remove('show');
    setTimeout(() => toast.remove(), 300);
  }, 3000);
}

function formatearFechaCorta(fechaValor) {
  if (!fechaValor) return '';
  try {
    const d = new Date(fechaValor);
    if (Number.isNaN(d.getTime())) return String(fechaValor);
    return d.toISOString().substring(0, 10); // yyyy-mm-dd
  } catch {
    return String(fechaValor);
  }
}

/* ==========================
   LOGIN
   ========================== */

function initLogin() {
  const form = document.getElementById('login-form');
  if (!form) return; // No estamos en la página de login

  const inputUser = document.getElementById('username');
  const inputPass = document.getElementById('password');
  const divError = document.getElementById('login-error');

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!inputUser || !inputPass) return;

    const username = inputUser.value.trim();
    const password = inputPass.value.trim();

    if (!username || !password) {
      const msg = 'Por favor ingrese usuario y contraseña.';
      showError(divError, msg);
      showToast(msg, 'error');
      return;
    }

    try {
      const resp = await fetch(`${BASE_URL}/api/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password })
      });

      const data = await resp.json().catch(() => null);

      if (!resp.ok || !data || !data.ok) {
        const msg =
          (data && data.msg) || 'Usuario o contraseña incorrectos.';
        showError(divError, msg);
        showToast(msg, 'error');
        return;
      }

      // Guardar usuario en localStorage
      setLoggedUser(data.user);
      // Limpiar impersonación anterior, por si acaso
      setImpersonatedUser(null);

      // Redirigir según rol
      if (data.user.rol === 'admin') {
        window.location.href = 'dashboard_admin.html';
      } else {
        window.location.href = 'dashboard_cliente.html';
      }
    } catch (err) {
      console.error('Error en login:', err);
      const msg =
        'Ocurrió un error al iniciar sesión. Intente de nuevo.';
      showError(divError, msg);
      showToast(msg, 'error');
    }
  });
}

/* ==========================
   ADMIN
   ========================== */

function initAdminPage() {
  const adminUserLabel = document.getElementById('admin-username');
  const btnLogout = document.getElementById('btn-logout');

  if (!adminUserLabel && !btnLogout) {
    return; // No estamos en la página admin
  }

  const user = getLoggedUser();
  if (!user || user.rol !== 'admin') {
    // Si no hay admin logueado, mandamos al login
    window.location.href = 'login.html';
    return;
  }

  if (adminUserLabel) {
    adminUserLabel.textContent = `Usuario administrador: ${user.login}`;
  }

  if (btnLogout) {
    btnLogout.addEventListener('click', () => {
      clearLoggedUser();
      setImpersonatedUser(null);
      window.location.href = 'login.html';
    });
  }

  // Cargar usuarios si existe la tabla
  loadAdminUsers();
}

async function loadAdminUsers() {
  const tbody = document.getElementById('tbody-usuarios');
  if (!tbody) return;

  tbody.innerHTML = '<tr><td colspan="4">Cargando usuarios...</td></tr>';

  try {
    const resp = await fetch(`${BASE_URL}/api/admin/usuarios`);
    const data = await resp.json().catch(() => null);

    if (!resp.ok || !data || !data.ok || !Array.isArray(data.usuarios)) {
      tbody.innerHTML =
        '<tr><td colspan="4">No se pudieron obtener los usuarios.</td></tr>';
      return;
    }

    if (data.usuarios.length === 0) {
      tbody.innerHTML =
        '<tr><td colspan="4">No hay usuarios en el sistema.</td></tr>';
      return;
    }

    tbody.innerHTML = '';

    data.usuarios.forEach((u) => {
      const tr = document.createElement('tr');

      const tdLogin = document.createElement('td');
      tdLogin.textContent = u.login;

      const tdNombre = document.createElement('td');
      tdNombre.textContent = u.nombre || '';

      const tdRol = document.createElement('td');
      tdRol.textContent = u.rol;

      const tdAccion = document.createElement('td');

      // Botón "Ver como cliente"
      const btn = document.createElement('button');
      btn.className = 'btn-outline';
      btn.textContent = 'Ver como cliente';
      btn.dataset.usuarioId = u.usuarioId;
      btn.dataset.login = u.login;
      btn.dataset.nombre = u.nombre || '';
      btn.dataset.rol = u.rol;

      btn.addEventListener('click', () => {
        const impersonated = {
          usuarioId: u.usuarioId,
          login: u.login,
          nombre: u.nombre,
          rol: u.rol
        };
        setImpersonatedUser(impersonated);
        window.location.href = 'dashboard_cliente.html?from=admin';
      });

      tdAccion.appendChild(btn);

      tr.appendChild(tdLogin);
      tr.appendChild(tdNombre);
      tr.appendChild(tdRol);
      tr.appendChild(tdAccion);

      tbody.appendChild(tr);
    });
  } catch (err) {
    console.error('Error cargando usuarios admin:', err);
    tbody.innerHTML =
      '<tr><td colspan="4">Error al cargar los usuarios.</td></tr>';
  }
}

/* ==========================
   CLIENTE
   ========================== */

function initClientePage() {
  const labelCliente = document.getElementById('cliente-username');
  const labelImpersonation = document.getElementById('cliente-impersonation');
  const btnHeader = document.getElementById('btnClienteHeader');

  if (!labelCliente && !btnHeader) {
    return; // No estamos en la página de cliente
  }

  const params = getQueryParams();
  const fromAdmin = params.get('from') === 'admin';

  const loggedUser = getLoggedUser();
  const impersonatedUser = getImpersonatedUser();

  let effectiveUser = null;

  if (fromAdmin && impersonatedUser && impersonatedUser.usuarioId) {
    effectiveUser = impersonatedUser;
  } else {
    effectiveUser = loggedUser;
  }

  if (!effectiveUser) {
    window.location.href = 'login.html';
    return;
  }

  // Mostrar quién es el cliente
  if (labelCliente) {
    const nombreMostrar =
      effectiveUser.nombre && effectiveUser.nombre.trim().length > 0
        ? effectiveUser.nombre
        : effectiveUser.login;
    labelCliente.textContent = `Cliente: ${nombreMostrar}`;
  }

  // Etiqueta de "modo administrador"
  if (labelImpersonation) {
    if (
      fromAdmin &&
      impersonatedUser &&
      loggedUser &&
      loggedUser.rol === 'admin'
    ) {
      labelImpersonation.textContent = `Modo administrador: viendo como ${effectiveUser.login}`;
      labelImpersonation.style.display = 'block';
    } else {
      labelImpersonation.textContent = '';
      labelImpersonation.style.display = 'none';
    }
  }

  // Configurar botón de cabecera
  if (btnHeader) {
    if (fromAdmin) {
      btnHeader.textContent = '← Volver al panel administrador';
      btnHeader.addEventListener('click', () => {
        window.location.href = 'dashboard_admin.html';
      });
    } else {
      btnHeader.textContent = 'Cerrar sesión';
      btnHeader.addEventListener('click', () => {
        clearLoggedUser();
        setImpersonatedUser(null);
        window.location.href = 'login.html';
      });
    }
  }

  // Cargar propiedades, facturas y pagos para el usuario efectivo
  loadClientePropiedades(effectiveUser.usuarioId);
  loadClienteFacturas(effectiveUser.usuarioId);
  loadClientePagos(effectiveUser.usuarioId);

  // Delegación de eventos para botones "Pagar"
  const tbodyFacturas = document.getElementById('tbody-facturas-pendientes');
  if (tbodyFacturas) {
    tbodyFacturas.addEventListener('click', (ev) => {
      const target = ev.target;
      if (target && target.matches('button.btn-pay')) {
        const facturaId = target.dataset.facturaId;
        if (facturaId) {
          hacerPagoFactura(effectiveUser.usuarioId, facturaId, target);
        }
      }
    });
  }
}

/* ==========================
   Propiedades del cliente
   ========================== */

async function loadClientePropiedades(usuarioId) {
  const tbody = document.getElementById('tbody-propiedades');
  if (!tbody) return;

  tbody.innerHTML =
    '<tr><td colspan="5">Cargando propiedades...</td></tr>';

  // Referencias a las etiquetas del resumen
  const lblTotalProps = document.getElementById('resumen-total-propiedades');
  const lblDeudaTotal = document.getElementById('resumen-deuda-total');

  try {
    const resp = await fetch(
      `${BASE_URL}/api/client/propiedades?usuarioId=${encodeURIComponent(
        usuarioId
      )}`
    );
    const data = await resp.json().catch(() => null);

    // Si hubo error en la respuesta
    if (!resp.ok || !data || !data.ok || !Array.isArray(data.propiedades)) {
      tbody.innerHTML =
        '<tr><td colspan="5">No se pudieron obtener las propiedades.</td></tr>';

      if (lblTotalProps) lblTotalProps.textContent = '0';
      if (lblDeudaTotal) lblDeudaTotal.textContent = '₡0';
      return;
    }

    // Si no tiene propiedades
    if (data.propiedades.length === 0) {
      tbody.innerHTML =
        '<tr><td colspan="5">Este usuario no tiene propiedades asociadas.</td></tr>';

      if (lblTotalProps) lblTotalProps.textContent = '0';
      if (lblDeudaTotal) lblDeudaTotal.textContent = '₡0';
      return;
    }

    // Aquí ya SÍ hay propiedades
    tbody.innerHTML = '';

    let totalPropiedades = data.propiedades.length;
    let totalDeuda = 0;

    data.propiedades.forEach((p) => {
      // asegurar que la deuda sea número
      let deuda = Number(p.deudaPendiente ?? p.deuda_total ?? 0);
      if (Number.isNaN(deuda)) deuda = 0;
      totalDeuda += deuda;

      const tr = document.createElement('tr');

      const tdFinca = document.createElement('td');
      tdFinca.textContent = p.finca;

      const tdZona = document.createElement('td');
      tdZona.textContent = p.zona || '—';

      const tdUso = document.createElement('td');
      tdUso.textContent = p.uso || '—';

      const tdFecha = document.createElement('td');
      tdFecha.textContent = formatearFechaCorta(p.fechaRegistro);

      const tdDeuda = document.createElement('td');
      tdDeuda.textContent = `₡${deuda.toLocaleString('es-CR')}`;

      tr.appendChild(tdFinca);
      tr.appendChild(tdZona);
      tr.appendChild(tdUso);
      tr.appendChild(tdFecha);
      tr.appendChild(tdDeuda);

      tbody.appendChild(tr);
    });

    // Actualizar el resumen arriba
    if (lblTotalProps) {
      lblTotalProps.textContent = String(totalPropiedades);
    }
    if (lblDeudaTotal) {
      lblDeudaTotal.textContent = `₡${totalDeuda.toLocaleString('es-CR')}`;
    }
  } catch (err) {
    console.error('Error cargando propiedades cliente:', err);
    tbody.innerHTML =
      '<tr><td colspan="5">Error al cargar las propiedades.</td></tr>';

    if (lblTotalProps) lblTotalProps.textContent = '0';
    if (lblDeudaTotal) lblDeudaTotal.textContent = '₡0';
  }
}


/* ==========================
   Facturas del cliente
   ========================== */

async function loadClienteFacturas(usuarioId) {
  const tbody = document.getElementById('tbody-facturas-pendientes');
  if (!tbody) return;

  tbody.innerHTML =
    '<tr><td colspan="7">Cargando facturas pendientes...</td></tr>';

  try {
    const resp = await fetch(
      `${BASE_URL}/api/client/facturas?usuarioId=${encodeURIComponent(
        usuarioId
      )}`
    );
    const data = await resp.json().catch(() => null);

    if (!resp.ok || !data || !data.ok || !Array.isArray(data.facturas)) {
      tbody.innerHTML =
        '<tr><td colspan="7">No se pudieron obtener las facturas.</td></tr>';
      return;
    }

    if (data.facturas.length === 0) {
      tbody.innerHTML =
        '<tr><td colspan="7">No hay facturas pendientes para este usuario (todo al día).</td></tr>';
      return;
    }

    tbody.innerHTML = '';

    data.facturas.forEach((f) => {
      const tr = document.createElement('tr');

      const tdNum = document.createElement('td');
      tdNum.textContent = f.facturaId ?? f.numero;

      const tdPeriodo = document.createElement('td');
      tdPeriodo.textContent = f.periodoTexto || '—';

      const tdServicio = document.createElement('td');
      tdServicio.textContent = f.servicio || 'Servicios municipales';

      const tdMonto = document.createElement('td');
      tdMonto.textContent = `₡${Number(f.montoColones || 0).toLocaleString(
        'es-CR'
      )}`;

      const tdVence = document.createElement('td');
      tdVence.textContent = formatearFechaCorta(f.fechaVencimiento);

      const tdEstado = document.createElement('td');
      tdEstado.textContent = f.estado || 'PENDIENTE';

      const tdAccion = document.createElement('td');

      const btnPagar = document.createElement('button');
      btnPagar.className = 'btn-primary btn-pay';
      btnPagar.textContent = 'Pagar';
      btnPagar.dataset.facturaId = f.facturaId;

      tdAccion.appendChild(btnPagar);

      tr.appendChild(tdNum);
      tr.appendChild(tdPeriodo);
      tr.appendChild(tdServicio);
      tr.appendChild(tdMonto);
      tr.appendChild(tdVence);
      tr.appendChild(tdEstado);
      tr.appendChild(tdAccion);

      tbody.appendChild(tr);
    });
  } catch (err) {
    console.error('Error cargando facturas cliente:', err);
    tbody.innerHTML =
      '<tr><td colspan="7">Error al cargar facturas pendientes.</td></tr>';
  }
}

/* ==========================
   Pagos del cliente
   ========================== */

async function loadClientePagos(usuarioId) {
  const tbody = document.getElementById('tbody-historial-pagos');
  if (!tbody) return;

  tbody.innerHTML =
    '<tr><td colspan="5">Cargando historial de pagos...</td></tr>';

  try {
    const resp = await fetch(
      `${BASE_URL}/api/client/pagos?usuarioId=${encodeURIComponent(
        usuarioId
      )}`
    );
    const data = await resp.json().catch(() => null);

    if (!resp.ok || !data || !data.ok || !Array.isArray(data.pagos)) {
      tbody.innerHTML =
        '<tr><td colspan="5">No se pudo obtener el historial de pagos.</td></tr>';
      return;
    }

    if (data.pagos.length === 0) {
      tbody.innerHTML =
        '<tr><td colspan="5">Este usuario aún no tiene pagos registrados.</td></tr>';
      return;
    }

    tbody.innerHTML = '';

    data.pagos.forEach((p) => {
      const tr = document.createElement('tr');

      const tdFecha = document.createElement('td');
      tdFecha.textContent = formatearFechaCorta(p.fecha);

      const tdFactura = document.createElement('td');
      tdFactura.textContent = p.facturaId;

      const tdDetalle = document.createElement('td');
      tdDetalle.textContent = p.detalle || '';

      const tdMonto = document.createElement('td');
      tdMonto.textContent = `₡${Number(p.montoColones || 0).toLocaleString(
        'es-CR'
      )}`;

      const tdMedio = document.createElement('td');
      tdMedio.textContent = p.medio || '';

      tr.appendChild(tdFecha);
      tr.appendChild(tdFactura);
      tr.appendChild(tdDetalle);
      tr.appendChild(tdMonto);
      tr.appendChild(tdMedio);

      tbody.appendChild(tr);
    });
  } catch (err) {
    console.error('Error cargando pagos cliente:', err);
    tbody.innerHTML =
      '<tr><td colspan="5">Error al cargar el historial de pagos.</td></tr>';
  }
}

/* ==========================
   Pago desde la vista cliente
   ========================== */

async function hacerPagoFactura(usuarioId, facturaId, btn) {
  const confirmar = window.confirm(
    `¿Desea pagar la factura ${facturaId} ahora?`
  );
  if (!confirmar) return;

  let originalText = '';
  if (btn) {
    originalText = btn.textContent;
    btn.disabled = true;
    btn.textContent = 'Procesando...';
  }

  try {
    const referencia = `PAGO_PORTAL_WEB_${Date.now()}`;

    const resp = await fetch(`${BASE_URL}/api/client/pagar`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        usuarioId,
        facturaId,
        medio: 'WEB',
        referencia
      })
    });

    const data = await resp.json().catch(() => null);

    if (!resp.ok || !data || !data.ok) {
      const msg =
        (data && data.msg) ||
        'No se pudo procesar el pago. Verifique la información.';
      showToast(msg, 'error');
      return;
    }

    showToast('Pago realizado correctamente.', 'success');

    // Recargar facturas y pagos
    loadClienteFacturas(usuarioId);
    loadClientePagos(usuarioId);
  } catch (err) {
    console.error('Error al pagar factura:', err);
    showToast('Ocurrió un error al procesar el pago.', 'error');
  } finally {
    if (btn) {
      btn.disabled = false;
      btn.textContent = originalText || 'Pagar';
    }
  }
}
