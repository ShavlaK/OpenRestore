#!/usr/bin/env python3
import sys, os
DIR = os.path.dirname(os.path.abspath(__file__))
VENV_PY = os.path.join(DIR, 'venv', 'bin', 'python3')
if os.path.exists(VENV_PY) and os.path.abspath(sys.executable) != os.path.abspath(VENV_PY):
    os.execv(VENV_PY, [VENV_PY] + sys.argv)
import sys, json, os, asyncio, subprocess

DIR = os.path.dirname(os.path.abspath(__file__))
VENV_BIN = os.path.join(DIR, "venv", "bin")
IPATOOL_BIN = os.path.join(DIR, "bin", "ipatool")
if not os.path.exists(IPATOOL_BIN):
    IPATOOL_BIN = "/opt/homebrew/bin/ipatool"

def get_devices():
    cmd = [os.path.join(VENV_BIN, "pymobiledevice3"), "usbmux", "list"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0:
        try:
            return json.loads(res.stdout)
        except:
            return []
    return []

def get_all_devices_info():
    """Return full device info for all connected devices (USB and Wi-Fi/Network)."""
    from pymobiledevice3.lockdown import create_using_usbmux

    async def _fetch_all():
        devices = get_devices()
        if not devices:
            return []

        results = []
        for dev in devices:
            udid = dev.get("UniqueDeviceID") or dev.get("Identifier", "")
            raw_conn = dev.get("ConnectionType", "USB")
            conn_type = "Wi-Fi" if raw_conn in ["Network", "WiFi", "Wireless"] else "USB"

            item = {
                "DeviceName": dev.get("DeviceName", "") or "iPhone",
                "ProductType": dev.get("ProductType", ""),
                "ProductVersion": dev.get("ProductVersion", ""),
                "UniqueDeviceID": udid,
                "ConnectionType": conn_type,
                "BatteryCurrentCapacity": None,
                "TotalDiskCapacity": None,
                "AvailableDiskCapacity": None,
                "SerialNumber": None,
                "WiFiAddress": None,
            }

            try:
                ld = await create_using_usbmux(serial=udid if udid else None)
                # Battery
                try:
                    bat = await ld.get_value(domain="com.apple.mobile.battery", key="BatteryCurrentCapacity")
                    item["BatteryCurrentCapacity"] = int(bat) if bat is not None else None
                except Exception:
                    pass

                # Disk
                try:
                    disk = await ld.get_value(domain="com.apple.disk_usage")
                    if isinstance(disk, dict):
                        total = disk.get("TotalDiskCapacity") or disk.get("TotalDataCapacity")
                        avail = disk.get("TotalDataAvailable") or disk.get("TotalSystemAvailable")
                        item["TotalDiskCapacity"] = int(total) if total else None
                        item["AvailableDiskCapacity"] = int(avail) if avail else None
                except Exception:
                    pass

                # Serial & Wifi
                try:
                    info = await ld.get_value()
                    if isinstance(info, dict):
                        if not item["DeviceName"] or item["DeviceName"] == "iPhone":
                            item["DeviceName"] = info.get("DeviceName", item["DeviceName"])
                        item["SerialNumber"] = info.get("SerialNumber")
                        item["WiFiAddress"] = info.get("WiFiAddress")
                        if not item["ProductVersion"]:
                            item["ProductVersion"] = info.get("ProductVersion", "")
                        if not item["ProductType"]:
                            item["ProductType"] = info.get("ProductType", "")
                except Exception:
                    pass

                try:
                    await ld.close()
                except:
                    pass
            except Exception as e:
                item["lockdown_error"] = str(e)

            results.append(item)
        return results

    try:
        return asyncio.run(_fetch_all())
    except Exception:
        return []

def get_device_info():
    """Return device info for the primary device (backwards compatibility)."""
    all_devs = get_all_devices_info()
    if all_devs:
        # Prefer USB connected device if available
        usb_dev = next((d for d in all_devs if d.get("ConnectionType") == "USB"), all_devs[0])
        return usb_dev
    return {}

def unpair_device(udid=None):
    """Unpair and remove pairing record for device."""
    try:
        cmd = [os.path.join(VENV_BIN, "pymobiledevice3"), "lockdown", "unpair"]
        if udid:
            cmd += ["--udid", udid]
        res = subprocess.run(cmd, capture_output=True, text=True)
        return {"success": res.returncode == 0, "message": res.stdout or res.stderr}
    except Exception as e:
        return {"success": False, "error": str(e)}

def get_installed_apps():
    import urllib.request, plistlib
    from pymobiledevice3.lockdown import create_using_usbmux
    from pymobiledevice3.services.installation_proxy import InstallationProxyService

    async def _fetch_apps():
        ld = await create_using_usbmux()
        svc = InstallationProxyService(lockdown=ld)
        options = {
            "ApplicationType": "User",
            "ReturnAttributes": [
                "CFBundleIdentifier", "CFBundleDisplayName", "CFBundleName",
                "CFBundleShortVersionString", "CFBundleVersion", "iTunesMetadata",
                "ApplicationDSID", "SignerIdentity", "softwareVersionExternalIdentifier",
                "MinimumOSVersion", "Path"
            ]
        }
        res = await svc.lookup(options)
        await ld.close()
        return res or {}

    try:
        raw_apps = asyncio.run(_fetch_apps())
    except Exception:
        # Fallback to CLI list if direct lockdown lookup fails
        cmd = [os.path.join(VENV_BIN, "pymobiledevice3"), "apps", "list"]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0:
            try:
                raw_apps = json.loads(res.stdout)
            except Exception:
                raw_apps = {}
        else:
            raw_apps = {}

    try:
        apps = []
        bundle_to_app = {}

        # Load catalog for fast local delisted app resolution & icons
        catalog_map = {}
        catalog_file = os.path.join(DIR, "catalog.json")
        if os.path.exists(catalog_file):
            try:
                with open(catalog_file, "r", encoding="utf-8") as f:
                    cat_json = json.load(f)
                    for item in cat_json.get("apps", []):
                        aid = item.get("adam_id")
                        bid = item.get("bundle_id")
                        art = item.get("artwork_url")
                        if bid and aid:
                            catalog_map[bid] = {"adam_id": int(aid), "artwork": art}
                        for extra_bid in item.get("bundle_ids", []):
                            if extra_bid and aid:
                                catalog_map[extra_bid] = {"adam_id": int(aid), "artwork": art}
            except Exception:
                pass

        for bundle_id, info in raw_apps.items():
            if not isinstance(info, dict): continue
            path = info.get("Path", "")
            if path.startswith("/Applications/") or bundle_id.startswith("com.apple."):
                continue
            name = info.get("CFBundleDisplayName") or info.get("CFBundleName") or bundle_id
            version = info.get("CFBundleShortVersionString") or info.get("CFBundleVersion") or "1.0"
            
            # Extract Adam ID directly from device's iTunesMetadata bplist
            adam_id = None
            meta_raw = info.get("iTunesMetadata")
            if meta_raw and isinstance(meta_raw, bytes):
                try:
                    meta = plistlib.loads(meta_raw)
                    adam_id = meta.get("itemId")
                except Exception:
                    pass
            elif meta_raw and isinstance(meta_raw, dict):
                adam_id = meta_raw.get("itemId")

            if not adam_id:
                adam_id = info.get("TWAppStoreIdentifier") or info.get("itemId")

            adam_id = int(adam_id) if adam_id and str(adam_id).isdigit() else None
            artwork_url = None

            # Check local catalog
            if not adam_id and bundle_id in catalog_map:
                adam_id = catalog_map[bundle_id]["adam_id"]
            if bundle_id in catalog_map:
                artwork_url = catalog_map[bundle_id]["artwork"]

            app_obj = {
                "bundleId": bundle_id,
                "name": name,
                "version": version,
                "adamId": adam_id,
                "artworkUrl": artwork_url,
                "minOS": info.get("MinimumOSVersion", "")
            }
            apps.append(app_obj)
            bundle_to_app[bundle_id] = app_obj

        # Batch resolve Artwork and any remaining missing Adam IDs via iTunes Lookup API
        bundles_needing_art = [b for b, o in bundle_to_app.items() if not o.get("artworkUrl")]
        if bundles_needing_art:
            for i in range(0, len(bundles_needing_art), 50):
                chunk = bundles_needing_art[i:i+50]
                try:
                    b_str = ",".join(chunk)
                    url = f"https://itunes.apple.com/lookup?bundleId={b_str}&country=ru"
                    req = urllib.request.Request(url, headers={"User-Agent": "iTunes/12.9.5 (Macintosh; OS X 10.14.6)"})
                    with urllib.request.urlopen(req, timeout=6) as resp:
                        res_data = json.loads(resp.read().decode())
                        for item in res_data.get("results", []):
                            bid = item.get("bundleId")
                            track_id = item.get("trackId")
                            art = item.get("artworkUrl100") or item.get("artworkUrl60")
                            if bid in bundle_to_app:
                                if not bundle_to_app[bid].get("adamId") and track_id:
                                    bundle_to_app[bid]["adamId"] = int(track_id)
                                if art:
                                    bundle_to_app[bid]["artworkUrl"] = art
                except Exception:
                    pass

        apps.sort(key=lambda x: x["name"].lower())
        return apps
    except Exception:
        return []

def validate_and_fix_ipa(ipa_path):
    if not os.path.exists(ipa_path):
        return ipa_path
    try:
        import zipfile, shutil
        with zipfile.ZipFile(ipa_path, 'r') as z:
            names = z.namelist()
            nested_ipas = [n for n in names if n.endswith(".ipa") and not n.startswith("._") and not "/._" in n]
            if nested_ipas:
                nested_ipa = nested_ipas[0]
                temp_extract = ipa_path + ".temp_fix"
                z.extract(nested_ipa, temp_extract)
                extracted_path = os.path.join(temp_extract, nested_ipa)
                os.replace(extracted_path, ipa_path)
                shutil.rmtree(temp_extract, ignore_errors=True)
    except Exception:
        pass
    return ipa_path

def install_ipa(ipa_path):
    if not os.path.exists(ipa_path):
        return {"success": False, "error": "IPA file not found"}
    validate_and_fix_ipa(ipa_path)
    cmd = [os.path.join(VENV_BIN, "pymobiledevice3"), "apps", "install", ipa_path]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode == 0:
        return {"success": True, "message": "App installed successfully"}
    return {"success": False, "error": proc.stderr or proc.stdout}

def uninstall_app(bundle_id):
    cmd = [os.path.join(VENV_BIN, "pymobiledevice3"), "apps", "uninstall", bundle_id]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode == 0:
        return {"success": True, "message": f"App {bundle_id} uninstalled successfully"}
    return {"success": False, "error": proc.stderr or proc.stdout}

# --- Direct App Store (ipatool) commands ---

def ipatool_auth_info():
    # 1. Read official Apple Configurator active session & purchases
    db_path = os.path.expanduser("~/Library/Group Containers/K36BKF7T3D.group.com.apple.configurator/Library/Caches/Assets/com.apple.configurator.purchases.cache/store.sqlite")
    if os.path.exists(db_path):
        try:
            import sqlite3
            conn = sqlite3.connect(db_path)
            cur = conn.cursor()
            cur.execute("SELECT COUNT(*) FROM ZMOBILEAPP")
            cnt = cur.fetchone()[0]
            cur.execute("SELECT ZREDOWNLOADBUYPARAMS FROM ZMOBILEAPP WHERE ZREDOWNLOADBUYPARAMS LIKE '%ownerDsid=%' LIMIT 1")
            row = cur.fetchone()
            dsid = ""
            if row and row[0]:
                for p in row[0].split("&"):
                    if p.startswith("ownerDsid="):
                        dsid = p.split("=")[1]
                        break
            if dsid:
                email = "senya.shavlak@yandex.ru"
                return {
                    "authenticated": True,
                    "name": email.split("@")[0],
                    "email": email,
                    "dsid": dsid,
                    "purchases_count": cnt,
                    "source": "Apple Configurator"
                }
        except Exception:
            pass

    return {"authenticated": False}

def ipatool_login(email, password, code=None):
    if not os.path.exists(IPATOOL_BIN):
        return {"success": False, "error": "ipatool binary not found"}
    cmd = [IPATOOL_BIN, "auth", "login", "--email", email, "--password", password, "--format", "json", "--non-interactive"]
    if code and str(code).strip():
        cmd += ["--auth-code", str(code).strip()]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    out = proc.stdout.strip()
    err = proc.stderr.strip()
    combined = (out + " " + err).lower()

    if "2fa" in combined or "code" in combined or "two-factor" in combined:
        return {"success": False, "requires_2fa": True, "error": "Требуется 6-значный код двухфакторной аутентификации (2FA)."}

    if "403" in combined:
        return {
            "success": False,
            "is_403_blocked": True,
            "error": "Apple заблокировала прямой CLI-вход (HTTP 403). Пожалуйста, используйте официальный вход через Apple Configurator — он работает без ограничений."
        }

    if proc.returncode == 0:
        return {"success": True, "message": "Успешный вход в Apple ID!"}

    try:
        data = json.loads(out)
        if "error" in data:
            err_msg = data["error"]
            if "2fa" in err_msg.lower() or "code" in err_msg.lower():
                return {"success": False, "requires_2fa": True, "error": "Введите проверочный код (2FA), отправленный на ваши устройства Apple."}
            if "403" in err_msg:
                return {
                    "success": False,
                    "is_403_blocked": True,
                    "error": "Apple заблокировала прямой CLI-вход (HTTP 403). Используйте вход через Apple Configurator."
                }
            return {"success": False, "error": err_msg}
    except:
        pass

    return {"success": False, "error": err or out or "Неверный логин или пароль"}

def ipatool_revoke():
    if not os.path.exists(IPATOOL_BIN):
        return {"success": False}
    cmd = [IPATOOL_BIN, "auth", "revoke", "--format", "json"]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    return {"success": proc.returncode == 0}

def ipatool_purchase(bundle_id):
    if not os.path.exists(IPATOOL_BIN):
        return {"success": False, "error": "ipatool not found"}
    cmd = [IPATOOL_BIN, "purchase", "--bundle-identifier", bundle_id, "--format", "json", "--non-interactive"]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode == 0:
        return {"success": True, "message": f"Лицензия FairPlay для {bundle_id} успешно получена"}
    return {"success": False, "error": proc.stderr or proc.stdout}

def ipatool_download(identifier, output_dir, is_bundle_id=False):
    """Directly downloads official FairPlay signed IPA from Apple Store via ipatool."""
    if not os.path.exists(IPATOOL_BIN):
        return {"success": False, "error": "ipatool binary not found"}
    os.makedirs(output_dir, exist_ok=True)
    cmd = [IPATOOL_BIN, "download", "--format", "json", "--purchase", "--output", output_dir]
    if is_bundle_id:
        cmd += ["--bundle-identifier", identifier]
    else:
        cmd += ["--app-id", str(identifier)]
    
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode == 0:
        # Find downloaded ipa
        try:
            data = json.loads(proc.stdout.strip())
            return {"success": True, "data": data}
        except:
            return {"success": True, "message": proc.stdout.strip()}
    return {"success": False, "error": proc.stderr or proc.stdout}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No action specified"})); sys.exit(1)
    action = sys.argv[1]
    if action == "devices":
        print(json.dumps(get_devices(), ensure_ascii=False))
    elif action == "devinfo":
        print(json.dumps(get_device_info(), ensure_ascii=False))
    elif action == "devinfo_all":
        print(json.dumps(get_all_devices_info(), ensure_ascii=False))
    elif action == "unpair":
        udid = sys.argv[2] if len(sys.argv) > 2 else None
        print(json.dumps(unpair_device(udid), ensure_ascii=False))
    elif action == "apps":
        print(json.dumps(get_installed_apps(), ensure_ascii=False))
    elif action == "install":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "No IPA path provided"}))
        else:
            print(json.dumps(install_ipa(sys.argv[2]), ensure_ascii=False))
    elif action == "uninstall":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "No bundle ID provided"}))
        else:
            print(json.dumps(uninstall_app(sys.argv[2]), ensure_ascii=False))
    elif action == "auth_info":
        print(json.dumps(ipatool_auth_info(), ensure_ascii=False))
    elif action == "auth_login":
        if len(sys.argv) < 4:
            print(json.dumps({"success": False, "error": "Usage: auth_login <email> <password> [code]"}))
        else:
            code = sys.argv[4] if len(sys.argv) > 4 else None
            print(json.dumps(ipatool_login(sys.argv[2], sys.argv[3], code), ensure_ascii=False))
    elif action == "auth_revoke":
        print(json.dumps(ipatool_revoke(), ensure_ascii=False))
    elif action == "purchase":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Usage: purchase <bundle_id>"}))
        else:
            print(json.dumps(ipatool_purchase(sys.argv[2]), ensure_ascii=False))
    elif action == "download_direct":
        if len(sys.argv) < 4:
            print(json.dumps({"success": False, "error": "Usage: download_direct <adamId|bundleId> <output_dir> [is_bundle_id]"}))
        else:
            is_b = len(sys.argv) > 4 and sys.argv[4] == "1"
            print(json.dumps(ipatool_download(sys.argv[2], sys.argv[3], is_b), ensure_ascii=False))
    else:
        print(json.dumps({"error": f"Unknown action {action}"}))