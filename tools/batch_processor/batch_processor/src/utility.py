import argparse
import json
import yaml
from dateutil import parser

from utility.paths import DATASET_DIR
from processing.data_models import Dataset, DatasetEntry


def setup_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="CATS Batch Processor. Either --config or --generate-full-config must be specified."
    )
    parser.add_argument("--cores", type=int, default=0, help="Number of CPU cores to use, 0 for all (default)")
    parser.add_argument("--config", type=str, help="Path to config YAML file")
    parser.add_argument(
        "--generate-full-config",
        action="store_true",
        help="Generate full example configuration from current CATS database, does not run any pipelines",
    )
    args = parser.parse_args()

    if not args.generate_full_config and not args.config:
        parser.error("The --config argument is required unless --generate-full-config is specified.")

    return args


def load_config_file(file_path: str) -> dict:
    with open(file_path, "r") as file:
        config_data = yaml.safe_load(file)

    if config_data["defaults"]["averaging_method"] not in ["arithmetic", "geometric", "both"]:
        raise ValueError(
            f"Invalid averaging method {config_data['defaults']['averaging_method']}. Must be 'arithmetic', 'geometric' or 'both'."
        )

    for module in config_data["modules"]:
        weight = module["weight"]
        if weight < 0:
            raise ValueError(f"Invalid weight {weight} for module {module['name']}. Must be larger than 0.")

    return config_data


def fetch_datasets(dataset_name: str, default_risk_score: float) -> Dataset:
    loaded_dataset: list[DatasetEntry] = []
    all_paths = []

    full_path = DATASET_DIR / dataset_name
    all_paths.append(full_path)

    with open(full_path, "r", encoding="utf-8") as file:
        for line in file:
            content = json.loads(line)
            newEntry = DatasetEntry.from_json(content)

            newEntry.metadata["risk_score"] = default_risk_score
            newEntry.metadata["raw_risk_scores"] = []
            loaded_dataset.append(newEntry)

    loaded_dataset.sort(key=lambda x: parser.isoparse(x.features["timestamp"]))

    if not loaded_dataset:
        raise ValueError("No dataset entries found in the selected datasets.")

    return Dataset(data=loaded_dataset, file_names=all_paths)
