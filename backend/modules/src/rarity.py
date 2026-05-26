from processing.data_models import DatasetEntry


def normalized_box_rarity(alerts_in_group: list[DatasetEntry], expected_additional_alerts: float) -> float:
    normalizer = 1 + expected_additional_alerts
    if normalizer == 1:
        score = 1
    else:
        score = (normalizer - 1) / (len(alerts_in_group) + normalizer - 2)
    return score


def normalized_triangle_rarity(
    alerts_in_group: list[DatasetEntry],
    expected_additional_alerts: float,
    average_distance: float,
) -> float:
    normalizer = 1 + (average_distance * expected_additional_alerts)
    if normalizer == 1:
        score = 1
    else:
        score = (normalizer - 1) / (
            sum(1 - alert.metadata["relative_distance"] for alert in alerts_in_group) + normalizer - 2
        )
    return score
