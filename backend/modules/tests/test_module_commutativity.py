import os
import importlib
from copy import deepcopy
from processing.data_models import AveragingMethod, Dataset, DatasetEntry
from itertools import permutations

from processing.post_processing import calculate_results

test_dataset_json = [
    {
        "features": {
            "timestamp": "2021-01-01T00:00:00Z",
            "source_ip": "192.168.1.10",
            "rule_id": "rule_001",
            "hostname": "host1",
            "rule_level": "high",
        },
        "metadata": {
            "alert_id": "alert_001",
            "alert_source": "sigma",
            "risk_score": 0.5,
            "raw_risk_scores": [],
            "misuse": True,
        },
    },
    {
        "features": {
            "timestamp": "2021-01-01T00:00:30Z",
            "source_ip": "192.168.1.20",
            "rule_id": "rule_002",
            "hostname": "host1",
            "rule_level": "medium",
        },
        "metadata": {
            "alert_id": "alert_002",
            "alert_source": "sigma",
            "risk_score": 0.5,
            "raw_risk_scores": [],
            "misuse": False,
        },
    },
    {
        "features": {
            "timestamp": "2021-01-01T00:01:00Z",
            "source_ip": "192.168.1.30",
            "rule_id": "rule_001",
            "hostname": "host2",
            "rule_level": "low",
        },
        "metadata": {
            "alert_id": "alert_003",
            "alert_source": "sigma",
            "risk_score": 0.5,
            "raw_risk_scores": [],
            "misuse": True,
        },
    },
]


def get_module_names():
    modules_dir = os.path.dirname(os.path.dirname(__file__))
    module_files = [f[:-3] for f in os.listdir(modules_dir) if f.endswith(".py") and not f.startswith("_")]
    return module_files


def create_test_dataset():
    entries = [DatasetEntry.from_json(entry) for entry in test_dataset_json]
    return Dataset(data=entries, file_names=["test.jsonl"])


def run_modules_in_order(module_names, dataset):
    result_dataset = deepcopy(dataset)
    weight = 1.0 / len(module_names)

    for module_name in module_names:
        module = importlib.import_module(f"modules.{module_name}")

        args = get_module_args(module_name)

        result_dataset, _ = module.process(result_dataset, args, weight=weight, averaging_method=AveragingMethod.GEOMETRIC_MEAN)

    return result_dataset


def get_module_args(module_name):
    if module_name == "level_score":
        return []
    elif module_name == "fixed_score":
        return [0.5]
    elif module_name in ["rarity", "variety", "accumulated_risk"]:
        return ["Hostname", "Box", "One minute", "Past"]
    else:
        raise ValueError(f"Unknown module name: {module_name}")


def test_all_module_combinations():
    test_dataset = create_test_dataset()

    all_modules = [
        "accumulated_risk",
        "fixed_score",
        "level_score",
        "rarity",
        "variety",
    ]
    module_permutations = permutations(all_modules)
    scores = []

    for module_order in module_permutations:
        processed_dataset = run_modules_in_order(module_order, deepcopy(test_dataset))
        result = calculate_results(processed_dataset)
        scores.append(result["general_metrics"]["alerts_auc_absolute"])

    # All scores should be the same, no matter the module order
    first_score = scores[0]
    for score in scores[1:]:
        assert score == first_score, f"AUC scores differ: {score} != {first_score}"


def test_individual_module_scores():
    dataset = create_test_dataset()
    rarity_module = importlib.import_module("modules.rarity")

    # Run rarity twice with same input
    result1, _ = rarity_module.process(
        deepcopy(dataset),
        ["Hostname", "Box", "One minute", "Past"],
        weight=0.5,
        averaging_method=AveragingMethod.GEOMETRIC_MEAN,
    )
    result2, _ = rarity_module.process(
        deepcopy(dataset),
        ["Hostname", "Box", "One minute", "Past"],
        weight=0.5,
        averaging_method=AveragingMethod.GEOMETRIC_MEAN,
    )

    scores1 = [alert.metadata["risk_score"] for alert in result1.data]
    scores2 = [alert.metadata["risk_score"] for alert in result2.data]

    assert scores1 == scores2

    variety_module = importlib.import_module("modules.variety")

    # Run variety twice with same input
    result3, _ = variety_module.process(
        deepcopy(dataset),
        ["Hostname", "Box", "One minute", "Past"],
        weight=0.5,
        averaging_method=AveragingMethod.GEOMETRIC_MEAN,
    )
    result4, _ = variety_module.process(
        deepcopy(dataset),
        ["Hostname", "Box", "One minute", "Past"],
        weight=0.5,
        averaging_method=AveragingMethod.GEOMETRIC_MEAN,
    )

    scores3 = [alert.metadata["risk_score"] for alert in result3.data]
    scores4 = [alert.metadata["risk_score"] for alert in result4.data]

    assert scores3 == scores4
