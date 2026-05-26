# Dataset Normalizer

- [Requirements](#requirements)
- [Usage](#usage)
- [Configuration](#configuration)
  - [General](#general)
  - [Dataset-specific](#dataset-specific)
- [Labeling](#labeling)
  - [Default (SOCBED \& APT 29)](#default-socbed--apt-29)
  - [AIT](#ait)

This tool facilitates normalizing a dataset into the format expected by CATS, as detailed in [Data Model](../../docs/dataset_model.md).
Some manual effort, specifically identifying where features are located within your alerts and how they should be labeled, is still required.
The normalization process consists of three steps:

- **Normalize**: Extract all desired information from alerts.
- **Validate**: Ensure that all required values are present and all values are in their desired format.
- **Label**: Apply labels to all alerts (optional).

## Requirements

- Python v3.9+
- Additional packages via `pip install -r requirements.txt`

## Usage

Run `python normalizer.py --help` to see available parameters:
- `--dataset`: Path to the JSONL dataset containing alerts
- `--config`: Path to the dataset-specific config file, defining where specific features can be found (more info [below](#dataset-specific))
- `--alert-source`: String informing about the origin and type of alerts in the form of `<origin>_<type>`.
  For example, for Sigma alerts stemming from the SOCBED dataset, this would be `socbed_sigma`.
- `--label-method` *(optional)*: One of [socbed, ait]. If provided, the tool tries to label the dataset using the given method.
  If none of these options fit your dataset (which is likely), you need to label it yourself (more info [below](#labeling)).

A full command could look like this:
```sh
python normalizer.py --dataset socbed_sigma.jsonl --config config/default_sigma.yml --alert-source socbed_sigma --label-method socbed

### Output:
# Starting normalization of socbed_sigma.jsonl...
# 172
# Finished normalizing alerts.

# Starting labeling of alerts...
# 172
# Finished labeling alerts.

# Creating normalized_socbed_sigma.jsonl...
# All done!
```
The normalized dataset will be saved in the same directory the command was executed from.
Note: Executing this example with the provided `socbed_sigma.jsonl` in the datasets directory will result in an error because this dataset is already labeled and normalized.
The non-labeled dataset is not provided in this repository.

As a convenience method, you can use `--reverse` to extract alerts from a previously normalized dataset and store them in a separate file.
`--config` does not need to be supplied in this case.
```sh
python normalizer.py --dataset normalized_socbed_sigma.jsonl --reverse

### Output:
# Extracting raw alerts from normalized_socbed_sigma.jsonl...
# 172
# Finished reverting normalization. Raw alerts written to raw_socbed_sigma.jsonl.
```

## Configuration

Configuration files are located in the [config](config/) directory as YAML files.
There are two types of configuration files, *general* and *dataset-specific*.

### General

General configuration can be found in [_general.yml](config/_general.yml).
It defines general attributes applied to all features during the normalization process.
It's not recommended to modify existing entries here as this might break functionality of CATS modules relying on this format.
Each feature is defined like this:
```yml
<feature_name>:
  type: <integer|string>
  mandatory: <true|false>
  is_list: <true|false>
  lowercase: <true|false>  # optional
```
- `type`: Defines the type this value should be stored as.
- `mandatory`: If set to true and an alert is missing this feature, an exception is thrown.
- `is_list`: If the value(s) should be stored in a list as opposed to a single value.
  Conversely, an exception will be thrown if this is set to false, but multiple values are found, as the tool doesn't know how it should handle this.
- `lowercase` *(optional)*: Only usable when type is string.
  The value will be converted to lowercase if set to true.

### Dataset-specific

All other files in this directory contain configuration pertaining to a specific type of dataset, i.e., where certain features can be found.
Each feature defined in the general configuration must also be defined here, in the form of either a list of entries or `null`.
```yml
<feature_name>:
  - <search_method_1>
  - <search_method_2>
  - ...
```
There are two search methods available, `key` and `set_if_conditions_met`:
- `key`: Take the directly value from a specific field, potentially using regex for further control.
  ```yml
  - key: key1.key2.key3
    regex: <string>           # optional
    regex_match_index: <int>  # optional
  ```
  - `key`: Where this value can be found in each alert, in dot-notation.
  - `regex` *(optional)*: If this field is supplied, the tool will not take the entire value of the field, but instead try to find a given substring using this regex.
  **Be careful regarding special characters**.
  Usually, the best idea is to put the entire thing in single quotes (`'`), since then you don't have to worry about escaping any characters apart from the `'` itself (which simply becomes `''`).
  You only need to use double quotes when your regex *must* contain escape sequences (`\n`, `\t`, etc), but then you'll also have to escape all special YAML characters (`\`, `[`, `]`, and so on).
  - `regex_match_index` *(optional)*: Only has an effect when a regex is supplied.
  Normally, all matches are used - if this is set, only the match at that exact index will be returned, if available.
  Useful to avoid an overly complex regex statement just to get a specific value.

- `set_if_conditions_met`: Set a completely custom value if fields contain specific values.
  Useful if the info you need cannot be simply parsed from the contents of the alert.
  ```yml
  - set_if_conditions_met:
      if:
        - key: some.key
          contains: some_string
        - key: another.key
          matches_exactly: another_string
      then_set_to: something_cool
  ```
  - `if`: List of conditions, which are ANDed.
    If you need OR, just chain multiple of these search methods.
    - `key`: Which field to check against
      - *If the field happens to contain a list of items, at least one item in the list must pass the check*.
    - `contains`: Substring that must be present in the field.
    - `matches_exactly`: Value that the field must be exactly equal to.
      - *You must use either `contains` or `matches_exactly` per condition, not both*.
  - `then_set_to`: Value to use if every single condition is fulfilled

Apart from this, note the following:
- Use `null` to mark a feature as not present, in which case the parser will skip it.
- If you supply multiple search methods, the parser will use the first one providing a non-null value, going from top to bottom.
- Putting the most likely search methods at the top will increase performance.

Example:
```yml
hostname: # will first look in "predecoder.hostname". If nothing is found, sets hostname to "intranet-server" if both conditions are fulfilled
  - key: predecoder.hostname
  - set_if_conditions_met:
      if:
        - key: full_log
          contains: https://intranet.smith.russellmitchell.com
        - key: location
          matches_exactly: /var/log/apache2/intranet-access.log
      then_set_to: intranet-server
username: null # skipped
log_level: null # skipped
source_ip: # will first look in "data.srcip". If nothing is found, searches in "full_log" using provided regex
  - key: data.srcip
  - key: full_log
    regex: 'lip=(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'
```

You will need to identify where each individual feature is located in your dataset, create a corresponding `.yml` configuration file, and then supply it to the tool using the previously mentioned `--config` flag.
The benefit of this approach is that it is immediately apparent where every feature is sourced from, just by glancing over the configuration.

## Labeling

CATS expects the field `metadata.misuse` to be present, filled with either `True/False` or `"yes"/"no"/"unknown"`.
If you have a custom dataset, the normalizer has no way of knowing how these labels should be applied, so you will have to program this step yourself.
Known labeling methods are included as options with `--label-method` and are shortly explained below.

### Default (SOCBED & APT 29)
The desired label already exists as part of the original alert in `metadata.misuse`.
Thus, they can just be read and used directly.

### AIT
Here, `event_labels` were used as opposed to `time_labels`, since they are significantly more precise.

However, there is one additional problem not mentioned on the website:
Various alerts, for some reason, share the same exact `timestamp`, which doubles as their identifier - unfortunately, in a couple of cases these alerts consist of both true _and_ false positives, like in this example:
```sh
time,name,ip,host,short,time_label,event_label
[...] # Two TPs followed by two FPs
1642996621,Wazuh: Web server 400 error code.,10.143.2.4,intranet_server,W-Acc-400,service_scans,service_scan
1642996621,Wazuh: Web server 400 error code.,10.143.2.4,intranet_server,W-Acc-400,service_scans,service_scan
1642996621,Wazuh: Web server 400 error code.,172.19.130.68,webserver,W-Acc-400,service_scans,-
1642996621,Wazuh: Web server 400 error code.,172.19.130.68,webserver,W-Acc-400,service_scans,-
```
Here, it can be difficult to determine which alert is associated with which ground truth entry.
To remedy this, the `source_ip`/`destination_ip` and `hostname` features, where available, were used to filter the ground truth beyond just using timestamps.
This fixed the issue for AMiner and Suricata, but only partially so for Wazuh:
The tool labels 7655/23116 as TPs, but the ground truth lists 7639 as TPs - a difference of 16.
However, as of right now, I don't see a way of rectifying this any more than I already did.