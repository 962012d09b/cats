from processing.data_models import Dataset, DatasetEntry, AveragingMethod
from processing.post_processing import calculate_results
from numpy import float64
from unittest.mock import patch

# Mock data
mock_dataset_entries = [
    DatasetEntry(
        full_alert={},
        features={"rule_name": "rule1"},
        metadata={
            "risk_score": 1.0,
            "raw_risk_scores": [1.0, 1.0],
            "misuse": True,
            "alert_source": "dataset1",
            "alert_id": 1,
        },
    ),
    DatasetEntry(
        full_alert={},
        features={"rule_name": "rule1"},
        metadata={
            "risk_score": 0.50,
            "raw_risk_scores": [1.0, 0.5],
            "misuse": False,
            "alert_source": "dataset1",
            "alert_id": 2,
        },
    ),
    DatasetEntry(
        full_alert={},
        features={"rule_name": "rule2"},
        metadata={
            "risk_score": 0.25,
            "raw_risk_scores": [0.5, 0.5],
            "misuse": True,
            "alert_source": "dataset1",
            "alert_id": 3,
        },
    ),
    DatasetEntry(
        full_alert={},
        features={"rule_name": "rule2"},
        metadata={
            "risk_score": 0.25,
            "raw_risk_scores": [0.75, (1.0 / 3.0)],
            "misuse": False,
            "alert_source": "dataset2",
            "alert_id": 4,
        },
    ),
    DatasetEntry(
        full_alert={},
        features={},
        metadata={
            "risk_score": 0.25,
            "raw_risk_scores": [0.8, 0.3125],
            "misuse": "unknown",
            "alert_source": "dataset2",
            "alert_id": 5,
        },
    ),
]
mock_dataset = Dataset(data=mock_dataset_entries, file_names=[])

test_pipeline = [
    {
        "name": "Pipe 1",
        "modules": [
            {
                "id": 1,
                "name": "Rule Level",
                "description": "Assigns a risk score based on the level of the triggered rule. Supports Sigma and Suricata.",
                "file_name": "level_score.py",
                "does_exist": True,
                "inputs": [],
                "input_presets": None,
                "tags": ["static"],
                "weight": 0.2,
                "uuid": "b0cb09ef-20ea-4f66-bb30-946513681506",
            },
            {
                "id": 1,
                "name": "Rule Level",
                "description": "Assigns a risk score based on the level of the triggered rule. Supports Sigma and Suricata.",
                "file_name": "level_score.py",
                "does_exist": True,
                "inputs": [],
                "input_presets": None,
                "tags": ["static"],
                "weight": 0.8,
                "uuid": "b0cb09ef-20ea-4f66-bb30-946513681506",
            },
        ],
        "settings": {
            "averaging_method": AveragingMethod.GEOMETRIC_MEAN.value,
            "default_risk_score": 0.5,
        },
        "is_visible": True,
        "uuid": "806dd84b-ef41-43ab-b7ba-bd0f634136a7",
    }
]


def test_calculate_results():
    results = calculate_results(mock_dataset)

    expected_results = {
        "total_alert_count": {
            "all": 5,
            "all_except_unknown": 4,
            "tp": 2,
            "fp": 2,
            "unknown": 1,
        },
        "alert_count_per_score": {
            "all": {
                0.25: 3,
                0.50: 1,
                1.0: 1,
            },
            "all_except_unknown": {
                0.25: 2,
                0.50: 1,
                1.0: 1,
            },
            "fp": {
                0.25: 1,
                0.50: 1,
            },
            "tp": {
                0.25: 1,
                1.0: 1,
            },
            "unknown": {
                0.25: 1,
            },
        },
        "alert_count_per_score_accumulated": {
            "all": {
                0.25: 5,
                0.50: 2,
                1.0: 1,
            },
            "all_except_unknown": {
                0.25: 4,
                0.50: 2,
                1.0: 1,
            },
            "fp": {
                0.25: 2,
                0.50: 1,
                1.0: 0,
            },
            "tp": {
                0.25: 2,
                0.50: 1,
                1.0: 1,
            },
            "unknown": {
                0.25: 1,
                0.50: 0,
                1.0: 0,
            },
        },
        "alert_count_per_alert_type": {
            "all": {
                "n/a": 1,
                "rule1": 2,
                "rule2": 2,
            },
            "all_except_unknown": {
                "rule1": 2,
                "rule2": 2,
            },
            "fp": {
                "rule1": 1,
                "rule2": 1,
            },
            "tp": {
                "rule1": 1,
                "rule2": 1,
            },
            "unknown": {
                "n/a": 1,
            },
        },
        "general_metrics": {
            "alerts_auc_relative": 0.25,
            "alerts_auc_absolute": 0.625,
            "alerts_average_precision_absolute": 0.75,  # (0.5 - 0) * 1 + (0.5 - 0.5) * 0.5 + (1 - 0.5) *0.5
            "alerts_average_precision_relative": 0.5,
            "alerts_brier_score_absolute": 0.78125,  # 1 - 1/2 * ( 1/2*(0^2 + 0.75^2) + 1/2*(0.5^2 + 0.25^2) )
            "alerts_brier_score_relative": 0.125,  # (0.78125 - 0.75) / (1 - 0.75)
            "alert_types_auc_relative": 0.25,
            "alert_types_auc_absolute": 0.625,
            "alert_types_average_precision_absolute": 0.75,
            "alert_types_average_precision_relative": 0.5,
            "alert_types_average_precision_no_skill": 0.5,
            "alert_types_brier_score_absolute": 0.78125,  # 1 - 1/2 * ( 1/2*(0^2 + 0.5^2) + 1/2*(0.75^2 + 0.25^2) ), same score in this example
            "alert_types_brier_score_relative": 0.125,
            "maximum_score": 1.0,
            "minimum_score": 0.25,
            "tp_prevalence": 0.5,
            "unique_alert_types": 2,
            "composite_score_absolute": 0.71875,
            "composite_score_relative": 0.2916666666666667,
            "feature_count": {
                "rule_name": 4,
            },
        },
        "metrics_per_score": {
            0.25: {
                "f1": 2 * (0.5 * 1) / (0.5 + 1),
                "fpr": 1.0,
                "mcc": 0,
                "precision": 0.5,
                "recall": 1.0,
                "tpr": 1.0,
            },
            0.50: {
                "f1": 0.5,
                "fpr": 0.5,
                "mcc": float64(0.0),
                "precision": 0.5,
                "recall": 0.5,
                "tpr": 0.5,
            },
            1.0: {
                "f1": 2 * (1 * 0.5) / (1 + 0.5),
                "fpr": 0.0,
                "mcc": float64(0.5773502691896258),
                "precision": 1.0,
                "recall": 0.5,
                "tpr": 0.5,
            },
        },
    }

    assert results == expected_results
