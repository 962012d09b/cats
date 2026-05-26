from datetime import datetime
from modules.src.variety import (
    normalized_box_variety,
    normalized_triangle_variety,
    find_closest_unique_alerts_by_alert_type,
    expected_additional_variety,
    expected_relative_distance,
)
from processing.data_models import DatasetEntry
import pytest


class TestNormalizedBoxVariety:
    def test_single_unique_alert_expected_one(self):
        alerts = [self._create_alert_with_type("type1")]
        expected_additional_variety = 1.0
        result = normalized_box_variety(alerts, expected_additional_variety)
        # With 1 alert and expected 1, normalized expected = 2, so 1 - 0.5^(1/2) = 1 - 0.707... ≈ 0.293
        assert result == 0.2928932188134524

    def test_more_unique_alerts_than_expected(self):
        alerts = [
            self._create_alert_with_type("type1"),
            self._create_alert_with_type("type2"),
            self._create_alert_with_type("type3"),
            self._create_alert_with_type("type4"),
            self._create_alert_with_type("type5"),
        ]
        expected_additional_variety = 2.0
        result = normalized_box_variety(alerts, expected_additional_variety)
        # With 5 unique alerts and expected 2, normalized expected = 3, so 1 - 0.5^(5/3) ≈ 0.685
        assert result == 0.6850197375262816

    def test_fewer_unique_alerts_than_expected(self):
        alerts = [
            self._create_alert_with_type("type1"),
            self._create_alert_with_type("type2"),
        ]
        expected_additional_variety = 5.0
        result = normalized_box_variety(alerts, expected_additional_variety)
        # With 2 unique alerts and expected 5, normalized expected = 6, so 1 - 0.5^(2/6) ≈ 0.206
        assert result == 0.2062994740159002

    def test_empty_alerts_raises_exception(self):
        alerts = []
        expected_additional_variety = 1.0
        with pytest.raises(ValueError):
            normalized_box_variety(alerts, expected_additional_variety)

    def _create_alert_with_type(self, alert_type, timestamp=None):
        if timestamp is None:
            timestamp = datetime(2023, 1, 1, 12, 0, 0)
        return DatasetEntry(
            full_alert={},
            features={"timestamp": timestamp.isoformat(), "rule_id": alert_type},
            metadata={"alert_id": f"test_{alert_type}"},
        )


class TestNormalizedTriangleVariety:
    def setup_method(self):
        self.base_time = datetime(2023, 1, 1, 12, 0, 0)
        self.rel_window_length = 0.1  # 10% of dataset
        self.num_alerts_by_type = {
            "type1": 10,
            "type2": 5,
            "type3": 3,
        }

    def test_single_unique_alert_center_of_window(self):
        alerts = [self._create_alert_with_type_and_distance("type1", 0.0)]  # At center
        expected_additional_variety = 1.0

        result = normalized_triangle_variety(
            alerts,
            expected_additional_variety,
            self.rel_window_length,
            self.num_alerts_by_type,
        )

        # Expected relative distance depends on the alert type distribution
        # Weighted sum = (1-0) = 1 for the single alert at distance 0
        # The exact value depends on expected_relative_distance calculation
        assert result == 0.359094663586218

    def test_multiple_unique_alerts_fewer_than_expected(self):
        alerts = [
            self._create_alert_with_type_and_distance("type1", 0.0),  # Center
            self._create_alert_with_type_and_distance("type2", 0.5),  # Half distance
            self._create_alert_with_type_and_distance("type3", 1.0),  # Edge
        ]
        expected_additional_variety = 2.0

        result = normalized_triangle_variety(
            alerts,
            expected_additional_variety,
            self.rel_window_length,
            self.num_alerts_by_type,
        )

        # Weighted sum = (1-0) + (1-0.5) + (1-1.0) = 1 + 0.5 + 0 = 1.5
        # Less than expected 2, so risk score should be lower than 0.5
        assert result == 0.38818521112401383

    def test_multiple_unique_alerts_more_than_expected(self):
        alerts = [
            self._create_alert_with_type_and_distance("type1", 0.0),  # Center
            self._create_alert_with_type_and_distance("type2", 0.2),
            self._create_alert_with_type_and_distance("type3", 0.4),
            self._create_alert_with_type_and_distance("type4", 0.6),
            self._create_alert_with_type_and_distance("type5", 0.8),
        ]
        expected_additional_variety = 2.0

        result = normalized_triangle_variety(
            alerts,
            expected_additional_variety,
            self.rel_window_length,
            self.num_alerts_by_type,
        )

        # Weighted sum = 3.0
        # More than expected 2, so risk score should be higher than 0.5
        assert result == 0.6256826641126325

    def test_empty_alerts_raises_exception(self):
        alerts = []
        expected_additional_variety = 1.0

        # This should raise an error in the weighted sum calculation
        with pytest.raises(ValueError):
            normalized_triangle_variety(
                alerts,
                expected_additional_variety,
                self.rel_window_length,
                self.num_alerts_by_type,
            )

    def test_zero_relative_window_length(self):
        alerts = [
            self._create_alert_with_type_and_distance("type1", 0.0),
        ]
        expected_additional_variety = 0.0
        rel_window_length = 0.0

        result = normalized_triangle_variety(
            alerts,
            expected_additional_variety,
            rel_window_length,
            self.num_alerts_by_type,
        )

        assert result == 0.5

    def _create_alert_with_type_and_distance(self, alert_type, distance):
        return DatasetEntry(
            full_alert={},
            features={"timestamp": self.base_time.isoformat(), "rule_id": alert_type},
            metadata={"alert_id": f"test_{alert_type}_{distance}", "relative_distance": distance},
        )


