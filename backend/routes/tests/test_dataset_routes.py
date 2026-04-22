from database.sql_models import Dataset, db
from typing import Optional

AUTH_HEADER = {"Authorization": "Bearer da46d0ec15764ea5e9c79f8506f8e97a"}


def test_get_datasets(client):
    response = client.get("/api/datasets", headers=AUTH_HEADER)
    expected_response = [
        {
            "alert_source_count": 1,
            "alert_type_count": 1,
            "false_alert_count": 0,
            "true_alert_count": 1,
            "name": "Test Dataset 1",
            "description": "This is a description 1",
            "file_name": "some_dataset_1.jsonl",
            "does_exist": True,
            "duration_iso8601": "P0D",
            "id": 1,
            "tags": ["dataset_tag_1"],
        },
        {
            "alert_source_count": 1,
            "alert_type_count": 1,
            "false_alert_count": 1,
            "true_alert_count": 0,
            "name": "Test Dataset 2",
            "description": "This is a description 2",
            "file_name": "some_dataset_2.jsonl",
            "does_exist": True,
            "duration_iso8601": "P0D",
            "id": 2,
            "tags": ["dataset_tag_2"],
        },
    ]

    assert response.status_code == 200
    assert response.json == expected_response


def test_add_new_dataset(mocker, client, app_context):
    mock_file_existence_check = mocker.patch("routes.dataset_routes.check_dataset_existence", return_value=True)
    mock_json_check = mocker.patch(
        "routes.dataset_routes.get_dataset_statistics",
        return_value=(5, 6, 7, 8, "P1DT2H3M4S"),
    )
    response = client.post(
        "/api/datasets",
        json={
            "name": "Test Dataset 3",
            "description": "This is a description 3",
            "file_name": "some_dataset_3.jsonl",
            "tags": ["dataset_tag_3"],
        },
        headers=AUTH_HEADER,
    )

    assert response.status_code == 200

    added_dataset = db.session.query(Dataset).filter_by(name="Test Dataset 3").first()

    mock_file_existence_check.assert_called_once_with("some_dataset_3.jsonl")
    mock_json_check.assert_called()
    assert added_dataset is not None
    assert added_dataset.description == "This is a description 3"
    assert added_dataset.file_name == "some_dataset_3.jsonl"
    assert added_dataset.tags == ["dataset_tag_3"]
    assert added_dataset.does_exist is True
    assert added_dataset.true_alert_count == 5
    assert added_dataset.false_alert_count == 6
    assert added_dataset.alert_type_count == 7
    assert added_dataset.alert_source_count == 8
    assert added_dataset.duration_iso8601 == "P1DT2H3M4S"


def test_edit_existing_dataset(mocker, client, app_context):
    mock_check = mocker.patch("routes.dataset_routes.check_dataset_existence", return_value=True)
    mock_json_check = mocker.patch(
        "routes.dataset_routes.get_dataset_statistics",
        return_value=(1, 2, 3, 4, "P1DT2H3M4S"),
    )
    response = client.put(
        "/api/datasets",
        json={
            "id": 1,
            "name": "Updated Dataset 1",
            "description": "Updated description 1",
            "file_name": "updated_dataset_1.jsonl",
            "tags": ["updated_dataset_tag_1"],
        },
        headers=AUTH_HEADER,
    )
    assert response.status_code == 200

    edited_dataset: Optional[Dataset] = db.session.get(Dataset, 1)
    assert edited_dataset is not None

    mock_check.assert_called_once_with("updated_dataset_1.jsonl")
    mock_json_check.assert_called()
    assert edited_dataset.name == "Updated Dataset 1"
    assert edited_dataset.description == "Updated description 1"
    assert edited_dataset.file_name == "updated_dataset_1.jsonl"
    assert edited_dataset.tags == ["updated_dataset_tag_1"]
    assert edited_dataset.does_exist is True
    assert edited_dataset.true_alert_count == 1
    assert edited_dataset.false_alert_count == 2
    assert edited_dataset.alert_type_count == 3
    assert edited_dataset.alert_source_count == 4
    assert edited_dataset.duration_iso8601 == "P1DT2H3M4S"


def test_edit_nonexistent_dataset(client, app_context):
    response = client.put(
        "/api/datasets",
        json={
            "id": 999,
            "name": "Updated Dataset 1",
            "description": "Updated description 1",
            "file_name": "updated_dataset_1.jsonl",
        },
        headers=AUTH_HEADER,
    )
    assert response.status_code == 404


def test_delete_existing_dataset(client, app_context):
    dataset_id = 1
    response = client.delete("/api/datasets", json={"id": dataset_id}, headers=AUTH_HEADER)
    assert response.status_code == 200

    deleted_dataset = db.session.get(Dataset, dataset_id)
    assert deleted_dataset is None
