import threading
from unittest.mock import patch, MagicMock

import database.sql_models as sql
from processing.data_models import Dataset, DatasetEntry, AveragingMethod, Pipeline, Module, PipelineSettings
from processing.processing import fetch_datasets_from_db, process_pipelines


mock_dataset_items = [
    sql.Dataset(
        name="Name1",
        description="Description1",
        file_name="some_dataset_1.jsonl",
        does_exist=True,
    ),
    sql.Dataset(
        name="Name2",
        description="Description2",
        file_name="some_dataset_2.jsonl",
        does_exist=True,
    ),
]


mock_pipelines = [
    Pipeline(
        name="pipeline1",
        modules=[Module(file_name="module1.py", args=["arg1", "arg2"], weight=1.0)],
        settings=PipelineSettings(
            averaging_method=AveragingMethod.GEOMETRIC_MEAN,
            default_risk_score=0.5,
        ),
    ),
    Pipeline(
        name="pipeline2",
        modules=[Module(file_name="module2.py", args=["arg3", "arg4"], weight=1.0)],
        settings=PipelineSettings(
            averaging_method=AveragingMethod.ARITHMETIC_MEAN,
            default_risk_score=0.5,
        ),
    ),
]


@patch("processing.processing.db.session.query")
@patch("os.path.join", side_effect=lambda *args: "/".join(args))
def test_fetch_datasets(mock_path_join, mock_query):
    mock_query.return_value.filter.return_value.all.return_value = mock_dataset_items

    selected_dataset_ids = [1, 2]
    dataset = fetch_datasets_from_db(selected_dataset_ids, default_risk_score=0.5)

    assert dataset is not None
    assert len(dataset.data) == 2
    assert dataset.data[0].full_alert == {"type": "example alert 1"}
    assert dataset.data[1].full_alert == {"type": "example alert 2"}


@patch("processing.processing.fetch_datasets_from_db")
@patch("processing.processing.current_app.cache.get")
@patch("processing.processing.current_app.cache.set")
@patch("processing.processing.import_module")
@patch("processing.processing.calculate_results")
def test_process_pipelines(
    mock_calculate_results,
    mock_import_module,
    mock_cache_set,
    mock_cache_get,
    mock_fetch_datasets,
    app_context,
):
    mock_fetch_datasets.return_value = Dataset(
        data=[
            DatasetEntry(
                full_alert={"type": "example alert 1"},
                features={"condition": "equals"},
                metadata={"timestamp": "2023-01-01T00:00:00Z"},
            ),
            DatasetEntry(
                full_alert={"type": "example alert 2"},
                features={"condition": "contains"},
                metadata={"timestamp": "2023-01-02T00:00:00Z"},
            ),
        ],
        file_names=["dataset1.json", "dataset2.json"],
    )

    mock_cache_get.return_value = None

    mock_module = MagicMock()
    mock_module.process.return_value = (mock_fetch_datasets.return_value, "log")
    mock_import_module.return_value = mock_module

    mock_calculate_results.return_value = {"result": "calculated"}

    dataset_json = [1, 2]
    pipelines_json = [pipe.to_json() for pipe in mock_pipelines]

    expected_key_1 = f"{str(['dataset1.json', 'dataset2.json'])}{str(pipelines_json[0]['modules'])}{str({'default_risk_score': 0.5, 'averaging_method': AveragingMethod.GEOMETRIC_MEAN.value})}"
    expected_key_2 = f"{str(['dataset1.json', 'dataset2.json'])}{str(pipelines_json[1]['modules'])}{str({'default_risk_score': 0.5, 'averaging_method': AveragingMethod.ARITHMETIC_MEAN.value})}"

    pipelines = process_pipelines(dataset_json, pipelines_json, 0.5)

    assert len(pipelines) == 2
    assert pipelines[0].results == {"result": "calculated"}
    assert pipelines[1].results == {"result": "calculated"}

    mock_cache_get.assert_any_call(f"{expected_key_1}_results")
    mock_cache_get.assert_any_call(f"{expected_key_1}_logs")
    mock_cache_get.assert_any_call(f"{expected_key_2}_results")
    mock_cache_get.assert_any_call(f"{expected_key_2}_logs")

    mock_cache_set.assert_any_call(f"{expected_key_1}_results", {"result": "calculated"})
    mock_cache_set.assert_any_call(f"{expected_key_1}_logs", ["log"])
    mock_cache_set.assert_any_call(f"{expected_key_2}_results", {"result": "calculated"})
    mock_cache_set.assert_any_call(f"{expected_key_2}_logs", ["log"])


