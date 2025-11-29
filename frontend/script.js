// --------------------------------------------------------------
// script.js COMPLETO — EXTENDIDO (Bitácora, Reportes, Pruebas,
// Portal cliente e integración con combo de clientes)
// --------------------------------------------------------------

console.log('script.js cargado ');

const BASE_URL = 'http://localhost:3000';
const STORAGE_KEY = 't3bd_user';
const IMPERSONATE_KEY = 't3bd_impersonated';

// =============================================================
// OnLoad
// =============================================================
document.addEventListener('DOMContentLoaded', () => {
  initLogin();
  initAdminPage();
  initClientePage();
});

/* =============================================================
   HELPERS
============================================================= */

function showToast(msg, type = 'info') {
  // Sencillo por ahora; se puede cambiar por un toast bonito
  alert(msg);
}

function formatearFechaCorta(f) {
  if (!f) return '';
  const d = new Date(f);
  if (isNaN(d)) return f;
  return d.toISOString().substring(0, 10);
}

/* =============================================================
   LOGIN
============================================================= */

function initLogin() {
  const form = document.getElementById('login-form');
  if (!form) return;

  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();

    const u = document.getElementById('username').value.trim();
    const p = document.getElementById('password').value.trim();

    if (!u || !p) return showToast('Ingrese usuario y contraseña', 'error');

    const res = await fetch(`${BASE_URL}/api/login`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({username: u, password: p})
    });

    const data = await res.json();

    if (!data.ok) return showToast(data.msg || 'Error', 'error');

    localStorage.setItem(STORAGE_KEY, JSON.stringify(data.user));
    localStorage.removeItem(IMPERSONATE_KEY);

    if (data.user.rol === 'admin') location.href = 'dashboard_admin.html';
    else location.href = 'dashboard_cliente.html';
  });
}

/* =============================================================
   ADMIN PAGE
============================================================= */

function initAdminPage() {
  const lblAdmin = document.getElementById('admin-username');
  if (!lblAdmin) return; // no estamos en dashboard_admin

  const user = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null');
  if (!user || user.rol !== 'admin') return location.href = 'login.html';

  lblAdmin.textContent = `Usuario administrador: ${user.login}`;
  const btnLogout = document.getElementById('btn-logout');
  if (btnLogout) {
    btnLogout.onclick = () => {
      localStorage.removeItem(STORAGE_KEY);
      localStorage.removeItem(IMPERSONATE_KEY);
      location.href = 'login.html';
    };
  }

  loadAdminUsers();
  initAdminSearch();
  initBitacora();
  initAdminTests();
  initAdminReports();
}

/* =============================================================
   ADMIN — USUARIOS
============================================================= */

async function loadAdminUsers() {
  const tbody = document.getElementById('tbody-usuarios');
  if (!tbody) return;

  tbody.innerHTML = '<tr><td colspan="4">Cargando...</td></tr>';

  try {
    const res = await fetch(`${BASE_URL}/api/admin/usuarios`);
    const data = await res.json();

    if (!data.ok || !Array.isArray(data.usuarios)) {
      tbody.innerHTML = '<tr><td colspan="4">Error cargando usuarios</td></tr>';
      return;
    }

    tbody.innerHTML = '';

    data.usuarios.forEach(u => {
      const tr = document.createElement('tr');

      tr.innerHTML = `
        <td>${u.login}</td>
        <td>${u.nombre || ''}</td>
        <td>${u.rol}</td>
        <td>
          <button class="btn-outline btn-impersonar"
                  data-id="${u.usuarioId}"
                  data-login="${u.login}"
                  data-nombre="${u.nombre}">
            Ver como cliente
          </button>
        </td>
      `;

      tbody.appendChild(tr);
    });

    tbody.querySelectorAll('.btn-impersonar').forEach(btn => {
      btn.onclick = () => {
        const imp = {
          usuarioId: Number(btn.dataset.id),
          login: btn.dataset.login,
          nombre: btn.dataset.nombre,
          rol: 'no-admin'
        };
        localStorage.setItem(IMPERSONATE_KEY, JSON.stringify(imp));
        location.href = 'dashboard_cliente.html?from=admin';
      };
    });
  } catch (err) {
    console.error('Error cargando usuarios admin:', err);
    tbody.innerHTML = '<tr><td colspan="4">Error cargando usuarios</td></tr>';
  }
}

