from datetime import datetime, timedelta
from modules.src.rarity import normalized_box_rarity, normalized_triangle_rarity
from modules.src.correlation_utility import calculate_average_distance_for_triangle
from processing.data_models import DatasetEntry


class TestNormalizedBoxRarity:
    def test_expected_matches_actual(self):
        alerts = [self._create_alert() for _ in range(5)]
        expected_additional_alerts = 5 - 1
        result = normalized_box_rarity(alerts, expected_additional_alerts)
        # With 5 alerts and expected 4 additional, normalizer = 1 + 4 = 5
        # score = (5 - 1) / (5 + 5 - 2) = 4 / 8 = 0.5
        assert result == 0.5

    def test_more_alerts_than_expected(self):
        alerts = [self._create_alert() for _ in range(5)]
        expected_additional_alerts = 2.0
        result = normalized_box_rarity(alerts, expected_additional_alerts)
        # With 5 alerts and expected 2 additional, normalizer = 1 + 2 = 3
        # score = (3 - 1) / (5 + 3 - 2) = 2 / 6 ≈ 0.333
        assert result == 0.3333333333333333

    def test_fewer_alerts_than_expected(self):
        alerts = [self._create_alert() for _ in range(2)]
        expected_additional_alerts = 5.0
        result = normalized_box_rarity(alerts, expected_additional_alerts)
        # With 2 alerts and expected 5 additional, normalizer = 1 + 5 = 6
        # score = (6 - 1) / (2 + 6 - 2) = 5 / 6 ≈ 0.833
        assert result == 0.8333333333333334

    def test_zero_expected_alerts(self):
        alerts = [self._create_alert() for _ in range(3)]
        expected_additional_alerts = 0.0
        result = normalized_box_rarity(alerts, expected_additional_alerts)
        # With 3 alerts and expected 0 additional, normalizer = 1
        # score = 1 (special case when normalizer == 1)
        assert result == 1.0

    def test_single_alert_few_expected(self):
        alerts = [self._create_alert()]
        expected_additional_alerts = 5
        result = normalized_box_rarity(alerts, expected_additional_alerts)
        # With 1 alert and expected 5 additional, normalizer = 1 + 5 = 6
        # score = (6 - 1) / (1 + 6 - 2) = 5 / 5 = 1.0
        assert result == 1.0

    def test_single_alert_many_expected(self):
        alerts = [self._create_alert()]
        expected_additional_alerts = 9999
        result = normalized_box_rarity(alerts, expected_additional_alerts)
        # With 1 alert and expected 9999 additional, normalizer = 1 + 9999 = 10000
        # score = (10000 - 1) / (1 + 10000 - 2) = 9999 / 9999 = 1.0
        assert result == 1.0

    def test_extremely_rare(self):
        alerts = [self._create_alert() for _ in range(2)]
        expected_additional_alerts = 9998
        result = normalized_box_rarity(alerts, expected_additional_alerts)
        # With 2 alerts and expected 9998 additional, normalizer = 1 + 9998 = 9999
        # score = (9999 - 1) / (2 + 9999 - 2) = 9998 / 9999 ≈ 0.999
        assert result == 0.9998999899989999

    def test_extremely_common(self):
        alerts = [self._create_alert() for _ in range(1000)]
        expected_additional_alerts = 1.0
        result = normalized_box_rarity(alerts, expected_additional_alerts)
        # With 1000 alerts and expected 1 additional, normalizer = 1 + 1 = 2
        # score = (2 - 1) / (1000 + 2 - 2) = 1 / 1000 = 0.001
        assert result == 0.001

    def _create_alert(self, timestamp=None):
        if timestamp is None:
            timestamp = datetime(2023, 1, 1, 12, 0, 0)
        return DatasetEntry(
            full_alert={},
            features={"timestamp": timestamp.isoformat()},
            metadata={"alert_id": "test"},
        )


