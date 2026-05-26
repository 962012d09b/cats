from datetime import datetime, timedelta
import zipfile
from os import listdir
from processing.post_processing import get_label
from utility.paths import DATASET_DIR
import json
from dateutil import parser
from isodate import duration_isoformat
from pathlib import Path


def initialize_datasets():
    dir_contents = listdir(DATASET_DIR)
    archives = [archive for archive in dir_contents if archive.endswith(".zip")]

    for archive in archives:
        archive_path = DATASET_DIR / archive
        with zipfile.ZipFile(archive_path, "r") as zip_ref:
            expected_filename = archive.replace(".zip", ".jsonl")
            if expected_filename not in dir_contents:
                print(f"Extracting dataset {expected_filename}...")
                zip_ref.extractall(DATASET_DIR)


def get_dataset_statistics(dataset_name):
    true_alert_count = 0
    false_alert_count = 0
    alert_types = set()
    alert_sources = set()

    earliest_time = None
    latest_time = None
    duration_iso8601 = ""

    dataset_path = DATASET_DIR / f"{dataset_name}"
    verify_valid_directory(dataset_path)

    with open(dataset_path, "r", encoding="utf-8") as file:
        count = 0
        for line in file:
            count += 1
            try:
                alert_dict = json.loads(line)

                if alert_dict["metadata"]["misuse"] == True or alert_dict["metadata"]["misuse"] == "yes":
                    true_alert_count += 1
                elif alert_dict["metadata"]["misuse"] == False or alert_dict["metadata"]["misuse"] == "no":
                    false_alert_count += 1

                alert_types.add(alert_dict["features"].get("rule_name", ""))
                alert_sources.add(alert_dict["metadata"].get("alert_source", ""))

                timestamp = parser.isoparse(alert_dict["features"]["timestamp"])
                if earliest_time is None or timestamp < earliest_time:
                    earliest_time = timestamp
                if latest_time is None or timestamp > latest_time:
                    latest_time = timestamp

            except json.JSONDecodeError as e:
                raise ValueError(f"File '{dataset_name}' does not contain valid JSONL.\nError in line {count}: {e}")

    if earliest_time and latest_time:
        delta = latest_time - earliest_time
        duration_iso8601 = duration_isoformat(delta)
    else:
        raise ValueError(f"File '{dataset_name}' does not contain valid timestamps.")

    return true_alert_count, false_alert_count, len(alert_types), len(alert_sources), duration_iso8601


def fetch_preview(dataset_name):
    dataset_path = DATASET_DIR / f"{dataset_name}"
    verify_valid_directory(dataset_path)

    preview = []

    with open(dataset_path, "r", encoding="utf-8") as file:
        for line in file:
            preview.append(json.loads(line))
            if len(preview) >= 10:
                break

    return preview


def fetch_jitter_data(dataset_name):
    # grouped into minutes

    dataset_path = DATASET_DIR / f"{dataset_name}"
    verify_valid_directory(dataset_path)

    jitter_data: dict[datetime, dict[str, dict[str, int]]] = {}

    with open(dataset_path, "r", encoding="utf-8") as file:
        for line in file:
            alert_dict = json.loads(line)
            timestamp = parser.isoparse(alert_dict["features"]["timestamp"])
            timestamp_group = timestamp.replace(second=0, microsecond=0)
            alert_type = alert_dict["features"].get("rule_name", "unknown")

            label = get_label(alert_dict["metadata"]["misuse"])

            jitter_data.setdefault(timestamp_group, {})
            jitter_data[timestamp_group].setdefault(alert_type, {})
            jitter_data[timestamp_group][alert_type].setdefault(label.value, 0)

            jitter_data[timestamp_group][alert_type][label.value] += 1

    timestamps = list(jitter_data.keys())
    smallest_timestamp = min(timestamps)
    largest_timestamp = max(timestamps)

    cur_timestamp = smallest_timestamp
    while cur_timestamp <= largest_timestamp:
        jitter_data.setdefault(cur_timestamp, {})
        cur_timestamp += timedelta(minutes=1)

    # Sort by timestamp ascending and convert to ISO format strings for JSON serialization
    return {timestamp.isoformat(): counts for timestamp, counts in sorted(jitter_data.items(), key=lambda x: x[0])}


def verify_valid_directory(full_path: Path):
    if not full_path.resolve().is_relative_to(DATASET_DIR.resolve()):
        raise ValueError("Invalid access")