/* =============================================================
   ADMIN — BUSCAR CLIENTE + COMBO
============================================================= */

function initAdminSearch() {
  const form    = document.getElementById('admin-search-form');
  const tipo    = document.getElementById('admin-search-type');
  const valor   = document.getElementById('admin-search-value');
  const wrapper = document.getElementById('admin-search-table-wrapper');
  const empty   = document.getElementById('admin-search-empty');
  const tbody   = document.getElementById('tbody-admin-busqueda');

  if (!form) return; // no estamos en dashboard_admin

  // ==== NUEVO: combo de clientes ====
  const combo = document.getElementById('admin-clientes-list');
  if (combo) {
    cargarComboClientes(combo, tipo, valor, form);
  }
  // ==================================

  form.onsubmit = async (ev) => {
    ev.preventDefault();

    empty.textContent = 'Buscando...';
    wrapper.style.display = 'none';
    tbody.innerHTML = '';

    const params = new URLSearchParams();
    params.append('tipo', tipo.value);
    params.append('valor', valor.value.trim());

    try {
      const res = await fetch(`${BASE_URL}/api/admin/buscar-cliente?${params}`);
      const data = await res.json();

      if (!data || data.length === 0) {
        empty.textContent = 'No se encontraron resultados.';
        return;
      }

      empty.textContent = '';
      wrapper.style.display = 'block';
      tbody.innerHTML = '';

      data.forEach(r => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td>${r.UsuarioLogin || '-'}</td>
          <td>${r.NombrePersona}</td>
          <td>${r.Identificacion || '-'}</td>
          <td>${r.Finca || '-'}</td>
          <td>
            ${
              r.UsuarioID
                ? `<button class="btn-chip btn-impersonar2"
                           data-id="${r.UsuarioID}"
                           data-login="${r.UsuarioLogin}"
                           data-nombre="${r.NombrePersona}">
                     Ver como cliente
                   </button>`
                : '<span style="font-size:0.8rem;color:#666;">Sin usuario</span>'
            }
          </td>
        `;
        tbody.appendChild(tr);
      });

      tbody.querySelectorAll('.btn-impersonar2').forEach(btn => {
        btn.onclick = () => {
          const imp = {
            usuarioId: Number(btn.dataset.id),
            login: btn.dataset.login,
            nombre: btn.dataset.nombre,
            rol: 'no-admin'
          };
          localStorage.setItem(IMPERSONATE_KEY, JSON.stringify(imp));
          location.href = 'dashboard_cliente.html?from=admin';
        };
      });
    } catch (err) {
      console.error('Error en búsqueda admin:', err);
      empty.textContent = 'Error al buscar.';
    }
  };

  // Botones de "Casos sugeridos"
  document.querySelectorAll('.suggested-finca').forEach(b => {
    b.onclick = () => {
      tipo.value = 'finca';
      valor.value = b.dataset.finca;
      form.dispatchEvent(new Event('submit'));
    };
  });
}

// ==== NUEVO: función para llenar combo de clientes ====
async function cargarComboClientes(combo, tipoSelect, valorInput, form) {
  try {
    combo.innerHTML = '<option value="">Cargando clientes...</option>';

    const res = await fetch(`${BASE_URL}/api/admin/clientes-todos`);
    const data = await res.json();

    if (!data.ok || !data.clientes || data.clientes.length === 0) {
      combo.innerHTML = '<option value="">Sin clientes para listar</option>';
      return;
    }

    combo.innerHTML = '<option value="">-- Seleccione un cliente --</option>';

    data.clientes.forEach(c => {
      const opt = document.createElement('option');
      opt.value = c.finca || c.identificacion;
      opt.dataset.identificacion = c.identificacion || '';
      opt.dataset.finca = c.finca || '';
      opt.textContent = `${c.finca || 'Sin finca'} – ${c.nombre}`;
      combo.appendChild(opt);
    });

    combo.onchange = () => {
      if (!combo.value) return;

      const selected = combo.options[combo.selectedIndex];
      const finca = selected.dataset.finca;
      const ident = selected.dataset.identificacion;

      if (finca) {
        tipoSelect.value = 'finca';
        valorInput.value = finca;
      } else {
        tipoSelect.value = 'identificacion';
        valorInput.value = ident;
      }

      // dispara la búsqueda automáticamente
      form.dispatchEvent(new Event('submit'));
    };
  } catch (err) {
    console.error('Error al cargar combo de clientes:', err);
    combo.innerHTML = '<option value="">Error al cargar clientes</option>';
  }
}

/* =============================================================
   ADMIN — BITÁCORA
============================================================= */

function initBitacora() {
  const btn   = document.getElementById('btn-bitacora-filtrar');
  const desde = document.getElementById('bitacora-desde');
  const hasta = document.getElementById('bitacora-hasta');

  // Rango real del xmlUltimo.xml (AJUSTAR SI EL XML CAMBIA)
  const minDate = '2025-06-01';
  const maxDate = '2025-11-28';

  [desde, hasta].forEach(inp => {
    if (inp) {
      inp.min = minDate;
      inp.max = maxDate;
    }
  });

  if (btn) btn.onclick = loadBitacora;
  loadBitacora();
}

async function loadBitacora() {
  const tabla = document.getElementById('bitacora-tabla')?.value || '';
  const desde = document.getElementById('bitacora-desde')?.value || '';
  const hasta = document.getElementById('bitacora-hasta')?.value || '';

  const tbody = document.getElementById('tbody-bitacora');
  if (!tbody) return;

  tbody.innerHTML = '<tr><td colspan="7">Cargando...</td></tr>';

  const params = new URLSearchParams();
  if (tabla) params.append('tabla', tabla);
  if (desde) params.append('desde', desde);
  if (hasta) params.append('hasta', hasta);

  try {
    const res = await fetch(`${BASE_URL}/api/admin/bitacora?${params}`);
    const data = await res.json();

    if (!Array.isArray(data) || data.length === 0) {
      tbody.innerHTML = '<tr><td colspan="7">Sin datos</td></tr>';
      return;
    }

    tbody.innerHTML = '';

    data.forEach(row => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${formatearFechaCorta(row.Fecha)}</td>
        <td>${row.Tabla}</td>
        <td>${row.PK}</td>
        <td>${row.Usuario || '-'}</td>
        <td>${row.IP || '-'}</td>
        <td>${row.Accion}</td>
        <td>
          <button class="btn-chip btn-ver-detalle"
                  data-antes='${row.JsonAntes || ''}'
                  data-despues='${row.JsonDespues || ''}'>
            Ver
          </button>
        </td>
      `;
      tbody.appendChild(tr);
    });

    document.querySelectorAll('.btn-ver-detalle').forEach(btn => {
      btn.onclick = () => {
        const modal = document.getElementById('modal-bitacora');
        const pre   = document.getElementById('modal-bitacora-pre');
        if (!modal || !pre) return;

        modal.classList.remove('hidden');
        pre.textContent =
          'ANTES:\n' + (btn.dataset.antes || '-') +
          '\n\nDESPUÉS:\n' + (btn.dataset.despues || '-');
      };
    });

    const closeBtn = document.getElementById('close-modal-bitacora');
    if (closeBtn) {
      closeBtn.onclick = () => {
        const modal = document.getElementById('modal-bitacora');
        if (modal) modal.classList.add('hidden');
      };
    }
  } catch (err) {
    console.error('Error cargando bitácora:', err);
    tbody.innerHTML = '<tr><td colspan="7">Error cargando bitácora</td></tr>';
  }
}

