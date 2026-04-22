from datetime import datetime
import json
from rich import print as rich_print
import yaml

from batch_processor.src.models import CompletedPipeline
from batch_processor.src.db_parser import generate_cats_import


def print_stats(avg_runtime: float) -> None:
    print(f"\nAll done!")
    print(f"Average runtime per execution: {avg_runtime:.3f} seconds\n")


def print_warnings(warn_counter: int, crashes: list[Exception]) -> None:
    if warn_counter > 0:
        rich_print(f"[yellow]Warning: {warn_counter} pipelines completed with warnings[/yellow]")
    if crashes:
        rich_print(
            f"[red]Error: {len(crashes)} pipelines crashed. Modules should always handle errors gracefully.\n[/red]"
            f"[red]Some errors:[/red]\n" + "\n".join([f" - {str(crash)}" for crash in crashes[:5]])
        )


def print_result(config: CompletedPipeline):
    result = config.results
    modules = config.config

    print(f"Best obtained AUC score: {result['general_metrics']['alerts_auc_absolute']:.3f}")
    print("For module configuration:")
    for index, module in enumerate(modules):
        print(f" ({index+1}) {module.name} ({module.file_name})")
        if module.args:
            print(f"     Args: {', '.join(str(arg) for arg in module.args)}")
        else:
            print("     Args: None")

    rounded_weights = [round(w, 3) for w in config.used_weights]
    print("Using weights:", rounded_weights)
    print(f"Using averaging method: {config.used_averaging_method.capitalize()} mean")


def create_save_files(config_data: dict, results: list[CompletedPipeline], best_result: CompletedPipeline):
    prefix = config_data["datasets"][0].removesuffix(".jsonl")
    if not config_data["defaults"]["combine_modules"]:
        prefix += "_" + config_data["modules"][0]["name"].replace(" ", "_").lower()

    save_timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    if config_data["defaults"]["save_results"]:
        save_results(results, save_timestamp, prefix)
    if config_data["defaults"]["generate_cats_import"]:
        generate_cats_import(best_result, save_timestamp, config_data["defaults"]["risk_score"], prefix)
    if config_data["defaults"]["save_used_config"]:
        save_used_config(config_data, save_timestamp, prefix)


def save_results(final_results: list[CompletedPipeline], timestamp: str, prefix: str) -> None:
    print("\nWriting results to file...")

    output_file = f"{prefix}_cats_results_{timestamp}.jsonl"
    results_list_dict = [result.to_json() for result in final_results]

    with open(output_file, "w", encoding="utf-8") as file:
        for result in results_list_dict:
            file.write(json.dumps(result) + "\n")

    print(f"Results saved to {output_file}\n")


def save_used_config(config_data: dict, timestamp: str, prefix: str) -> None:
    print("Writing used config to file...")
    file_name = f"{prefix}_cats_config_{timestamp}.yaml"

    with open(file_name, "w", encoding="utf-8") as file:
        yaml.dump(config_data, file, sort_keys=False, default_flow_style=False)

    print(f"Config saved to {file_name}\n")
