import pytest
from flask_sqlalchemy import SQLAlchemy
from pathlib import Path
from unittest.mock import patch, mock_open

from database.sql_models import db
from utility.init_db import initialize_database
from main import create_app


@pytest.fixture()
def app():
    app = create_app(db_uri="sqlite:///:memory:")
    app.config.update({"TESTING": True})

    # SETUP START
    with app.app_context():
        initialize_test_database(db)
    # SETUP END

    yield app

    # CLEAN UP START
    with app.app_context():
        db.drop_all()
    # CLEAN UP END


@pytest.fixture(autouse=True)
def mock_global_open():
    mock_dataset_content = {
        "some_dataset_1.jsonl": '{"full_alert": {"type": "example alert 1"}, "features": {"timestamp": "2023-01-02T00:00:00Z"}, "metadata": {"misuse": true}}',
        "some_dataset_2.jsonl": '{"full_alert": {"type": "example alert 2"}, "features": {"timestamp": "2023-01-02T00:00:00Z"}, "metadata": {"misuse": false}}',
    }

    def custom_mock_open(file_name, *args, **kwargs):
        base_name = Path(file_name).name
        if base_name in mock_dataset_content:
            return mock_open(read_data=mock_dataset_content[base_name])()
        else:
            raise FileNotFoundError(f"No such file or directory: '{file_name}'")

    with patch("builtins.open", new_callable=lambda: custom_mock_open):
        yield


@pytest.fixture()
def client(app):
    return app.test_client()


@pytest.fixture()
def runner(app):
    return app.test_cli_runner()


@pytest.fixture()
def app_context(app):
    with app.app_context():
        yield


def initialize_test_database(db: SQLAlchemy):
    TEST_MODULES = [
        {
            "name": "Test Module 1",
            "description": "Description of Test Module 1",
            "file_name": "module_1.py",
            "inputs": [
                {
                    "type": "digit_slider",
                    "description": "A test slider",
                    "min_value": 1,
                    "max_value": 10,
                    "divisions": 9,
                    "initial_value": 5,
                },
            ],
            "tags": ["mod_tag_1"],
        },
        {
            "name": "Test Module 2",
            "description": "Description of Test Module 2",
            "file_name": "module_2.py",
            "inputs": [],
            "tags": ["mod_tag_2"],
        },
    ]

    TEST_DATASETS = [
        {
            "name": "Test Dataset 1",
            "description": "This is a description 1",
            "file_name": "some_dataset_1.jsonl",
            "tags": ["dataset_tag_1"],
        },
        {
            "name": "Test Dataset 2",
            "description": "This is a description 2",
            "file_name": "some_dataset_2.jsonl",
            "tags": ["dataset_tag_2"],
        },
    ]

    initialize_database(db, TEST_DATASETS, TEST_MODULES, testing=True)
