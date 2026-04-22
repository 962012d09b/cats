from copy import deepcopy
from datetime import datetime, timedelta

from modules.src.correlation_utility import (
    assign_new_scores,
    calculate_average_distance_for_triangle,
    find_alerts_in_time_range,
    get_window_bounds,
    group_alerts_by_feature,
    parse_timestamps,
)
from processing.data_models import AveragingMethod, Dataset, DatasetEntry


test_dataset_json = [
    {
        "features": {
            "timestamp": "2021-01-01T00:00:00Z",
            "source_ip": "127.0.0.1",
            "rule_id": "1",
            "hostname": "host1",
        },
        "metadata": {
            "risk_score": 0.25,
        },
    },
    {
        "features": {
            "timestamp": "2021-01-01T00:30:00Z",
            "source_ip": "127.0.0.1",
            "rule_id": "1",
            "hostname": "host1",
        },
        "metadata": {
            "risk_score": 0.50,
        },
    },
    {
        "features": {
            "timestamp": "2021-01-01T00:59:59Z",
            "source_ip": "127.0.0.1",
            "rule_id": "2",
            "hostname": "host2",
        },
        "metadata": {
            "risk_score": 0.75,
        },
    },
    {
        "features": {
            "timestamp": "2021-01-01T01:00:00Z",
            "source_ip": "127.0.0.1",
            "rule_id": "2",
            "hostname": "host3",
        },
        "metadata": {
            "risk_score": 0.25,
        },
    },
    {
        "features": {
            "timestamp": "2021-01-01T01:00:01Z",
            "source_ip": "127.0.0.1",
            "rule_id": "2",
            "hostname": "host2",
        },
        "metadata": {
            "risk_score": 0.25,
        },
    },
    {
        "features": {
            "timestamp": "2021-01-01T02:00:00Z",
            "source_ip": "127.0.0.1",
            "rule_id": "2",
            "hostname": "host2",
        },
        "metadata": {
            "risk_score": 0.25,
        },
    },
]
test_dataset = [DatasetEntry.from_json(entry) for entry in test_dataset_json]


def test_group_alerts_by_feature():
    grouped_alerts, alerts_without_feature = group_alerts_by_feature(test_dataset, "hostname")

    assert len(grouped_alerts) == 3
    assert len(alerts_without_feature) == 0
    assert grouped_alerts["host1"] == [test_dataset[0], test_dataset[1]]
    assert grouped_alerts["host2"] == [test_dataset[2], test_dataset[4], test_dataset[5]]
    assert grouped_alerts["host3"] == [test_dataset[3]]

    grouped_alerts, alerts_without_feature = group_alerts_by_feature(test_dataset, "rule_id")

    assert len(grouped_alerts) == 2
    assert len(alerts_without_feature) == 0
    assert grouped_alerts["1"] == [test_dataset[0], test_dataset[1]]
    assert grouped_alerts["2"] == [test_dataset[2], test_dataset[3], test_dataset[4], test_dataset[5]]

    grouped_alerts, alerts_without_feature = group_alerts_by_feature(test_dataset, "source_ip")

    assert len(grouped_alerts) == 1
    assert len(alerts_without_feature) == 0
    assert grouped_alerts["127.0.0.1"] == test_dataset


def test_find_alerts_in_time_range():
    # no group, past only
    timestamps = parse_timestamps(test_dataset)
    time_window = timedelta(hours=1)

    alerts, _ = find_alerts_in_time_range(timestamps, test_dataset, time_window, 0, False)
    assert len(alerts) == 1
    alerts, _ = find_alerts_in_time_range(timestamps, test_dataset, time_window, 1, False)
    assert len(alerts) == 2
    alerts, _ = find_alerts_in_time_range(timestamps, test_dataset, time_window, 2, False)
    assert len(alerts) == 3
    alerts, _ = find_alerts_in_time_range(timestamps, test_dataset, time_window, 3, False)
    assert len(alerts) == 4
    alerts, _ = find_alerts_in_time_range(timestamps, test_dataset, time_window, 4, False)
    assert len(alerts) == 4
    alerts, _ = find_alerts_in_time_range(timestamps, test_dataset, time_window, 5, False)
    assert len(alerts) == 3

    # no group, future included
    time_window = timedelta(hours=1)
    alerts, _ = find_alerts_in_time_range(timestamps, test_dataset, time_window, 0, True)
    assert len(alerts) == 2
    alerts, _ = find_alerts_in_time_range(timestamps, test_dataset, time_window, 1, True)
    assert len(alerts) == 4
    alerts, _ = find_alerts_in_time_range(timestamps, test_dataset, time_window, 2, True)
    assert len(alerts) == 4
    alerts, _ = find_alerts_in_time_range(timestamps, test_dataset, time_window, 3, True)
    assert len(alerts) == 4
    alerts, _ = find_alerts_in_time_range(timestamps, test_dataset, time_window, 4, True)
    assert len(alerts) == 3
    alerts, _ = find_alerts_in_time_range(timestamps, test_dataset, time_window, 5, True)
    assert len(alerts) == 1


