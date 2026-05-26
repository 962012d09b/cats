from sqlalchemy.exc import OperationalError
import os
from typing import Optional
import uuid
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import yaml
import json
from rich import print as rich_print
from pathlib import Path

from utility.paths import DB_PATH
from database.sql_models import (
    Dataset as SQLDataset,
    Module as SQLModule,
    CheckboxInput,
    DropdownInput,
    DigitSliderInput,
    RangeSliderInput,
    SmallTextInput,
)
from batch_processor.src.models import CompletedPipeline


def check_database_existence():
    if not Path(DB_PATH).exists():
        rich_print(f"[red]CATS database not found at {DB_PATH}.\n[/red]")
        rich_print(
            "Starting the CATS backend should create the database and resolve this issue. From the repository root, run:"
        )
        rich_print("[bold]docker compose up --build -d[/bold]\n")
        os._exit(1)

    engine = create_engine(f"sqlite:///{DB_PATH}")
    Session = sessionmaker(bind=engine)
    session = Session()

    try:
        session.query(SQLDataset).first()
        session.query(SQLModule).first()
    except OperationalError:
        rich_print(f"[red]CATS database found at {DB_PATH}, but it is missing critical data.\n[/red]")
        rich_print(
            "Delete the file and start the CATS backend again to resolve this issue. From the repository root, run:"
        )
        rich_print(f"[bold]rm {DB_PATH}[/bold]")
        rich_print("[bold]docker compose up --build -d[/bold]\n")
        os._exit(1)


def generate_config_from_database():
    engine = create_engine(f"sqlite:///{DB_PATH}")
    Session = sessionmaker(bind=engine)
    session = Session()

    datasets = session.query(SQLDataset).all()
    modules = session.query(SQLModule).all()

    config_data = {
        "datasets": [dataset.file_name for dataset in datasets],
        "modules": [
            {
                "name": module.name,
                "file_name": module.file_name,
                "id": module.id,
                "weight": 1,
                "parameters": get_input_defaults(module),
            }
            for module in modules
        ],
        "defaults": {
            "risk_score": 0.5,
            # "fixed_module_order": False,
            "save_results": True,
            "generate_cats_import": True,
            "save_used_config": True,
            "optimize_weights": True,
            "weight_resolution": 0.2,
            "averaging_method": "both",
            "combine_modules": True,
        },
    }

    file_name = "example_full_config.yaml"
    with open(file_name, "w") as file:
        file.write("# Configuration file generated from CATS database\n")
        file.write("# Contains ALL currently registered datasets and modules\n")
        file.write("# You'll most likely want to refine this further, e.g., by (un)commenting certain lines\n\n")

        yaml.dump({"defaults": config_data["defaults"]}, file)

        file.write(f"\n{'#' * 30}\n\n")

        # comment out all but the first dataset to avoid having the user immediately run a gargantuan task
        file.write("datasets:\n")
        file.write(f"- {config_data["datasets"][0]}\n")
        for ds in config_data["datasets"][1:]:
            file.write(f"# - {ds}\n")

        file.write(f"\n{'#' * 30}\n\n")

        yaml.dump({"modules": config_data["modules"]}, file, default_flow_style=False, sort_keys=False)

    print(f"Configuration file generated as {file_name}")


def get_input_defaults(module: SQLModule) -> Optional[list]:
    defaults = []
    for input in module.inputs:
        if isinstance(input, CheckboxInput):
            defaults.append([v for v in input.initial_values])
        elif isinstance(input, DropdownInput):
            defaults.append([v for v in input.items])
        elif isinstance(input, DigitSliderInput):
            defaults.append([input.initial_value])
        elif isinstance(input, RangeSliderInput):
            defaults.append([v for v in input.initial_values])
        elif isinstance(input, SmallTextInput):
            defaults.append([input.initial_value])
        else:
            raise ValueError(f"Unknown input type: {type(input)}")
    return defaults if defaults else None


def generate_cats_import(
    best_pipeline: CompletedPipeline, timestamp: str, default_risk_score: float, prefix: str
) -> None:
    engine = create_engine(f"sqlite:///{DB_PATH}")
    Session = sessionmaker(bind=engine)
    session = Session()

    modules = []
    for index, pipeline_module in enumerate(best_pipeline.config):
        # Fetch the full module from the DB
        db_module = session.query(SQLModule).filter_by(id=pipeline_module.id).first()
        if not db_module:
            continue

        # Build inputs with all DB info, but set current_value from pipeline_module.args
        inputs = []
        for db_input, current_value in zip(db_module.inputs, pipeline_module.args):
            input_dict = {
                "type": db_input.type,
                "description": getattr(db_input, "description", ""),
                "runtimeType": db_input.type,
                "current_value": current_value,
            }
            if isinstance(db_input, CheckboxInput):
                input_dict["labels"] = list(db_input.labels)
                input_dict["is_mutually_exclusive"] = db_input.is_mutually_exclusive
                input_dict["initial_values"] = list(db_input.initial_values)
            elif isinstance(db_input, DropdownInput):
                input_dict["items"] = list(db_input.items)
            elif isinstance(db_input, DigitSliderInput):
                input_dict["min_value"] = db_input.min_value
                input_dict["max_value"] = db_input.max_value
                input_dict["divisions"] = db_input.divisions
                input_dict["initial_value"] = db_input.initial_value
            elif isinstance(db_input, RangeSliderInput):
                input_dict["min_value"] = db_input.min_value
                input_dict["max_value"] = db_input.max_value
                input_dict["divisions"] = db_input.divisions
                input_dict["initial_values"] = list(db_input.initial_values)
                input_dict["min_range"] = db_input.min_range
                input_dict["max_range"] = db_input.max_range
            elif isinstance(db_input, SmallTextInput):
                input_dict["initial_value"] = db_input.initial_value
                input_dict["regex"] = db_input.regex
                input_dict["has_to_match_regex"] = db_input.has_to_match_regex
                input_dict["error_message"] = db_input.error_message
            else:
                raise ValueError(f"Unknown input type: {type(db_input)}")
            inputs.append(input_dict)

        modules.append(
            {
                "id": db_module.id,
                "name": db_module.name,
                "description": db_module.description,
                "file_name": db_module.file_name,
                "does_exist": db_module.does_exist,
                "inputs": inputs,
                "input_presets": db_module.input_presets,
                "tags": db_module.tags,
                "weight": best_pipeline.used_weights[index],
                "uuid": str(uuid.uuid4()),
            }
        )

    import_json = [
        {
            "name": "Best Case",
            "modules": modules,
            "is_visible": True,
            "uuid": str(uuid.uuid4()),
            "settings": {
                "default_risk_score": default_risk_score,
                "averaging_method": [
                    best_pipeline.used_averaging_method == "geometric",
                    best_pipeline.used_averaging_method == "arithmetic",
                ],
            },
        }
    ]

    filename = f"{prefix}_cats_import_{timestamp}.json"
    with open(filename, "w") as f:
        json.dump(import_json, f, separators=(",", ": "), sort_keys=False)

    print(f"Generated CATS import file: {filename}")
    print("You can import this (as one single string) into CATS to recreate the best pipeline configuration.\n")
