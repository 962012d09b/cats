import enum


class AveragingMethod(enum.Enum):
    GEOMETRIC_MEAN = 0
    ARITHMETIC_MEAN = 1


class DatasetEntry:
    def __init__(self, full_alert: dict, features: dict, metadata: dict) -> None:
        self.full_alert = full_alert
        self.features = features
        self.metadata = metadata

    @classmethod
    def from_json(cls, json_data: dict):
        full_alert = json_data.get("full_alert", {})
        features = json_data.get("features", {})
        metadata = json_data.get("metadata", {})
        return cls(full_alert=full_alert, features=features, metadata=metadata)

    def to_json(self) -> dict:
        result = {
            "full_alert": self.full_alert,
            "features": self.features,
            "metadata": self.metadata,
        }
        return result


class Dataset:
    def __init__(self, data: list[DatasetEntry], file_names: list[str]) -> None:
        self.data = data
        self.file_names = file_names
        self.results = {}


class Module:
    def __init__(self, file_name: str, args: list, weight: float) -> None:
        self.file_name = file_name
        self.args = args
        self.weight = weight

    @classmethod
    def from_json(cls, json_data: dict):
        file_name = json_data.get("file_name", "")
        args = []
        weight = json_data["weight"]

        all_inputs = json_data.get("inputs", [])
        for input in all_inputs:
            args.append(input["current_value"])
        if not args and "args" in json_data:
            args = json_data["args"]

        return cls(file_name=file_name, args=args, weight=weight)

    def to_json(self) -> dict:
        result = {
            "file_name": self.file_name,
            "args": self.args,
            "weight": self.weight,
        }
        return result


class PipelineSettings:
    def __init__(self, default_risk_score: float, averaging_method: AveragingMethod) -> None:
        self.default_risk_score = default_risk_score
        self.averaging_method = averaging_method

    @classmethod
    def from_json(cls, json_data: dict):
        default_risk_score = json_data.get("default_risk_score", 0.0)
        if type(json_data["averaging_method"]) is int:
            averaging_method = AveragingMethod(json_data["averaging_method"])
        elif type(json_data["averaging_method"]) is list:
            averaging_method = AveragingMethod(json_data["averaging_method"].index(True))
        else:
            raise ValueError("Invalid averaging method type in JSON data")
        return cls(default_risk_score=default_risk_score, averaging_method=averaging_method)

    def to_json(self) -> dict:
        return {
            "default_risk_score": self.default_risk_score,
            "averaging_method": self.averaging_method.value,
        }


class Pipeline:
    def __init__(self, name: str, modules: list[Module], settings: PipelineSettings) -> None:
        self.name = name
        self.modules = modules
        self.settings = settings
        self.logs = []
        self.results = {}
        self.time_to_compute = 0.0
        self.time_to_preprocess = 0.0

    @classmethod
    def from_json(cls, json_data: dict) -> "Pipeline":
        if not json_data:
            raise ValueError("JSON data for Pipeline cannot be empty")

        if json_data["modules"]:
            # normalize weights to sum to 1
            weight_sum = sum(module_json["weight"] for module_json in json_data["modules"])
            for module_json in json_data["modules"]:
                module_json["weight"] /= weight_sum

        modules = [Module.from_json(module_json) for module_json in json_data["modules"]]
        settings = PipelineSettings.from_json(json_data["settings"])
        return cls(name=json_data["name"], modules=modules, settings=settings)

    def to_json(self) -> dict:
        result = {
            "name": self.name,
            "modules": [mod.to_json() for mod in self.modules],
            "settings": self.settings.to_json(),
            "logs": self.logs,
            "results": self.results,
            "time_to_compute": self.time_to_compute,
            "time_to_preprocess": self.time_to_preprocess,
        }
        return result
