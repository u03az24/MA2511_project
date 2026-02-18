# MA2511 Project

This repository contains:

- EEG data files in `data/` (`.mat` recordings and metadata JSON/TXT files).
- A small Python EEG utility package in `work/EEG/` that:
  - loads channel/state recordings from the dataset,
  - applies notch filtering,
  - trims recordings across states to equal length.
- `work/preprocess.py` builds the preprocessed dataset object for a selected rat dataset.
- `work/export_features.py` exports preprocessed raw samples to rat-specific parquet files, for example:
  - `output/preprocessed_raw_long_R1.parquet`
  - `output/preprocessed_raw_long_R3.parquet`
- `work/load_data.R` loads the Parquet export into R.
- `work/ma2511_main.R` computes window features in memory, prepares long/wide feature tables, and runs least-squares evaluations for:
  - within-subject (R1 and R3),
  - cross-subject (R1 -> R3 and R3 -> R1),
  - stratified holdout within R3.
- `work/ma2511_main.R` includes optional figure saving (`saveFigures <- TRUE`) to `output/figures/`.
- `output/figures/*.png` is tracked for report-ready visuals; parquet exports in `output/` remain ignored.
- Python dependencies listed in `work/requirements.py`.
- R dependencies listed in `work/requirements.R`.
