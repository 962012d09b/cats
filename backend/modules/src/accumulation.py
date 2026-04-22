from processing.data_models import DatasetEntry


def normalized_box_accumulation(alerts: list[DatasetEntry], additional_expected_count: float) -> float:
    if not alerts:
        raise ValueError("Alerts list is empty")

    normalized_expected_count = additional_expected_count + 1
    return 1 - 0.5 ** (len(alerts) / normalized_expected_count)


def normalized_triangle_accumulation(
    alerts: list[DatasetEntry],
    additional_expected_count: float,
    average_distance: float,
) -> float:
    if not alerts:
        raise ValueError("Alerts list is empty")
    normalized_expected_count = 1 + (average_distance * additional_expected_count)
    risk_score = 1 - 0.5 ** (
        sum(1 - alert.metadata["relative_distance"] for alert in alerts) / normalized_expected_count
    )

    return risk_score
