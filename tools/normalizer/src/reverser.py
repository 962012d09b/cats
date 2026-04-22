from pathlib import Path
import jsonlines


def revert_normalization(normalized_dataset_path: Path) -> None:
    output_path = f"raw_{normalized_dataset_path.name.removeprefix('normalized_')}"
    print(f"Extracting raw alerts from {normalized_dataset_path}...")

    with jsonlines.open(normalized_dataset_path) as normalized_alerts:
        with jsonlines.open(output_path, mode="w") as writer:
            for index, normalized_alert in enumerate(normalized_alerts):
                print(f"\r{index}", end="")
                if not "full_alert" in normalized_alert:
                    raise ValueError("Alert does not contain 'full_alert' field. Cannot revert normalization.")

                raw_alert = normalized_alert["full_alert"]
                writer.write(raw_alert)

    print(f"\nFinished reverting normalization. Raw alerts written to {output_path}.\n")
