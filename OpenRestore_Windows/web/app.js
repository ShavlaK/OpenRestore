let currentTab = 'devices';
let allPurchases = [];
let allLibrary = [];

// Prevent browser reload / devtools keys to feel like a native desktop app
window.addEventListener('keydown', (e) => {
  if ((e.ctrlKey && (e.key === 'r' || e.key === 'R' || e.key === 'u' || e.key === 'U')) || e.key === 'F5' || e.key === 'F12') {
    e.preventDefault();
  }
});

document.addEventListener('DOMContentLoaded', () => {
  initSSE();
  refreshAll();
  setInterval(refreshStatus, 5000);
  setTimeout(() => checkForUpdates(true), 3000);
});

// SSE for Real-time Progress & Logs
function initSSE() {
  const evtSource = new EventSource('/api/events');
  evtSource.onmessage = (event) => {
    try {
      const data = JSON.parse(event.data);
      handleProgressEvent(data);
    } catch (e) {
      console.error(e);
    }
  };
}

function handleProgressEvent(evt) {
  const spinner = document.getElementById('progress-spinner');
  const stageText = document.getElementById('progress-stage-text');
  const percentText = document.getElementById('progress-percent-text');
  const barFill = document.getElementById('progress-bar-fill');

  if (evt.stage) {
    stageText.innerText = evt.stage;
  }

  if (evt.percent !== undefined) {
    const pct = Math.min(100, Math.max(0, Math.round(evt.percent)));
    percentText.innerText = `${pct}%`;
    barFill.style.width = `${pct}%`;

    if (pct > 0 && pct < 100) {
      spinner.classList.remove('hidden');
    } else {
      spinner.classList.add('hidden');
    }
  }

  if (evt.type === 'complete') {
    spinner.classList.add('hidden');
    refreshAll();
  }

  if (evt.log) {
    appendLog(evt.log);
  }
}

function appendLog(msg) {
  const consoleEl = document.getElementById('log-console');
  const div = document.createElement('div');
  div.innerText = `[${new Date().toLocaleTimeString()}] ${msg}`;
  consoleEl.appendChild(div);
  consoleEl.scrollTop = consoleEl.scrollHeight;
}

function toggleLogConsole() {
  const el = document.getElementById('log-console');
  const btnText = document.getElementById('console-toggle-text');
  if (el.classList.contains('hidden')) {
    el.classList.remove('hidden');
    btnText.innerText = 'Скрыть консоль логов';
  } else {
    el.classList.add('hidden');
    btnText.innerText = 'Показать консоль логов';
  }
}

// Navigation Tabs
function switchTab(tab) {
  currentTab = tab;
  document.querySelectorAll('.tab-content').forEach(el => el.classList.add('hidden'));
  document.querySelectorAll('.nav-btn').forEach(el => {
    el.classList.remove('bg-zinc-800', 'text-white');
    el.classList.add('text-zinc-400');
  });

  const activeContent = document.getElementById(`tab-${tab}`);
  const activeBtn = document.getElementById(`nav-${tab}`);
  if (activeContent) activeContent.classList.remove('hidden');
  if (activeBtn) {
    activeBtn.classList.add('bg-zinc-800', 'text-white');
    activeBtn.classList.remove('text-zinc-400');
  }

  const titles = {
    devices: 'Устройства',
    purchases: 'Покупки Apple ID',
    custom: 'Произвольный Adam ID',
    library: 'Библиотека IPA',
    settings: 'Настройки'
  };
  document.getElementById('header-title').innerText = titles[tab] || 'Open Store';

  if (tab === 'purchases') loadPurchases(false);
  if (tab === 'library') loadLibrary();
}

// Refresh Data
function refreshAll() {
  refreshStatus();
  if (currentTab === 'library') loadLibrary();
  if (currentTab === 'purchases') loadPurchases(false);
}

