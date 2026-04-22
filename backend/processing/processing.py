from copy import deepcopy
from importlib import import_module

import celery
from flask import json, current_app
import time
from dateutil import parser

import database.sql_models as sql
from database.sql_models import db
from processing.data_models import Dataset, DatasetEntry, Pipeline
from processing.post_processing import calculate_results
from utility.dataset_helper import verify_valid_directory
from utility.paths import DATASET_DIR


def fetch_datasets_from_db(selected_dataset_ids: list[int], default_risk_score: float) -> Dataset:
    datasets = db.session.query(sql.Dataset).filter(sql.Dataset.id.in_(selected_dataset_ids)).all()
    combined_data: list[DatasetEntry] = []
    all_paths = []

    for dataset in datasets:
        full_path = DATASET_DIR / dataset.file_name
        verify_valid_directory(full_path)

        all_paths.append(full_path)

        with open(full_path, "r", encoding="utf-8") as file:
            for line in file:
                content = json.loads(line)
                newEntry = DatasetEntry.from_json(content)

                newEntry.metadata["risk_score"] = default_risk_score
                newEntry.metadata["raw_risk_scores"] = []

                combined_data.append(newEntry)

    combined_data.sort(key=lambda x: parser.isoparse(x.features["timestamp"]))

    if not combined_data:
        raise ValueError("No dataset entries found in the selected datasets.")

    return Dataset(data=combined_data, file_names=all_paths)


def process_pipelines(
    dataset_ids: list[int],
    pipelines_json: list[dict],
    default_risk_score: float,
    task: celery.Task | None = None,
) -> list[Pipeline]:
    server_cache = getattr(current_app, "cache")
    preprocessing_start = time.perf_counter()

    dataset = fetch_datasets_from_db(dataset_ids, default_risk_score)
    pipelines = [Pipeline.from_json(pipeline) for pipeline in pipelines_json]

    # +1 per pipe for postprocessing, +1 for preprocessing
    total_progress = sum([len(pipe.modules) + 1 for pipe in pipelines]) + 1
    current_progress = 0

    # The process of: pipelines as json --> pipelines as objects --> pipelines as json
    # gets rid of all values irrelevant for the purpose of caching
    pipelines_json = [pipeline.to_json() for pipeline in pipelines]
    dataset_names = dataset.file_names
    preprocessing_end = time.perf_counter()
    time_to_preprocess = preprocessing_end - preprocessing_start

    current_progress += 1

    for index, pipeline in enumerate(pipelines):
        if pipeline is None:
            raise ValueError(f"Internal error: pipeline {index} is None")

        start_time = time.perf_counter()
        unique_cache_key = (
            f"{str(dataset_names)}{str(pipelines_json[index]["modules"])}{str(pipelines_json[index]["settings"])}"
        )
        cached_result = server_cache.get(f"{unique_cache_key}_results")
        cached_logs = server_cache.get(f"{unique_cache_key}_logs") or []

        if cached_result:
            update_state(
                task, f"Loading cached results for pipeline {pipeline.name}", current_progress / total_progress
            )
            pipeline.results = cached_result
            pipeline.logs = cached_logs

            current_progress += len(pipeline.modules) + 1
        else:
            temp_dataset = deepcopy(dataset)
            pipeline_logs = []

            for index, module in enumerate(pipeline.modules):
                update_state(
                    task,
                    f"Processing pipeline {pipeline.name}: Module {index + 1}/{len(pipeline.modules)}",
                    current_progress / total_progress,
                )

                import_path = f"modules.{module.file_name.replace('.py', '')}"
                imported_module = import_module(import_path)

                temp_dataset, logs = imported_module.process(
                    temp_dataset,
                    module.args,
                    weight=module.weight,
                    averaging_method=pipeline.settings.averaging_method,
                )
                pipeline_logs.append(logs)

                current_progress += 1

            update_state(
                task,
                f"Processing pipeline {pipeline.name}: Post-processing",
                current_progress / total_progress,
            )

            pipeline.logs = pipeline_logs

            pipeline.results = calculate_results(temp_dataset)
            server_cache.set(f"{unique_cache_key}_results", pipeline.results)
            server_cache.set(f"{unique_cache_key}_logs", pipeline_logs)

            current_progress += 1

        end_time = time.perf_counter()
        if cached_result:
            pipeline.time_to_compute = 0
        else:
            pipeline.time_to_compute = end_time - start_time

        pipeline.time_to_preprocess = time_to_preprocess

    return pipelines


def update_state(task: celery.Task | None, message: str, progress: float):
    if task:
        task.update_state(task_id=task.request.id, state="PROCESSING", meta={"status": message, "progress": progress})
