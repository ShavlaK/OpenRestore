import json
import os
import threading
import time
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from typing import Dict, Any

from configurator_db import ConfiguratorDB, quit_configurator, open_configurator, is_configurator_running
from asset_watcher import AssetWatcher
from device_manager import DeviceManager

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CATALOG_PATH = os.path.join(SCRIPT_DIR, "catalog.json")

# Global state for background restore task
CURRENT_TASK = {
    "running": False,
    "adam_id": None,
    "app_name": None,
    "status": "idle",
    "logs": [],
    "error": None,
    "result": None
}

def log_task(msg: str):
    timestamp = time.strftime("%H:%M:%S")
    CURRENT_TASK["logs"].append(f"[{timestamp}] {msg}")
    CURRENT_TASK["status"] = msg

def run_restore_task_background(adam_id: int, external_version_id: int = 0, auto_install: bool = True):
    global CURRENT_TASK
    CURRENT_TASK["running"] = True
    CURRENT_TASK["adam_id"] = adam_id
    CURRENT_TASK["logs"] = []
    CURRENT_TASK["error"] = None
    CURRENT_TASK["result"] = None

    db = ConfiguratorDB()
    dm = DeviceManager()

    def progress(msg):
        log_task(msg)

    try:
        log_task(f"Инициализация восстановления для Adam ID {adam_id}...")
        if not db.exists():
            raise RuntimeError("Apple Configurator не найден или не инициализирован.")

        owner_dsid = db.get_owner_dsid()
        if not owner_dsid:
            raise RuntimeError("Не найден Apple ID в Apple Configurator. Войдите в аккаунт.")

        log_task(f"Apple ID подтверждён (DSID: {owner_dsid[:4]}***).")

        if is_configurator_running():
            log_task("Закрываю Apple Configurator перед обновлением базы...")
            quit_configurator()

        log_task("Внедряю запрос в базу Apple Configurator...")
        db.inject_restore_request(adam_id, external_version_id)
        log_task(f"Запрос «Restore request {adam_id}» успешно добавлен.")

        log_task("Открываю Apple Configurator...")
        open_configurator()
        time.sleep(3.0)

        log_task("Ожидаю действия в Apple Configurator (Действия -> Добавить -> Приложения)...")
        watcher = AssetWatcher(adam_id=adam_id, output_dir=os.path.expanduser("~/Downloads/OpenRestore"))
        saved_ipa, meta = watcher.watch_and_capture(progress_callback=progress)

        CURRENT_TASK["result"] = {
            "ipa_path": saved_ipa,
            "meta": meta
        }
        log_task(f"Успешно сохранён IPA: {saved_ipa}")

        if auto_install and dm.is_available():
            devs = dm.list_devices()
            if devs:
                log_task(f"Устанавливаю {meta.get('app_name')} на {devs[0].get('name')} через cfgutil...")
                ok, msg = dm.install_app(saved_ipa)
                if ok:
                    log_task("Приложение успешно установлено на iPhone!")
                else:
                    log_task(f"Результат установки: {msg}")

        CURRENT_TASK["status"] = "completed"
    except Exception as e:
        CURRENT_TASK["error"] = str(e)
        CURRENT_TASK["status"] = "error"
        log_task(f"Ошибка: {e}")
    finally:
        try:
            db.remove_restore_request(adam_id)
            log_task("База Configurator очищена.")
        except Exception:
            pass
        CURRENT_TASK["running"] = False

