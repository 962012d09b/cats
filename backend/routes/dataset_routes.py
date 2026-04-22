from datetime import datetime
from flask import Blueprint, request, jsonify

from database.schemas import datasets_schema
from database.sql_models import db, Dataset
from sqlalchemy import false
from utility.paths import check_dataset_existence
from utility.dataset_helper import fetch_jitter_data, fetch_preview, get_dataset_statistics

dataset_routes_bp = Blueprint("dataset_routes_bp", __name__)


@dataset_routes_bp.route("/api/datasets", methods=["GET"])
def get_datasets():
    all_datasets = Dataset.query.all()
    return datasets_schema.jsonify(all_datasets)


@dataset_routes_bp.route("/api/datasets", methods=["POST"])
def add_new_dataset():
    assert request.json is not None
    does_exist = check_dataset_existence(request.json["file_name"])

    true_alert_count = 0
    false_alert_count = 0
    alert_type_count = 0
    alert_source_count = 0
    duration_iso8601 = ""
    if does_exist:
        true_alert_count, false_alert_count, alert_type_count, alert_source_count, duration_iso8601 = (
            get_dataset_statistics(request.json["file_name"])
        )

    new_dataset = Dataset()
    new_dataset.name = request.json["name"]
    new_dataset.description = request.json.get("description")
    new_dataset.file_name = request.json["file_name"]
    new_dataset.does_exist = does_exist
    new_dataset.tags = request.json["tags"]
    new_dataset.true_alert_count = true_alert_count
    new_dataset.false_alert_count = false_alert_count
    new_dataset.alert_type_count = alert_type_count
    new_dataset.alert_source_count = alert_source_count
    new_dataset.duration_iso8601 = duration_iso8601
    db.session.add(new_dataset)
    db.session.commit()

    return {}


@dataset_routes_bp.route("/api/datasets", methods=["PUT"])
def edit_existing_dataset():
    assert request.json is not None
    dataset_id = request.json["id"]
    dataset = db.session.query(Dataset).filter_by(id=dataset_id).first()
    if dataset is None:
        return jsonify({"error": "Dataset not found"}), 404

    does_exist = check_dataset_existence(request.json["file_name"])

    true_alert_count = 0
    false_alert_count = 0
    alert_type_count = 0
    alert_source_count = 0
    duration_iso8601 = ""
    if does_exist:
        true_alert_count, false_alert_count, alert_type_count, alert_source_count, duration_iso8601 = (
            get_dataset_statistics(request.json["file_name"])
        )

    dataset.name = request.json["name"]
    dataset.description = request.json["description"]
    dataset.file_name = request.json["file_name"]
    dataset.does_exist = does_exist
    dataset.tags = request.json["tags"]
    dataset.true_alert_count = true_alert_count
    dataset.false_alert_count = false_alert_count
    dataset.alert_type_count = alert_type_count
    dataset.alert_source_count = alert_source_count
    dataset.duration_iso8601 = duration_iso8601

    db.session.commit()

    return {}


@dataset_routes_bp.route("/api/datasets", methods=["DELETE"])
def delete_existing_dataset():
    assert request.json is not None
    dataset_id = request.json["id"]
    Dataset.query.filter_by(id=dataset_id).delete()

    db.session.commit()

    return {}


@dataset_routes_bp.route("/api/datasets/<int:dataset_id>/preview", methods=["GET"])
def get_dataset_preview(dataset_id):
    dataset = db.session.query(Dataset).filter_by(id=dataset_id).first()
    if dataset is None:
        return jsonify({"error": "Dataset not found"}), 404

    preview = fetch_preview(dataset.file_name)
    return jsonify(preview)


@dataset_routes_bp.route("/api/datasets/<int:dataset_id>/jitter", methods=["GET"])
def get_jitter_data(dataset_id):
    dataset = db.session.query(Dataset).filter_by(id=dataset_id).first()
    if dataset is None:
        return jsonify({"error": "Dataset not found"}), 404

    jitter_data = fetch_jitter_data(dataset.file_name)
    return jsonify(jitter_data)