async function refreshStatus() {
  try {
    const res = await fetch('/api/status');
    const data = await res.json();

    // Apple ID
    const appleEmailEl = document.getElementById('sidebar-apple-email');
    const settingsEmailEl = document.getElementById('settings-apple-email');
    if (data.isLoggedIn && data.appleEmail) {
      appleEmailEl.innerText = data.appleEmail;
      settingsEmailEl.innerText = `${data.appleName || ''} (${data.appleEmail})`;
      document.getElementById('auth-box').classList.add('hidden');
      document.getElementById('purchases-view').classList.remove('hidden');
    } else {
      appleEmailEl.innerText = 'Не авторизован';
      settingsEmailEl.innerText = 'Не авторизован';
      document.getElementById('auth-box').classList.remove('hidden');
      document.getElementById('purchases-view').classList.add('hidden');
    }

    // Devices
    const devices = data.devices || [];
    document.getElementById('badge-device-count').innerText = devices.length;
    renderDevices(devices);

    const devNameEl = document.getElementById('sidebar-device-name');
    const devConnEl = document.getElementById('sidebar-device-conn');
    const indicator = document.getElementById('status-indicator');

    if (devices.length > 0) {
      const dev = devices[0];
      devNameEl.innerText = dev.deviceName || 'iPhone';
      devConnEl.innerText = dev.connectionType === 'USB' ? '🟢 USB (Кабель)' : '🔵 Wi-Fi сеть';
      indicator.className = dev.connectionType === 'USB' ? 'w-2.5 h-2.5 rounded-full bg-emerald-500 shadow-md shadow-emerald-500/50' : 'w-2.5 h-2.5 rounded-full bg-blue-500 shadow-md shadow-blue-500/50';
    } else {
      devNameEl.innerText = 'Устройство не найдено';
      devConnEl.innerText = 'Подключите по USB';
      indicator.className = 'w-2.5 h-2.5 rounded-full bg-zinc-600 animate-pulse';
    }

    if (data.downloadsDir) {
      document.getElementById('settings-folder-path').innerText = data.downloadsDir;
    }
  } catch (e) {
    console.error(e);
  }
}

function renderDevices(devices) {
  const container = document.getElementById('devices-list');
  if (!devices || devices.length === 0) {
    container.innerHTML = `
      <div class="p-8 border border-zinc-800 rounded-2xl bg-zinc-900/40 text-center col-span-full">
        <i class="fa-solid fa-mobile-screen text-4xl text-zinc-600 mb-3 animate-pulse"></i>
        <p class="text-zinc-300 font-medium">Устройства не обнаружены</p>
        <p class="text-xs text-zinc-500 mt-1">Подключите iPhone кабелем и нажмите «Доверять компьютеру»</p>
      </div>
    `;
    return;
  }

  container.innerHTML = devices.map(d => `
    <div class="p-5 border border-zinc-800 rounded-2xl bg-zinc-900/50 flex items-start gap-4">
      <div class="w-12 h-12 rounded-2xl bg-blue-600/10 text-blue-400 flex items-center justify-center text-xl flex-shrink-0">
        <i class="fa-solid fa-mobile-screen-button"></i>
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2">
          <h4 class="font-bold text-white text-sm truncate">${d.deviceName}</h4>
          <span class="text-[10px] px-2 py-0.5 rounded-full font-semibold ${d.connectionType === 'USB' ? 'bg-emerald-500/20 text-emerald-400' : 'bg-blue-500/20 text-blue-400'}">
            ${d.connectionType === 'USB' ? '🟢 USB' : '🔵 Wi-Fi'}
          </span>
        </div>
        <p class="text-xs text-zinc-400 mt-1">${d.productType || 'iPhone'} • ${d.productVersion || 'iOS'}</p>
        <p class="text-[10px] text-zinc-500 font-mono mt-1 truncate">UDID: ${d.udid}</p>
      </div>
    </div>
  `).join('');
}

