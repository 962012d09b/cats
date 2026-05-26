from os.path import isfile, join
from pathlib import Path

REPOSITORY_ROOT_DIR = Path(__file__).parent.parent.parent.resolve()
BACKEND_DIR = REPOSITORY_ROOT_DIR / "backend"
DATASET_DIR = REPOSITORY_ROOT_DIR / "datasets"
MODULE_DIR = BACKEND_DIR / "modules"

DB_PATH = join(BACKEND_DIR, "database", "db.sqlite")


def check_dataset_existence(file_name: str) -> bool:
    full_path = join(DATASET_DIR, file_name)
    return isfile(full_path)


def check_module_existence(file_name: str) -> bool:
    full_path = join(MODULE_DIR, file_name)
    return isfile(full_path)
