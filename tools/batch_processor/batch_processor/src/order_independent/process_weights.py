from argparse import Namespace
from concurrent.futures import ProcessPoolExecutor
import itertools
from sklearn.metrics import roc_auc_score
import numpy as np
from numpy.typing import NDArray
import time
from processing.post_processing import calculate_results, get_label_bool
from rich.progress import Progress, TimeElapsedColumn, TimeRemainingColumn, BarColumn
import signal
from rich import print as rich_print
import os

from processing.data_models import Dataset, DatasetEntry

from batch_processor.src.results_output import print_stats
from batch_processor.src.models import CompletedPipeline, SingleModuleResult


CHUNKSIZE = 20


def process_all_weights(
    args: Namespace,
    dataset: Dataset,
    weights_list: NDArray[np.float64],
    preprocessed_modules: list[list[SingleModuleResult]],
    averaging_method: str,
) -> list[CompletedPipeline]:
    interrupted = False

    def handle_sigint(signum, frame):
        nonlocal interrupted
        if interrupted:
            os._exit(1)
        else:
            rich_print(f"[yellow]Worker {os.getpid()} interrupted, finishing up... (this may take a bit)[/yellow]")
            interrupted = True

    signal.signal(signal.SIGINT, handle_sigint)

    result_counts = [len(group) for group in preprocessed_modules]
    all_combinations = list(itertools.product(*[range(count) for count in result_counts]))
    ground_truth = np.array([get_label_bool(entry.metadata["misuse"]) for entry in dataset.data])

    print(f"\nTotal module combinations to optimize: {len(all_combinations)}")

    num_cores = args.cores if args.cores > 0 else (os.cpu_count() or 1)

    print(f"Using {num_cores} cores with chunksize: {CHUNKSIZE}")
    rich_print("[italic]Allow up to a minute of initialization for larger workloads.[/italic]")

    task_args = [(combination) for combination in all_combinations]

    results = []
    runtimes = []

    progress = Progress(
        "[progress.description]{task.description}",
        BarColumn(),
        "[progress.percentage]{task.percentage:>3.0f}%",
        "({task.completed:,}/{task.total:,})",
        TimeElapsedColumn(),
        TimeRemainingColumn(),
    )

    task_id = progress.add_task("[green]Processing...", total=len(all_combinations))

    with progress:
        with ProcessPoolExecutor(
            max_workers=num_cores,
            initializer=pool_initializer,
            initargs=(dataset, weights_list, preprocessed_modules, ground_truth, averaging_method),
        ) as executor:
            for result in executor.map(timed_weight_optimization, task_args, chunksize=CHUNKSIZE):
                if interrupted:
                    break

                results.append(result)
                runtimes.append(result.duration)

                progress.update(task_id, advance=1)

    if interrupted:
        rich_print("[yellow]Stopped process early. Finishing up...[/yellow]")

    if runtimes:
        print_stats(avg_runtime=sum(runtimes) / len(runtimes))

    return results


def pool_initializer(
    DATASET: Dataset,
    WEIGHTS_LIST: NDArray[np.float64],
    PREPROCESSED_MODULES: list[list[SingleModuleResult]],
    GROUND_TRUTH: NDArray[np.bool_],
    AVERAGING_METHOD: str,
):
    global dataset
    global weights_list
    global preprocessed_modules
    global ground_truth
    global averaging_method

    dataset = DATASET
    weights_list = WEIGHTS_LIST
    preprocessed_modules = PREPROCESSED_MODULES
    ground_truth = GROUND_TRUTH
    averaging_method = AVERAGING_METHOD


def timed_weight_optimization(
    args: tuple[int, ...],
) -> CompletedPipeline:
    start = time.perf_counter()

    task_indices = args

    relevant_modules: list[SingleModuleResult] = []
    for module_idx, result_idx in enumerate(task_indices):
        relevant_modules.append(preprocessed_modules[module_idx][result_idx])

    result, weights, averaging_method = find_best_weight_set(relevant_modules)
    duration = time.perf_counter() - start
    logs = []
    for m in relevant_modules:
        if m.logs:
            logs.append(m.logs)

    return CompletedPipeline(
        config=[m.module for m in relevant_modules],
        results=result,
        logs=logs,
        duration=duration,
        used_weights=weights,
        used_averaging_method=averaging_method,
    )


def find_best_weight_set(
    relevant_modules: list[SingleModuleResult],
) -> tuple[dict, list[float], str]:
    best_auc_score = -1
    best_weights = None
    best_averaging_method = ""

    used_averaging_method = ""

    scores_matrix = np.stack([module.scores for module in relevant_modules], axis=1)

    for weights_array in weights_list:

        if averaging_method == "geometric":
            normalized_weighted_scores = geometric_mean(scores_matrix, weights_array)
            auc_score = roc_auc_score(ground_truth, normalized_weighted_scores)

        elif averaging_method == "arithmetic":
            normalized_weighted_scores = arithmetic_mean(scores_matrix, weights_array)
            auc_score = roc_auc_score(ground_truth, normalized_weighted_scores)

        else:
            geo_mean = geometric_mean(scores_matrix, weights_array)
            geo_auc_score = roc_auc_score(ground_truth, geo_mean)

            arith_mean = arithmetic_mean(scores_matrix, weights_array)
            arith_auc_score = roc_auc_score(ground_truth, arith_mean)

            if geo_auc_score >= arith_auc_score:
                auc_score = geo_auc_score
                used_averaging_method = "geometric"
            else:
                auc_score = arith_auc_score
                used_averaging_method = "arithmetic"

        if auc_score > best_auc_score:
            best_auc_score = auc_score
            best_weights = weights_array
            best_averaging_method = used_averaging_method if used_averaging_method else averaging_method

    if best_weights is None:
        raise RuntimeError("No valid weight combination found during optimization.")

    if best_averaging_method == "geometric":
        final_scores = geometric_mean(scores_matrix, best_weights)
    elif best_averaging_method == "arithmetic":
        final_scores = arithmetic_mean(scores_matrix, best_weights)
    else:
        raise ValueError(f"Unknown averaging method: {best_averaging_method}")

    final_dataset = Dataset(
        file_names=[],
        data=[
            DatasetEntry(
                full_alert={},
                features=alert.features,
                metadata={**alert.metadata, "risk_score": score},
            )
            for alert, score in zip(dataset.data, final_scores)
        ],
    )

    final_results = calculate_results(final_dataset)
    return final_results, best_weights.tolist(), best_averaging_method


def geometric_mean(scores_matrix: NDArray[np.float64], weights: list[float]) -> NDArray[np.float64]:
    weighted_scores = np.power(scores_matrix, weights)
    return np.prod(weighted_scores, axis=1)


def arithmetic_mean(scores_matrix: NDArray[np.float64], weights: list[float]) -> NDArray[np.float64]:
    weighted_scores = scores_matrix * weights
    return np.sum(weighted_scores, axis=1)
