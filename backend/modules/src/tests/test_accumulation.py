from datetime import datetime, timedelta
from modules.src.accumulation import normalized_box_accumulation, normalized_triangle_accumulation
from modules.src.correlation_utility import calculate_average_distance_for_triangle
from processing.data_models import DatasetEntry
import pytest


class TestNormalizedBoxAccumulation:
    def test_single_alert_expected_one(self):
        alerts = [self._create_alert()]
        additional_expected_count = 1.0
        result = normalized_box_accumulation(alerts, additional_expected_count)
        # With 1 alert and expected 1, normalized expected = 2, so 1 - 0.5^(1/2) = 1 - 0.707... ≈ 0.293
        assert result == 0.2928932188134524

    def test_more_alerts_than_expected(self):
        alerts = [self._create_alert() for _ in range(5)]
        additional_expected_count = 2.0
        result = normalized_box_accumulation(alerts, additional_expected_count)
        # With 5 alerts and expected 2, normalized expected = 3, so 1 - 0.5^(5/3) ≈ 0.685
        assert result == 0.6850197375262816

    def test_fewer_alerts_than_expected(self):
        alerts = [self._create_alert() for _ in range(2)]
        additional_expected_count = 5.0
        result = normalized_box_accumulation(alerts, additional_expected_count)
        # With 2 alerts and expected 5, normalized expected = 6, so 1 - 0.5^(2/6) ≈ 0.206
        assert result == 0.2062994740159002

    def test_empty_alerts_raises_exception(self):
        alerts = []
        additional_expected_count = 1.0
        with pytest.raises(ValueError):
            normalized_box_accumulation(alerts, additional_expected_count)

    def _create_alert(self, timestamp=None):
        if timestamp is None:
            timestamp = datetime(2023, 1, 1, 12, 0, 0)
        return DatasetEntry(
            full_alert={},
            features={"timestamp": timestamp.isoformat()},
            metadata={"alert_id": "test"},
        )


class TestNormalizedTriangleAccumulation:
    def setup_method(self):
        self.base_time = datetime(2023, 1, 1, 12, 0, 0)
        self.dataset_start = datetime(2023, 1, 1, 0, 0, 0)
        self.dataset_end = datetime(2023, 1, 1, 23, 59, 59)

    def test_single_alert_center_of_window(self):
        alerts = [self._create_alert_with_distance(0.0)]  # At center
        cur_alert_timestamp = self.base_time
        window_start = self.base_time - timedelta(hours=1)
        window_end = self.base_time + timedelta(hours=1)
        additional_expected_count = 1.0

        average_distance = calculate_average_distance_for_triangle(
            cur_alert_timestamp=cur_alert_timestamp,
            window_start=window_start,
            window_end=window_end,
            include_future=True,
            dataset_start=self.dataset_start,
            dataset_end=self.dataset_end,
        )
        result = normalized_triangle_accumulation(alerts, additional_expected_count, average_distance)

        # With full overlap and expected 1, normalized expected = 1 + (0.5 * 1) = 1.5
        # With 1 alert at distance 0, weighted sum = 1, so 1 - 0.5^(1/1.5) ≈ 0.37
        assert result == 0.3700394750525634

    def test_multiple_alerts_varying_distances(self):
        alerts = [
            self._create_alert_with_distance(0.0),  # Center
            self._create_alert_with_distance(0.5),  # Half distance
            self._create_alert_with_distance(1.0),  # Edge
        ]
        cur_alert_timestamp = self.base_time
        window_start = self.base_time - timedelta(hours=1)
        window_end = self.base_time + timedelta(hours=1)
        additional_expected_count = 2.0

        average_distance = calculate_average_distance_for_triangle(
            cur_alert_timestamp=cur_alert_timestamp,
            window_start=window_start,
            window_end=window_end,
            include_future=True,
            dataset_start=self.dataset_start,
            dataset_end=self.dataset_end,
        )
        result = normalized_triangle_accumulation(alerts, additional_expected_count, average_distance)
        # Weighted sum = (1-0) + (1-0.5) + (1-1.0) = 1 + 0.5 + 0 = 1.5
        # Normalized expected = 1 + (0.5 * 2) = 2
        # Score = 1 - 0.5^(1.5/2) ≈ 0.405
        assert result == 0.4053964424986395

    def test_partial_dataset_overlap(self):
        alerts = [self._create_alert_with_distance(0.0)]
        cur_alert_timestamp = self.dataset_start + timedelta(hours=0.5)
        window_start = self.dataset_start - timedelta(hours=0.5)  # Half hour before dataset start
        window_end = self.dataset_start + timedelta(hours=1.5)
        additional_expected_count = 1.0

        average_distance = calculate_average_distance_for_triangle(
            cur_alert_timestamp=cur_alert_timestamp,
            window_start=window_start,
            window_end=window_end,
            include_future=True,
            dataset_start=self.dataset_start,
            dataset_end=self.dataset_end,
        )
        result = normalized_triangle_accumulation(alerts, additional_expected_count, average_distance)

        # One fourth of the time window is outside the dataset (on its left)
        # Average distance = (0.75*0.5 + 0.5*1) / (0.5 + 1) ≈ 0.5833
        # Normalized expected = 1 + (0.5833 * 1) ≈ 1.5833
        # Score = 1 - 0.5^(1/1.5833) ≈ 0.3545
        assert result == 0.3545304010262975

    def test_zero_expected_count(self):
        alerts = [self._create_alert_with_distance(0.0)]
        cur_alert_timestamp = self.base_time
        window_start = self.base_time - timedelta(hours=1)
        window_end = self.base_time + timedelta(hours=1)
        additional_expected_count = 0.0

        average_distance = calculate_average_distance_for_triangle(
            cur_alert_timestamp=cur_alert_timestamp,
            window_start=window_start,
            window_end=window_end,
            include_future=True,
            dataset_start=self.dataset_start,
            dataset_end=self.dataset_end,
        )
        result = normalized_triangle_accumulation(alerts, additional_expected_count, average_distance)

        # With expected 0, normalized expected = 1 + (0.5 * 0) = 1
        # With 1 alert at distance 0, score = 1 - 0.5^(1/1) = 0.5
        assert result == 0.5

    def test_empty_alerts_raises_exception(self):
        alerts = []
        additional_expected_count = 1.0

        with pytest.raises(ValueError):
            normalized_triangle_accumulation(alerts, additional_expected_count, 1)

    def _create_alert_with_distance(self, distance):
        return DatasetEntry(
            full_alert={},
            features={"timestamp": self.base_time.isoformat()},
            metadata={"alert_id": f"test_{distance}", "relative_distance": distance},
        )
