from enum import Enum
from math import prod
from processing.data_models import Dataset, DatasetEntry, AveragingMethod

import numpy as np
from sklearn.metrics import roc_auc_score, average_precision_score, brier_score_loss


class Label(Enum):
    TRUE_POSITIVE = "tp"
    FALSE_POSITIVE = "fp"
    UNKNOWN = "unknown"


def normalize_scores(
    dataset: Dataset, num_of_modules: int, averaging_method: AveragingMethod, weights: list[float] = []
) -> Dataset:
    if num_of_modules == 0:
        # empty pipeline, just keep the default score set during preprocessing
        return dataset

    if weights:
        if len(weights) != num_of_modules:
            raise ValueError("Weights list must match number of modules")
        if abs(sum(weights) - 1.0) > 1e-10:
            raise NotImplementedError("Weights must sum to 1, averaging not implemented otherwise")

        for entry in dataset.data:
            all_scores = entry.metadata["raw_risk_scores"]
            if averaging_method == AveragingMethod.GEOMETRIC_MEAN:
                entry.metadata["risk_score"] = prod(score**weight for score, weight in zip(all_scores, weights))
            elif averaging_method == AveragingMethod.ARITHMETIC_MEAN:
                entry.metadata["risk_score"] = sum(score * weight for score, weight in zip(all_scores, weights))
            else:
                raise ValueError(f"Averaging method not implemented: {averaging_method}")

    else:
        for entry in dataset.data:
            all_scores = entry.metadata["raw_risk_scores"]

            if averaging_method == AveragingMethod.GEOMETRIC_MEAN:
                entry.metadata["risk_score"] = prod(all_scores) ** (1 / (num_of_modules))
            elif averaging_method == AveragingMethod.ARITHMETIC_MEAN:
                entry.metadata["risk_score"] = sum(all_scores) / num_of_modules
            else:
                raise ValueError(f"Averaging method not implemented: {averaging_method}")

    return dataset


def calculate_results(dataset: Dataset) -> dict:
    # fields don't necessarily have to be all defined here, that's just for clarity
    # having "all_except_unknown" is technically redundant,
    # but it makes related code a lot more explicit and readable
    results = {
        "total_alert_count": {
            "all": 0,
            "all_except_unknown": 0,
            "tp": 0,
            "fp": 0,
            "unknown": 0,
        },
        "alert_count_per_score": {
            "all": {},
            "all_except_unknown": {},
            "tp": {},
            "fp": {},
            "unknown": {},
        },
        "alert_count_per_score_accumulated": {
            # REVERSED, i.e., highest score first
            "all": {},
            "all_except_unknown": {},
            "tp": {},
            "fp": {},
            "unknown": {},
        },
        "alert_count_per_alert_type": {
            "all": {},
            "all_except_unknown": {},
            "tp": {},
            "fp": {},
            "unknown": {},
        },
        "general_metrics": {
            "tp_prevalence": 0,
            "maximum_score": 0,
            "minimum_score": 0,
            "unique_alert_types": 0,
            "alerts_auc_relative": 0,
            "alerts_auc_absolute": 0,
            "alerts_average_precision_absolute": 0,
            "alerts_average_precision_relative": 0,
            "alerts_brier_score_absolute": 0,
            "alerts_brier_score_relative": 0,
            "alert_types_auc_relative": 0,
            "alert_types_auc_absolute": 0,
            "alert_types_average_precision_absolute": 0,
            "alert_types_average_precision_relative": 0,
            "alert_types_average_precision_no_skill": 0,
            "alert_types_brier_score_absolute": 0,
            "alert_types_brier_score_relative": 0,
            "composite_score_absolute": 0,
            "composite_score_relative": 0,
            "feature_count": {},
        },
        "metrics_per_score": {
            # tpr, fpr, precision, recall, f1, mcc
        },
    }

    y_true, y_scores, alert_types = count_alerts_and_features(dataset.data, results)
    count_accumulated_alerts(results)
    calculate_metrics_per_score(results)
    calculate_general_metrics(results, y_true, y_scores)
    calculate_metrics_weighted_per_alert_type(results, y_true, y_scores, alert_types)
    calculate_composite_scores(results)

    return results


