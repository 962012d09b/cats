from bisect import bisect_left, bisect_right
from enum import Enum
from dateutil import parser
from processing.data_models import DatasetEntry
from datetime import datetime, timedelta


class TimeWindowForm(Enum):
    BOX = "Box"
    TRIANGLE = "Triangle"


class Operator(Enum):
    ACCUMULATE = "Accumulate"
    COUNT = "Count"
    INVERSE_COUNT = "Inverse Count"


def parse_timestamps(dataset: list[DatasetEntry]) -> list[datetime]:
    """
    Given a list of DatasetEntry objects, extract the timestamps from each entry.
    The timestamps are expected to be in ISO 8601 format.

    :param dataset: List of DatasetEntry objects.
    :type dataset: list[DatasetEntry]
    :return: List of datetime objects representing the timestamps, in the same order.
    :rtype: list[datetime]
    """

    timestamps = []
    for entry in dataset:
        timestamps.append(parser.isoparse(entry.features["timestamp"]))

    return timestamps


def parse_single_timestamp(entry: DatasetEntry) -> datetime:
    """
    Given a single DatasetEntry object, extract the timestamp.
    The timestamp is expected to be in ISO 8601 format.

    :param entry: A single DatasetEntry object.
    :type entry: DatasetEntry
    :return: A datetime object representing the timestamp.
    :rtype: datetime
    """

    return parser.isoparse(entry.features["timestamp"])


def get_window_bounds(
    cur_alert_timestamp: datetime, time_window: timedelta, include_future: bool
) -> tuple[datetime, datetime]:
    if include_future:
        return cur_alert_timestamp - time_window / 2, cur_alert_timestamp + time_window / 2
    else:
        return cur_alert_timestamp - time_window, cur_alert_timestamp


def additional_alerts_expected(
    window_start: datetime,
    window_end: datetime,
    total_num_alerts: int,
    dataset_start: datetime,
    dataset_end: datetime,
) -> float:
    effective_window_length = min(window_end, dataset_end) - max(window_start, dataset_start)
    additional_expected = (effective_window_length / (dataset_end - dataset_start)) * (
        total_num_alerts - 1
    )  # Exclude current alert

    if additional_expected == 0 and window_end != dataset_start:
        # the only scenario where this can happen if we look at the very first alert in the dataset with past only
        raise ValueError("Expected number of additional alerts cannot be zero after the first alert.")

    return additional_expected


def group_alerts_by_feature(
    alerts: list[DatasetEntry], feature: str
) -> tuple[dict[str, list[DatasetEntry]], list[DatasetEntry]]:
    """
    Given a list of DatasetEntry objects, group them by a specified feature.

    :param alerts: List of DatasetEntry objects.
    :type alerts: list[DatasetEntry]
    :param feature: Feature to group by.
    :type feature: str

    :return grouped_alerts: dictionary where the keys are the unique values of the specified feature and the values are lists of DatasetEntry objects that share that feature value
    :return alerts_without_feature: list of DatasetEntry objects that do not have the specified feature.
    """

    grouped_alerts = {}
    alerts_without_feature = []

    for alert in alerts:
        if feature not in alert.features:
            alerts_without_feature.append(alert)
            continue

        group_id = alert.features[feature]

        if type(group_id) == list:
            # With our current modules, this exception should never be raised
            raise NotImplementedError("Behavior for correlation of list features is not implemented")

        grouped_alerts.setdefault(group_id, []).append(alert)

    return grouped_alerts, alerts_without_feature


def find_alerts_in_time_range(
    timestamps: list[datetime],
    alerts: list[DatasetEntry],
    time_window: timedelta,
    current_index: int,
    include_future: bool,
) -> tuple[list[DatasetEntry], list[datetime]]:
    """
    Collect alerts within a specified time window around the current alert.
    For each one, the relative temporal distance to the current alert is calculated and stored in the metadata.

    :param timestamps: List of timestamps corresponding to the alerts.
    :type timestamps: list[datetime]
    :param alerts: List of DatasetEntry objects representing the alerts.
    :type alerts: list[DatasetEntry]
    :param time_window: Time window (timedelta) to look for alerts.
    :type time_window: timedelta
    :param current_index: Index of the current alert in the list.
    :type current_index: int
    :param include_future: Boolean indicating whether to include future alerts. If True, the time window is shifted to the right so that half of the time window is before the current alert and half is after it.
    :type include_future: bool
    :return: List of DatasetEntry objects that fall within the specified time window.
    :rtype: list[DatasetEntry]
    """

    if include_future:
        time_window = time_window / 2

    base_time = timestamps[current_index]
    lower_bound = base_time - time_window

    lower_index = bisect_left(timestamps, lower_bound, 0, current_index + 1)
    if include_future:
        upper_bound = base_time + time_window
        upper_index = bisect_right(timestamps, upper_bound, current_index, len(alerts))
    else:
        upper_index = current_index + 1

    collected_alerts = []
    collected_datetimes = []

    for index in range(lower_index, upper_index):
        alert_to_add = alerts[index]

        relative_distance = base_time - timestamps[index]
        alert_to_add.metadata["relative_distance"] = abs(relative_distance / time_window)
        collected_alerts.append(alert_to_add)
        collected_datetimes.append(timestamps[index])

    return collected_alerts, collected_datetimes


