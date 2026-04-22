from modules.src.accumulation import normalized_box_accumulation, normalized_triangle_accumulation
from modules.src.correlation_utility import (
    TimeWindowForm,
    additional_alerts_expected,
    calculate_average_distance_for_triangle,
    find_alerts_in_time_range,
    get_window_bounds,
    group_alerts_by_feature,
    parse_single_timestamp,
    parse_timestamps,
    assign_new_scores,
)
from processing.data_models import AveragingMethod, Dataset, DatasetEntry
from datetime import timedelta


def process(
    dataset: Dataset, args: list, weight: float, averaging_method: AveragingMethod
) -> tuple[Dataset, list[str]]:
    logs: list[str] = []

    group_by_feature, time_window_form, time_window, include_future = parse_args(args)
    new_scores = {}

    dataset_start = parse_single_timestamp(dataset.data[0])
    dataset_end = parse_single_timestamp(dataset.data[-1])

    try:
        grouped_alerts, _ = group_alerts_by_feature(dataset.data, group_by_feature)
        number_of_groups = len(grouped_alerts)

        if number_of_groups == 0:
            raise ValueError(
                f"There are no alerts with the specified feature {group_by_feature} in the currently selected dataset. Choose a different feature to group by."
            )

        for group in grouped_alerts.values():
            timestamps = parse_timestamps(group)

            for index, alert in enumerate(group):
                relevant_alerts, _ = find_alerts_in_time_range(
                    timestamps=timestamps,
                    alerts=group,
                    time_window=time_window,
                    current_index=index,
                    include_future=include_future,
                )

                window_start, window_end = get_window_bounds(timestamps[index], time_window, include_future)
                total_additional_alerts_exp_in_time_window = additional_alerts_expected(
                    window_start=window_start,
                    window_end=window_end,
                    total_num_alerts=len(dataset.data),
                    dataset_start=dataset_start,
                    dataset_end=dataset_end,
                )
                additional_exp_alerts_in_group = total_additional_alerts_exp_in_time_window / number_of_groups

                if time_window_form == TimeWindowForm.BOX:
                    risk_score = normalized_box_accumulation(relevant_alerts, additional_exp_alerts_in_group)
                elif time_window_form == TimeWindowForm.TRIANGLE:
                    average_distance = calculate_average_distance_for_triangle(
                        cur_alert_timestamp=timestamps[index],
                        window_start=window_start,
                        window_end=window_end,
                        include_future=include_future,
                        dataset_start=dataset_start,
                        dataset_end=dataset_end,
                    )
                    risk_score = normalized_triangle_accumulation(
                        relevant_alerts, additional_exp_alerts_in_group, average_distance
                    )
                else:
                    raise ValueError(f"Invalid time window form: {time_window_form}")

                # Clamp risk_score to [0, 1] to prevent floating point precision errors)
                clamped_risk_score = max(0.0, min(1.0, risk_score))
                if abs(clamped_risk_score - risk_score) > 1e-9:
                    logs.append(
                        f"Clamped risk score from {risk_score} to {clamped_risk_score} for alert ID {alert.metadata['alert_id']}"
                    )

                new_scores[alert.metadata["alert_id"]] = clamped_risk_score

        assign_new_scores(dataset, new_scores, averaging_method, weight, logs)

    except Exception as err:
        lineno = err.__traceback__.tb_lineno if err.__traceback__ is not None else "unknown"
        logs.append(f"{repr(err)} in line {lineno}")
        return dataset, logs
    return dataset, logs


def parse_args(args):
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

    time_window_form = TimeWindowForm(args[1])
    time_window = calculate_time_delta(args[2])
    include_future: bool = True if args[3] == "Past + Future" else False

    return group_by_feature, time_window_form, time_window, include_future


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
