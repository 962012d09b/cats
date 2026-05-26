# Batch Processor

- [Installation](#installation)
- [Usage](#usage)
  - [Configuration](#configuration)
    - [`defaults`](#defaults)
    - [`datasets`](#datasets)
    - [`modules`](#modules)
  - [Running a batch process](#running-a-batch-process)
  - [Cancelling a running batch process](#cancelling-a-running-batch-process)


This tool enables quick computation all possible configurations of a CATS pipeline given a set of modules to use.



## Installation
`cats_backend` must be installed in the same virtual environment.
Simply install `batch_processor` via 
```
pip install -r requirements.txt
pip install -e .
```

## Usage
`batch_processor` works from any directory.
Run `batch_processor -h` to see all available options.
```
~$ batch_processor --help
usage: batch_processor [-h] [--cores CORES] [--config CONFIG] [--generate-full-config]

CATS Batch Processor. Either --config or --generate-full-config must be specified.

options:
  -h, --help            show this help message and exit
  --cores CORES         Number of CPU cores to use, 0 for all (default)
  --config CONFIG       Path to config YAML file
  --generate-full-config
                        Generate full example configuration from current CATS database, does not run any pipelines
```

### Configuration
Start by generating the default configuration with `batch_processor --generate-full-config`.
This will fetch all datasets and modules currently registered in your local CATS instance and create a `example_full_config.yaml` in your current directory.
Modify this config file how you see fit, the following sections will explain each field in detail.

#### `defaults`
Defines certain behaviors and default values.
If you are unsure, just stick to the defaults.
All entries are mandatory.
```yml
defaults:
  risk_score: 0.5
  save_results: True
  generate_cats_import: True
  save_used_config: True
  optimize_weights: True
  weight_resolution: 0.2
  averaging_method: "both"
  combine_modules: True
```

- `risk_score` | $x \in (0,1]$<br>
  Default risk score to assign to all alerts at the beginning of a pipeline that are not covered by the first module.
- `save_results` | *true/false*<br>
  If *true*, saves the details and results of every single pipeline in one `.jsonl` file after processing has finished.
- `generate_cats_import` | *true/false*<br>
  If *true*, saves a `.json` file that can be used to import the best-performing pipeline into the CATS frontend.
- `save_used_config` | *true/false*<br>
  If *true*, saves the config used for this particular run as a separate file.
- `optimize_weights` | *true/false*<br>
  If *true*, fully optimizes weights for every configuration.
- `weight_resolution` | $x \in (0,0.2]$ with $1 \bmod x = 0$<br>
  How fine-grained the weight optimization will be.
- `averaging_method` | $x \in \{arithmetic, geometric, both\}$<br>
  Determines which method is used to average scores across modules.
  Option `both` always picks the best method, but effectively doubles the workload.
- `combine_modules` | *true/false*<br>
  If *true*, modules will be combined into a pipeline and evaluated together.
  If *false*, every module will be evaluated on its own and weights will be ignored.
  This is effectively the same as running the batch processor separately for every module, creating a distinct results file for each one.


#### `datasets`
List of datasets (located in the root `datasets/` directory) to use for this process.
At least one must be specified.
The batch processor will run separately for each dataset listed here.
```yml
datasets:
- socbed_sigma.jsonl
- socbed_suricata.jsonl
```

#### `modules`
List of modules to use in each pipeline.
The `batch_processor` will execute every single possible combination of arguments as an individual pipeline.
At least one module must be specified
```yml
modules:
- name: Rule Level
  file_name: level_score.py
  id: 1
  weight: 0.3
  parameters: null
- name: Accumulation
  file_name: accumulated_risk.py
  id: 2
  weight: 0.7
  parameters:
  - - Hostname
    - Source IP
    - Destination IP
    - Alert Type
    - Username
  - - Box
    - Triangle
  - - One hour
    - One day
    - One week
    - One month
    - One year
  - - Past
    - Past + Future
```
All of this will be set automatically with `--generate-full-config`.
- `name` | *str*<br>
  Only used for visual purposes.
- `file_name.py` | *str*<br>
  The Python file in `backend/modules/` the `process()` function for this module will be sourced from.
- `id` | *int*<br>
  The internal ID of this module in CATS (specifically, the ID of the module in the SQLite database), necessary to create the import string.
- `parameters` | *List[ List[str | int | bool] ]*<br>
  List of possible parameters ("inputs") your module accepts.
  Each entry again contains a list that defines the possible values for each input.
  Typically, this will just cover all possible values (e.g., for a dropdown menu).
  For other input types like sliders, whose ranges are continuous, you need to set the values individually.
- `weight` | $x \in [0,1]$ with all module weights together summing up to $1$<br>
  The factor calculated by this module will be multiplied with this weight before averaging. You may use numbers that do not sum up to $1$, in which case they will be normalized to fit that range (e.g., $(1, 1, 2)$ will become $(\frac{1}{4}, \frac{1}{4}, \frac{1}{2})$).

For example, if you were to have a single module with two inputs 
```yml
modules:
- name: Test
  file_name: test.py
  id: 1
  weight: 1
  parameters:
  - - A
    - B
  - - 1
    - 2
    - 3
```
the `batch_processor` would run 6 pipelines in total.
Each pipeline would only contain this module, and one pipeline runs for each possible input combination ([A, 1], [A, 2], [A, 3], [B, 1], [B, 2], and [B, 3]).

### Running a batch process
Start a batch process from a given config file via
```
batch_processor --config your_config.yaml
```
You can also specify the number of cores to be used with `--cores <num of cores>`, the default is to use all available cores.
Depending on the size of your dataset and the complexity of your parameter space, this operation could now finish anytime between "a couple of seconds" and "the heat death of the universe".
After successful completion, three files will be created (or fewer, if toggled off):
- `cats_results_<current_timestamp>.jsonl`<br>
  Contains configuration and results for every pipeline, one per line.
- `cats_import_<current_timestamp>.json`<br>
  Contains an import string that can be used with the CATS frontend to directly visualize the best result.
- `cats_config_<current_timestamp>.yaml`<br>
  Contains a copy of the config YAML file used for this run.
  Comments will not be copied.


### Cancelling a running batch process
When pressing `CTRL+C`, the program will wait until all currently running pipelines have finished, and then produce the same three output files.
```
[...]
Received interrupt, waiting for running pipelines to complete... (CTRL+C again to exit non-gracefully)
Processing... ━━━━━━╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  16% 0:00:05 0:00:28
Stopped batch process early. Finishing up...
[...]
```
Note that the above message may take a short while to appear, as the parent process only checks for interrupts between every completed pipeline.