def count_alerts_and_features(data: list[DatasetEntry], results: dict) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    # collect and return once to avoid multiple passes over data
    y_true = []
    y_scores = []
    alert_types = []

    for entry in data:
        score = entry.metadata["risk_score"]
        label = get_label(entry.metadata["misuse"])
        rule_name = entry.features.get("rule_name", "n/a")
        features = entry.features.keys()

        for feature in features:
            results["general_metrics"]["feature_count"][feature] = (
                results["general_metrics"]["feature_count"].get(feature, 0) + 1
            )

        results["total_alert_count"]["all"] += 1
        results["alert_count_per_score"]["all"][score] = results["alert_count_per_score"]["all"].get(score, 0) + 1
        results["alert_count_per_alert_type"]["all"][rule_name] = (
            results["alert_count_per_alert_type"]["all"].get(rule_name, 0) + 1
        )

        if label != Label.UNKNOWN:
            y_true.append(1 if label == Label.TRUE_POSITIVE else 0)
            y_scores.append(score)
            alert_types.append(rule_name)

            results["total_alert_count"]["all_except_unknown"] += 1
            results["alert_count_per_score"]["all_except_unknown"][score] = (
                results["alert_count_per_score"]["all_except_unknown"].get(score, 0) + 1
            )
            results["alert_count_per_alert_type"]["all_except_unknown"][rule_name] = (
                results["alert_count_per_alert_type"]["all_except_unknown"].get(rule_name, 0) + 1
            )

        if label == Label.TRUE_POSITIVE:
            results["total_alert_count"]["tp"] += 1
            results["alert_count_per_score"]["tp"][score] = results["alert_count_per_score"]["tp"].get(score, 0) + 1
            results["alert_count_per_alert_type"]["tp"][rule_name] = (
                results["alert_count_per_alert_type"]["tp"].get(rule_name, 0) + 1
            )
        elif label == Label.FALSE_POSITIVE:
            results["total_alert_count"]["fp"] += 1
            results["alert_count_per_score"]["fp"][score] = results["alert_count_per_score"]["fp"].get(score, 0) + 1
            results["alert_count_per_alert_type"]["fp"][rule_name] = (
                results["alert_count_per_alert_type"]["fp"].get(rule_name, 0) + 1
            )
        elif label == Label.UNKNOWN:
            results["total_alert_count"]["unknown"] += 1
            results["alert_count_per_score"]["unknown"][score] = (
                results["alert_count_per_score"]["unknown"].get(score, 0) + 1
            )
            results["alert_count_per_alert_type"]["unknown"][rule_name] = (
                results["alert_count_per_alert_type"]["unknown"].get(rule_name, 0) + 1
            )

    return np.array(y_true), np.array(y_scores), np.array(alert_types)


def count_accumulated_alerts(results: dict):
    accumulated_all = 0
    accumulated_tp = 0
    accumulated_fp = 0
    accumulated_unknown = 0

    for score in sorted(results["alert_count_per_score"]["all"].keys(), reverse=True):
        accumulated_tp += results["alert_count_per_score"]["tp"].get(score, 0)
        results["alert_count_per_score_accumulated"]["tp"][score] = accumulated_tp

        accumulated_fp += results["alert_count_per_score"]["fp"].get(score, 0)
        results["alert_count_per_score_accumulated"]["fp"][score] = accumulated_fp

        accumulated_unknown += results["alert_count_per_score"]["unknown"].get(score, 0)
        results["alert_count_per_score_accumulated"]["unknown"][score] = accumulated_unknown

        accumulated_all += results["alert_count_per_score"]["all"][score]
        results["alert_count_per_score_accumulated"]["all"][score] = accumulated_all
        results["alert_count_per_score_accumulated"]["all_except_unknown"][score] = (
            accumulated_all - accumulated_unknown
        )


