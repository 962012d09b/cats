from unittest import mock
from database.sql_models import Module, Input, db

AUTH_HEADER = {"Authorization": "Bearer da46d0ec15764ea5e9c79f8506f8e97a"}


def test_get_modules(client):
    response = client.get("/api/modules", headers=AUTH_HEADER)
    expected_response = [
        {
            "name": "Test Module 1",
            "description": "Description of Test Module 1",
            "file_name": "module_1.py",
            "id": 1,
            "input_presets": None,
            "does_exist": True,
            "inputs": [
                {
                    "description": "A test slider",
                    "divisions": 9,
                    "id": 1,
                    "initial_value": 5,
                    "max_value": 10,
                    "min_value": 1,
                    "module_id": 1,
                    "type": "digit_slider",
                },
            ],
            "tags": ["mod_tag_1"],
        },
        {
            "name": "Test Module 2",
            "description": "Description of Test Module 2",
            "file_name": "module_2.py",
            "id": 2,
            "input_presets": None,
            "does_exist": True,
            "inputs": [],
            "tags": ["mod_tag_2"],
        },
    ]

    assert response.status_code == 200
    assert response.json == expected_response


@mock.patch("routes.module_routes.check_module_existence", return_value=True)
def test_add_new_module(mock_check, client, app_context):
    response = client.post(
        "/api/modules",
        json={
            "name": "Test Module 3",
            "description": "Description of Test Module 3",
            "file_name": "module_3.py",
            "inputs": [],
            "tags": ["mod_tag_3"],
        },
        headers=AUTH_HEADER,
    )

    assert response.status_code == 200

    added_module = db.session.query(Module).filter_by(name="Test Module 3").first()

    assert added_module is not None
    assert added_module.description == "Description of Test Module 3"
    assert added_module.file_name == "module_3.py"
    assert added_module.does_exist is True
    assert added_module.tags == ["mod_tag_3"]
    assert added_module.inputs == []


@mock.patch("routes.module_routes.check_module_existence", return_value=True)
def test_edit_existing_module(mock_check, client, app_context):
    response = client.put(
        "/api/modules",
        json={
            "id": 1,
            "name": "Updated Module 1",
            "description": "Updated description of Module 1",
            "file_name": "module_1.py",
            "inputs": [
                {
                    "type": "digit_slider",
                    "description": "An updated slider",
                    "min_value": 2,
                    "max_value": 20,
                    "divisions": 18,
                    "initial_value": 10,
                },
            ],
            "tags": ["mod_tag_1"],
        },
        headers=AUTH_HEADER,
    )

    assert response.status_code == 200

    updated_module = db.session.query(Module).filter_by(id=1).first()

    assert updated_module is not None
    assert updated_module.name == "Updated Module 1"
    assert updated_module.description == "Updated description of Module 1"
    assert updated_module.file_name == "module_1.py"
    assert updated_module.does_exist is True

    updated_input = db.session.query(Input).filter_by(module_id=1).first()

    assert updated_input is not None
    assert updated_input.type == "digit_slider"
    assert updated_input.description == "An updated slider"
    assert updated_input.min_value == 2  # type: ignore
    assert updated_input.max_value == 20  # type: ignore
    assert updated_input.divisions == 18  # type: ignore
    assert updated_input.initial_value == 10  # type: ignore
    assert updated_input.module_id == 1


def test_edit_nonexistent_module(client):
    response = client.put(
        "/api/modules",
        json={
            "id": 3,
            "name": "Updated Module 3",
            "description": "Updated description of Module 3",
            "file_name": "module_3.py",
            "inputs": [],
        },
        headers=AUTH_HEADER,
    )

    assert response.status_code == 404


def test_delete_existing_module(client, app_context):
    response = client.delete(
        "/api/modules",
        json={
            "id": 1,
        },
        headers=AUTH_HEADER,
    )

    assert response.status_code == 200

    deleted_module = db.session.query(Module).filter_by(id=1).first()

    assert deleted_module is None
