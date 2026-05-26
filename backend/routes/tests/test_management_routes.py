from unittest.mock import patch

from database.sql_models import db

AUTH_HEADER = {"Authorization": "Bearer da46d0ec15764ea5e9c79f8506f8e97a"}


@patch("routes.management_routes.db.session.begin")
@patch("routes.management_routes.os.path.isfile", return_value=True)
@patch("routes.management_routes.initialize_database")
def test_reinitialize_db(mock_init_db, mock_is_path, mock_begin, client, app_context):
    response = client.delete("/api/reinitialize_db", headers=AUTH_HEADER)
    assert response.status_code == 200
    assert response.json == {"message": "Database reinitialized successfully"}
    mock_init_db.assert_called_once_with(db, reset=True)


@patch("routes.management_routes.os.path.isfile", return_value=False)
@patch("routes.management_routes.initialize_database")
def test_reinitialize_db_not_found(mock_init_db, mock_is_path, client, app_context):
    response = client.delete("/api/reinitialize_db", headers=AUTH_HEADER)
    assert response.status_code == 404
    assert response.json == {"error": "Database file not found"}
