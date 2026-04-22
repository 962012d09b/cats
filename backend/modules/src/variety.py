import math
from processing.data_models import DatasetEntry
from scipy.stats import poisson


MIN_REL_WINDOW_LENGTH = 1 / (2 * 365 * 24 * 60)  # dataset spans 2 years, window is 1 minute


def prob_at_least_one_alert_in_window(relative_window_len: float, total_num_alerts: float) -> float:
    if total_num_alerts == 0:
        raise ValueError("Total number of alerts cannot be 0")

    expected_count = relative_window_len * total_num_alerts
    prob_zero = poisson.pmf(0, expected_count)  # P(X = 0)
    prob_at_least_one = 1 - prob_zero  # P(X > 0) = 1 - P(X = 0)

    return float(prob_at_least_one)


def expected_additional_variety(
    rel_window_len: float, num_alerts_by_type: dict[str, float], current_alert_type: str
) -> float:
    # Calculate the expected number of unique alert types (excluding the current alert type)
    return sum(
        prob_at_least_one_alert_in_window(rel_window_len, total_count)
        for id, total_count in num_alerts_by_type.items()
        if id != current_alert_type
    )


def find_closest_unique_alerts_by_alert_type(alerts: list[DatasetEntry]) -> list[DatasetEntry]:
    # Sort relevant alerts by their relative distance to the current alert, from closest to farthest
    alerts.sort(key=lambda x: x.metadata["relative_distance"])

    result = []
    seen_alert_types = set()
    for alert in alerts:
        alert_type = alert.features.get("rule_id")
        if alert_type and alert_type not in seen_alert_types:
            seen_alert_types.add(alert_type)
            result.append(alert)

    if not result:
        raise ValueError(
            "No relevant alerts found in the time window. Impossible scenario, should at least contain original alert."
        )
    return result


def conditional_expectation_value(rel_window_length: float, num_alerts_in_dataset: float) -> float:
    # Returns the expectation value of the distance between the current and another alert,
    # given that there is at least one other alert in the window.

    if rel_window_length * num_alerts_in_dataset < MIN_REL_WINDOW_LENGTH:
        return 0.5 * rel_window_length  # Approximate as half the window length

    λ = num_alerts_in_dataset
    W = rel_window_length
    prob_at_least_one = prob_at_least_one_alert_in_window(W, λ)

    # Expected conditional distance
    return (1 - math.exp(-λ * W) * (1 + λ * W)) / (λ * prob_at_least_one)


def expected_relative_distance(rel_window_length: float, num_alerts_by_type: dict[str, float]):
    # Returns the weighted-average expected distance of the closest unique alerts relative to the window size.
    # E.g., a value of 0.1 means that the closest unique alerts are on average at 10% of the window length.
    if rel_window_length == 0:
        return 0.0

    alert_counts = num_alerts_by_type.values()

    return (
        sum(
            prob_at_least_one_alert_in_window(rel_window_length, n)
            * conditional_expectation_value(rel_window_length, n)
            for n in alert_counts
        )
        / sum(prob_at_least_one_alert_in_window(rel_window_length, n) for n in alert_counts)
        / rel_window_length
    )


def normalized_box_variety(closest_unique_alerts: list[DatasetEntry], expected_additional_variety: float) -> float:
    if not closest_unique_alerts:
        raise ValueError("Alerts list is empty")

    normalized_expected_count = expected_additional_variety + 1
    return 1 - 0.5 ** (len(closest_unique_alerts) / normalized_expected_count)


def normalized_triangle_variety(
    closest_unique_alerts: list[DatasetEntry],
    exp_additional_variety: float,
    rel_window_length: float,
    num_alerts_by_type: dict[str, float],
) -> float:
    if not closest_unique_alerts:
        raise ValueError("Alerts list is empty")

    exp_relative_distance = expected_relative_distance(rel_window_length, num_alerts_by_type)
    normalizer = 1 + exp_additional_variety * (1 - exp_relative_distance)
    return 1 - 0.5 ** (sum(1 - alert.metadata["relative_distance"] for alert in closest_unique_alerts) / normalizer)