/* =============================================================
   ADMIN — PRUEBAS MASIVAS
============================================================= */

function initAdminTests() {
  document.querySelectorAll('.admin-test-btn').forEach(btn => {
    btn.onclick = () => runAdminTest(btn.dataset.action);
  });
}

async function runAdminTest(action) {
  const out = document.getElementById('admin-test-output');
  if (!out) return;

  out.textContent = 'Procesando...';

  const map = {
    facturar: 'facturar',
    intereses: 'intereses',
    pagos: 'pagos',
    rango: 'rango'
  };

  const endpoint = map[action];
  if (!endpoint) return;

  try {
    const res = await fetch(`${BASE_URL}/api/admin/test/${endpoint}`, { method: 'POST' });
    const data = await res.json();

    if (!data.ok) out.textContent = data.msg || 'Error';
    else out.textContent = data.msg || 'Proceso completado';
  } catch (err) {
    console.error('Error ejecutando prueba admin:', err);
    out.textContent = 'Error ejecutando el proceso';
  }
}

/* =============================================================
   ADMIN — REPORTES
============================================================= */

function initAdminReports() {
  const btn = document.getElementById('btn-report');
  if (!btn) return;

  btn.onclick = loadReport;
}

async function loadReport() {
  const tipo  = document.getElementById('report-type')?.value;
  const thead = document.getElementById('thead-report');
  const tbody = document.getElementById('tbody-report');

  if (!thead || !tbody) return;

  tbody.innerHTML = '<tr><td colspan="10">Cargando...</td></tr>';

  try {
    const res = await fetch(`${BASE_URL}/api/admin/report?tipo=${encodeURIComponent(tipo)}`);
    const data = await res.json();

    if (!data || !data.columns || !data.rows) {
      tbody.innerHTML = '<tr><td colspan="10">Error generando reporte</td></tr>';
      return;
    }

    thead.innerHTML = '<tr>' + data.columns.map(c => `<th>${c}</th>`).join('') + '</tr>';
    tbody.innerHTML = '';

    data.rows.forEach(r => {
      const tr = document.createElement('tr');
      let rowHtml = '';
      data.columns.forEach(c => {
        rowHtml += `<td>${r[c]}</td>`;
      });
      tr.innerHTML = rowHtml;
      tbody.appendChild(tr);
    });
  } catch (err) {
    console.error('Error cargando reporte:', err);
    tbody.innerHTML = '<tr><td colspan="10">Error cargando reporte</td></tr>';
  }
}

