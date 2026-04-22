from modules.src.correlation_utility import assign_new_scores
from processing.data_models import AveragingMethod, Dataset

# from your_library import your_fancy_function


# Your module should ALWAYS exit gracefully, even if it fails
# While critical failure will still be handled by flask,
# it prevents the frontend from reading out the error logs properly
# In case of an error, just pass on the original dataset contents and return the error logs like shown below


def process(
    dataset: Dataset, args: list, weight: float, averaging_method: AveragingMethod
) -> tuple[Dataset, list[str]]:
    logs: list[str] = []
    new_scores: dict[str, float] = {}

    try:
        ## do stuff with data and arguments
        for entry in dataset.data:
            full_alert = entry.full_alert
            metadata = entry.metadata
            features = entry.features

            ## new scores should ALWAYS be written like this...
            # new_scores[metadata["alert_id"]] = your_fancy_function(full_alert, args)

        ## ... and then assigned to the dataset via the utility function at the end of the module
        assign_new_scores(dataset, new_scores, averaging_method, weight, logs)

    except Exception as err:
        lineno = err.__traceback__.tb_lineno if err.__traceback__ is not None else "unknown"
        logs.append(f"{repr(err)} in line {lineno}")
        return dataset, logs
    return dataset, logs
