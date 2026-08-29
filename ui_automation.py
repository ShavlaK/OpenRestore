import subprocess
import time

def focus_configurator() -> bool:
    script = '''
    tell application "Apple Configurator"
        activate
    end tell
    '''
    try:
        res = subprocess.run(["/usr/bin/osascript", "-e", script], capture_output=True)
        return res.returncode == 0
    except Exception:
        return False

def open_configurator_devices() -> bool:
    try:
        subprocess.run(["/usr/bin/open", "configurator://devices"], capture_output=True)
        return True
    except Exception:
        return False