class TestNormalizedTriangleRarity:
    def setup_method(self):
        self.base_time = datetime(2023, 1, 1, 12, 0, 0)
        self.dataset_start = datetime(2023, 1, 1, 0, 0, 0)
        self.dataset_end = datetime(2023, 1, 1, 23, 59, 59)

    def test_single_alert_center_of_window(self):
        alerts = [self._create_alert_with_distance(0.0)]  # At center
        cur_alert_timestamp = self.base_time
        window_start = self.base_time - timedelta(hours=1)
        window_end = self.base_time + timedelta(hours=1)
        expected_additional_alerts = 1.0

        average_distance = calculate_average_distance_for_triangle(
            cur_alert_timestamp=cur_alert_timestamp,
            window_start=window_start,
            window_end=window_end,
            include_future=True,
            dataset_start=self.dataset_start,
            dataset_end=self.dataset_end,
        )
        result = normalized_triangle_rarity(alerts, expected_additional_alerts, average_distance)

        # With full overlap and expected 1, normalizer = 1 + (0.5 * 1) = 1.5
        # Weighted sum = 1 - 0 = 1
        # score = (1.5 - 1) / (1 + 1.5 - 2) = 0.5 / 0.5 = 1.0
        assert result == 1.0

    def test_multiple_alerts_varying_distances(self):
        alerts = [
            self._create_alert_with_distance(0.0),
            self._create_alert_with_distance(0.5),
            self._create_alert_with_distance(1.0),
        ]
        cur_alert_timestamp = self.base_time
        window_start = self.base_time - timedelta(hours=1)
        window_end = self.base_time + timedelta(hours=1)
        expected_additional_alerts = 2.0

        average_distance = calculate_average_distance_for_triangle(
            cur_alert_timestamp=cur_alert_timestamp,
            window_start=window_start,
            window_end=window_end,
            include_future=True,
            dataset_start=self.dataset_start,
            dataset_end=self.dataset_end,
        )
        result = normalized_triangle_rarity(alerts, expected_additional_alerts, average_distance)

        # Weighted sum = (1-0) + (1-0.5) + (1-1.0) = 1 + 0.5 + 0 = 1.5
        # Normalizer = 1 + (0.5 * 2) = 2
        # score = (2 - 1) / (1.5 + 2 - 2) = 1 / 1.5 ≈ 0.667
        assert result == 0.6666666666666666

    def test_partial_dataset_overlap(self):
        alerts = alerts = [
            self._create_alert_with_distance(0.0),
            self._create_alert_with_distance(0.5),
            self._create_alert_with_distance(1.0),
        ]
        cur_alert_timestamp = self.dataset_start + timedelta(hours=0.5)
        window_start = self.dataset_start - timedelta(hours=0.5)  # Half hour before dataset start
        window_end = self.dataset_start + timedelta(hours=1.5)
        expected_additional_alerts = 1.0

        average_distance = calculate_average_distance_for_triangle(
            cur_alert_timestamp=cur_alert_timestamp,
            window_start=window_start,
            window_end=window_end,
            include_future=True,
            dataset_start=self.dataset_start,
            dataset_end=self.dataset_end,
        )
        result = normalized_triangle_rarity(alerts, expected_additional_alerts, average_distance)

        # One fourth of the time window is outside the dataset (on its left)
        # Average distance = (0.75*0.5 + 0.5*1) / (0.5 + 1) ≈ 0.5833
        # Normalizer = 1 + (0.5833 * 1) ≈ 1.5833
        # Weighted sum = 1 + 0.5 = 1.5
        # score = (1.5833 - 1) / (1.5 + 1.5833 - 2) ≈ 0.538
        assert result == 0.5384615384615385

    def test_zero_expected_count(self):
        alerts = [self._create_alert_with_distance(0.0)]
        cur_alert_timestamp = self.base_time
        window_start = self.base_time - timedelta(hours=1)
        window_end = self.base_time + timedelta(hours=1)
        expected_additional_alerts = 0.0

        average_distance = calculate_average_distance_for_triangle(
            cur_alert_timestamp=cur_alert_timestamp,
            window_start=window_start,
            window_end=window_end,
            include_future=True,
            dataset_start=self.dataset_start,
            dataset_end=self.dataset_end,
        )
        result = normalized_triangle_rarity(alerts, expected_additional_alerts, average_distance)

        # With expected 0, normalizer = 1 + (0.5 * 0) = 1
        # When normalizer == 1, score = 1 (special case)
        assert result == 1.0

    def test_alerts_at_edges(self):
        alerts = [
            self._create_alert_with_distance(1.0),  # At edge
            self._create_alert_with_distance(0),  # At edge
        ]
        cur_alert_timestamp = self.base_time
        window_start = self.base_time - timedelta(hours=1)
        window_end = self.base_time + timedelta(hours=1)
        expected_additional_alerts = 1.0

        average_distance = calculate_average_distance_for_triangle(
            cur_alert_timestamp=cur_alert_timestamp,
            window_start=window_start,
            window_end=window_end,
            include_future=True,
            dataset_start=self.dataset_start,
            dataset_end=self.dataset_end,
        )
        result = normalized_triangle_rarity(alerts, expected_additional_alerts, average_distance)

        # Weighted sum = (1-1.0) + (1-0) = 0 + 1 = 1
        # Normalizer = 1 + (0.5 * 1) = 1.5
        # score = (1.5 - 1) / (1 + 1.5 - 2) = 0.5 / 0.5 = 1.0
        # This represents alerts that are far from current alert (maximally distant)
        assert result == 1.0

    def _create_alert_with_distance(self, distance):
        return DatasetEntry(
            full_alert={},
            features={"timestamp": self.base_time.isoformat()},
            metadata={"alert_id": f"test_{distance}", "relative_distance": distance},
        )
