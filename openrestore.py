#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OpenRestore - Бесплатный и открытый инструмент для восстановления и установки 
любых iOS-приложений из App Store (включая удаленные) через Apple Configurator.
100% Free, Open Source & Local.
"""

import argparse
import json
import os
import signal
import sys
import threading
import time
from typing import Optional, Dict, Any, List

from configurator_db import ConfiguratorDB, quit_configurator, open_configurator, is_configurator_running
from asset_watcher import AssetWatcher
from device_manager import DeviceManager
import ui_automation

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CATALOG_PATH = os.path.join(SCRIPT_DIR, "catalog.json")

def load_catalog() -> List[Dict[str, Any]]:
    if os.path.exists(CATALOG_PATH):
        try:
            with open(CATALOG_PATH, "r", encoding="utf-8") as f:
                return json.load(f).get("apps", [])
        except Exception:
            pass
    return []

def print_banner():
    print(r"""
[1;36m===================================================================
   ___                   ____           _                  
  / _ \ _ __   ___ _ __ |  _ \ ___  ___| |_ ___  _ __ ___  
 | | | | '_ \ / _ \ '_ \| |_) / _ \/ __| __/ _ \| '__/ _ \ 
 | |_| | |_) |  __/ | | |  _ <  __/\__ \ || (_) | | |  __/ 
  \___/| .__/ \___|_| |_|_| \_\___||___/\__\___/|_|  \___| 
       |_|   \033[1;32m100% Free & Open Source iOS Restore Tool\033[1;36m
===================================================================\033[0m
""")

def restore_app_flow(adam_id: int, external_version_id: int = 0, auto_install: bool = True, output_dir: str = "~/Downloads/OpenRestore"):
    db = ConfiguratorDB()
    if not db.exists():
        print("\033[1;31m[!] Ошибка: Apple Configurator не найден или не инициализирован.\033[0m")
        print("Пожалуйста, установите Apple Configurator из Mac App Store, запустите его и войдите в свой Apple ID.")
        sys.exit(1)

    print(f"\033[1;34m[*] Проверяем Apple Configurator и текущий аккаунт...\033[0m")
    owner_dsid = db.get_owner_dsid()
    if not owner_dsid:
        print("\033[1;31m[!] Не найден авторизованный Apple ID в кэше Configurator.\033[0m")
        print("Откройте Apple Configurator, войдите в аккаунт и скачайте любое бесплатное приложение для создания сессии.")
        sys.exit(1)

    print(f"\033[1;32m[✓] Авторизованный аккаунт подтверждён (DSID: {owner_dsid[:4]}***).\033[0m")

    # Graceful shutdown of Configurator before DB update
    if is_configurator_running():
        print("[*] Закрываю Apple Configurator перед подготовкой кэша...")
        quit_configurator()

    backup_dir = os.path.join(SCRIPT_DIR, ".backups")
    backup_file = os.path.join(backup_dir, f"store-{adam_id}-{int(time.time())}.sqlite")
    try:
        db.backup(backup_file)
    except Exception as e:
        print(f"[!] Предупреждение при создании резервной копии: {e}")

    # Trap Ctrl+C for clean DB restoration
    def cleanup_handler(signum, frame):
        print("\n\033[1;33m[*] Отмена операции. Очищаю временные записи в Apple Configurator...\033[0m")
        try:
            db.remove_restore_request(adam_id)
        except Exception:
            pass
        print("\033[1;32m[✓] База данных Configurator очищена.\033[0m")
        sys.exit(130)

    signal.signal(signal.SIGINT, cleanup_handler)
    signal.signal(signal.SIGTERM, cleanup_handler)

    try:
        print(f"[*] Добавляю запрос на восстановление для Adam ID {adam_id}...")
        db.inject_restore_request(adam_id, external_version_id)
        print(f"\033[1;32m[✓] Запрос «Restore request {adam_id}» успешно добавлен в локальный список Configurator.\033[0m")

        print("[*] Открываю Apple Configurator и ожидаю инициализации...")
        open_configurator()
        time.sleep(3.0)

        # Device check
        dm = DeviceManager()
        devices = dm.list_devices()
        if devices:
            dev_name = devices[0].get("name", "iPhone")
            print(f"\033[1;32m[✓] Обнаружено подключённое устройство: {dev_name}\033[0m")
        else:
            print("\033[1;33m[!] iPhone пока не обнаружен. Подключите iPhone по USB и подтвердите доверие («Доверять этому компьютеру»).\033[0m")

        print("""
\033[1;33m═══════════════════════════════════════════════════════════════════
 СЛЕДУЮЩИЕ ШАГИ В ОКНЕ APPLE CONFIGURATOR:
 1. Подключите и разблокируйте iPhone по USB.
 2. В Apple Configurator дважды кликните по вашему устройству.
 3. Нажмите в верхнем меню «Действия» (Actions) → «Добавить» (Add) → «Приложения» (Apps).
 4. Найдите в списке «Restore request {adam_id}» и нажмите «Добавить» (Add).
 5. Apple начнет официальную загрузку приложения.
═══════════════════════════════════════════════════════════════════\033[0m
""".format(adam_id=adam_id))

        watcher = AssetWatcher(adam_id=adam_id, output_dir=output_dir)
        def progress(msg):
            print(f"\033[1;34m[*] {msg}\033[0m")

        saved_ipa, meta = watcher.watch_and_capture(progress_callback=progress)

        print("\n\033[1;32m═══════════════════════════════════════════════════════════════════")
        print(f" [✓] УСПЕШНО СОХРАНЁН ОФИЦИАЛЬНЫЙ IPA:")
        print(f"     Путь: {saved_ipa}")
        print(f"     Приложение: {meta.get('app_name', 'iOS App')}")
        print(f"     Bundle ID: {meta.get('bundle_id')}")
        print(f"     Версия: {meta.get('short_version')}")
        print(f"     SHA-256: {meta.get('sha256')}")
        print(f"     FairPlay DRM: {'Сохранён (привязан к Apple ID)' if meta.get('has_sinf') else 'Без sinf'}")
        print("═══════════════════════════════════════════════════════════════════\033[0m\n")

        # Direct installation via cfgutil if requested
        if auto_install and dm.is_available():
            print("[*] Проверяю статус установки на iPhone через cfgutil...")
            devices = dm.list_devices()
            if devices:
                print(f"[*] Выполняю установку {saved_ipa} на {devices[0].get('name')}...")
                ok, msg = dm.install_app(saved_ipa)
                if ok:
                    print(f"\033[1;32m[✓] {msg}\033[0m")
                else:
                    print(f"\033[1;33m[!] Примечание: {msg}\033[0m")
                    print("Apple Configurator также может завершить установку автоматически.")
            else:
                print("[!] Устройство не найдено по USB для мгновенной установки cfgutil. Файл IPA сохранён.")

    finally:
        print("[*] Очищаю временную запись в кэше Configurator...")
        try:
            db.remove_restore_request(adam_id)
            print("\033[1;32m[✓] База данных Apple Configurator в идеальном состоянии.\033[0m")
        except Exception as e:
            print(f"[!] Ошибка очистки базы: {e}")

def run_interactive_menu():
    print_banner()
    catalog = load_catalog()
    dm = DeviceManager()

    while True:
        devices = dm.list_devices()
        dev_str = f"\033[1;32m{devices[0].get('name')} (Подключен)\033[0m" if devices else "\033[1;31mНе подключен\033[0m"
        print(f"Статус iPhone: {dev_str}")
        print("\n\033[1;37mВыберите действие:\033[0m")
        print(" 1) Выбрать приложение из популярного каталога (ВК, Сбер, Тинькофф, 2ГИС...)")
        print(" 2) Ввести произвольный Adam ID вручную")
        print(" 3) Установить ранее сохранённый .ipa файл на iPhone")
        print(" 4) Запустить локальный Web Dashboard (GUI в браузере)")
        print(" 5) Список подключенных устройств")
        print(" 0) Выход\n")

        choice = input("\033[1;36mВведите номер [0-5]: \033[0m").strip()
        if choice == "0":
            print("До свидания!")
            break
        elif choice == "1":
            print("\n\033[1;33m=== Каталог приложений ===\033[0m")
            for i, app in enumerate(catalog, 1):
                print(f" {i:2d}) {app['name']} [{app['category']}] (Adam ID: {app['adam_id']})")
            print("  0) Назад")
            app_choice = input("\n\033[1;36mВыберите номер приложения: \033[0m").strip()
            if app_choice.isdigit():
                idx = int(app_choice) - 1
                if 0 <= idx < len(catalog):
                    selected = catalog[idx]
                    print(f"\nВыбрано: {selected['name']} (Adam ID: {selected['adam_id']})")
                    restore_app_flow(selected['adam_id'])
        elif choice == "2":
            adam_id_str = input("\nВведите Adam ID (например, 564177498 для VK): ").strip()
            if adam_id_str.isdigit() and int(adam_id_str) > 0:
                restore_app_flow(int(adam_id_str))
            else:
                print("\033[1;31mНекорректный Adam ID.\033[0m")
        elif choice == "3":
            downloads_dir = os.path.expanduser("~/Downloads/OpenRestore")
            ipas = [f for f in os.listdir(downloads_dir) if f.endswith(".ipa")] if os.path.exists(downloads_dir) else []
            if not ipas:
                ipa_path = input("Введите полный путь к .ipa файлу: ").strip()
            else:
                print("\nСохранённые IPA:")
                for i, ipa in enumerate(ipas, 1):
                    print(f" {i}) {ipa}")
                c = input("Выберите номер или введите путь: ").strip()
                if c.isdigit() and 1 <= int(c) <= len(ipas):
                    ipa_path = os.path.join(downloads_dir, ipas[int(c)-1])
                else:
                    ipa_path = c
            if os.path.exists(ipa_path):
                ok, msg = dm.install_app(ipa_path)
                print(f"Результат: {msg}")
            else:
                print("Файл не найден.")
        elif choice == "4":
            start_web_server()
        elif choice == "5":
            devs = dm.list_devices()
            print("\nПодключенные устройства:")
            if not devs:
                print(" (нет подключенных устройств)")
            for d in devs:
                print(f" - {d.get('name')} | Тип: {d.get('type')} | UDID: {d.get('udid')} | ECID: {d.get('ecid')}")
            print("")

def start_web_server(port: int = 8088):
    from web_server import run_server
    run_server(port)

def main():
    parser = argparse.ArgumentParser(description="OpenRestore - Free & Open Source iOS App Restorer via Apple Configurator")
    subparsers = parser.add_subparsers(dest="command")

    # Restore command
    restore_parser = subparsers.add_parser("restore", help="Восстановить приложение по Adam ID")
    restore_parser.add_argument("adam_id", type=int, help="App Store Adam ID (например, 564177498)")
    restore_parser.add_argument("--version", type=int, default=0, help="External Version ID (опционально)")
    restore_parser.add_argument("--no-install", action="store_true", help="Не устанавливать автоматически через cfgutil")
    restore_parser.add_argument("--output", default="~/Downloads/OpenRestore", help="Папка для сохранения IPA")

    # Devices command
    subparsers.add_parser("devices", help="Список подключенных iOS устройств")

    # Install command
    install_parser = subparsers.add_parser("install", help="Установить IPA на устройство")
    install_parser.add_argument("ipa_path", help="Путь к .ipa файлу")

    # Web GUI command
    gui_parser = subparsers.add_parser("gui", help="Запустить локальный Web Dashboard")
    gui_parser.add_argument("--port", type=int, default=8088, help="Порт сервера (по умолчанию 8088)")

    args = parser.parse_args()

    if args.command == "restore":
        print_banner()
        restore_app_flow(
            adam_id=args.adam_id,
            external_version_id=args.version,
            auto_install=not args.no_install,
            output_dir=args.output
        )
    elif args.command == "devices":
        dm = DeviceManager()
        devs = dm.list_devices()
        print(f"Найдено устройств: {len(devs)}")
        for d in devs:
            print(f"- {d.get('name')} (Тип: {d.get('type')}, UDID: {d.get('udid')})")
    elif args.command == "install":
        dm = DeviceManager()
        ok, msg = dm.install_app(args.ipa_path)
        print(msg)
    elif args.command == "gui":
        start_web_server(args.port)
    else:
        run_interactive_menu()

if __name__ == "__main__":
    main()
