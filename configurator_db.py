import os
import shutil
import sqlite3
import subprocess
import time
from typing import Optional, List, Dict, Any

DEFAULT_CONFIGURATOR_DB = os.path.expanduser(
    "~/Library/Group Containers/K36BKF7T3D.group.com.apple.configurator/Library/Caches/Assets/com.apple.configurator.purchases.cache/store.sqlite"
)

# CoreData epoch is 2001-01-01 00:00:00 UTC
COREDATA_EPOCH_DIFF = 978307200

def get_coredata_timestamp() -> float:
    return time.time() - COREDATA_EPOCH_DIFF

def is_configurator_running() -> bool:
    try:
        res = subprocess.run(
            ["/usr/bin/pgrep", "-x", "Apple Configurator"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        return res.returncode == 0
    except Exception:
        return False

def quit_configurator(timeout: float = 15.0) -> bool:
    if not is_configurator_running():
        return True
    try:
        subprocess.run(
            ["/usr/bin/osascript", "-e", 'tell application id "com.apple.configurator.ui" to quit'],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    except Exception:
        pass

    start_time = time.time()
    while is_configurator_running() and (time.time() - start_time < timeout):
        time.sleep(0.25)
    return not is_configurator_running()

def open_configurator() -> bool:
    try:
        res = subprocess.run(
            ["/usr/bin/open", "configurator://devices"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        return res.returncode == 0
    except Exception:
        return False

class ConfiguratorDB:
    def __init__(self, db_path: str = DEFAULT_CONFIGURATOR_DB):
        self.db_path = db_path

    def exists(self) -> bool:
        return os.path.exists(self.db_path)

    def _get_connection(self) -> sqlite3.Connection:
        if not self.exists():
            raise FileNotFoundError(f"Apple Configurator database not found at {self.db_path}")
        conn = sqlite3.connect(self.db_path, timeout=10.0)
        conn.row_factory = sqlite3.Row
        return conn

    def get_owner_dsid(self) -> Optional[str]:
        """Extracts ownerDsid from an existing purchase in Apple Configurator."""
        conn = self._get_connection()
        try:
            cur = conn.cursor()
            cur.execute("""
                SELECT ZREDOWNLOADBUYPARAMS 
                FROM ZMOBILEAPP 
                WHERE ZREDOWNLOADBUYPARAMS LIKE '%ownerDsid=%' 
                ORDER BY Z_PK DESC 
                LIMIT 1;
            """)
            row = cur.fetchone()
            if not row or not row["ZREDOWNLOADBUYPARAMS"]:
                return None
            params = row["ZREDOWNLOADBUYPARAMS"]
            for part in params.split("&"):
                if part.startswith("ownerDsid="):
                    return part.split("=", 1)[1]
            return None
        finally:
            conn.close()

    def backup(self, dest_path: str) -> bool:
        os.makedirs(os.path.dirname(os.path.abspath(dest_path)), exist_ok=True)
        conn = self._get_connection()
        try:
            bconn = sqlite3.connect(dest_path)
            with bconn:
                conn.backup(bconn)
            bconn.close()
            return True
        finally:
            conn.close()

    def has_adam_id(self, adam_id: int) -> bool:
        conn = self._get_connection()
        try:
            cur = conn.cursor()
            cur.execute("SELECT COUNT(*) FROM ZMOBILEAPP WHERE ZADAMID = ?", (adam_id,))
            count = cur.fetchone()[0]
            return count > 0
        finally:
            conn.close()

    def list_purchased_apps(self) -> List[Dict[str, Any]]:
        conn = self._get_connection()
        try:
            cur = conn.cursor()
            cur.execute("""
                SELECT ZADAMID, ZNAME, ZITEMNAME, ZBUNDLEID, ZARTWORKURL, ZSOFTWAREVERSIONEXTERNALID, ZPURCHASEDATE, ZREDOWNLOADBUYPARAMS 
                FROM ZMOBILEAPP 
                WHERE ZNAME NOT LIKE 'Restore request%'
                ORDER BY ZPURCHASEDATE DESC;
            """)
            apps = []
            for row in cur.fetchall():
                dsid = ""
                params = row["ZREDOWNLOADBUYPARAMS"] or ""
                for part in params.split("&"):
                    if part.startswith("ownerDsid="):
                        dsid = part.split("=", 1)[1]

                apps.append({
                    "adam_id": row["ZADAMID"],
                    "name": row["ZNAME"] or row["ZITEMNAME"],
                    "bundle_id": row["ZBUNDLEID"] or "",
                    "artwork_url": row["ZARTWORKURL"] or "",
                    "version_id": row["ZSOFTWAREVERSIONEXTERNALID"] or 0,
                    "purchase_date": row["ZPURCHASEDATE"],
                    "owner_dsid": dsid
                })
            return apps
        finally:
            conn.close()

    def inject_restore_request(self, adam_id: int, external_version_id: int = 0) -> bool:
        """Injects a temporary 'Restore request <Adam ID>' row into ZMOBILEAPP."""
        owner_dsid = self.get_owner_dsid()
        if not owner_dsid:
            raise ValueError("Не найден ownerDsid в базе Apple Configurator. Войдите в Apple Account в Apple Configurator.")

        buy_params = f"productType=C&price=0&salableAdamId={adam_id}&pricingParameters=STDRDL&pg=default&ownerDsid={owner_dsid}"
        if external_version_id > 0:
            buy_params += f"&appExtVrsId={external_version_id}"

        now_cd = get_coredata_timestamp()
        req_name = f"Restore request {adam_id}"

        conn = self._get_connection()
        try:
            with conn:
                cur = conn.cursor()
                cur.execute("UPDATE Z_PRIMARYKEY SET Z_MAX = Z_MAX + 1 WHERE Z_NAME = 'MobileApp';")
                cur.execute("""
                    INSERT INTO ZMOBILEAPP (
                        Z_PK, Z_ENT, Z_OPT, ZADAMID, ZSOFTWAREVERSIONEXTERNALID,
                        ZIPHONECOMPATIBLE, ZIPODTOUCHCOMPATIBLE, ZIPADCOMPATIBLE,
                        ZNAME, ZITEMNAME, ZKIND, ZLASTUPDATED, ZPURCHASEDATE,
                        ZREDOWNLOADBUYPARAMS
                    )
                    SELECT
                        Z_MAX, Z_ENT, 1, ?, ?,
                        1, 1, 1,
                        ?, ?, 'software', ?, ?,
                        ?
                    FROM Z_PRIMARYKEY WHERE Z_NAME = 'MobileApp';
                """, (adam_id, external_version_id, req_name, req_name, now_cd, now_cd, buy_params))
                
                cur.execute("PRAGMA integrity_check;")
                res = cur.fetchone()[0]
                if res != "ok":
                    raise RuntimeError(f"Database integrity check failed after injection: {res}")
            return True
        finally:
            conn.close()

    def remove_restore_request(self, adam_id: int) -> bool:
        """Removes the temporary 'Restore request <Adam ID>' row and resets Z_MAX."""
        if not self.exists():
            return False
        conn = self._get_connection()
        try:
            with conn:
                cur = conn.cursor()
                cur.execute("""
                    DELETE FROM ZMOBILEAPP
                    WHERE ZADAMID = ? AND ZNAME LIKE ?;
                """, (adam_id, f"Restore request {adam_id}%"))
                cur.execute("""
                    UPDATE Z_PRIMARYKEY
                    SET Z_MAX = (SELECT COALESCE(MAX(Z_PK), 0) FROM ZMOBILEAPP)
                    WHERE Z_NAME = 'MobileApp';
                """)
                cur.execute("PRAGMA integrity_check;")
                res = cur.fetchone()[0]
                return res == "ok"
        finally:
            conn.close()