def calculate_metrics_per_score(results: dict):
    # This IGNORES alerts labeled as "unknown"
    for score in results["alert_count_per_score"]["all"].keys():
        tp = results["alert_count_per_score_accumulated"]["tp"][score]
        fp = results["alert_count_per_score_accumulated"]["fp"][score]
        tn = results["total_alert_count"]["fp"] - fp  # all FPs AFTER the cutoff score are TNs
        fn = results["total_alert_count"]["tp"] - tp  # all TPs AFTER the cutoff score are FNs

        tpr = tp / (tp + fn) if tp + fn > 0 else 0
        fpr = fp / (fp + tn) if fp + tn > 0 else 0
        precision = tp / (tp + fp) if tp + fp > 0 else 0
        recall = tp / (tp + fn) if tp + fn > 0 else 0
        f1 = 2 * (precision * recall) / (precision + recall) if precision + recall > 0 else 0
        mcc = (
            (tn * tp - fn * fp) / np.sqrt((tp + fp) * (tp + fn) * (tn + fp) * (tn + fn))
            if ((tp + fp) * (tp + fn) * (tn + fp) * (tn + fn)) > 0
            else 0
        )

        results["metrics_per_score"][score] = {
            "tpr": tpr,
            "fpr": fpr,
            "precision": precision,
            "recall": recall,
            "f1": f1,
            "mcc": mcc,
        }


def calculate_general_metrics(results: dict, y_true: np.ndarray, y_scores: np.ndarray):
    tp_count = results["total_alert_count"]["tp"]
    results["general_metrics"]["tp_prevalence"] = (
        tp_count / results["total_alert_count"]["all_except_unknown"]
        if results["total_alert_count"]["all_except_unknown"] > 0
        else 0
    )
    try:
        results["general_metrics"]["maximum_score"] = max(
            results["alert_count_per_score"]["all_except_unknown"].keys()
        )
        results["general_metrics"]["minimum_score"] = min(
            results["alert_count_per_score"]["all_except_unknown"].keys()
        )
    except ValueError:
        results["general_metrics"]["maximum_score"] = None
        results["general_metrics"]["minimum_score"] = None

    if len(np.unique(y_true)) < 2:
        # only one class present
        results["general_metrics"]["alerts_auc_relative"] = None
        results["general_metrics"]["alerts_auc_absolute"] = None
        return

    auc_absolute = roc_auc_score(y_true, y_scores)
    auc_relative = 2 * auc_absolute - 1
    results["general_metrics"]["alerts_auc_relative"] = auc_relative
    results["general_metrics"]["alerts_auc_absolute"] = auc_absolute

    ap_absolute = average_precision_score(y_true, y_scores)
    ap_random = results["general_metrics"]["tp_prevalence"]
    ap_relative = (ap_absolute - ap_random) / (1 - ap_random)
    results["general_metrics"]["alerts_average_precision_absolute"] = ap_absolute
    results["general_metrics"]["alerts_average_precision_relative"] = ap_relative

    brier_absolute = weighted_inverse_balanced_brier_score(
        y_true, y_scores, np.ones_like(y_true, dtype=float), results
    )
    best_random_brier = 0.75
    brier_relative = (brier_absolute - best_random_brier) / (1 - best_random_brier)
    results["general_metrics"]["alerts_brier_score_absolute"] = brier_absolute
    results["general_metrics"]["alerts_brier_score_relative"] = brier_relative


def calculate_metrics_weighted_per_alert_type(
    results: dict, y_true: np.ndarray, y_scores: np.ndarray, alert_types: np.ndarray
):
    if len(np.unique(y_true)) < 2:
        # only one class present
        set_alert_type_metrics_to_none(results)
        return

    inv_freq_weights = compute_inverse_frequency_weights(alert_types)

    auc_absolute = roc_auc_score(y_true, y_scores, sample_weight=inv_freq_weights)
    auc_relative = 2 * auc_absolute - 1

    ap_absolute = average_precision_score(y_true, y_scores, sample_weight=inv_freq_weights)
    weighted_no_skill_ap = np.sum(inv_freq_weights * y_true) / np.sum(inv_freq_weights)
    ap_relative = (ap_absolute - weighted_no_skill_ap) / (1 - weighted_no_skill_ap) if weighted_no_skill_ap < 1 else 0

    brier_absolute = weighted_inverse_balanced_brier_score(y_true, y_scores, inv_freq_weights, results)
    best_random_brier = 0.75
    brier_relative = (brier_absolute - best_random_brier) / (1 - best_random_brier)

    results["general_metrics"]["unique_alert_types"] = len(np.unique(alert_types))
    results["general_metrics"]["alert_types_auc_absolute"] = auc_absolute
    results["general_metrics"]["alert_types_auc_relative"] = auc_relative
    results["general_metrics"]["alert_types_average_precision_absolute"] = ap_absolute
    results["general_metrics"]["alert_types_average_precision_relative"] = ap_relative
    results["general_metrics"]["alert_types_average_precision_no_skill"] = weighted_no_skill_ap
    results["general_metrics"]["alert_types_brier_score_absolute"] = brier_absolute
    results["general_metrics"]["alert_types_brier_score_relative"] = brier_relative


