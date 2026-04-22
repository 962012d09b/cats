from flask import Blueprint, jsonify, request
import os

from utility.init_db import initialize_database
from database.sql_models import SavedPipeline, db
from database.schemas import saved_pipelines_schema
from utility.paths import DB_PATH

management_routes_bp = Blueprint("management_routes_bp", __name__)


@management_routes_bp.route("/api/reinitialize_db", methods=["DELETE"])
def reinitialize_db():
    try:
        if not os.path.isfile(DB_PATH):
            return jsonify({"error": "Database file not found"}), 404

        db.session.remove()
        db.drop_all()

        initialize_database(db, reset=True)
        return jsonify({"message": "Database reinitialized successfully"}), 200

    except Exception as e:
        print(e)
        return jsonify({"error": "Failed to reinitialize database", "details": str(e)}), 500


@management_routes_bp.route("/api/saves", methods=["GET"])
def get_saved_pipelines():
    saved_pipelines = SavedPipeline.query.all()
    return saved_pipelines_schema.jsonify(saved_pipelines)


@management_routes_bp.route("/api/saves", methods=["POST"])
def save_pipeline():
    assert request.json is not None, "Request JSON cannot be None"

    new_save = SavedPipeline(
        name=request.json["name"],
        description=request.json["description"],
        pipeline_data=request.json["pipeline_data"],
    )

    db.session.add(new_save)
    db.session.commit()

    return {}


@management_routes_bp.route("/api/saves", methods=["PUT"])
def edit_saved_pipeline():
    assert request.json is not None, "Request JSON cannot be None"

    save_id = request.json["id"]
    save = db.session.query(SavedPipeline).filter_by(id=save_id).first()
    if save is None:
        return jsonify({"error": "Save not found"}), 404

    save.name = request.json["name"]
    save.description = request.json["description"]
    save.pipeline_data = request.json["pipeline_data"]

    db.session.commit()

    return {}


@management_routes_bp.route("/api/saves", methods=["DELETE"])
def delete_saved_pipeline():
    assert request.json is not None, "Request JSON cannot be None"

    save_id = request.json["id"]
    save = db.session.query(SavedPipeline).filter_by(id=save_id).first()
    if save is None:
        return jsonify({"error": "Save not found"}), 404

    db.session.delete(save)
    db.session.commit()

    return {}
