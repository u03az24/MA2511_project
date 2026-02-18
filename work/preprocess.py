from pathlib import Path

import EEG

SampleFreq = 1024.0
DataRootDir = Path(__file__).resolve().parents[1] / "data"
RatId = "R1"
StateNames = ["NREM", "REM", "AW"]
ChannelNames = ["BOr", "M1l", "M1r", "S1l", "S1r", "V2l", "V2r"]


def BuildPreprocessedDataset(
    sampleFreq: float = SampleFreq,
    dataRootDir: str | Path = DataRootDir,
    ratId: str = RatId,
    stateNames: list[str] = StateNames,
    channelNames: list[str] = ChannelNames,
    notchCentre: float = 51.0,
    notchWidth: float = 1.5,
    trimToShortestState: bool = True,
):
    dataDir = Path(dataRootDir) / ratId
    dataset = EEG.Dataset(sampleFreq, str(dataDir), stateNames, channelNames)
    dataset.NotchNoise(freqCentre=notchCentre, freqWidth=notchWidth)
    if trimToShortestState:
        dataset.TrimToShortestState()
    return dataset


if __name__ == "__main__":
    BuildPreprocessedDataset()
