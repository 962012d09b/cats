from marshmallow import fields
from flask_marshmallow import Marshmallow

import database.sql_models as sql

from marshmallow_sqlalchemy import auto_field
from marshmallow import fields, post_dump


ma = Marshmallow()


class DatasetSchema(ma.SQLAlchemyAutoSchema):
    class Meta(ma.SQLAlchemyAutoSchema.Meta):
        model = sql.Dataset
        load_instance = True


# Base schema for Input
class InputSchema(ma.SQLAlchemyAutoSchema):
    class Meta(ma.SQLAlchemyAutoSchema.Meta):
        model = sql.Input
        load_instance = True
        include_fk = True

    type = auto_field()


# Schemas for each Input subclass
class CheckboxInputSchema(InputSchema):
    class Meta(InputSchema.Meta):
        model = sql.CheckboxInput


class DropdownInputSchema(InputSchema):
    class Meta(InputSchema.Meta):
        model = sql.DropdownInput


class DigitSliderInputSchema(InputSchema):
    class Meta(InputSchema.Meta):
        model = sql.DigitSliderInput


class RangeSliderInputSchema(InputSchema):
    class Meta(InputSchema.Meta):
        model = sql.RangeSliderInput


class ShortStringInputSchema(InputSchema):
    class Meta(InputSchema.Meta):
        model = sql.SmallTextInput


# Create a polymorphic field for inputs
class PolymorphicInputSchema(ma.SQLAlchemySchema):
    class Meta(ma.SQLAlchemyAutoSchema.Meta):
        model = sql.Input
        load_instance = True

    type = fields.String()
    input = fields.Method("get_input")

    def get_input(self, obj):
        if obj.type == "checkbox":
            return CheckboxInputSchema().dump(obj)
        elif obj.type == "digit_slider":
            return DigitSliderInputSchema().dump(obj)
        elif obj.type == "range_slider":
            return RangeSliderInputSchema().dump(obj)
        elif obj.type == "small_text":
            return ShortStringInputSchema().dump(obj)
        elif obj.type == "dropdown":
            return DropdownInputSchema().dump(obj)
        else:
            raise ValueError(f"Unknown input type: {obj.type}")

    @post_dump
    def remove_wrapper(self, data, **kwargs):
        return data["input"]


class ModuleSchema(ma.SQLAlchemyAutoSchema):
    class Meta(ma.SQLAlchemyAutoSchema.Meta):
        model = sql.Module
        load_instance = True

    inputs = fields.List(fields.Nested(PolymorphicInputSchema))


class SavedPipelineSchema(ma.SQLAlchemyAutoSchema):
    class Meta(ma.SQLAlchemyAutoSchema.Meta):
        model = sql.SavedPipeline
        load_instance = True

    name = auto_field()
    description = auto_field()
    pipeline_data = auto_field()


datasets_schema = DatasetSchema(many=True)
modules_schema = ModuleSchema(many=True)
saved_pipelines_schema = SavedPipelineSchema(many=True)