/* =============================================================
   CLIENTE – PORTAL DE USUARIO
   (carga de propiedades, facturas y pagos)
============================================================= */

function initClientePage() {
  const lblUser         = document.getElementById('cliente-username');
  const lblImpersonation= document.getElementById('cliente-impersonation');
  const btnHeader       = document.getElementById('btnClienteHeader');

  if (!lblUser || !btnHeader) {
    // No estamos en dashboard_cliente.html
    return;
  }

  // Usuario real y usuario "impersonado"
  const storedUser       = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null');
  const impersonatedUser = JSON.parse(localStorage.getItem(IMPERSONATE_KEY) || 'null');

  if (!storedUser && !impersonatedUser) {
    location.href = 'login.html';
    return;
  }

  const effectiveUser = impersonatedUser || storedUser;

  let label = `Cliente: ${effectiveUser.login}`;
  if (effectiveUser.nombre) {
    label += ` – ${effectiveUser.nombre}`;
  }
  lblUser.textContent = label;

  if (impersonatedUser) {
    if (lblImpersonation) {
      lblImpersonation.style.display = 'block';
      lblImpersonation.textContent =
        `Viendo como ${impersonatedUser.login} (desde admin)`;
    }

    btnHeader.textContent = 'Volver al admin';
    btnHeader.onclick = () => {
      localStorage.removeItem(IMPERSONATE_KEY);
      location.href = 'dashboard_admin.html';
    };
  } else {
    if (lblImpersonation) {
      lblImpersonation.style.display = 'none';
      lblImpersonation.textContent = '';
    }

    btnHeader.textContent = 'Cerrar sesión';
    btnHeader.onclick = () => {
      localStorage.removeItem(STORAGE_KEY);
      localStorage.removeItem(IMPERSONATE_KEY);
      location.href = 'login.html';
    };
  }

  const uid = Number(effectiveUser.usuarioId || effectiveUser.UsuarioID || 0);
  if (!uid) {
    console.error('No se pudo determinar el UsuarioID para el cliente', effectiveUser);
    return;
  }

  loadClientPropiedades(uid);
  loadClientFacturas(uid);
  loadClientPagos(uid);
}