@patch("processing.processing.fetch_datasets_from_db")
@patch("processing.processing.current_app.cache.get")
@patch("processing.processing.current_app.cache.set")
def test_process_pipelines_with_cache(mock_cache_set, mock_cache_get, mock_fetch_datasets, app_context):
    mock_fetch_datasets.return_value = Dataset(
        data=[
            DatasetEntry(
                full_alert={"type": "example alert 1"},
                features={"condition": "equals"},
                metadata={"timestamp": "2023-01-01T00:00:00Z"},
            ),
            DatasetEntry(
                full_alert={"type": "example alert 2"},
                features={"condition": "contains"},
                metadata={"timestamp": "2023-01-02T00:00:00Z"},
            ),
        ],
        file_names=["dataset1.json", "dataset2.json"],
    )

    # Pretend values are cached
    mock_cache_get.side_effect = lambda key: {"result": "cached"} if "_result" in key else ["cached log"]

    dataset_json = [1, 2]
    pipelines_json = [
        {
            "name": "pipeline1",
            "modules": [
                {
                    "file_name": "module1.py",
                    "inputs": [{"current_value": "arg1"}, {"current_value": "arg2"}],
                    "weight": 1.0,
                }
            ],
            "settings": {
                "averaging_method": AveragingMethod.GEOMETRIC_MEAN.value,
                "default_risk_score": 0.3,
            },
        },
        {
            "name": "pipeline2",
            "modules": [
                {
                    "file_name": "module2.py",
                    "inputs": [{"current_value": "arg3"}, {"current_value": "arg4"}],
                    "weight": 1.0,
                }
            ],
            "settings": {
                "averaging_method": AveragingMethod.ARITHMETIC_MEAN.value,
                "default_risk_score": 0.9,
            },
        },
    ]

    pipelines = process_pipelines(dataset_json, pipelines_json, 0.5)
    # Mimic the json averaging process (json -> object -> json)
    pipelines_json = [pipe.to_json() for pipe in [Pipeline.from_json(pipe) for pipe in pipelines_json]]

    assert len(pipelines) == 2
    assert pipelines[0].results == {"result": "cached"}
    assert pipelines[1].results == {"result": "cached"}
    assert pipelines[0].logs == ["cached log"]
    assert pipelines[1].logs == ["cached log"]

    unique_cache_key_1 = f"{str(['dataset1.json', 'dataset2.json'])}{str(pipelines_json[0]['modules'])}{str({'default_risk_score': 0.3, 'averaging_method': AveragingMethod.GEOMETRIC_MEAN.value})}"
    unique_cache_key_2 = f"{str(['dataset1.json', 'dataset2.json'])}{str(pipelines_json[1]['modules'])}{str({'default_risk_score': 0.9, 'averaging_method': AveragingMethod.ARITHMETIC_MEAN.value})}"

    mock_cache_get.assert_any_call(f"{unique_cache_key_1}_results")
    mock_cache_get.assert_any_call(f"{unique_cache_key_1}_logs")
    mock_cache_get.assert_any_call(f"{unique_cache_key_2}_results")
    mock_cache_get.assert_any_call(f"{unique_cache_key_2}_logs")

    mock_cache_set.assert_not_called()
