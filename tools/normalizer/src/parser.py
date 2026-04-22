import random
import re
import uuid


def parse_alert(
    original_alert: dict,
    specific_conf: dict,
    general_conf: dict,
    source: str,
    index: int,
    features: list[str],
) -> dict:
    normalized_alert = {
        "full_alert": original_alert,
        "features": {},
        "metadata": {},
    }

    for feature in features:
        datatype_config = general_conf["features"][feature]

        feature_configs = specific_conf[feature]
        if not feature_configs:
            # no configuration for this feature, skip
            continue

        value = None

        for feature_config in feature_configs:
            # iterate over all configured locations, take first hit
            value = get_value(feature_config, feature, original_alert)
            if value:
                break

        if value:
            # Don't enter empty values to avoid unnecessary bloat
            value = enforce_type(value, datatype_config, feature)
            normalized_alert["features"][feature] = value

    rd = random.Random()
    rd.seed(source + str(index))

    normalized_alert["metadata"]["alert_source"] = source
    normalized_alert["metadata"]["alert_id"] = str(uuid.UUID(int=rd.getrandbits(128), version=4))
    normalized_alert["metadata"]["alert_index"] = index

    return normalized_alert


def get_value(feature_config: dict, feature: str, original_alert: dict):
    if "set_if_conditions_met" in feature_config:
        conditions_config: dict = feature_config["set_if_conditions_met"]
        value = set_value_if_met(conditions_config, original_alert)

    elif "key" in feature_config:
        field_key = feature_config["key"]
        regex = feature_config.get("regex", None)
        regex_match_index = feature_config.get("regex_match_index", -1)

        if regex:
            value = parse_value_with_regex(field_key, original_alert, regex, regex_match_index)
        elif type(field_key) is list:
            value = get_multiple_values_directly(field_key, original_alert)
        else:
            value = get_value_directly(field_key, original_alert)

    else:
        raise ValueError(f"No valid key or conditions found for feature {feature} in alert {original_alert}")

    if type(value) is list and len(value) == 1:
        return value[0]
    else:
        return value


def get_value_directly(field: str, alert: dict):
    keys = field.split(".")
    cur_field = alert

    try:
        for key in keys:
            cur_field = cur_field[key]
    except KeyError:
        return None

    return cur_field


def get_multiple_values_directly(fields: list[str], alert: dict):
    values = []
    for field in fields:
        new_value = get_value_directly(field, alert)
        if type(new_value) is list:
            values.extend(new_value)
        else:
            values.append(new_value)
    values = [val for val in values if val is not None]
    return values


def parse_value_with_regex(field: str, alert: dict, regex: str, regex_match_index: int):
    value = get_value_directly(field, alert)

    if value is None:
        return None
    elif type(value) is list:
        results = parse_multiple_values(value, regex)
    elif type(value) is str:
        results = parse_single_value(value, regex)
    else:
        raise ValueError(f"Field {field} returned non-string values {value} for alert {alert}")

    if results is not None and len(results) > 1:
        seen = {}
        results = [seen.setdefault(result, result) for result in results if result not in seen]
    else:
        results = results

    if regex_match_index >= 0 and results is not None:
        if len(results) > regex_match_index:
            return results[regex_match_index]
        else:
            return None
    else:
        return results


def parse_single_value(value_to_parse: str, regex: str):
    matches = re.findall(regex, value_to_parse)
    if matches:
        return matches
    else:
        return None


def parse_multiple_values(values_to_parse: list[str], regex: str):
    results = []
    for value in values_to_parse:
        parsed_value = parse_single_value(value, regex)
        if parsed_value:
            results.extend(parsed_value)

    return results


def set_value_if_met(conditions_config: dict, alert: dict):
    value_if_all_conditions_match = conditions_config["then_set_to"]
    individual_conditions = conditions_config["if"]

    # all conditions are ANDed
    for condition in individual_conditions:
        field = condition["key"]
        if not ("contains" in condition or "matches_exactly" in condition):
            raise ValueError(f"Condition {condition} does not contain 'contains' or 'matches_exactly'")
        if "contains" in condition and "matches_exactly" in condition:
            raise ValueError(f"Condition {condition} contains both 'contains' and 'matches_exactly'")

        expected_value = condition["contains"] if "contains" in condition else condition["matches_exactly"]
        expected_value = str(expected_value)

        actual_value = get_value_directly(field, alert)

        if "matches_exactly" in condition:
            if type(actual_value) is list:
                if not any(expected_value == str(val) for val in actual_value):
                    return None
            else:
                if expected_value != str(actual_value):
                    return None
        else:
            if type(actual_value) is list:
                if not any(expected_value in str(val) for val in actual_value):
                    return None
            else:
                if expected_value not in str(actual_value):
                    return None

    return value_if_all_conditions_match


def enforce_type(value, dataype_conf: dict, feature: str):
    desired_type = dataype_conf["type"]
    as_list = dataype_conf["as_list"]
    lowercase = dataype_conf.get("lowercase", False)

    if type(value) is list:
        if not as_list:
            print(f'WARNING: {value} contains multiple values, but feature "{feature}" does not allow this!')
        value = [convert_value(val, desired_type, type(value)) for val in value]
    else:
        value = convert_value(value, desired_type, type(value))

    if lowercase:
        if type(value) is list:
            value = [str(val).lower() for val in value]
        else:
            value = str(value).lower()

    if as_list and type(value) is not list:
        return [value]
    else:
        return value


def convert_value(value, desired_type, actual_type):
    if desired_type == "string" and actual_type is not str:
        return str(value)
    elif desired_type == "integer" and actual_type is not int:
        return int(value)
    else:
        return value
