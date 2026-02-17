from pathlib import Path

import EEG

SAMPLE_FREQ = 1024.0
DATA_DIR = Path(__file__).resolve().parents[1] / "data" / "R1"
STATE_NAMES = ["NREM", "REM", "AW"]
CHANNEL_NAMES = ["BOr", "M1l", "M1r", "S1l", "S1r", "V2l", "V2r"]

def build_preprocessed_dataset(
    sample_freq=SAMPLE_FREQ,
    data_dir=DATA_DIR,
    state_names=STATE_NAMES,
    channel_names=CHANNEL_NAMES,
    notch_centre=51.0,
    notch_width=1.5,
    trim_to_shortest=True,
):
    dataset = EEG.Dataset(sample_freq, str(data_dir), state_names, channel_names)
    dataset.NotchNoise(freqCentre=notch_centre, freqWidth=notch_width)
    if trim_to_shortest:
        dataset.TrimToShortestState()
    return dataset


if __name__ == "__main__":
    build_preprocessed_dataset()
