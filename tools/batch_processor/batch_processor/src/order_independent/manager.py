from argparse import Namespace
from flask import config
from rich import print as rich_print
import itertools
import numpy as np
from numpy.typing import NDArray

from processing.data_models import Dataset

from batch_processor.src.models import CompletedPipeline
from batch_processor.src.order_independent.process_modules import process_individual_modules
from batch_processor.src.order_independent.process_weights import process_all_weights


def manage_order_independent_execution(
    args: Namespace, config_data: dict, dataset: Dataset
) -> list[CompletedPipeline]:
    full_weights_list = generate_weight_combinations(
        len(config_data["modules"]), config_data["defaults"]["weight_resolution"]
    )
    default_weights_list = generate_default_weights(config_data)
    if config_data["defaults"]["combine_modules"]:
        print(f"Generated {len(full_weights_list)} weight combination{'s' if len(full_weights_list) != 1 else ''}")

    preprocessed_modules = process_individual_modules(args, config_data, dataset)
    averaging_method = config_data["defaults"]["averaging_method"]

    if config_data["defaults"]["optimize_weights"]:
        # optimize over the full grid of weights
        return process_all_weights(args, dataset, full_weights_list, preprocessed_modules, averaging_method)
    else:
        # set of weights to optimize on only contains the user-specified weights
        if config_data["defaults"]["combine_modules"]:
            rich_print("\n[yellow]Skipping weight optimization as per configuration.[/yellow]")
        return process_all_weights(args, dataset, default_weights_list, preprocessed_modules, averaging_method)


def generate_weight_combinations(n_modules, resolution) -> NDArray[np.float64]:  # shape: (n_combinations, n_modules)
    steps = np.arange(0, 1 + resolution, resolution)

    combinations_array = np.array(list(itertools.product(steps, repeat=n_modules)))

    sums = np.sum(combinations_array, axis=1)
    # Add this to exclude 0-weights
    # & (np.all(combinations_array > 0, axis=1))
    valid_mask = np.abs(sums - 1.0) < 1e-10

    return combinations_array[valid_mask]


def generate_default_weights(config_data: dict) -> NDArray[np.float64]:
    user_weights = [mod["weight"] for mod in config_data["modules"]]
    normalized_weights = normalize_weights(user_weights)
    return np.array([normalized_weights])


def normalize_weights(weights: list[float]) -> list[float]:
    total_weight = sum(weights)
    if total_weight == 0:
        raise ValueError("Total weight cannot be zero.")
    return [w / total_weight for w in weights]