class TestFindClosestUniqueAlertsByAlertType:
    def test_single_alert(self):
        alerts = [self._create_alert("type1", 0.5)]
        result = find_closest_unique_alerts_by_alert_type(alerts)
        assert len(result) == 1
        assert result[0].features["rule_id"] == "type1"

    def test_multiple_alerts_different_types(self):
        alerts = [
            self._create_alert("type1", 0.3),
            self._create_alert("type2", 0.1),
            self._create_alert("type3", 0.8),
        ]
        result = find_closest_unique_alerts_by_alert_type(alerts)
        assert len(result) == 3
        # Should be sorted by distance
        assert result[0].features["rule_id"] == "type2"  # distance 0.1
        assert result[1].features["rule_id"] == "type1"  # distance 0.3
        assert result[2].features["rule_id"] == "type3"  # distance 0.8

    def test_multiple_alerts_same_type_keeps_closest(self):
        alerts = [
            self._create_alert("type1", 0.8),
            self._create_alert("type1", 0.2),  # Closer
            self._create_alert("type1", 0.5),
            self._create_alert("type2", 0.3),
        ]
        result = find_closest_unique_alerts_by_alert_type(alerts)
        assert len(result) == 2
        # Should keep the closest type1 (distance 0.2) and type2
        assert result[0].features["rule_id"] == "type1"
        assert result[1].features["rule_id"] == "type2"
        assert result[0].metadata["relative_distance"] == 0.2
        assert result[1].metadata["relative_distance"] == 0.3

    def test_empty_alerts_list_raises_exception(self):
        alerts = []
        with pytest.raises(ValueError):
            find_closest_unique_alerts_by_alert_type(alerts)

    def _create_alert(self, rule_id, distance):
        return DatasetEntry(
            full_alert={},
            features={"timestamp": datetime.now().isoformat(), "rule_id": rule_id},
            metadata={"alert_id": f"test_{rule_id}_{distance}", "relative_distance": distance},
        )


class TestExpectedRelativeDistance:
    def test_single_alert_type(self):
        rel_window_len = 0.5
        num_alerts_by_type = {"type1": 100}
        result = expected_relative_distance(rel_window_len, num_alerts_by_type)
        # prob_at_least_one is effectively 1 here
        # -> conditional expectation value becomes 1 / λ = 1 / 100 = 0.01
        # result = 0.01 / 1 / 0.5 = 0.02
        assert result == 0.02

    def test_multiple_alert_types(self):
        rel_window_len = 0.5
        num_alerts_by_type = {"type1": 100, "type2": 1000, "type3": 10000}
        result = expected_relative_distance(rel_window_len, num_alerts_by_type)
        # Calculation simplifies as above
        # result = (0.01 + 0.001 + 0.0001) / (3*1) / 0.5 = 0.0074
        assert result == 0.0074

    def test_small_window(self):
        rel_window_len = 1 / (365 * 24 * 60)  # 0.00000190258
        num_alerts_by_type = {"type1": 1}
        result = expected_relative_distance(rel_window_len, num_alerts_by_type)
        # With extremely small window size and alert count, the expected distance is close to half the window
        assert result == 0.4999910666522334

    def test_too_small_window(self):
        # Should be capped by MIN_REL_WINDOW_LENGTH
        rel_window_len = 1 / (10 * 365 * 24 * 60)
        num_alerts_by_type = {"type1": 1}
        result = expected_relative_distance(rel_window_len, num_alerts_by_type)
        assert result == 0.5

    def test_large_window(self):
        rel_window_len = 1.0
        num_alerts_by_type = {"type1": 100}
        result = expected_relative_distance(rel_window_len, num_alerts_by_type)
        # result = 0.01 / 1 / 1 = 0.01
        assert result == 0.01


def test_expected_additional_variety_for_zero_window():
    rel_window_len = 0.0
    num_alerts_by_type = {"type1": 10, "type2": 5, "type3": 2}
    current_alert_type = "type1"
    result = expected_additional_variety(rel_window_len, num_alerts_by_type, current_alert_type)

    assert result == 0.0