def test_get_window_bounds():
    time_window = timedelta(hours=1)

    start, end = get_window_bounds(datetime(2021, 1, 1, 0, 0, 0), time_window, False)
    assert start == datetime(2020, 12, 31, 23, 0, 0)
    assert end == datetime(2021, 1, 1, 0, 0, 0)
    assert end - start == time_window

    start, end = get_window_bounds(datetime(2021, 1, 1, 0, 0, 0), time_window, True)
    assert start == datetime(2020, 12, 31, 23, 30, 0)
    assert end == datetime(2021, 1, 1, 0, 30, 0)
    assert end - start == time_window


class TestAssignNewScores:
    dataset_bp = Dataset(
        file_names=[],
        data=[
            DatasetEntry(
                full_alert={}, features={}, metadata={"alert_id": "1", "risk_score": 0.5, "raw_risk_scores": [0.5]}
            ),
            DatasetEntry(
                full_alert={}, features={}, metadata={"alert_id": "2", "risk_score": 0.7, "raw_risk_scores": [0.7]}
            ),
        ],
    )

    def test_assign_existing_scores(self):
        dataset = deepcopy(self.dataset_bp)

        new_scores = {"1": 0.8, "2": 0.6}
        logs = []

        assign_new_scores(dataset, new_scores, AveragingMethod.GEOMETRIC_MEAN, 1.0, logs)

        assert dataset.data[0].metadata["risk_score"] == 0.4  # 0.5 * 0.8
        assert dataset.data[1].metadata["risk_score"] == 0.42  # 0.7 * 0.6
        assert dataset.data[0].metadata["raw_risk_scores"] == [0.5, 0.8]
        assert dataset.data[1].metadata["raw_risk_scores"] == [0.7, 0.6]

    def test_assign_weighted_geometric_mean(self):
        dataset = deepcopy(self.dataset_bp)

        new_scores = {"1": 0.8, "2": 0.6}
        logs = []

        assign_new_scores(dataset, new_scores, AveragingMethod.GEOMETRIC_MEAN, 0.5, logs)

        assert dataset.data[0].metadata["risk_score"] == 0.4472135954999579  # 0.5 * 0.8^0.5
        assert dataset.data[1].metadata["risk_score"] == 0.5422176684690383  # 0.7 * 0.6^0.5
        assert dataset.data[0].metadata["raw_risk_scores"] == [0.5, 0.8]
        assert dataset.data[1].metadata["raw_risk_scores"] == [0.7, 0.6]

    def test_assign_weighted_arithmetic_mean(self):
        dataset = deepcopy(self.dataset_bp)

        new_scores = {"1": 0.8, "2": 0.6}
        logs = []

        assign_new_scores(dataset, new_scores, AveragingMethod.ARITHMETIC_MEAN, 0.5, logs)

        assert dataset.data[0].metadata["risk_score"] == 0.9  # 0.5 + (0.8*0.5)
        assert dataset.data[1].metadata["risk_score"] == 1.0  # 0.7 + (0.6*0.5)
        assert dataset.data[0].metadata["raw_risk_scores"] == [0.5, 0.8]
        assert dataset.data[1].metadata["raw_risk_scores"] == [0.7, 0.6]

    def test_assign_missing_scores(self):
        dataset = deepcopy(self.dataset_bp)

        new_scores = {"1": 0.8}  # Missing score for alert_id "2"
        logs = []

        assign_new_scores(dataset, new_scores, AveragingMethod.GEOMETRIC_MEAN, 1.0, logs, warn_msg="Wee-ooo wee-ooo")

        assert dataset.data[0].metadata["risk_score"] == 0.4  # 0.5 * 0.8
        assert dataset.data[1].metadata["risk_score"] == 0.35  # 0.7 * 0.5 (default)
        assert dataset.data[0].metadata["raw_risk_scores"] == [0.5, 0.8]
        assert dataset.data[1].metadata["raw_risk_scores"] == [0.7, 0.5]
        assert logs[0] == "\nWee-ooo wee-ooo. Alert ID: 2"  # Warning message should be logged

    def test_assign_first_module_scores(self):
        dataset = deepcopy(self.dataset_bp)
        for entry in dataset.data:
            entry.metadata["raw_risk_scores"] = []

        new_scores = {"1": 0.8, "2": 0.6}
        logs = []

        assign_new_scores(dataset, new_scores, AveragingMethod.GEOMETRIC_MEAN, 1.0, logs)

        assert dataset.data[0].metadata["risk_score"] == 0.8  # Overwritten
        assert dataset.data[1].metadata["risk_score"] == 0.6  # Overwritten
        assert dataset.data[0].metadata["raw_risk_scores"] == [0.8]
        assert dataset.data[1].metadata["raw_risk_scores"] == [0.6]


