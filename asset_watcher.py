import glob
import hashlib
import os
import plistlib
import shutil
import subprocess
import time
from typing import Optional, Dict, Any, List, Tuple

DEFAULT_WATCH_DIRS = [
    os.path.expanduser("~/Library/Group Containers/K36BKF7T3D.group.com.apple.configurator/Library/Caches/Assets/TemporaryItems/MobileApps"),
    os.path.expanduser("~/Library/Group Containers/K36BKF7T3D.group.com.apple.configurator/Library/Caches/Assets/TemporaryItems"),
    os.path.expanduser("~/Library/Group Containers/K36BKF7T3D.group.com.apple.configurator/Library/Caches/Downloads"),
    os.path.expanduser("~/Library/Caches/com.apple.configurator"),
]

def get_candidate_watch_dirs() -> List[str]:
    dirs = []
    for d in DEFAULT_WATCH_DIRS:
        if os.path.exists(d):
            dirs.append(d)
        else:
            # Create if parent exists
            parent = os.path.dirname(d)
            if os.path.exists(parent):
                try:
                    os.makedirs(d, exist_ok=True)
                    dirs.append(d)
                except Exception:
                    pass

    # Also search /var/folders for any configurator temporary items
    var_folders = glob.glob("/var/folders/*/*/*/com.apple.configurator*")
    for vf in var_folders:
        if os.path.isdir(vf) and vf not in dirs:
            dirs.append(vf)
            
    return dirs

def compute_sha256(file_path: str) -> str:
    h = hashlib.sha256()
    with open(file_path, "rb") as f:
        while chunk := f.read(1024 * 1024):
            h.update(chunk)
    return h.hexdigest()

def inspect_app_metadata(wrapper_dir: str) -> Optional[Dict[str, Any]]:
    """Inspects metadata from iTunesMetadata.plist and Payload/*.app/Info.plist."""
    meta_plist_path = os.path.join(wrapper_dir, "iTunesMetadata.plist")
    item_id = None
    app_name = None
    bundle_id = None
    version_id = None
    short_version = None

    if os.path.exists(meta_plist_path):
        try:
            with open(meta_plist_path, "rb") as f:
                plist = plistlib.load(f)
                item_id = plist.get("itemId")
                app_name = plist.get("bundleDisplayName") or plist.get("itemName")
                bundle_id = plist.get("softwareVersionBundleId")
                version_id = plist.get("softwareVersionExternalIdentifier")
                short_version = plist.get("bundleShortVersionString")
        except Exception:
            pass

    # Look for Payload/*.app/Info.plist
    payload_dir = os.path.join(wrapper_dir, "Payload")
    if os.path.isdir(payload_dir):
        for entry in os.listdir(payload_dir):
            if entry.endswith(".app"):
                app_info_plist = os.path.join(payload_dir, entry, "Info.plist")
                if os.path.exists(app_info_plist):
                    try:
                        with open(app_info_plist, "rb") as f:
                            iplist = plistlib.load(f)
                            if not bundle_id:
                                bundle_id = iplist.get("CFBundleIdentifier")
                            if not app_name:
                                app_name = iplist.get("CFBundleDisplayName") or iplist.get("CFBundleName")
                            if not short_version:
                                short_version = iplist.get("CFBundleShortVersionString")
                    except Exception:
                        pass
                # Check FairPlay sinf
                sc_info = os.path.join(payload_dir, entry, "SC_Info")
                has_sinf = os.path.isdir(sc_info) and any(f.endswith(".sinf") for f in os.listdir(sc_info))
                return {
                    "item_id": item_id,
                    "app_name": app_name,
                    "bundle_id": bundle_id,
                    "version_id": version_id,
                    "short_version": short_version,
                    "has_sinf": has_sinf,
                    "payload_app": entry
                }

    if item_id is not None:
        return {
            "item_id": item_id,
            "app_name": app_name,
            "bundle_id": bundle_id,
            "version_id": version_id,
            "short_version": short_version,
            "has_sinf": False,
            "payload_app": None
        }
    return None

