from batch_processor.src.utility import (
    setup_args,
    load_config_file,
    fetch_datasets,
)
from batch_processor.src.results_output import (
    create_save_files,
    print_result,
)
from batch_processor.src.db_parser import check_database_existence, generate_config_from_database
from batch_processor.src.order_independent.manager import manage_order_independent_execution

from rich import print as rich_print


def main():
    args = setup_args()
    check_database_existence()

    if args.generate_full_config:
        generate_config_from_database()
        return

    config_data = load_config_file(args.config)
    combine_modules: bool = config_data["defaults"]["combine_modules"]

    for dataset_name in config_data["datasets"]:
        rich_print(f"[bold][underline]Using dataset: {dataset_name}[/underline][/bold]")
        dataset = fetch_datasets(dataset_name, config_data["defaults"]["risk_score"])

        if combine_modules:
            run(args, config_data, dataset)
        else:
            rich_print(
                "[yellow]Module combination disabled. "
                + "Running each module configuration separately without applying weights.\n[/yellow]"
            )

            for index, module_config in enumerate(config_data["modules"]):
                rich_print(
                    f"[bold][underline]Running module {index+1}/{len(config_data['modules'])}: "
                    + f"{module_config['name']} ({module_config['file_name']})[/underline][/bold]"
                )

                single_config_data = {
                    "modules": [{**module_config, "weight": 1.0}],
                    "defaults": {**config_data["defaults"], "optimize_weights": False},
                    "datasets": [dataset_name],
                }
                run(args, single_config_data, dataset)


def run(args, config_data, dataset):
    results = manage_order_independent_execution(args, config_data, dataset)

    best_result = max(results, key=lambda x: x.results["general_metrics"]["alerts_auc_absolute"])

    print_result(best_result)
    create_save_files(config_data, results, best_result)


if __name__ == "__main__":
    main()