def compute_inverse_frequency_weights(alert_types: np.ndarray) -> np.ndarray:
    unique_types, counts = np.unique(alert_types, return_counts=True)
    frequency_map = dict(zip(unique_types, counts))

    weights = np.array([1.0 / frequency_map[cur_type] for cur_type in alert_types])

    # weighted mean = unweighted mean scale
    weights = weights * len(alert_types) / np.sum(weights)
    return weights


def weighted_inverse_balanced_brier_score(
    y_true: np.ndarray, y_scores: np.ndarray, sample_weights: np.ndarray, results: dict
) -> float:
    tp_prevalence = results["general_metrics"]["tp_prevalence"]

    opposite_class_prevalence = np.where(y_true == 1, 1 - tp_prevalence, tp_prevalence)
    balanced_weights = sample_weights * opposite_class_prevalence

    brier_score = brier_score_loss(y_true, y_scores, sample_weight=balanced_weights)
    inverse_brier_score = 1 - brier_score
    return float(inverse_brier_score)


def calculate_composite_scores(results: dict):
    results["general_metrics"]["composite_score_absolute"] = np.mean(
        [
            results["general_metrics"]["alerts_auc_absolute"],
            results["general_metrics"]["alert_types_auc_absolute"],
            results["general_metrics"]["alerts_average_precision_absolute"],
            results["general_metrics"]["alert_types_average_precision_absolute"],
            results["general_metrics"]["alerts_brier_score_absolute"],
            results["general_metrics"]["alert_types_brier_score_absolute"],
        ]
    )
    results["general_metrics"]["composite_score_relative"] = np.mean(
        [
            max(results["general_metrics"]["alerts_auc_relative"], 0),
            max(results["general_metrics"]["alert_types_auc_relative"], 0),
            max(results["general_metrics"]["alerts_average_precision_relative"], 0),
            max(results["general_metrics"]["alert_types_average_precision_relative"], 0),
            max(results["general_metrics"]["alerts_brier_score_relative"], 0),
            max(results["general_metrics"]["alert_types_brier_score_relative"], 0),
        ]
    )


def set_alert_type_metrics_to_none(results: dict):
    results["general_metrics"]["alert_types_auc_relative"] = None
    results["general_metrics"]["alert_types_auc_absolute"] = None
    results["general_metrics"]["alert_types_average_precision_absolute"] = None
    results["general_metrics"]["alert_types_average_precision_relative"] = None
    results["general_metrics"]["alert_types_average_precision_no_skill"] = None
    results["general_metrics"]["alert_types_brier_score_absolute"] = None
    results["general_metrics"]["alert_types_brier_score_relative"] = None


def get_label(misuse: str | bool) -> Label:
    if type(misuse) is bool:
        return Label.TRUE_POSITIVE if misuse else Label.FALSE_POSITIVE
    elif type(misuse) is str:
        if misuse.lower() == "yes":
            return Label.TRUE_POSITIVE
        elif misuse.lower() == "no":
            return Label.FALSE_POSITIVE
        elif "unknown" in misuse.lower():
            return Label.UNKNOWN
        else:
            raise ValueError(f"Unsupported label string: {misuse}")
    else:
        raise ValueError(f"Unsupported label type: {type(misuse)}")


def get_label_bool(misuse: str | bool) -> bool:
    if type(misuse) is bool:
        return misuse
    elif type(misuse) is str:
        if misuse.lower() == "yes":
            return True
        elif misuse.lower() == "no":
            return False
        elif "unknown" in misuse.lower():
            return False
        else:
            raise ValueError(f"Unsupported label string: {misuse}")
    else:
        raise ValueError(f"Unsupported label type: {type(misuse)}")
