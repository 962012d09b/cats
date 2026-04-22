from processing.data_models import AveragingMethod, Dataset

import numpy as np
from numpy.typing import NDArray
from importlib import import_module


class Module:
    def __init__(self, name: str, file_name: str, id: int, args: list, weight: float):
        self.name = name
        self.file_name = file_name
        self.id = id
        self.args = args
        self.weight = weight

    def process(self, dataset: Dataset, weight: float, averaging_method: AveragingMethod) -> tuple[Dataset, list[str]]:
        import_path = f"modules.{self.file_name.replace('.py', '')}"
        imported_module = import_module(import_path)

        processed_dataset, logs = imported_module.process(dataset, self.args, weight, averaging_method)
        return processed_dataset, logs


class SingleModuleResult:
    def __init__(self, module: Module, dataset: Dataset, logs: list[str]):
        scores: list[float] = [entry.metadata["risk_score"] for entry in dataset.data]

        self.module = module
        self.scores: NDArray[np.float64] = np.array(scores)
        self.logs = logs


class CompletedPipeline:
    def __init__(
        self,
        config: list[Module],
        results: dict,
        logs: list[list[str]],
        duration: float,
        used_weights: list[float],
        used_averaging_method: str,
    ):
        self.config = config
        self.results = results
        self.logs = logs
        self.duration = duration
        self.used_weights = used_weights
        self.used_averaging_method = used_averaging_method

    def to_json(self) -> dict:
        return {
            "pipeline": [
                {
                    "name": module.name,
                    "file_name": module.file_name,
                    "args": module.args,
                }
                for module in self.config
            ],
            "results": self.results,
            "logs": self.logs,
            "duration": self.duration,
            "used_weights": self.used_weights,
            "used_averaging_method": self.used_averaging_method,
        }
