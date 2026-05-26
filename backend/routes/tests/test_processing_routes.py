from processing.data_models import AveragingMethod, Pipeline, PipelineSettings

AUTH_HEADER = {"Authorization": "Bearer da46d0ec15764ea5e9c79f8506f8e97a"}


def test_process_data(client, mocker):
    mock_process_data_task = mocker.patch(
        "routes.processing_routes.process_data_task.delay", return_value=mocker.Mock(id="test-job-id")
    )

    response = client.post(
        "/api/process",
        json={
            "pipelines": [
                {"name": "Test Pipeline 1", "modules": []},
            ],
            "datasets": [1, 2, 3],
            "pipeline_defaults": {"default_risk_score": 0.5, "default_normalization": [True, False]},
        },
        headers=AUTH_HEADER,
    )

    mock_process_data_task.assert_called_once_with(
        [1, 2, 3],  # datasets_json
        [{"name": "Test Pipeline 1", "modules": []}],  # pipelines_json
        0.5,  # default_risk_score
    )

    assert response.status_code == 200
    assert response.json == {
        "job_id": "test-job-id",
        "message": "Processing job started",
        "progress": 0.0,
        "results": [],
        "ready": False,
        "successful": False,
    }


def test_process_data_no_datasets(client):
    response = client.post(
        "/api/process",
        json={
            "pipelines": [
                {"name": "Test Pipeline 1", "modules": []},
            ],
            "datasets": [],
            "pipeline_defaults": {"default_risk_score": 0.5, "default_averaging": [True, False]},
        },
        headers=AUTH_HEADER,
    )

    assert response.status_code == 400
    assert response.json == {"error": "Missing pipelines or datasets"}


def test_process_data_no_pipelines(client, mocker):
    response = client.post(
        "/api/process",
        json={
            "pipelines": [],
            "datasets": [1, 2, 3],
            "pipeline_defaults": {"default_risk_score": 0.5, "default_averaging": [True, False]},
        },
        headers=AUTH_HEADER,
    )

    assert response.status_code == 400
    assert response.json == {"error": "Missing pipelines or datasets"}
