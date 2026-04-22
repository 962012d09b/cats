from argparse import Namespace
from concurrent.futures import ProcessPoolExecutor, as_completed
import itertools
from rich.progress import Progress, TimeElapsedColumn, TimeRemainingColumn, BarColumn
import signal
import os

from processing.data_models import AveragingMethod, Dataset

from batch_processor.src.models import Module, SingleModuleResult
from batch_processor.src.results_output import print_warnings


def process_individual_modules(
    args: Namespace,
    config_data: dict,
    dataset: Dataset,
) -> list[list[SingleModuleResult]]:

    def handle_sigint(signum, frame):
        # no point in saving any results at this stage, just exit
        os._exit(1)

    signal.signal(signal.SIGINT, handle_sigint)

    all_modules = generate_all_module_combinations(config_data)
    all_modules_len = sum(len(module) for module in all_modules)

    print(f"Generated {all_modules_len} module configurations")

    preprocessed_modules: list[list[SingleModuleResult]] = [[] for _ in range(len(all_modules))]

    warn_counter = 0
    crashes: list[Exception] = []

    progress = Progress(
        "[progress.description]{task.description}",
        BarColumn(),
        "[progress.percentage]{task.percentage:>3.0f}%",
        "({task.completed:,}/{task.total:,})",
        TimeElapsedColumn(),
        TimeRemainingColumn(),
    )

    task_id = progress.add_task("[green]Pre-processing...", total=all_modules_len)

    with progress:
        with ProcessPoolExecutor(max_workers=args.cores if args.cores > 0 else os.cpu_count()) as executor:
            # flatten modules while preserving group indices
            futures = {}
            for group_index, module_group in enumerate(all_modules):
                for module in module_group:
                    future = executor.submit(timed_run_module, (dataset, module))
                    futures[future] = (module, group_index)

            for future in as_completed(futures):
                try:
                    completed_module = future.result()
                    module, group_index = futures[future]
                    preprocessed_modules[group_index].append(completed_module)
                    if completed_module.logs:
                        warn_counter += 1
                except Exception as e:
                    crashes.append(e)
                finally:
                    progress.update(task_id, advance=1)

    print_warnings(warn_counter, crashes)

    return preprocessed_modules


def generate_all_module_combinations(config_data: dict) -> list[list[Module]]:
    modules = config_data["modules"]
    combinations_per_module: list[list[Module]] = []

    for module in modules:
        current_module_combinations: list[Module] = []

        args_combinations = generate_module_configs(module["parameters"])
        for args in args_combinations:
            current_module_combinations.append(
                Module(
                    name=module["name"],
                    file_name=module["file_name"],
                    id=module["id"],
                    args=list(args),
                    weight=module["weight"],
                )
            )

        combinations_per_module.append(current_module_combinations)

    return combinations_per_module


def generate_module_configs(param_options):
    if not param_options:
        return [()]
    return list(itertools.product(*param_options))


def timed_run_module(
    args: tuple[Dataset, Module],
) -> SingleModuleResult:
    dataset, module = args

    # Normalization method does not matter here
    # Both geometric and arithmetic produce the same result for a single module with weight 1
    # x^1 = x * 1
    dataset, logs = module.process(dataset, weight=1.0, averaging_method=AveragingMethod.GEOMETRIC_MEAN)
    result = SingleModuleResult(module, dataset, logs)

    return result
