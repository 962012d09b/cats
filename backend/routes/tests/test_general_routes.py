from flask import current_app

AUTH_HEADER = {"Authorization": "Bearer WrongPassword"}


def test_request_wrong_password(client):
    response = client.get("/api/datasets", headers=AUTH_HEADER)

    assert response.status_code == 401
    assert response.json == {"error": "Unauthorized"}


def test_request_no_auth_configured(client, app_context):
    current_app.config["AUTH_PASSWORD"] = None
    response = client.get("/api/datasets")

    assert response.status_code == 500
    assert response.json == {"error": "Authentication not configured"}