/* -------------------------------------------------------------
   CLIENTE – PROPIEDADES + RESUMEN
------------------------------------------------------------- */

async function loadClientPropiedades(usuarioId) {
  const resumenTotalProp  = document.getElementById('resumen-total-propiedades');
  const resumenDeudaTotal = document.getElementById('resumen-deuda-total');
  const tbody             = document.getElementById('tbody-propiedades');

  if (!tbody) return;

  tbody.innerHTML = '<tr><td colspan="5">Cargando propiedades...</td></tr>';

  try {
    const url = `${BASE_URL}/api/client/propiedades?usuarioId=${encodeURIComponent(usuarioId)}`;
    const res = await fetch(url);
    const data = await res.json();

    if (!data.ok) {
      console.error('Error desde API propiedades:', data);
      tbody.innerHTML = '<tr><td colspan="5">Error cargando propiedades.</td></tr>';
      if (resumenTotalProp) resumenTotalProp.textContent = '—';
      if (resumenDeudaTotal) resumenDeudaTotal.textContent = '—';
      return;
    }

    const props = data.propiedades || [];

    if (props.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5">No hay propiedades asociadas.</td></tr>';
      if (resumenTotalProp) resumenTotalProp.textContent = '0';
      if (resumenDeudaTotal) resumenDeudaTotal.textContent = '₡0';
      return;
    }

    tbody.innerHTML = '';
    let totalDeuda = 0;

    props.forEach(p => {
      const deuda = Number(p.deudaPendiente || p.DeudaPendiente || 0);
      totalDeuda += deuda;

      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${p.finca || p.Finca}</td>
        <td>${p.zona || p.Zona || '-'}</td>
        <td>${p.uso || p.Uso || '-'}</td>
        <td>${formatearFechaCorta(p.fechaRegistro || p.FechaRegistro)}</td>
        <td>₡${deuda.toLocaleString('es-CR', { minimumFractionDigits: 2 })}</td>
      `;
      tbody.appendChild(tr);
    });

    if (resumenTotalProp) resumenTotalProp.textContent = String(props.length);
    if (resumenDeudaTotal) {
      resumenDeudaTotal.textContent = `₡${totalDeuda.toLocaleString('es-CR', {
        minimumFractionDigits: 2
      })}`;
    }

  } catch (err) {
    console.error('Error JS al cargar propiedades:', err);
    tbody.innerHTML = '<tr><td colspan="5">Error cargando propiedades.</td></tr>';
    if (resumenTotalProp) resumenTotalProp.textContent = '—';
    if (resumenDeudaTotal) resumenDeudaTotal.textContent = '—';
  }
}

/* -------------------------------------------------------------
   CLIENTE – FACTURAS PENDIENTES
------------------------------------------------------------- */

async function loadClientFacturas(usuarioId) {
  const tbody = document.getElementById('tbody-facturas-pendientes');
  if (!tbody) return;

  tbody.innerHTML = '<tr><td colspan="7">Cargando facturas...</td></tr>';

  try {
    const url = `${BASE_URL}/api/client/facturas?usuarioId=${encodeURIComponent(usuarioId)}`;
    const res = await fetch(url);
    const data = await res.json();

    if (!data.ok) {
      console.error('Error desde API facturas:', data);
      tbody.innerHTML = '<tr><td colspan="7">Error cargando facturas.</td></tr>';
      return;
    }

    const facturas = data.facturas || [];

    if (facturas.length === 0) {
      tbody.innerHTML = '<tr><td colspan="7">No hay facturas pendientes.</td></tr>';
      return;
    }

    tbody.innerHTML = '';

    facturas.forEach(f => {
      const monto = Number(f.montoColones || f.Total || 0);

      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${f.numero || f.facturaId || f.FacturaID}</td>
        <td>${f.periodoTexto || f.PeriodoTexto || '-'}</td>
        <td>${f.servicio || f.Servicio || 'Servicios municipales'}</td>
        <td>₡${monto.toLocaleString('es-CR', { minimumFractionDigits: 2 })}</td>
        <td>${formatearFechaCorta(f.fechaVencimiento || f.FechaVencimiento)}</td>
        <td>${f.estado || f.Estado}</td>
        <td>
          <button class="btn-chip btn-pagar-factura"
                  data-id="${f.facturaId || f.FacturaID}"
                  data-monto="${monto}">
            Pagar
          </button>
        </td>
      `;
      tbody.appendChild(tr);
    });

    tbody.querySelectorAll('.btn-pagar-factura').forEach(btn => {
      btn.onclick = async () => {
        const facturaId = Number(btn.dataset.id);
        const monto = Number(btn.dataset.monto || 0);

        const ok = confirm(
          `¿Desea pagar la factura ${facturaId} por ₡${monto.toLocaleString('es-CR', {
            minimumFractionDigits: 2
          })}?`
        );
        if (!ok) return;

        await pagarFacturaDesdeCliente(usuarioId, facturaId);
        await loadClientPropiedades(usuarioId);
        await loadClientFacturas(usuarioId);
        await loadClientPagos(usuarioId);
      };
    });

  } catch (err) {
    console.error('Error JS al cargar facturas:', err);
    tbody.innerHTML = '<tr><td colspan="7">Error cargando facturas.</td></tr>';
  }
}

