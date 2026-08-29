import os
import re
import subprocess
from typing import List, Dict, Optional, Any, Tuple

CFGUTIL_BIN = "/Applications/Apple Configurator.app/Contents/MacOS/cfgutil"

class DeviceManager:
    def __init__(self, cfgutil_path: str = CFGUTIL_BIN):
        self.cfgutil_path = cfgutil_path

    def is_available(self) -> bool:
        return os.path.exists(self.cfgutil_path) and os.access(self.cfgutil_path, os.X_OK)

    def list_devices(self) -> List[Dict[str, str]]:
        """Returns a list of connected iOS devices detected by Apple Configurator."""
        if not self.is_available():
            return []

        try:
            res = subprocess.run(
                [self.cfgutil_path, "list"],
                capture_output=True,
                text=True,
                timeout=10
            )
            if res.returncode != 0 and not res.stdout:
                return []

            devices = []
            pattern = re.compile(r'(Type|ECID|UDID|Location|Name):\s*([^\t\n\r]+?)(?=\s+(?:Type|ECID|UDID|Location|Name):|$|\t)')
            for line in res.stdout.splitlines():
                line = line.strip()
                if not line or not line.startswith("Type:"):
                    continue

                matches = pattern.findall(line)
                dev = {}
                for k, v in matches:
                    dev[k.lower()] = v.strip()
                if "udid" in dev or "ecid" in dev or "type" in dev:
                    if "name" not in dev:
                        dev["name"] = dev.get("type", "iOS Device")
                    devices.append(dev)
            return devices
        except Exception:
            return []

    def install_app(self, ipa_path: str, ecid: Optional[str] = None, timeout: float = 300.0) -> Tuple[bool, str]:
        """Installs an IPA file directly onto the connected iOS device using cfgutil."""
        if not self.is_available():
            return False, "cfgutil не найден в /Applications/Apple Configurator.app"

        if not os.path.exists(ipa_path):
            return False, f"Файл {ipa_path} не найден."

        cmd = [self.cfgutil_path]
        if ecid:
            cmd.extend(["-e", ecid])
        cmd.extend(["install-app", ipa_path])

        try:
            res = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            if res.returncode == 0:
                return True, res.stdout.strip() or "Приложение успешно установлено!"
            else:
                err = (res.stderr or res.stdout).strip()
                return False, f"Ошибка установки: {err}"
        except subprocess.TimeoutExpired:
            return False, f"Превышено время ожидания установки ({timeout}с)."
        except Exception as e:
            return False, str(e)
