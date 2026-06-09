import runpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SITE_PACKAGES = ROOT / ".venv" / "Lib" / "site-packages"

if SITE_PACKAGES.exists():
    sys.path.insert(0, str(SITE_PACKAGES))

runpy.run_path(str(ROOT / "app.py"), run_name="__main__")
