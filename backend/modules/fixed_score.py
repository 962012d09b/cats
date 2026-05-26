from modules.src.correlation_utility import assign_new_scores
from processing.data_models import AveragingMethod, Dataset


def process(
    dataset: Dataset, args: list, weight: float, averaging_method: AveragingMethod
) -> tuple[Dataset, list[str]]:
    logs: list[str] = []
    new_scores: dict[str, float] = {}

    try:
        if type(args[0]) not in [int, float]:
            raise ValueError(f"Expected a number as first input, got {args[0]}")
        fixed_risk_score = args[0]
        for entry in dataset.data:
            new_scores[entry.metadata["alert_id"]] = fixed_risk_score

        assign_new_scores(dataset, new_scores, averaging_method, weight, logs)

    except Exception as err:
        lineno = err.__traceback__.tb_lineno if err.__traceback__ is not None else "unknown"
        logs.append(f"{repr(err)} in line {lineno}")
        return dataset, logs

    return dataset, []