// Login
async function handleLogin(e) {
  e.preventDefault();
  const email = document.getElementById('login-email').value;
  const password = document.getElementById('login-password').value;
  const authCode = document.getElementById('login-2fa').value;
  const btn = document.getElementById('btn-login-submit');
  const errorBox = document.getElementById('login-error-box');

  errorBox.classList.add('hidden');
  btn.disabled = true;
  btn.innerHTML = `<i class="fa-solid fa-circle-notch fa-spin"></i><span>Авторизация...</span>`;

  try {
    const res = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, authCode })
    });
    const data = await res.json();

    if (data.message === 'NEED_2FA') {
      const container2fa = document.getElementById('2fa-container');
      container2fa.classList.remove('hidden');
      document.getElementById('login-2fa').focus();
      errorBox.innerText = '⚠️ Введите 6-значный проверочный код 2FA, отправленный на ваши устройства Apple';
      errorBox.className = 'mb-4 p-3 bg-amber-950/40 border border-amber-500/40 rounded-xl text-xs text-amber-300';
      errorBox.classList.remove('hidden');
    } else if (data.success) {
      errorBox.classList.add('hidden');
      refreshStatus();
      loadPurchases(true);
    } else {
      errorBox.innerText = '❌ ' + (data.message || 'Ошибка авторизации. Проверьте логин, пароль и наличие iTunes.');
      errorBox.className = 'mb-4 p-3 bg-red-950/40 border border-red-500/40 rounded-xl text-xs text-red-300';
      errorBox.classList.remove('hidden');
    }
  } catch (err) {
    errorBox.innerText = '❌ Ошибка сети: ' + err;
    errorBox.className = 'mb-4 p-3 bg-red-950/40 border border-red-500/40 rounded-xl text-xs text-red-300';
    errorBox.classList.remove('hidden');
  } finally {
    btn.disabled = false;
    btn.innerHTML = `<i class="fa-solid fa-right-to-bracket"></i><span>Войти в Apple ID</span>`;
  }
}

// Purchases
async function loadPurchases(refresh = false) {
  try {
    const res = await fetch(`/api/purchases?refresh=${refresh}`);
    allPurchases = await res.json();
    document.getElementById('badge-purchases-count').innerText = allPurchases.length;
    renderPurchases(allPurchases);
  } catch (e) {
    console.error(e);
  }
}

function filterPurchases() {
  const query = document.getElementById('search-purchases').value.toLowerCase();
  const filtered = allPurchases.filter(p => p.name.toLowerCase().includes(query) || (p.bundleId && p.bundleId.toLowerCase().includes(query)));
  renderPurchases(filtered);
}

function renderPurchases(list) {
  const grid = document.getElementById('purchases-grid');
  if (!list || list.length === 0) {
    grid.innerHTML = `<div class="p-8 text-center text-zinc-500 col-span-full">Покупки не найдены</div>`;
    return;
  }

  grid.innerHTML = list.map(item => `
    <div class="p-3.5 border border-zinc-800/80 rounded-2xl bg-zinc-900/40 hover:bg-zinc-900/70 transition-all flex items-center gap-3">
      <img src="${item.iconUrl || 'https://img.icons8.com/color/96/apple-app-store--v1.png'}" class="w-12 h-12 rounded-xl bg-zinc-800 object-cover flex-shrink-0" onerror="this.src='https://img.icons8.com/color/96/apple-app-store--v1.png'">
      <div class="flex-1 min-w-0">
        <h4 class="font-semibold text-white text-xs truncate">${item.name}</h4>
        <p class="text-[10px] text-zinc-500 font-mono truncate">${item.bundleId || item.id}</p>
      </div>
      <button onclick="downloadApp(${item.id}, '${item.bundleId}', '${escapeHtml(item.name)}')" class="px-3 py-1.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-medium transition-all shadow-md shadow-blue-600/20 whitespace-nowrap">
        Скачать
      </button>
    </div>
  `).join('');
}

async function downloadApp(adamId, bundleId, appName) {
  try {
    await fetch('/api/download', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ adamId, bundleId, appName, install: true })
    });
  } catch (e) {
    alert('Ошибка запуска: ' + e);
  }
}

// Custom ID
function setAdamID(id) {
  document.getElementById('custom-adam-id').value = id;
}

async function downloadCustomID(install = true) {
  const val = document.getElementById('custom-adam-id').value;
  if (!val) {
    alert('Введите Adam ID');
    return;
  }
  const adamId = parseInt(val, 10);
  try {
    await fetch('/api/download', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ adamId, bundleId: '', appName: `App_${adamId}`, install })
    });
  } catch (e) {
    alert('Ошибка: ' + e);
  }
}

// Library
async function loadLibrary() {
  try {
    const res = await fetch('/api/library');
    allLibrary = await res.json();
    document.getElementById('badge-library-count').innerText = allLibrary.length;
    renderLibrary(allLibrary);
  } catch (e) {
    console.error(e);
  }
}

