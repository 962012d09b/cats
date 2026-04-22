from flask import Blueprint, jsonify, request

from database.schemas import modules_schema
from database.sql_models import (
    db,
    Module,
    CheckboxInput,
    DropdownInput,
    DigitSliderInput,
    RangeSliderInput,
    SmallTextInput,
)
from utility.paths import check_module_existence

module_routes_bp = Blueprint("module_routes_bp", __name__)


@module_routes_bp.route("/api/modules", methods=["GET"])
def get_modules():
    all_modules = Module.query.all()
    return modules_schema.jsonify(all_modules)


@module_routes_bp.route("/api/modules", methods=["POST"])
def add_new_module():
    assert request.json is not None, "Request JSON cannot be None"

    for input_data in request.json["inputs"]:
        input_data.pop("current_value", None)

    new_module = Module(
        name=request.json["name"],
        description=request.json["description"],
        file_name=request.json["file_name"],
        does_exist=check_module_existence(request.json["file_name"]),
        inputs=[create_input(input_data) for input_data in request.json["inputs"]],
        tags=request.json["tags"],
    )

    db.session.add(new_module)
    db.session.commit()

    return {}


@module_routes_bp.route("/api/modules", methods=["PUT"])
def edit_existing_module():
    assert request.json is not None, "Request JSON cannot be None"

    module_id = request.json["id"]
    module = db.session.query(Module).filter_by(id=module_id).first()
    if module is None:
        return jsonify({"error": "Module not found"}), 404

    for input in module.inputs:
        db.session.delete(input)

    module.name = request.json["name"]
    module.description = request.json["description"]
    module.file_name = request.json["file_name"]
    module.does_exist = check_module_existence(request.json["file_name"])
    module.tags = request.json["tags"]
    module.input_presets = request.json.get("input_presets", [])

    module.inputs = [create_input(input_data) for input_data in request.json["inputs"]]

    db.session.commit()

    return {}


@module_routes_bp.route("/api/modules", methods=["DELETE"])
def delete_existing_module():
    assert request.json is not None, "Request JSON cannot be None"

    module_id = request.json["id"]
    module = db.session.query(Module).filter_by(id=module_id).first()

    if module is None:
        return jsonify({"error": "Module not found"}), 404

    for input in module.inputs:
        db.session.delete(input)
    db.session.delete(module)

    db.session.commit()

    return {}


def create_input(input_data):
    input_type = input_data.get("type")
    input_data["id"] = None
    if input_type == "checkbox":
        return CheckboxInput(**input_data)
    elif input_type == "digit_slider":
        return DigitSliderInput(**input_data)
    elif input_type == "range_slider":
        return RangeSliderInput(**input_data)
    elif input_type == "small_text":
        return SmallTextInput(**input_data)
    elif input_type == "dropdown":
        return DropdownInput(**input_data)
    else:
        raise ValueError(f"Invalid/Unknown input type: {input_type}")
