import jsonlines
import argparse
from yaml import safe_load
from pathlib import Path
from datetime import datetime

from src.parser import parse_alert
import src.labeler as lbl
from src.validator import validate_alert
from src.reverser import revert_normalization

FILE_ROOT_DIR = Path(__file__).parent
GENERAL_CONFIG_PATH = FILE_ROOT_DIR / "config/_general.yml"
AIT_GROUND_TRUTH_PATH = FILE_ROOT_DIR / "resources/russellmitchell_ground_truth.txt"
DEDALE_GROUND_TRUTH_PATH = FILE_ROOT_DIR / "resources/dedale_ground_truth/"
MANUAL_LABELS_PATH = FILE_ROOT_DIR / "resources/manual_labels.yml"


def main():
    parser = argparse.ArgumentParser(description="Normalize a dataset for usage with CATS.")
    parser.add_argument("--dataset", type=str, help="The JSONL dataset to normalize.", required=True)
    parser.add_argument("--config", type=str, help="The path to the config file.", required=False)
    parser.add_argument(
        "--alert-source", type=str, help='Source and type of the dataset, e.g., "socbed_sigma".', required=False
    )
    parser.add_argument(
        "--label-method",
        choices=["default", "ait", "dedale"],
        help="If given, try to label alerts using provided method.",
    )
    parser.add_argument(
        "--reverse",
        action="store_true",
        help="Extracts raw alerts from supplied previously normalized dataset, then exits.",
    )

    args = parser.parse_args()

    if not args.reverse:
        if not args.config:
            parser.error("--config is required when not using --reverse")
        if not args.alert_source:
            parser.error("--alert-source is required when not using --reverse")

    dataset_path = Path(args.dataset)
    alert_source = args.alert_source
    label_method = args.label_method

    if args.reverse:
        revert_normalization(dataset_path)
        return

    config_path = Path(args.config)

    with open(GENERAL_CONFIG_PATH) as file:
        general_config = safe_load(file)
    with open(config_path) as file:
        specific_config = safe_load(file)

    features = list(general_config["features"].keys())
    print(f"Starting normalization of {dataset_path.name}...")
    normalized_alerts = []

    with jsonlines.open(dataset_path) as alerts:
        for index, alert in enumerate(alerts):
            print(f"\r{index}", end="")
            normalized_alert = parse_alert(
                alert,
                specific_conf=specific_config,
                general_conf=general_config,
                source=alert_source,
                index=index + 1,
                features=features,
            )
            validated_alert = validate_alert(
                normalized_alert,
                general_conf=general_config,
                features=features,
            )
            normalized_alerts.append(validated_alert)

    print("\nFinished normalizing alerts.\n")

    if label_method:
        normalized_alert = lbl.label_alerts(label_method, normalized_alerts)

    normalized_alerts.sort(key=lambda x: datetime.fromisoformat(x["features"]["timestamp"]))

    new_filename = "normalized_" + dataset_path.name
    print(f"\nCreating {new_filename}...")
    with jsonlines.open(new_filename, mode="w") as writer:
        writer.write_all(normalized_alerts)
    print("All done!")


if __name__ == "__main__":
    main()
