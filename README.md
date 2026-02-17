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
- Python dependencies listed in `work/requirements.txt`.
