from pathlib import Path

import EEG

SampleFreq = 1024.0
DataDir = Path(__file__).resolve().parents[1] / "data" / "R1"
StateNames = ["NREM", "REM", "AW"]
ChannelNames = ["BOr", "M1l", "M1r", "S1l", "S1r", "V2l", "V2r"]


def BuildPreprocessedDataset(
    sampleFreq: float = SampleFreq,
    dataDir: str | Path = DataDir,
    stateNames: list[str] = StateNames,
    channelNames: list[str] = ChannelNames,
    notchCentre: float = 51.0,
    notchWidth: float = 1.5,
    trimToShortestState: bool = True,
):
    dataset = EEG.Dataset(sampleFreq, str(dataDir), stateNames, channelNames)
    dataset.NotchNoise(freqCentre=notchCentre, freqWidth=notchWidth)
    if trimToShortestState:
        dataset.TrimToShortestState()
    return dataset


if __name__ == "__main__":
    BuildPreprocessedDataset()
