from datetime import datetime, timedelta
import numpy as np

from modules.src.aperiodicity import aperiodicity_score
import pytest


class TestAperiodicityScore:
    test_bin_length = 1  # seconds
    test_small_n_threshold = 15.0

    def test_perfectly_periodic(self):
        events = [datetime(2025, 1, 1) + timedelta(seconds=60 * i) for i in range(61)]
        assert aperiodicity_score(
            events, bin_width_in_seconds=self.test_bin_length, small_n_threshold=self.test_small_n_threshold
        ) == pytest.approx(0.050063855167414135, abs=1e-14)

    def test_random_events(self):
        rng = np.random.default_rng(42)
        offsets = np.sort(rng.uniform(0, 3600, size=200))
        events = [datetime(2025, 1, 1) + timedelta(seconds=float(t)) for t in offsets]
        score = aperiodicity_score(
            events, bin_width_in_seconds=self.test_bin_length, small_n_threshold=self.test_small_n_threshold
        )
        assert score == pytest.approx(0.9954978957368913, abs=1e-14)

    def test_bursty_periodic(self):
        bursty: list[datetime] = []
        for cycle in range(6):
            base = cycle * 600
            for j in range(5):
                bursty.append(datetime(2025, 1, 1) + timedelta(seconds=base + j * 0.5))
        bursty.sort()
        score = aperiodicity_score(
            bursty, bin_width_in_seconds=self.test_bin_length, small_n_threshold=self.test_small_n_threshold
        )
        assert score == pytest.approx(0.3713797769104747, abs=1e-14)

    def test_few_events(self):
        few = [datetime(2025, 1, 1), datetime(2025, 1, 1, 0, 5)]
        assert (
            aperiodicity_score(
                few, bin_width_in_seconds=self.test_bin_length, small_n_threshold=self.test_small_n_threshold
            )
            == 1.0
        )

        few3 = [datetime(2025, 1, 1) + timedelta(seconds=60 * i) for i in range(4)]
        score = aperiodicity_score(
            few3, bin_width_in_seconds=self.test_bin_length, small_n_threshold=self.test_small_n_threshold
        )
        assert score == pytest.approx(0.9847073834557029, abs=1e-14)


class TestParameterEffects:
    small_n_threshold = 15.0

    @pytest.mark.parametrize(
        "bin_length, expected",
        [
            (1.0, 0.3532868197452769),
            (10.0, 0.3559165833328759),
            (100.0, 0.2635971381157267),
            (1200.0, 1),
        ],
    )
    def test_different_bin_lengths(self, bin_length, expected):
        events = [datetime(2025, 1, 1) + timedelta(seconds=60 * i) for i in range(20)]
        score = aperiodicity_score(events, bin_width_in_seconds=bin_length, small_n_threshold=15.0)
        assert score == pytest.approx(expected, abs=1e-14)

    @pytest.mark.parametrize(
        "small_n_threshold, expected",
        [
            (1.0, 0.12179431613428499),
            (5.0, 0.13787921253303997),
            (10.0, 0.24064652953511056),
            (15.0, 0.3532868197452769),
            (20.0, 0.44486813120417656),
            (30.0, 0.5726801473818959),
        ],
    )
    def test_different_small_n_thresholds(self, small_n_threshold, expected):
        events = [datetime(2025, 1, 1) + timedelta(seconds=60 * i) for i in range(20)]
        score = aperiodicity_score(events, bin_width_in_seconds=1.0, small_n_threshold=small_n_threshold)
        assert score == pytest.approx(expected, abs=1e-14)
