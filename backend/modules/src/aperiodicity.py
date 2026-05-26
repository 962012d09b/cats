import math
from datetime import datetime
from typing import Sequence

import numpy as np


def aperiodicity_score(
    events: Sequence[datetime],
    bin_width_in_seconds: float,
    small_n_threshold: float,
) -> float:
    """Return the aperiodicity score for a sorted list of datetime events.

    Parameters
    ----------
    events:
        Sorted sequence of datetime objects.
    bin_width_seconds:
        Width of each time bin in seconds.  Defaults to 1 s (the highest
        frequency of interest is 1 Hz).
    small_n_threshold:
        Controls the small-n blending.  With fewer than ~this many events
        the score is pulled toward 1.0 (aperiodic), because periodicity
        cannot be established from very few observations.

    Returns
    -------
    float in [0, 1].  0 = periodic, 1 = aperiodic.
    """
    event_count = len(events)

    # --- Edge cases --------------------------------------------------------
    if event_count <= 2:
        return 1.0

    # --- 1. Bin events into a count time series ----------------------------
    t0 = events[0]
    # Offsets in seconds from the first event
    offsets = np.array([(e - t0).total_seconds() for e in events])

    span = offsets[-1] - offsets[0]
    if span <= 0:
        # All events at the same instant – no periodicity information.
        return 1.0
    if span <= bin_width_in_seconds:
        # All events within a single bin – no periodicity information.
        return 1.0

    n_bins = int(math.ceil(span / bin_width_in_seconds))
    bin_indices = np.minimum((offsets / bin_width_in_seconds).astype(np.int64), n_bins - 1)
    counts = np.bincount(bin_indices, minlength=n_bins).astype(np.float64)

    # Remove the DC component (mean event rate)
    counts -= counts.mean()

    # --- 2. FFT → power spectrum -------------------------------------------
    spectrum = np.fft.rfft(counts)
    power = np.abs(spectrum) ** 2

    # Discard the DC bin (index 0); it's ~0 after mean-centering but
    # conceptually irrelevant.
    power = power[1:]

    if len(power) == 0:
        return 1.0

    # --- 3. Spectral flatness ----------------------------------------------
    # Floor tiny / zero values to avoid log(0).
    floor = np.finfo(np.float64).tiny
    power_floored = np.maximum(power, floor)

    log_mean = np.mean(np.log(power_floored))  # log of geometric mean
    arith_mean = np.mean(power)

    if arith_mean <= 0:
        return 1.0

    spectral_flatness = np.exp(log_mean) / arith_mean

    # Normalize: the theoretical SF of white noise is e^(-γ) ≈ 0.5615
    # (power spectrum of white noise is exponentially distributed, and
    # geometric_mean / arithmetic_mean of Exp(λ) → e^(-γ) for large N).
    # Without normalization, random events score ~0.56 instead of ~1.0.
    EULER_MASCHERONI = 0.5772156649015329
    sf_white_noise = math.exp(-EULER_MASCHERONI)  # ≈ 0.5615
    spectral_flatness = spectral_flatness / sf_white_noise

    # Clip to [0, 1] for numerical safety
    spectral_flatness = float(np.clip(spectral_flatness, 0.0, 1.0))

    # --- 4. Small-n blending -----------------------------------------------
    # Blend toward 1.0 for small event counts: not enough data to
    # confidently claim periodicity.
    confidence = 1.0 - math.exp(-event_count / small_n_threshold)
    score = spectral_flatness * confidence + 1.0 * (1.0 - confidence)

    return score