from processing.data_models import AveragingMethod, Dataset


def assign_new_scores(
    dataset: Dataset,
    module_risk_scores: dict[str, float],
    averaging_method: AveragingMethod,
    weight: float,
    logs: list[str],
    warn_msg="",
) -> None:
    """
    Always use this function to update risk scores in the dataset to ensure consistency.
    This introduces overhead in some places where one pass over the dataset would be sufficient, but it guarantees that all modules behave the same.
    Readability > Performance.

    :param dataset: Dataset containing alerts.
    :type dataset: Dataset
    :param module_risk_scores: Dictionary mapping alert IDs to their new risk scores.
    :type module_risk_scores: dict[str, float]
    :param averaging_method: The method to use for averaging risk scores.
    :type averaging_method: AveragingMethod
    :param weight: The weight to apply to the new risk scores when averaging.
    :type weight: float
    :param logs: List of existing logs to append warning messages to.
    :type logs: list[str]
    :param warn_msg: Optional warning message to log if an alert ID is not found in module_risk_scores. Only use if this behavior is unexpected for the current module.
    :type warn_msg: str
    :return: List of warning messages for alerts that were not found in module_risk_scores, to be appended to existing logs.
    :rtype: list[str]
    """
    # no prior scores -> this must be the first module
    is_first_module_of_pipe = len(dataset.data[0].metadata["raw_risk_scores"]) == 0

    for alert in dataset.data:
        alert_id = alert.metadata.get("alert_id")

        if alert_id in module_risk_scores:
            new_score = module_risk_scores[alert_id]
        else:
            new_score = 0.5  # = undecided
            if warn_msg:
                logs.append(f"\n{warn_msg}. Alert ID: {alert_id}")

        if is_first_module_of_pipe:
            # If this is the first module of a pipeline, OVERWRITE the default risk score
            if averaging_method == AveragingMethod.GEOMETRIC_MEAN:
                alert.metadata["risk_score"] = new_score**weight
            elif averaging_method == AveragingMethod.ARITHMETIC_MEAN:
                alert.metadata["risk_score"] = new_score * weight
            else:
                raise NotImplementedError(f"Averaging method {averaging_method.value} has not been implemented")
        else:
            # If not, obtain new score and normalize on the fly
            old_score = alert.metadata["risk_score"]

            if averaging_method == AveragingMethod.GEOMETRIC_MEAN:
                alert.metadata["risk_score"] = old_score * new_score**weight
            elif averaging_method == AveragingMethod.ARITHMETIC_MEAN:
                alert.metadata["risk_score"] = old_score + new_score * weight
            else:
                raise NotImplementedError(f"Averaging method {averaging_method.value} has not been implemented")

        # store raw (not normalized) score so it can be used for weight optimization later on
        alert.metadata["raw_risk_scores"].append(new_score)


def calculate_average_distance_for_triangle(
    cur_alert_timestamp: datetime,
    window_start: datetime,
    window_end: datetime,
    include_future: bool,
    dataset_start: datetime,
    dataset_end: datetime,
) -> float:
    window_length = window_end - window_start

    if not include_future:
        overlap = (window_end - max(window_start, dataset_start)) / window_length
        average_distance = 1 - 0.5 * overlap
    else:
        overlap_left = (cur_alert_timestamp - max(window_start, dataset_start)) / (window_length * 0.5)
        overlap_right = (min(window_end, dataset_end) - cur_alert_timestamp) / (window_length * 0.5)

        avg_dist_left = 1 - 0.5 * overlap_left
        avg_dist_right = 1 - 0.5 * overlap_right

        average_distance = (avg_dist_left * overlap_left + avg_dist_right * overlap_right) / (
            overlap_left + overlap_right
        )  # weighted average, aka ratio of area covered by the (cutoff) triangle

    return average_distance