/* -------------------------------------------------------------
   CLIENTE – PAGOS (HISTORIAL)
------------------------------------------------------------- */

async function loadClientPagos(usuarioId) {
  const tbody = document.getElementById('tbody-historial-pagos');
  if (!tbody) return;

  tbody.innerHTML = '<tr><td colspan="5">Cargando pagos...</td></tr>';

  try {
    const url = `${BASE_URL}/api/client/pagos?usuarioId=${encodeURIComponent(usuarioId)}`;
    const res = await fetch(url);
    const data = await res.json();

    if (!data.ok) {
      console.error('Error desde API pagos:', data);
      tbody.innerHTML = '<tr><td colspan="5">Error cargando pagos.</td></tr>';
      return;
    }

    const pagos = data.pagos || [];

    if (pagos.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5">No hay pagos registrados.</td></tr>';
      return;
    }

    tbody.innerHTML = '';

    pagos.forEach(p => {
      const monto = Number(p.montoColones || p.Monto || 0);

      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${formatearFechaCorta(p.fecha || p.Fecha)}</td>
        <td>${p.facturaId || p.FacturaID}</td>
        <td>${p.detalle || p.Referencia || '-'}</td>
        <td>₡${monto.toLocaleString('es-CR', { minimumFractionDigits: 2 })}</td>
        <td>${p.medio || p.Medio}</td>
      `;
      tbody.appendChild(tr);
    });

  } catch (err) {
    console.error('Error JS al cargar pagos:', err);
    tbody.innerHTML = '<tr><td colspan="5">Error cargando pagos.</td></tr>';
  }
}

/* -------------------------------------------------------------
   CLIENTE – PAGO WEB (POST /api/client/pagar)
------------------------------------------------------------- */

async function pagarFacturaDesdeCliente(usuarioId, facturaId) {
  try {
    const res = await fetch(`${BASE_URL}/api/client/pagar`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        usuarioId,
        facturaId,
        medio: 'WEB',
        referencia: `PAGO_WEB_${facturaId}`
      })
    });

    const data = await res.json();

    if (!data.ok) {
      console.error('Error al pagar factura:', data);
      showToast(data.msg || 'Error al procesar el pago', 'error');
      return;
    }

    showToast('Pago realizado correctamente.', 'success');
  } catch (err) {
    console.error('Error JS al procesar pago:', err);
    showToast('Error al procesar el pago.', 'error');
  }
}
