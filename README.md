# MA2511 Project

This repository contains:

- EEG data files in `data/` (`.mat` recordings and metadata JSON/TXT files).
- A small Python EEG utility package in `work/EEG/` that:
  - loads channel/state recordings from the dataset,
  - applies notch filtering,
  - computes Welch PSD,
  - provides band-pass filtered signals (delta, theta, alpha, beta, gamma),
  - trims recordings across states to equal length.
- A preprocessing entry script in `work/preprocess.py` that builds a notch-filtered, length-matched dataset object.
- An export script in `work/export_features.py` that writes preprocessed raw samples to `output/preprocessed_raw_long.parquet`.
- A load script in `work/load_data.R` that reads the Parquet export into R.
- A main R script in `work/ma2511_main.R` that computes window features in memory.
- Python dependencies listed in `work/requirements.py`.
- R dependencies listed in `work/requirements.R`.