HTML_DASHBOARD = """<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenRestore — Установка приложений iOS</title>
    <style>
        :root {
            --bg-color: #0b0f19;
            --card-bg: rgba(23, 32, 54, 0.7);
            --card-border: rgba(255, 255, 255, 0.08);
            --accent: #3b82f6;
            --accent-glow: rgba(59, 130, 246, 0.35);
            --success: #10b981;
            --warning: #f59e0b;
            --danger: #ef4444;
            --text: #f3f4f6;
            --text-dim: #9ca3af;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", Roboto, sans-serif; }
        body { background: var(--bg-color); color: var(--text); padding: 24px; min-height: 100vh; background-image: radial-gradient(at 0% 0%, rgba(59, 130, 246, 0.15) 0, transparent 50%), radial-gradient(at 100% 100%, rgba(16, 185, 129, 0.1) 0, transparent 50%); }
        .container { max-width: 1100px; margin: 0 auto; }
        header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 28px; padding-bottom: 16px; border-bottom: 1px solid var(--card-border); }
        .logo { font-size: 24px; font-weight: 800; background: linear-gradient(135deg, #60a5fa, #34d399); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
        .badge { display: inline-flex; align-items: center; gap: 6px; padding: 6px 12px; border-radius: 9999px; font-size: 13px; font-weight: 600; }
        .badge-success { background: rgba(16, 185, 129, 0.15); color: #34d399; border: 1px solid rgba(16, 185, 129, 0.3); }
        .badge-warning { background: rgba(245, 158, 11, 0.15); color: #fbbf24; border: 1px solid rgba(245, 158, 11, 0.3); }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-bottom: 24px; }
        @media (max-width: 768px) { .grid { grid-template-columns: 1fr; } }
        .card { background: var(--card-bg); border: 1px solid var(--card-border); border-radius: 16px; padding: 20px; backdrop-filter: blur(12px); box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3); }
        h2 { font-size: 18px; margin-bottom: 16px; color: #fff; display: flex; align-items: center; gap: 8px; }
        .input-group { display: flex; gap: 8px; margin-bottom: 16px; }
        input, select { flex: 1; background: rgba(0, 0, 0, 0.3); border: 1px solid var(--card-border); padding: 10px 14px; border-radius: 10px; color: #fff; font-size: 14px; outline: none; transition: border-color 0.2s; }
        input:focus { border-color: var(--accent); }
        button { background: var(--accent); color: white; border: none; padding: 10px 18px; border-radius: 10px; font-weight: 600; font-size: 14px; cursor: pointer; transition: all 0.2s; box-shadow: 0 4px 12px var(--accent-glow); }
        button:hover { filter: brightness(1.1); transform: translateY(-1px); }
        button:disabled { opacity: 0.5; cursor: not-allowed; transform: none; }
        .btn-success { background: var(--success); }
        .btn-outline { background: transparent; border: 1px solid var(--card-border); box-shadow: none; }
        .btn-outline:hover { background: rgba(255, 255, 255, 0.05); }
        .app-list { max-height: 480px; overflow-y: auto; display: flex; flex-direction: column; gap: 10px; padding-right: 4px; }
        .app-item { display: flex; justify-content: space-between; align-items: center; padding: 12px 14px; background: rgba(255, 255, 255, 0.03); border: 1px solid var(--card-border); border-radius: 12px; transition: background 0.2s; }
        .app-item:hover { background: rgba(255, 255, 255, 0.07); }
        .app-info h4 { font-size: 15px; margin-bottom: 2px; }
        .app-info p { font-size: 12px; color: var(--text-dim); }
        .terminal { background: #05070e; border: 1px solid #1e293b; border-radius: 12px; padding: 14px; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12px; line-height: 1.6; color: #a5f3fc; height: 260px; overflow-y: auto; }
        .instruction-box { background: rgba(59, 130, 246, 0.08); border: 1px solid rgba(59, 130, 246, 0.2); border-radius: 12px; padding: 14px; margin-bottom: 16px; font-size: 13px; line-height: 1.5; }
        .instruction-box ol { padding-left: 20px; margin-top: 6px; }
        .instruction-box li { margin-bottom: 4px; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div>
                <div class="logo">⚡ OpenRestore</div>
                <div style="font-size: 13px; color: var(--text-dim); margin-top: 2px;">100% Free & Open Source iOS Restore Solution</div>
            </div>
            <div id="device-status">
                <span class="badge badge-warning">🔍 Поиск iPhone...</span>
            </div>
        </header>

        <div class="grid">
            <!-- Left Column: Catalog & Custom Restore -->
            <div class="card">
                <h2>📱 Каталог приложений</h2>
                <div class="input-group">
                    <input type="text" id="search-input" placeholder="Поиск по названию или Adam ID..." oninput="filterApps()">
                </div>
                <div class="app-list" id="apps-container"></div>

                <h2 style="margin-top: 24px;">🎯 Произвольный Adam ID</h2>
                <div class="input-group">
                    <input type="number" id="custom-adam-id" placeholder="Например: 564177498">
                    <button onclick="startRestore(document.getElementById('custom-adam-id').value)">Восстановить</button>
                </div>
            </div>

            <!-- Right Column: Live Status & Installation Guidance -->
            <div class="card">
                <h2>⚙️ Процесс восстановления</h2>
                <div class="instruction-box" id="guide-box">
                    <strong>Инструкция:</strong>
                    <ol>
                        <li>Выберите приложение и нажмите «Восстановить».</li>
                        <li>В открывшемся <b>Apple Configurator</b> дважды кликните по вашему iPhone.</li>
                        <li>Нажмите меню <b>Действия</b> → <b>Добавить</b> → <b>Приложения</b>.</li>
                        <li>Выберите появившийся пункт <b>«Restore request...»</b> и нажмите <b>Добавить</b>.</li>
                        <li>OpenRestore перехватит загрузку, сохранит .ipa и установит на iPhone!</li>
                    </ol>
                </div>

                <h2 style="font-size: 15px; margin-top: 16px;">Терминал событий:</h2>
                <div class="terminal" id="terminal-logs">
                    <div style="color: #64748b;">Ожидание запуска...</div>
                </div>

                <div style="margin-top: 16px; display: flex; justify-content: space-between; align-items: center;">
                    <button class="btn-outline" onclick="openConfiguratorManual()">Открыть Configurator</button>
                    <button class="btn-outline" onclick="refreshStatus()">Обновить статус</button>
                </div>
            </div>
        </div>

        <!-- Saved IPAs Library -->
        <div class="card">
            <h2>💾 Сохранённые IPA-файлы (Мгновенная установка в 1 клик)</h2>
            <div id="library-container" style="display: flex; flex-direction: column; gap: 8px; font-size: 13px;">
                <div style="color: var(--text-dim);">Загрузка библиотеки...</div>
            </div>
        </div>
    </div>

    <script>
        let catalog = [];

        async function init() {
            await loadCatalog();
            await checkDevices();
            await loadLibrary();
            setInterval(pollStatus, 2000);
            setInterval(checkDevices, 5000);
        }

        async function loadCatalog() {
            try {
                const res = await fetch('/api/catalog');
                catalog = await res.json();
                renderApps(catalog);
            } catch (e) {
                console.error(e);
            }
        }

        function renderApps(apps) {
            const container = document.getElementById('apps-container');
            container.innerHTML = '';
            apps.forEach(app => {
                const item = document.createElement('div');
                item.className = 'app-item';
                item.innerHTML = `
                    <div class="app-info">
                        <h4>${app.name}</h4>
                        <p>${app.category} • Adam ID: <code>${app.adam_id}</code></p>
                    </div>
                    <button onclick="startRestore(${app.adam_id})">Восстановить</button>
                `;
                container.appendChild(item);
            });
        }

        function filterApps() {
            const query = document.getElementById('search-input').value.toLowerCase();
            const filtered = catalog.filter(a => 
                a.name.toLowerCase().includes(query) || 
                String(a.adam_id).includes(query) ||
                (a.category && a.category.toLowerCase().includes(query))
            );
            renderApps(filtered);
        }

        async function checkDevices() {
            try {
                const res = await fetch('/api/devices');
                const devs = await res.json();
                const statusEl = document.getElementById('device-status');
                if (devs && devs.length > 0) {
                    statusEl.innerHTML = `<span class="badge badge-success">📱 ${devs[0].name || 'iPhone'} (${devs[0].type || 'USB'})</span>`;
                } else {
                    statusEl.innerHTML = `<span class="badge badge-warning">⚠️ iPhone не подключен</span>`;
                }
            } catch(e) {}
        }

        async function startRestore(adamId) {
            if (!adamId) return alert('Введите Adam ID');
            try {
                const res = await fetch('/api/restore', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ adam_id: parseInt(adamId) })
                });
                const data = await res.json();
                if (data.error) alert(data.error);
                pollStatus();
            } catch (e) {
                alert('Ошибка: ' + e);
            }
        }

        async function pollStatus() {
            try {
                const res = await fetch('/api/task');
                const task = await res.json();
                const term = document.getElementById('terminal-logs');
                if (task.logs && task.logs.length > 0) {
                    term.innerHTML = task.logs.map(l => `<div>${l}</div>`).join('');
                    term.scrollTop = term.scrollHeight;
                }
                if (task.result && task.status === 'completed') {
                    loadLibrary();
                }
            } catch (e) {}
        }

        async function loadLibrary() {
            try {
                const res = await fetch('/api/library');
                const files = await res.json();
                const lib = document.getElementById('library-container');
                if (!files || files.length === 0) {
                    lib.innerHTML = '<div style="color: var(--text-dim);">Пока нет сохранённых IPA файлов в ~/Downloads/OpenRestore</div>';
                    return;
                }
                lib.innerHTML = files.map(f => `
                    <div class="app-item">
                        <div>
                            <b>${f.filename}</b>
                            <div style="font-size: 11px; color: var(--text-dim);">Размер: ${(f.size / (1024*1024)).toFixed(1)} MB • ${f.date}</div>
                        </div>
                        <button class="btn-success" onclick="installIpa('${f.path}')">Установить на iPhone</button>
                    </div>
                `).join('');
            } catch(e) {}
        }

        async function installIpa(path) {
            if (!confirm('Установить этот IPA на подключенный iPhone?')) return;
            try {
                const res = await fetch('/api/install', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ ipa_path: path })
                });
                const data = await res.json();
                alert(data.message || data.error);
            } catch(e) {
                alert('Ошибка: ' + e);
            }
        }

        function openConfiguratorManual() {
            fetch('/api/open_configurator', { method: 'POST' });
        }

        function refreshStatus() {
            checkDevices();
            loadLibrary();
            pollStatus();
        }

        window.onload = init;
    </script>
</body>
</html>
"""

class OpenRestoreHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass # Suppress standard server logging to keep terminal clean

    def _set_json(self, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()

    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        if url.path == "/" or url.path == "/index.html":
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(HTML_DASHBOARD.encode('utf-8'))
        elif url.path == "/api/catalog":
            self._set_json()
            if os.path.exists(CATALOG_PATH):
                with open(CATALOG_PATH, "r", encoding="utf-8") as f:
                    apps = json.load(f).get("apps", [])
                self.wfile.write(json.dumps(apps).encode('utf-8'))
            else:
                self.wfile.write(b"[]")
        elif url.path == "/api/devices":
            self._set_json()
            dm = DeviceManager()
            devs = dm.list_devices()
            self.wfile.write(json.dumps(devs).encode('utf-8'))
        elif url.path == "/api/task":
            self._set_json()
            self.wfile.write(json.dumps(CURRENT_TASK).encode('utf-8'))
        elif url.path == "/api/library":
            self._set_json()
            out_dir = os.path.expanduser("~/Downloads/OpenRestore")
            files = []
            if os.path.exists(out_dir):
                for f in sorted(os.listdir(out_dir), reverse=True):
                    if f.endswith(".ipa"):
                        fp = os.path.join(out_dir, f)
                        st = os.stat(fp)
                        files.append({
                            "filename": f,
                            "path": fp,
                            "size": st.st_size,
                            "date": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(st.st_mtime))
                        })
            self.wfile.write(json.dumps(files).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        url = urllib.parse.urlparse(self.path)
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length) if length > 0 else b'{}'
        try:
            data = json.loads(body.decode('utf-8'))
        except Exception:
            data = {}

        if url.path == "/api/restore":
            self._set_json()
            adam_id = data.get("adam_id")
            if not adam_id:
                self.wfile.write(json.dumps({"error": "Adam ID не указан"}).encode('utf-8'))
                return
            if CURRENT_TASK["running"]:
                self.wfile.write(json.dumps({"error": "Уже выполняется другая операция восстановления"}).encode('utf-8'))
                return
            
            t = threading.Thread(target=run_restore_task_background, args=(int(adam_id), 0, True), daemon=True)
            t.start()
            self.wfile.write(json.dumps({"status": "started", "adam_id": adam_id}).encode('utf-8'))

        elif url.path == "/api/install":
            self._set_json()
            ipa_path = data.get("ipa_path")
            dm = DeviceManager()
            ok, msg = dm.install_app(ipa_path)
            self.wfile.write(json.dumps({"success": ok, "message": msg}).encode('utf-8'))

        elif url.path == "/api/open_configurator":
            self._set_json()
            open_configurator()
            self.wfile.write(json.dumps({"success": True}).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

def run_server(port: int = 8088):
    server = HTTPServer(('127.0.0.1', port), OpenRestoreHandler)
    print(f"\n\033[1;32m[✓] OpenRestore Web Dashboard запущен по адресу: http://127.0.0.1:{port}\033[0m")
    print("Нажмите Ctrl+C для остановки сервера.\n")
    # Open browser automatically
    try:
        import subprocess
        subprocess.run(["/usr/bin/open", f"http://127.0.0.1:{port}"], check=False)
    except Exception:
        pass

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[*] Сервер остановлен.")
        server.server_close()
