from processing.data_models import DatasetEntry, Dataset, Module, AveragingMethod, Pipeline, PipelineSettings
import pytest


def test_dataset_entry_init():
    full_alert = {"type": "click"}
    features = {"condition": "equals"}
    metadata = {"timestamp": "2023-01-01T00:00:00Z"}
    entry = DatasetEntry(full_alert, features, metadata)
    assert entry.full_alert == full_alert
    assert entry.features == features
    assert entry.metadata == metadata


def test_dataset_entry_from_json():
    json_data = {
        "full_alert": {"type": "click"},
        "features": {"condition": "equals"},
        "metadata": {"timestamp": "2023-01-01T00:00:00Z"},
    }
    entry = DatasetEntry.from_json(json_data)
    assert entry.full_alert == json_data["full_alert"]
    assert entry.features == json_data["features"]
    assert entry.metadata == json_data["metadata"]


def test_dataset_init():
    entries = [
        DatasetEntry(
            {"type": "click"},
            {"condition": "equals"},
            {"timestamp": "2023-01-01T00:00:00Z"},
        )
    ]
    dataset = Dataset(entries, ["some_file_name"])
    assert dataset.data == entries
    assert dataset.file_names == ["some_file_name"]
    assert dataset.results == {}


def test_module_init():
    file_name = "module.py"
    args = ["arg1", "arg2"]
    module = Module(file_name, args, weight=1.0)
    assert module.file_name == file_name
    assert module.args == args
    assert module.weight == 1.0


def test_module_from_json():
    json_data = {
        "file_name": "module.py",
        "inputs": [{"current_value": "arg1"}, {"current_value": "arg2"}],
        "weight": 1.0,
    }
    module = Module.from_json(json_data)
    assert module.file_name == json_data["file_name"]
    assert module.args == ["arg1", "arg2"]
    assert module.weight == 1.0


def test_module_to_json():
    module = Module("module.py", ["arg1", "arg2"], weight=1.0)
    json_data = module.to_json()
    assert json_data == {"file_name": "module.py", "args": ["arg1", "arg2"], "weight": 1.0}


def test_pipeline_init():
    name = "pipeline1"
    modules = [Module("module.py", ["arg1", "arg2"], weight=1.0)]
    settings = PipelineSettings(default_risk_score=0.5, averaging_method=AveragingMethod.GEOMETRIC_MEAN)
    pipeline = Pipeline(name, modules, settings)
    assert pipeline.name == name
    assert pipeline.modules == modules
    assert pipeline.settings == settings


def test_pipeline_from_json():
    json_data = {
        "name": "pipeline1",
        "modules": [
            {
                "file_name": "module.py",
                "inputs": [{"current_value": "arg1"}, {"current_value": "arg2"}],
                "weight": 1.0,
            },
        ],
        "settings": {
            "averaging_method": AveragingMethod.GEOMETRIC_MEAN.value,
            "default_risk_score": 0.5,
        },
    }
    pipeline: Pipeline = Pipeline.from_json(json_data)
    assert pipeline.name == json_data["name"]
    assert len(pipeline.modules) == len(json_data["modules"])
    assert pipeline.modules[0].file_name == json_data["modules"][0]["file_name"]
    assert pipeline.modules[0].args == ["arg1", "arg2"]
    assert pipeline.modules[0].weight == 1.0
    assert pipeline.settings.averaging_method == AveragingMethod.GEOMETRIC_MEAN
    assert pipeline.settings.default_risk_score == 0.5


def test_weight_normalization_from_json():
    json_data = {
        "name": "pipeline1",
        "modules": [
            {"file_name": "module.py", "inputs": [], "weight": 2},
            {"file_name": "module.py", "inputs": [], "weight": 2},
            {"file_name": "module.py", "inputs": [], "weight": 5},
            {"file_name": "module.py", "inputs": [], "weight": 1},
        ],
        "settings": {
            "averaging_method": AveragingMethod.GEOMETRIC_MEAN.value,
            "default_risk_score": 0.5,
        },
    }

    pipeline: Pipeline = Pipeline.from_json(json_data)
    assert pipeline.modules[0].weight == 0.2
    assert pipeline.modules[1].weight == 0.2
    assert pipeline.modules[2].weight == 0.5
    assert pipeline.modules[3].weight == 0.1


def test_pipeline_to_json():
    modules = [Module("module.py", ["arg1", "arg2"], weight=1.0)]
    pipeline = Pipeline(
        "pipeline1",
        modules,
        PipelineSettings(averaging_method=AveragingMethod.GEOMETRIC_MEAN, default_risk_score=0.5),
    )
    pipeline.logs = ["log1", "log2"]
    pipeline.results = {"result1": "value1"}
    json_data = pipeline.to_json()
    assert json_data == {
        "name": "pipeline1",
        "modules": [{"file_name": "module.py", "args": ["arg1", "arg2"], "weight": 1.0}],
        "settings": {
            "averaging_method": AveragingMethod.GEOMETRIC_MEAN.value,
            "default_risk_score": 0.5,
        },
        "logs": ["log1", "log2"],
        "results": {"result1": "value1"},
        "time_to_compute": 0.0,
        "time_to_preprocess": 0.0,
    }


def test_pipeline_from_empty_json_raises_exception():
    with pytest.raises(ValueError):
        Pipeline.from_json({})
