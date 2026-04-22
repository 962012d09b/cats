from modules.src.correlation_utility import (
    find_alerts_in_time_range,
    get_window_bounds,
    group_alerts_by_feature,
    parse_timestamps,
    assign_new_scores,
)
from modules.src.aperiodicity import aperiodicity_score
from processing.data_models import AveragingMethod, Dataset, DatasetEntry
from datetime import timedelta
from math import log


def process(
    dataset: Dataset, args: list, weight: float, averaging_method: AveragingMethod
) -> tuple[Dataset, list[str]]:
    logs: list[str] = []

    group_by_feature, time_window, include_future, small_n = parse_args(args)
    new_scores = {}

    try:
        grouped_alerts, _ = group_alerts_by_feature(dataset.data, group_by_feature)

        if len(grouped_alerts) == 0:
            raise ValueError(
                f"There are no alerts with the specified feature {group_by_feature} in the currently selected dataset. Choose a different feature to group by."
            )

        for group in grouped_alerts.values():
            timestamps = parse_timestamps(group)

            for index, alert in enumerate(group):
                _, relevant_timestamps = find_alerts_in_time_range(
                    timestamps=timestamps,
                    alerts=group,
                    time_window=time_window,
                    current_index=index,
                    include_future=include_future,
                )

                risk_score = aperiodicity_score(
                    events=relevant_timestamps,
                    bin_width_in_seconds=1,
                    small_n_threshold=small_n,
                )

                new_scores[alert.metadata["alert_id"]] = risk_score

        mean_score = sum(new_scores.values()) / len(new_scores)

        if mean_score == 0 or mean_score == 1:
            logs.append(f"Mean aperiodicity score is {mean_score}. No normalization applied.")
            assign_new_scores(dataset, new_scores, averaging_method, weight, logs)
        else:
            normalization_exponent = log(0.5) / log(mean_score)
            new_scores_normalized = {k: v ** normalization_exponent for k, v in new_scores.items()}
            assign_new_scores(dataset, new_scores_normalized, averaging_method, weight, logs)

    except Exception as err:
        lineno = err.__traceback__.tb_lineno if err.__traceback__ is not None else "unknown"
        logs.append(f"{repr(err)} in line {lineno}")
        return dataset, logs
    return dataset, logs


def parse_args(args) -> tuple[str, timedelta, bool, int]:
    if args[0] == "Hostname":
        group_by_feature = "hostname"
    elif args[0] == "Source IP":
        group_by_feature = "source_ip"
    elif args[0] == "Destination IP":
        group_by_feature = "destination_ip"
    elif args[0] == "Alert Type":
        group_by_feature = "rule_id"
    elif args[0] == "Username":
        group_by_feature = "username"
    else:
        raise ValueError(f"Invalid feature for grouping: {args[0]}")

    time_window = calculate_time_delta(args[1])
    include_future: bool = True if args[2] == "Past + Future" else False
    small_n = int(round(args[3]))

    return group_by_feature, time_window, include_future, small_n


def calculate_time_delta(time_window: str) -> timedelta:
    match time_window.lower():
        case "one minute":
            return timedelta(minutes=1)
        case "one hour":
            return timedelta(hours=1)
        case "one day":
            return timedelta(days=1)
        case "one week":
            return timedelta(weeks=1)
        case "four weeks":
            return timedelta(weeks=4)
        case _:
            raise ValueError("Invalid time window format.")
