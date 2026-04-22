from pathlib import Path

from flask_sqlalchemy import SQLAlchemy

import database.sql_models as sql
from utility.dataset_helper import get_dataset_statistics
from utility.paths import DB_PATH, check_dataset_existence, check_module_existence

DEFAULT_MODULES = [
    {
        "name": "Rule Level",
        "description": "Modify risk score based on the level of the triggered rule. Supports Sigma, Suricata and Wazuh.",
        "file_name": "level_score.py",
        "inputs": [],
        "tags": ["static"],
    },
    {
        "name": "Accumulation",
        "description": "Modify event risk scores based on accumulated risk within a group, defined by some feature.",
        "file_name": "accumulated_risk.py",
        "inputs": [
            {
                "type": "dropdown",
                "description": "Group by:",
                "items": ["Hostname", "Source IP", "Destination IP", "Alert Type", "Username"],
            },
            {
                "type": "dropdown",
                "description": "Sliding Window:",
                "items": ["Box", "Triangle"],
            },
            {
                "type": "dropdown",
                "items": ["One minute", "One hour", "One day", "One week", "Four weeks"],
            },
            {
                "type": "dropdown",
                "items": ["Past", "Past + Future"],
            },
        ],
        "tags": ["dynamic"],
    },
    {
        "name": "Rarity",
        "description": 'Modify event risk scores based on the size of the group they belong to, with smaller groups ("rarer events") being assigned higher scores.',
        "file_name": "rarity.py",
        "inputs": [
            {
                "type": "dropdown",
                "description": "Group by:",
                "items": ["Alert Type", "Hostname", "Source IP", "Destination IP", "Username"],
            },
            {
                "type": "dropdown",
                "description": "Sliding Window:",
                "items": ["Box", "Triangle"],
            },
            {
                "type": "dropdown",
                "items": ["One minute", "One hour", "One day", "One week", "Four weeks"],
            },
            {
                "type": "dropdown",
                "items": ["Past", "Past + Future"],
            },
        ],
        "tags": ["dynamic"],
    },
    {
        "name": "Variety",
        "description": "Modify event risk scores based on the variety of alert types of surrounding alerts, grouped by some feature.",
        "file_name": "variety.py",
        "inputs": [
            {
                "type": "dropdown",
                "description": "Group by:",
                "items": ["Hostname", "Source IP", "Destination IP", "Username"],
            },
            {
                "type": "dropdown",
                "description": "Sliding Window:",
                "items": ["Box", "Triangle"],
            },
            {
                "type": "dropdown",
                "items": ["One minute", "One hour", "One day", "One week", "Four weeks"],
            },
            {
                "type": "dropdown",
                "items": ["Past", "Past + Future"],
            },
        ],
        "tags": ["dynamic"],
    },
    {
        "name": "Aperiodicity",
        "description": "Computes a score in [0, 1] indicating how aperiodic a set of events is.",
        "file_name": "aperiodicity.py",
        "inputs": [
            {
                "type": "dropdown",
                "description": "Group by:",
                "items": ["Alert Type", "Hostname", "Source IP", "Destination IP", "Username"],
            },
            {
                "type": "dropdown",
                "description": "Sliding Window:",
                "items": ["One minute", "One hour", "One day", "One week", "Four weeks"],
            },
            {
                "type": "dropdown",
                "items": ["Past", "Past + Future"],
            },
            {
                "type": "digit_slider",
                "description": "Event count confidence threshold",
                "min_value": 1,
                "max_value": 30,
                "divisions": 29,
                "initial_value": 5,
            },
        ],
        "tags": ["dynamic"],
    },
    {
        "name": "Fixed Risk Score",
        "description": "Produces a fixed risk score for every event.",
        "file_name": "fixed_score.py",
        "inputs": [
            {
                "type": "digit_slider",
                "description": "Risk score value:",
                "min_value": 0,
                "max_value": 1,
                "divisions": 100,
                "initial_value": 0.5,
            },
        ],
        "tags": ["static"],
    },
]

