import os
from unittest.mock import patch

from utility.paths import check_dataset_existence, check_module_existence, DATASET_DIR, BACKEND_DIR, MODULE_DIR


@patch("utility.paths.isfile")
def test_dataset_exists(mock_isfile):
    mock_isfile.return_value = True
    file_name = "existing_file.csv"

    result = check_dataset_existence(file_name)

    mock_isfile.assert_called_once_with(os.path.join(DATASET_DIR, file_name))
    assert result


@patch("utility.paths.isfile")
def test_dataset_does_not_exist(mock_isfile):
    mock_isfile.return_value = False
    file_name = "non_existing_file.csv"

    result = check_dataset_existence(file_name)

    mock_isfile.assert_called_once_with(os.path.join(DATASET_DIR, file_name))
    assert not result


@patch("utility.paths.isfile")
def test_module_exists(mock_isfile):
    mock_isfile.return_value = True
    file_name = "existing_module.py"

    result = check_module_existence(file_name)

    mock_isfile.assert_called_once_with(os.path.join(MODULE_DIR, file_name))
    assert result


@patch("utility.paths.isfile")
def test_module_does_not_exist(mock_isfile):
    mock_isfile.return_value = False
    file_name = "non_existing_module.py"

    result = check_module_existence(file_name)

    mock_isfile.assert_called_once_with(os.path.join(MODULE_DIR, file_name))
    assert not result


def test_backend_root_dir_is_valid():
    assert BACKEND_DIR.exists()
    assert BACKEND_DIR.is_dir()
    assert str(BACKEND_DIR).endswith("backend")
