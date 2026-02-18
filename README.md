# MA2511 Project

## What this project does

This project uses rat intracranial EEG data to build window-level features and evaluate least-squares state classification.

Main evaluation in `work/ma2511_main.R` includes:
- within-subject (R1 and R3),
- cross-subject (R1 -> R3 and R3 -> R1),
- stratified holdout within R3.

## Run order (start to finish)

1. Install dependencies

```bash
pip install -r work/requirements.py
Rscript work/requirements.R
```

2. Export preprocessed parquet files from Python

```bash
python work/export_features.py R1 R3
```

This creates:
- `output/preprocessed_raw_long_R1.parquet`
- `output/preprocessed_raw_long_R3.parquet`

3. Run the main R analysis

```bash
Rscript work/ma2511_main.R
```

## Figures

- Set `saveFigures <- TRUE` in `work/ma2511_main.R` to save report figures.
- Saved files go to `output/figures/`.
- `output/figures/*.png` is tracked in git.
- Parquet exports in `output/` remain ignored.

## Key files

- `work/preprocess.py`: preprocessing entry point used by exporter.
- `work/export_features.py`: rat-specific preprocessing + parquet export.
- `work/ma2511_main.R`: main analysis script.
