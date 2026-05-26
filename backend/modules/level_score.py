from modules.src.correlation_utility import assign_new_scores
from processing.data_models import AveragingMethod, Dataset, DatasetEntry


DEFAULT_SCORE = 0.5


def process(
    dataset: Dataset, args: list, weight: float, averaging_method: AveragingMethod
) -> tuple[Dataset, list[str]]:
    logs = []
    skip_counter = {}
    new_scores = {}

    try:
        for event in dataset.data:
            try:
                new_risk_score = get_risk_score_for(event)
                new_scores[event.metadata["alert_id"]] = new_risk_score
            except KeyError as err:
                key = f"{event.metadata['alert_source']} | {repr(err)}"
                skip_counter[key] = skip_counter.get(key, 0) + 1
                new_scores[event.metadata["alert_id"]] = DEFAULT_SCORE

        assign_new_scores(dataset, new_scores, averaging_method, weight, logs)

        if skip_counter:
            logs.append(
                f"Skipped {sum(skip_counter.values())} unsupported events (assigned fixed score of {DEFAULT_SCORE}): {skip_counter}"
            )

    except Exception as err:
        lineno = err.__traceback__.tb_lineno if err.__traceback__ is not None else "unknown"
        logs.append(f"{repr(err)} in line {lineno}")
        return dataset, logs

    return dataset, logs


def get_risk_score_for(evt: DatasetEntry):
    rule_level: str = evt.features["rule_level"]
    source = evt.metadata["alert_source"]

    if "sigma" in source:
        return {
            "critical": 1.0,
            "high": 0.75,
            "medium": 0.5,
            "low": 0.25,
            "informational": 0.0,
        }[rule_level]

    elif "suricata" in source:
        if int(rule_level) > 3 and int(rule_level) < 256:
            rule_level = "3"
        return {
            "1": 0.75,
            "2": 0.5,
            "3": 0.25,
        }[rule_level]

    elif "wazuh" in source:
        # https://documentation.wazuh.com/current/user-manual/ruleset/rules/rules-classification.html
        # ranges from 0 to 15
        if int(rule_level) == 0:
            return 0.0
        else:
            return 1.0 / 15 * int(rule_level)

    elif "falco" in source:
        # https://falco.org/docs/concepts/rules/basic-elements/#priority
        return {
            "emergency": 1.0,
            "alert": 6 / 7,
            "critial": 5 / 7,
            "error": 4 / 7,
            "warning": 3 / 7,
            "notice": 2 / 7,
            "informational": 1 / 7,
            "debug": 0.0,
        }[rule_level]

    else:
        raise ValueError(f"Unsupported alert source: {source}")
