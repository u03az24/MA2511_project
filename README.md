# MA2511 Project

This repository contains:

- EEG data files in `data/` (`.mat` recordings and metadata JSON/TXT files).
- A small Python EEG utility package in `work/EEG/` that:
  - loads channel/state recordings from the dataset,
  - applies notch filtering,
  - trims recordings across states to equal length.
- `work/preprocess.py` builds the preprocessed dataset object.
- `work/export_features.py` exports preprocessed raw samples to `output/preprocessed_raw_long.parquet`.
- `work/load_data.R` loads the Parquet export into R.
- `work/ma2511_main.R` computes window features in memory and prepares long/wide feature tables.
- Python dependencies listed in `work/requirements.py`.
- R dependencies listed in `work/requirements.R`.