class TestCalculateAverageDistanceForTriangle:
    test_dataset_start = datetime(2021, 1, 1, 10, 0, 0)
    test_dataset_end = datetime(2021, 1, 1, 20, 0, 0)

    def test_full_overlap_past_only(self):
        cur_alert_timestamp = datetime(2021, 1, 1, 15, 0, 0)
        window_start = cur_alert_timestamp - timedelta(hours=1)
        window_end = cur_alert_timestamp

        average_distance = calculate_average_distance_for_triangle(
            cur_alert_timestamp=cur_alert_timestamp,
            window_start=window_start,
            window_end=window_end,
            include_future=False,
            dataset_start=self.test_dataset_start,
            dataset_end=self.test_dataset_end,
        )
        assert average_distance == 0.5

    def test_full_overlap_include_future(self):
        cur_alert_timestamp = datetime(2021, 1, 1, 15, 0, 0)
        window_start = cur_alert_timestamp - timedelta(hours=0.5)
        window_end = cur_alert_timestamp + timedelta(hours=0.5)

        average_distance = calculate_average_distance_for_triangle(
            cur_alert_timestamp=cur_alert_timestamp,
            window_start=window_start,
            window_end=window_end,
            include_future=True,
            dataset_start=self.test_dataset_start,
            dataset_end=self.test_dataset_end,
        )
        assert average_distance == 0.5

    def test_start_of_dataset_past_only(self):
        cur_alert_timestamp = self.test_dataset_start
        window_start = cur_alert_timestamp - timedelta(hours=1)
        window_end = cur_alert_timestamp

        average_distance = calculate_average_distance_for_triangle(
            cur_alert_timestamp=cur_alert_timestamp,
            window_start=window_start,
            window_end=window_end,
            include_future=False,
            dataset_start=self.test_dataset_start,
            dataset_end=self.test_dataset_end,
        )
        assert average_distance == 1.0

    def test_start_of_dataset_include_future(self):
        cur_alert_timestamp = self.test_dataset_start
        window_start = cur_alert_timestamp - timedelta(hours=0.5)
        window_end = cur_alert_timestamp + timedelta(hours=0.5)

        average_distance = calculate_average_distance_for_triangle(
            cur_alert_timestamp=cur_alert_timestamp,
            window_start=window_start,
            window_end=window_end,
            include_future=True,
            dataset_start=self.test_dataset_start,
            dataset_end=self.test_dataset_end,
        )
        assert average_distance == 0.5

    def test_end_of_dataset_past_only(self):
        cur_alert_timestamp = self.test_dataset_end
        window_start = cur_alert_timestamp - timedelta(hours=1)
        window_end = cur_alert_timestamp

        average_distance = calculate_average_distance_for_triangle(
            cur_alert_timestamp=cur_alert_timestamp,
            window_start=window_start,
            window_end=window_end,
            include_future=False,
            dataset_start=self.test_dataset_start,
            dataset_end=self.test_dataset_end,
        )
        assert average_distance == 0.5

    def test_end_of_dataset_include_future(self):
        cur_alert_timestamp = self.test_dataset_end
        window_start = cur_alert_timestamp - timedelta(hours=0.5)
        window_end = cur_alert_timestamp + timedelta(hours=0.5)

        average_distance = calculate_average_distance_for_triangle(
            cur_alert_timestamp=cur_alert_timestamp,
            window_start=window_start,
            window_end=window_end,
            include_future=True,
            dataset_start=self.test_dataset_start,
            dataset_end=self.test_dataset_end,
        )
        assert average_distance == 0.5

    def test_partial_overlap_past_only(self):
        cur_alert_timestamp = self.test_dataset_start + timedelta(hours=0.75)
        window_start = cur_alert_timestamp - timedelta(hours=1)
        window_end = cur_alert_timestamp

        average_distance = calculate_average_distance_for_triangle(
            cur_alert_timestamp=cur_alert_timestamp,
            window_start=window_start,
            window_end=window_end,
            include_future=False,
            dataset_start=self.test_dataset_start,
            dataset_end=self.test_dataset_end,
        )
        assert average_distance == 0.625

    def test_partial_overlap_include_future(self):
        cur_alert_timestamp = self.test_dataset_start + timedelta(hours=0.25)
        window_start = cur_alert_timestamp - timedelta(hours=0.5)
        window_end = cur_alert_timestamp + timedelta(hours=0.5)

        average_distance = calculate_average_distance_for_triangle(
            cur_alert_timestamp=cur_alert_timestamp,
            window_start=window_start,
            window_end=window_end,
            include_future=True,
            dataset_start=self.test_dataset_start,
            dataset_end=self.test_dataset_end,
        )
        assert average_distance == 0.5833333333333334
