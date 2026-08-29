import json
import os
import shutil
import sqlite3
import tempfile
import unittest
import zipfile

from configurator_db import ConfiguratorDB, get_coredata_timestamp
from device_manager import DeviceManager
from asset_watcher import inspect_app_metadata, package_wrapper_to_ipa, compute_sha256

class TestOpenRestore(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.db_path = os.path.join(self.test_dir, "test_store.sqlite")

        # Create a mock Configurator SQLite DB matching Apple Configurator schema
        conn = sqlite3.connect(self.db_path)
        with conn:
            cur = conn.cursor()
            cur.execute("""
                CREATE TABLE ZMOBILEAPP (
                    Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZADAMID INTEGER,
                    ZAPPLETVCOMPATIBLE INTEGER, ZARTWORKNEEDSSHINE INTEGER, ZDAAPITEMID INTEGER,
                    ZDAAPPURCHASEDTOKEN INTEGER, ZDOWNLOADASSETSIZE INTEGER, ZGENREID INTEGER,
                    ZIPADCOMPATIBLE INTEGER, ZIPHONECOMPATIBLE INTEGER, ZIPODTOUCHCOMPATIBLE INTEGER,
                    ZRATINGRANK INTEGER, ZSELLERID INTEGER, ZSOFTWAREVERSIONEXTERNALID INTEGER,
                    ZLASTUPDATED TIMESTAMP, ZPURCHASEDATE TIMESTAMP, ZRELEASEDATE TIMESTAMP,
                    ZARTWORKTOKEN VARCHAR, ZARTWORKURL VARCHAR, ZBUNDLEID VARCHAR,
                    ZBUNDLESHORTVERSIONSTRING VARCHAR, ZCOPYRIGHT VARCHAR, ZGENRE VARCHAR,
                    ZITEMNAME VARCHAR, ZKIND VARCHAR, ZMINIMUMOSVERSION VARCHAR, ZNAME VARCHAR,
                    ZREDOWNLOADBUYPARAMS VARCHAR, ZSELLERNAME VARCHAR, ZSOFTWAREKIND VARCHAR
                );
            """)
            cur.execute("CREATE TABLE Z_PRIMARYKEY (Z_ENT INTEGER PRIMARY KEY, Z_NAME VARCHAR, Z_SUPER INTEGER, Z_MAX INTEGER);")
            cur.execute("INSERT INTO Z_PRIMARYKEY (Z_ENT, Z_NAME, Z_SUPER, Z_MAX) VALUES (1, 'MobileApp', NULL, 1);")
            cur.execute("""
                INSERT INTO ZMOBILEAPP (
                    Z_PK, Z_ENT, Z_OPT, ZADAMID, ZNAME, ZBUNDLEID, ZKIND, ZREDOWNLOADBUYPARAMS
                ) VALUES (
                    1, 1, 1, 570510529, 'Spaceteam', 'com.sleepingbeastgames.spaceteam', 'software',
                    'productType=C&price=0&salableAdamId=570510529&pricingParameters=STDRDL&pg=default&appExtVrsId=872097802&ownerDsid=11549357268'
                );
            """)
        conn.close()

    def tearDown(self):
        shutil.rmtree(self.test_dir)

    def test_catalog_integrity(self):
        catalog_path = os.path.join(os.path.dirname(__file__), "catalog.json")
        self.assertTrue(os.path.exists(catalog_path))
        with open(catalog_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        apps = data.get("apps", [])
        self.assertGreater(len(apps), 5)
        # Check VKontakte
        vk = next((a for a in apps if a["adam_id"] == 564177498), None)
        self.assertIsNotNone(vk)
        self.assertEqual(vk["name"], "ВКонтакте")

    def test_db_owner_dsid(self):
        db = ConfiguratorDB(self.db_path)
        dsid = db.get_owner_dsid()
        self.assertEqual(dsid, "11549357268")

    def test_db_injection_and_removal(self):
        db = ConfiguratorDB(self.db_path)
        target_adam_id = 564177498  # VK
        self.assertFalse(db.has_adam_id(target_adam_id))

        # Inject
        ok = db.inject_restore_request(target_adam_id)
        self.assertTrue(ok)
        self.assertTrue(db.has_adam_id(target_adam_id))

        # Verify inserted row properties
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        cur.execute("SELECT * FROM ZMOBILEAPP WHERE ZADAMID = ?", (target_adam_id,))
        row = cur.fetchone()
        self.assertIsNotNone(row)
        self.assertEqual(row["ZNAME"], f"Restore request {target_adam_id}")
        self.assertIn(f"salableAdamId={target_adam_id}", row["ZREDOWNLOADBUYPARAMS"])
        self.assertIn("ownerDsid=11549357268", row["ZREDOWNLOADBUYPARAMS"])
        self.assertEqual(row["ZIPHONECOMPATIBLE"], 1)

        # Check Z_MAX
        cur.execute("SELECT Z_MAX FROM Z_PRIMARYKEY WHERE Z_NAME = 'MobileApp';")
        self.assertEqual(cur.fetchone()[0], 2)
        conn.close()

        # Remove
        removed = db.remove_restore_request(target_adam_id)
        self.assertTrue(removed)
        self.assertFalse(db.has_adam_id(target_adam_id))

        # Check Z_MAX restored
        conn = sqlite3.connect(self.db_path)
        cur = conn.cursor()
        cur.execute("SELECT Z_MAX FROM Z_PRIMARYKEY WHERE Z_NAME = 'MobileApp';")
        self.assertEqual(cur.fetchone()[0], 1)
        conn.close()

    def test_ipa_packaging_and_metadata(self):
        # Create mock extracted wrapper directory
        wrapper_dir = os.path.join(self.test_dir, "MockApp.wrapper")
        payload_dir = os.path.join(wrapper_dir, "Payload", "MockApp.app")
        sc_info_dir = os.path.join(payload_dir, "SC_Info")
        os.makedirs(sc_info_dir, exist_ok=True)

        import plistlib
        meta_dict = {
            "itemId": 564177498,
            "bundleDisplayName": "VKontakte",
            "softwareVersionBundleId": "com.vk.vkclient",
            "softwareVersionExternalIdentifier": 887160195,
            "bundleShortVersionString": "8.87"
        }
        with open(os.path.join(wrapper_dir, "iTunesMetadata.plist"), "wb") as f:
            plistlib.dump(meta_dict, f)

        with open(os.path.join(payload_dir, "Info.plist"), "wb") as f:
            plistlib.dump({"CFBundleIdentifier": "com.vk.vkclient", "CFBundleDisplayName": "VK"}, f)

        # Mock FairPlay sinf file
        with open(os.path.join(sc_info_dir, "MockApp.sinf"), "wb") as f:
            f.write(b"FAIRPLAY_SINF_MOCK_DATA")

        # Mock binary
        with open(os.path.join(payload_dir, "MockApp"), "wb") as f:
            f.write(b"\xcf\xfa\xed\xfeMOCK_MACHO_BINARY")

        # Test metadata inspection
        meta = inspect_app_metadata(wrapper_dir)
        self.assertIsNotNone(meta)
        self.assertEqual(meta["item_id"], 564177498)
        self.assertEqual(meta["bundle_id"], "com.vk.vkclient")
        self.assertTrue(meta["has_sinf"])

        # Test packaging to .ipa
        out_ipa = os.path.join(self.test_dir, "output.ipa")
        packaged = package_wrapper_to_ipa(wrapper_dir, out_ipa)
        self.assertTrue(packaged)
        self.assertTrue(os.path.exists(out_ipa))

        # Check zip integrity and entries
        with zipfile.ZipFile(out_ipa, "r") as z:
            names = z.namelist()
            self.assertTrue(any("Payload/MockApp.app/Info.plist" in n for n in names))
            self.assertTrue(any("Payload/MockApp.app/SC_Info/MockApp.sinf" in n for n in names))

        sha = compute_sha256(out_ipa)
        self.assertEqual(len(sha), 64)

if __name__ == "__main__":
    unittest.main()
