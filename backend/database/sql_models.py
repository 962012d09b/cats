from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from typing import Optional


db = SQLAlchemy()
Base = db.Model


class Dataset(db.Model):
    id: Mapped[int] = mapped_column(primary_key=True)

    name: Mapped[str]
    description: Mapped[Optional[str]]
    file_name: Mapped[str]
    does_exist: Mapped[bool]
    tags: Mapped[list[str]] = mapped_column(JSON)
    true_alert_count: Mapped[int]
    false_alert_count: Mapped[int]
    alert_type_count: Mapped[int]
    alert_source_count: Mapped[int]
    duration_iso8601: Mapped[str]

    def __init__(self, **kwargs):
        super().__init__(**kwargs)


class Module(db.Model):
    id: Mapped[int] = mapped_column(primary_key=True)

    name: Mapped[str]
    description: Mapped[Optional[str]]
    file_name: Mapped[str]
    does_exist: Mapped[bool]
    tags: Mapped[list[str]] = mapped_column(JSON)
    inputs: Mapped[list["Input"]] = relationship(back_populates="module")
    input_presets: Mapped[Optional[list]] = mapped_column(JSON)

    def __init__(self, **kwargs):
        super().__init__(**kwargs)


class Input(db.Model):
    id: Mapped[int] = mapped_column(primary_key=True)
    module_id: Mapped[int] = mapped_column(ForeignKey("module.id"))
    module: Mapped[Module] = relationship(back_populates="inputs")

    type: Mapped[str]
    description: Mapped[Optional[str]]

    __mapper_args__ = {
        "polymorphic_identity": "input",
        "polymorphic_on": "type",
    }


class CheckboxInput(Input):
    id: Mapped[int] = mapped_column(ForeignKey("input.id"), primary_key=True)

    labels: Mapped[list[str]] = mapped_column(JSON)
    is_mutually_exclusive: Mapped[bool]
    initial_values: Mapped[list[bool]] = mapped_column(JSON)

    __mapper_args__ = {
        "polymorphic_identity": "checkbox",
    }


class DropdownInput(Input):
    id: Mapped[int] = mapped_column(ForeignKey("input.id"), primary_key=True)

    items: Mapped[list[str]] = mapped_column(JSON)

    __mapper_args__ = {
        "polymorphic_identity": "dropdown",
    }


class DigitSliderInput(Input):
    id: Mapped[int] = mapped_column(ForeignKey("input.id"), primary_key=True)

    min_value: Mapped[float]
    max_value: Mapped[float]
    divisions: Mapped[int]
    initial_value: Mapped[float]

    __mapper_args__ = {
        "polymorphic_identity": "digit_slider",
    }


class RangeSliderInput(Input):
    id: Mapped[int] = mapped_column(ForeignKey("input.id"), primary_key=True)

    min_value: Mapped[float]
    max_value: Mapped[float]
    divisions: Mapped[int]
    initial_values: Mapped[list[float]] = mapped_column(JSON)
    min_range: Mapped[Optional[float]]
    max_range: Mapped[Optional[float]]

    __mapper_args__ = {
        "polymorphic_identity": "range_slider",
    }


class SmallTextInput(Input):
    id: Mapped[int] = mapped_column(ForeignKey("input.id"), primary_key=True)

    initial_value: Mapped[str]
    regex: Mapped[Optional[str]]
    has_to_match_regex: Mapped[Optional[bool]]
    error_message: Mapped[Optional[str]]

    __mapper_args__ = {
        "polymorphic_identity": "small_text",
    }


class SavedPipeline(db.Model):
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str]
    description: Mapped[str]
    pipeline_data: Mapped[dict] = mapped_column(JSON)

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