function renderLibrary(list) {
  const container = document.getElementById('library-list');
  if (!list || list.length === 0) {
    container.innerHTML = `<div class="p-8 text-center text-zinc-500">В библиотеке пока нет скачанных файлов</div>`;
    return;
  }

  container.innerHTML = list.map(item => `
    <div class="p-3.5 border border-zinc-800/80 rounded-2xl bg-zinc-900/40 hover:bg-zinc-900/70 transition-all flex items-center justify-between gap-4">
      <div class="flex items-center gap-3 min-w-0">
        <div class="w-10 h-10 rounded-xl bg-amber-500/10 text-amber-400 flex items-center justify-center flex-shrink-0">
          <i class="fa-solid fa-box-archive text-base"></i>
        </div>
        <div class="min-w-0">
          <h4 class="font-semibold text-white text-xs truncate">${item.appName}</h4>
          <p class="text-[10px] text-zinc-500">${item.sizeMb} • Сохранено ${item.modTime}</p>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <button onclick="installLocalIPA('${escapeJs(item.filePath)}')" class="px-3.5 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-medium transition-all shadow-md shadow-emerald-600/20">
          Установить на iPhone
        </button>
      </div>
    </div>
  `).join('');
}

async function installLocalIPA(filePath) {
  try {
    await fetch('/api/install', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ filePath })
    });
  } catch (e) {
    alert('Ошибка: ' + e);
  }
}

async function openDownloadsFolder() {
  await fetch('/api/open-folder');
}

function escapeHtml(s) {
  return s.replace(/'/g, "\\'").replace(/"/g, '&quot;');
}

function escapeJs(s) {
  return s.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

// In-App Auto-Update System
let latestUpdateData = null;

async function checkForUpdates(silent = false) {
  try {
    const res = await fetch('/api/updates/check');
    if (!res.ok) return;
    const data = await res.json();
    latestUpdateData = data;

    const statusEl = document.getElementById('settings-update-status');
    const installBtn = document.getElementById('btn-install-update');

    if (data.isNewer) {
      if (statusEl) {
        statusEl.innerHTML = `<span class="text-emerald-400 font-semibold">🎉 Доступна новая версия ${data.version}!</span>`;
      }
      if (installBtn) {
        installBtn.classList.remove('hidden');
        installBtn.innerHTML = `<i class="fa-solid fa-cloud-arrow-down"></i> Обновить до ${data.version}`;
      }
      const navSettings = document.getElementById('nav-settings');
      if (navSettings && !document.getElementById('update-dot')) {
        navSettings.innerHTML += ` <span id="update-dot" class="ml-auto w-2 h-2 rounded-full bg-emerald-400 animate-ping"></span>`;
      }
      if (!silent) {
        alert(`Доступна новая версия: ${data.version}!\n\nНажмите кнопку «Обновить» в настройках для автоматической установки.`);
      }
    } else {
      if (statusEl) {
        statusEl.innerText = `У вас установлена самая актуальная версия (${data.currentVersion || 'v1.6.0'}).`;
      }
      if (installBtn) {
        installBtn.classList.add('hidden');
      }
      if (!silent) {
        alert('У вас установлена самая последняя версия программы!');
      }
    }
  } catch (err) {
    if (!silent) {
      alert('Ошибка проверки обновлений: ' + err.message);
    }
  }
}

function checkForUpdatesManual() {
  checkForUpdates(false);
}

async function installUpdateManual() {
  if (!confirm('Обновить Open Store до последней версии с GitHub?\n\nПрограмма автоматически скачает архив, распакует новую версию и перезапустится.')) {
    return;
  }
  try {
    const res = await fetch('/api/updates/install', { method: 'POST' });
    const data = await res.json();
    if (data.success) {
      document.getElementById('progress-stage-text').innerText = 'Скачивание и установка обновления...';
      document.getElementById('progress-percent-text').innerText = '100%';
      document.getElementById('progress-bar-fill').style.width = '100%';
    }
  } catch (err) {
    alert('Ошибка при запуске обновления: ' + err.message);
  }
}