DEFAULT_DATASETS = [
    {
        "name": "SOCBED Sigma",
        "description": "Sigma alerts obtained from running the default configuration of SOCBED.",
        "file_name": "socbed_sigma.jsonl",
        "tags": ["socbed", "host", "sigma"],
    },
    {
        "name": "SOCBED Suricata",
        "description": "Suricata alerts obtained from running the default configuration of SOCBED.",
        "file_name": "socbed_suricata.jsonl",
        "tags": ["socbed", "network", "suricata"],
    },
    {
        "name": "APT29 Sigma incl. user",
        "description": "Sigma alerts obtained from simulating an APT29 attack scenario, including additional simulated user behavior.",
        "file_name": "apt29_userbehavior_sigma.jsonl",
        "tags": ["apt29", "host", "sigma"],
    },
    {
        "name": "APT29 Suricata incl. user",
        "description": "Suricata alerts obtained from simulating an APT29 attack scenario, including additional simulated user behavior.",
        "file_name": "apt29_userbehavior_suricata.jsonl",
        "tags": ["apt29", "network", "suricata"],
    },
    {
        "name": "DEDALE Sigma",
        "description": "Sigma alerts obtained from all Winlogbeat data in the DEDALE dataset.",
        "file_name": "dedale_sigma.jsonl",
        "tags": ["dedale", "host", "sigma"],
    },
    {
        "name": "AIT AMiner",
        "description": 'AMiner alerts obtained from the "russelmitchell" AITv2 dataset.',
        "file_name": "ait_aminer.jsonl",
        "tags": ["ait", "host", "aminer"],
    },
    {
        "name": "AIT Suricata",
        "description": 'Suricata alerts obtained from the "russelmitchell" AITv2 dataset.',
        "file_name": "ait_suricata.jsonl",
        "tags": ["ait", "network", "suricata"],
    },
    {
        "name": "AIT Wazuh",
        "description": 'Wazuh alerts obtained from the "russelmitchell" AITv2 dataset.',
        "file_name": "ait_wazuh.jsonl",
        "tags": ["ait", "host", "wazuh"],
    },
]


def initialize_database(
    db: SQLAlchemy, datasets=DEFAULT_DATASETS, modules=DEFAULT_MODULES, testing=False, reset=False
):
    if testing or reset or not Path(DB_PATH).exists():
        db.create_all()

        for dataset in datasets:
            does_exist = True if testing else check_dataset_existence(dataset["file_name"])

            true_alert_count, false_alert_count, alert_type_count, alert_source_count, duration_iso8601 = (
                get_dataset_statistics(dataset["file_name"])
            )

            new_dataset = sql.Dataset()
            new_dataset.name = dataset["name"]
            new_dataset.description = dataset.get("description")
            new_dataset.file_name = dataset["file_name"]
            new_dataset.does_exist = does_exist
            new_dataset.tags = dataset["tags"]
            new_dataset.true_alert_count = true_alert_count
            new_dataset.false_alert_count = false_alert_count
            new_dataset.alert_type_count = alert_type_count
            new_dataset.alert_source_count = alert_source_count
            new_dataset.duration_iso8601 = duration_iso8601
            db.session.add(new_dataset)

        for mod in modules:
            new_module = sql.Module()
            new_module.name = mod["name"]
            new_module.description = mod.get("description")
            new_module.file_name = mod["file_name"]
            new_module.does_exist = True if testing else check_module_existence(mod["file_name"])
            new_module.tags = mod["tags"]
            db.session.add(new_module)

            for inp in mod["inputs"]:
                input_type = inp["type"]

                if input_type == "checkbox":
                    input_item = sql.CheckboxInput()
                    input_item.description = inp.get("description")
                    input_item.labels = inp["labels"]
                    input_item.is_mutually_exclusive = inp["is_mutually_exclusive"]
                    input_item.initial_values = inp["initial_values"]
                    input_item.module = new_module
                elif input_type == "dropdown":
                    input_item = sql.DropdownInput()
                    input_item.description = inp.get("description")
                    input_item.items = inp["items"]
                    input_item.module = new_module
                elif input_type == "digit_slider":
                    input_item = sql.DigitSliderInput()
                    input_item.description = inp.get("description")
                    input_item.min_value = inp["min_value"]
                    input_item.max_value = inp["max_value"]
                    input_item.divisions = inp["divisions"]
                    input_item.initial_value = inp["initial_value"]
                    input_item.module = new_module
                elif input_type == "ranged_slider":
                    input_item = sql.RangeSliderInput()
                    input_item.description = inp.get("description")
                    input_item.min_value = inp["min_value"]
                    input_item.max_value = inp["max_value"]
                    input_item.divisions = inp["divisions"]
                    input_item.initial_values = inp.get("initial_values")
                    input_item.min_range = inp.get("min_range")
                    input_item.max_range = inp.get("max_range")
                    input_item.module = new_module
                elif input_type == "small_text":
                    input_item = sql.SmallTextInput()
                    input_item.description = inp.get("description")
                    input_item.initial_value = inp["initial_value"]
                    input_item.module = new_module
                else:
                    raise ValueError(f"Unknown input type: {input_type}")

                db.session.add(input_item)

        db.session.commit()