def package_wrapper_to_ipa(source_dir: str, output_ipa_path: str) -> bool:
    """Uses macOS ditto or zip to package a wrapper directory into a valid .ipa file."""
    os.makedirs(os.path.dirname(os.path.abspath(output_ipa_path)), exist_ok=True)
    temp_ipa = output_ipa_path + ".tmp"
    if os.path.exists(temp_ipa):
        os.remove(temp_ipa)

    # Check if source_dir directly contains 'Payload'
    has_payload_directly = os.path.isdir(os.path.join(source_dir, "Payload"))

    try:
        if has_payload_directly:
            # Package contents of source_dir
            cmd = ["/usr/bin/ditto", "-c", "-k", "--keepParent", "Payload", temp_ipa]
            subprocess.run(cmd, cwd=source_dir, check=True)
            
            # If iTunesMetadata.plist exists, add it to zip
            if os.path.exists(os.path.join(source_dir, "iTunesMetadata.plist")):
                cmd_meta = ["/usr/bin/zip", "-q", "-u", temp_ipa, "iTunesMetadata.plist"]
                subprocess.run(cmd_meta, cwd=source_dir, check=False)
        else:
            # Find subfolder with Payload
            found = False
            for root, dirs, _ in os.walk(source_dir):
                if "Payload" in dirs:
                    cmd = ["/usr/bin/ditto", "-c", "-k", "--keepParent", "Payload", temp_ipa]
                    subprocess.run(cmd, cwd=root, check=True)
                    if os.path.exists(os.path.join(root, "iTunesMetadata.plist")):
                        cmd_meta = ["/usr/bin/zip", "-q", "-u", temp_ipa, "iTunesMetadata.plist"]
                        subprocess.run(cmd_meta, cwd=root, check=False)
                    found = True
                    break
            if not found:
                # Direct ditto
                cmd = ["/usr/bin/ditto", "-c", "-k", source_dir, temp_ipa]
                subprocess.run(cmd, check=True)

        if os.path.exists(output_ipa_path):
            os.remove(output_ipa_path)
        os.rename(temp_ipa, output_ipa_path)
        return True
    except Exception as e:
        if os.path.exists(temp_ipa):
            try:
                os.remove(temp_ipa)
            except Exception:
                pass
        raise e

class AssetWatcher:
    def __init__(self, adam_id: int, output_dir: str = "~/Downloads/OpenRestore", timeout: float = 600.0):
        self.adam_id = adam_id
        self.output_dir = os.path.expanduser(output_dir)
        self.timeout = timeout
        self.watch_dirs = get_candidate_watch_dirs()
        os.makedirs(self.output_dir, exist_ok=True)

    def watch_and_capture(self, progress_callback=None) -> Tuple[str, Dict[str, Any]]:
        """Watches Configurator temporary directories until the target Adam ID is downloaded."""
        start_time = time.time()
        seen_paths = set()

        if progress_callback:
            progress_callback(f"Начато наблюдение за кэшем Configurator (Adam ID {self.adam_id})...")

        last_status_time = time.time()
        while time.time() - start_time < self.timeout:
            for watch_dir in self.watch_dirs:
                if not os.path.exists(watch_dir):
                    continue

                for root, dirs, files in os.walk(watch_dir):
                    # Check if this directory is a candidate
                    meta_path = os.path.join(root, "iTunesMetadata.plist")
                    payload_path = os.path.join(root, "Payload")

                    if os.path.exists(meta_path) or os.path.isdir(payload_path):
                        meta = inspect_app_metadata(root)
                        if meta and meta.get("item_id") == self.adam_id:
                            if progress_callback:
                                progress_callback(f"Найден контент приложения: {meta.get('app_name')} ({meta.get('bundle_id')}). Проверяю FairPlay...")

                            # Wait a bit for file writing to finish (sinf and binary)
                            stable_count = 0
                            last_size = -1
                            while stable_count < 3 and time.time() - start_time < self.timeout:
                                current_size = sum(
                                    os.path.getsize(os.path.join(r, f))
                                    for r, _, fl in os.walk(root)
                                    for f in fl if os.path.exists(os.path.join(r, f))
                                )
                                if current_size == last_size and current_size > 0:
                                    stable_count += 1
                                else:
                                    stable_count = 0
                                    last_size = current_size
                                time.sleep(0.5)

                            # Re-inspect to confirm FairPlay sinf
                            meta = inspect_app_metadata(root)
                            timestamp_str = time.strftime("%Y%m%d-%H%M%S")
                            out_filename = f"{self.adam_id}-{timestamp_str}.ipa"
                            out_path = os.path.join(self.output_dir, out_filename)

                            if progress_callback:
                                progress_callback(f"Упаковываю IPA в {out_path}...")

                            package_wrapper_to_ipa(root, out_path)
                            meta["sha256"] = compute_sha256(out_path)
                            meta["file_size"] = os.path.getsize(out_path)
                            meta["ipa_path"] = out_path

                            if progress_callback:
                                progress_callback(f"Готово! Сохранён проверенный IPA: {out_path}")

                            return out_path, meta

                    # Also check for direct .ipa files created by Configurator
                    for f in files:
                        if f.endswith(".ipa") or f.endswith(".zip"):
                            full_f = os.path.join(root, f)
                            if full_f not in seen_paths:
                                seen_paths.add(full_f)
                                # Could be target
            
            if time.time() - last_status_time >= 5.0:
                last_status_time = time.time()
                elapsed = int(time.time() - start_time)
                if progress_callback:
                    progress_callback(f"Ожидание скачивания в Apple Configurator ({elapsed}с / {int(self.timeout)}с)...")

            time.sleep(0.5)

        raise TimeoutError(f"Превышено время ожидания загрузки приложения с Adam ID {self.adam_id} ({self.timeout}с).")
