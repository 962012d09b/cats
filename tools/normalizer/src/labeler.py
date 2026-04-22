import jsonlines
import pandas as pd
from dateutil import parser
import zipfile
import os

import yaml

from normalizer import AIT_GROUND_TRUTH_PATH, DEDALE_GROUND_TRUTH_PATH, MANUAL_LABELS_PATH


def label_alerts(label_method, normalized_alerts):
    print("Starting labeling of alerts...")

    try:
        if label_method == "default":
            for index, alert in enumerate(normalized_alerts):
                print(f"\r{index}", end="")
                label = default_label(alert)
                alert["metadata"]["misuse"] = label

        elif label_method == "ait":
            ait_type = get_ait_alert_type(normalized_alerts[0])
            ground_truth = load_ait_ground_truth(ait_type)
            for index, alert in enumerate(normalized_alerts):
                print(f"\r{index}", end="")
                label = ait_label(alert, ground_truth, ait_type)
                alert["metadata"]["misuse"] = label

        elif label_method == "dedale":
            ground_truth = load_dedale_ground_truth()
            manual_labels = load_manual_labels()["dedale"]
            for index, alert in enumerate(normalized_alerts):
                print(f"\r{index}", end="")
                label = dedale_label(alert, ground_truth, manual_labels)
                alert["metadata"]["misuse"] = label

        print("\nFinished labeling alerts.")
    except Exception as e:
        print(f"Unable to label alerts using method {label_method}.\n{e}")
        print("Either implement a custom labeling method or provide misuse labels in alert['metadata']['misuse'].")

    return normalized_alerts


def default_label(alert: dict):
    label = alert["full_alert"]["metadata"]["misuse"]
    return label


def ait_label(alert: dict, ground_truth: pd.DataFrame, ait_type: str):
    if ait_type == "aminer":
        epoch = int(alert["full_alert"]["LogData"]["Timestamps"][0])
    else:
        time = parser.isoparse(alert["full_alert"]["@timestamp"])
        epoch = int(time.timestamp())

    matches = ground_truth.loc[ground_truth["time"] == epoch]

    # many alerts feature the exact same timestamp
    # in these cases we want to, if possible, use available IP and hostname information as additional filters
    if "ip_addresses" in alert["features"]:
        filtered_by_ip = matches[matches["ip"].isin(alert["features"]["ip_addresses"])]
        if not filtered_by_ip.empty:
            matches = filtered_by_ip
    if "hostname" in alert["features"]:
        filtered_by_hostname = matches[matches["host"] == alert["features"]["hostname"]]
        if not filtered_by_hostname.empty:
            matches = filtered_by_hostname

    if matches.iloc[0]["event_label"] == "-":
        return False
    else:
        return True


def get_ait_alert_type(example_alert: dict) -> str:
    try:
        log_source = example_alert["full_alert"]["location"]
        if "suricata/eve.json" in log_source:
            return "suricata"
        else:
            return "wazuh"
    except KeyError:
        if "AnalysisComponent" in example_alert["full_alert"]:
            return "aminer"
        else:
            raise ValueError("Unknown AIT type")


def load_ait_ground_truth(ait_type: str) -> pd.DataFrame:
    path = AIT_GROUND_TRUTH_PATH

    if not os.path.exists(path):
        print("Ground truth file not found. Extracting from archive...")
        archive = path.with_suffix(".zip")
        with zipfile.ZipFile(archive, "r") as zip_ref:
            zip_ref.extractall(path.parent)

    df = pd.read_csv(path)

    if ait_type == "aminer":
        return df[df["name"].str.contains("AMiner", na=False)]
    elif ait_type == "suricata":
        return df[df["name"].str.contains("Suricata", na=False)]
    elif ait_type == "wazuh":
        return df[df["name"].str.contains("Wazuh", na=False)]
    else:
        raise ValueError("Unknown AIT type")


def dedale_label(alert: dict, ground_truth: dict, manual_labels: dict):
    cur_timestamp = alert["features"]["timestamp"]
    rule_name = alert["features"]["rule_name"]
    label = False

    if cur_timestamp in ground_truth:
        # since the entire log is copied, we can check for an exact message match
        label = alert["full_alert"]["log"]["message"] in ground_truth[cur_timestamp]

    if rule_name in manual_labels:
        entry = next((e for e in manual_labels[rule_name] if e["timestamp"] == cur_timestamp), None)
        if entry is not None:
            label = entry["label"]  # manual override

    return label


def load_dedale_ground_truth() -> dict:
    path = DEDALE_GROUND_TRUTH_PATH
    if not os.path.exists(path):
        print("Ground truth file not found. Extracting from archive...")
        archive = path.with_suffix(".zip")
        with zipfile.ZipFile(archive, "r") as zip_ref:
            zip_ref.extractall(path.parent)

    ground_truth_file = path / "clients_1_and_2" / "malicious_events_class_1_and_2.jsonl"

    with jsonlines.open(ground_truth_file) as reader:
        gt = {}
        for entry in reader:
            gt.setdefault(entry["@timestamp"], [])
            gt[entry["@timestamp"]].append(entry["message"])

        return gt


def load_manual_labels() -> dict:
    with open(MANUAL_LABELS_PATH, "r") as file:
        manual_labels = yaml.safe_load(file)
    return manual_labels
