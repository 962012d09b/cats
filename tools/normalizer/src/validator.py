from dateutil import parser
from datetime import datetime, timezone


def validate_alert(alert: dict, general_conf: dict, features: list[str]):
    for feature in features:
        verify_presence(alert, feature, general_conf)

    alert = timestamp_to_iso_utc(alert)

    return alert


def verify_presence(alert: dict, feature: str, config: dict):
    is_mandatory = config["features"][feature]["mandatory"]
    if is_mandatory and feature not in alert["features"]:
        raise Exception(f"Mandatory feature {feature} missing in alert:\n{alert}")


def timestamp_to_iso_utc(alert: dict):
    timestamp_str = alert["features"]["timestamp"]

    try:
        try:
            epoch_time = float(timestamp_str)
            is_epoch = True
        except ValueError:
            is_epoch = False

        if is_epoch:
            dt = datetime.fromtimestamp(epoch_time, tz=timezone.utc)
        else:
            dt = parser.parse(timestamp_str)

        dt_utc = dt.astimezone(timezone.utc)
        new_timestamp_str = dt_utc.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"
    except Exception as e:
        print(f"Error converting timestamp: {e}")
        return alert

    alert["features"]["timestamp"] = new_timestamp_str
    return alert
