from pathlib import Path
import sys

import pyarrow as pa
import pyarrow.parquet as pq

from preprocess import BuildPreprocessedDataset, SampleFreq, StateNames, ChannelNames, RatId, DataRootDir

WindowSeconds = 10.0
OutputDir = Path(__file__).resolve().parents[1] / "output"
NotchSettingsByRat = {
    "R1": (51.0, 1.5),
    "R3": (50.0, 1.0),
}


def BuildOutputParquetPath(ratId: str) -> Path:
    return OutputDir / f"preprocessed_raw_long_{ratId}.parquet"


def ListRatIds(dataRootDir: str | Path = DataRootDir) -> list[str]:
    dataRootDir = Path(dataRootDir)
    return sorted([path.name for path in dataRootDir.iterdir() if path.is_dir() and path.name.startswith("R")])


def ExportFeatures(
    ratId: str = RatId,
    outputParquet: str | Path | None = None,
    windowSeconds: float = WindowSeconds
) -> None:
    notchCentre, notchWidth = NotchSettingsByRat.get(ratId, (51.0, 1.5))
    dataset = BuildPreprocessedDataset(
        ratId=ratId,
        notchCentre=notchCentre,
        notchWidth=notchWidth
    )
    if outputParquet is None:
        outputParquet = BuildOutputParquetPath(ratId)
    outputParquet = Path(outputParquet)
    outputParquet.parent.mkdir(parents=True, exist_ok=True)
    nSamplesPerWindow = int(windowSeconds * SampleFreq)

    nSamples = len(dataset[StateNames[0]][ChannelNames[0]].data)
    nEpochs = nSamples // nSamplesPerWindow

    schema = pa.schema(
        [
            ("state", pa.string()),
            ("epoch", pa.int32()),
            ("channel", pa.string()),
            ("sample_index", pa.int32()),
            ("value", pa.float64()),
        ]
    )

    sampleIndices = list(range(nSamplesPerWindow))

    with pq.ParquetWriter(outputParquet, schema=schema, compression="snappy") as writer:
        for stateName in StateNames:
            for epoch in range(nEpochs):
                start = epoch * nSamplesPerWindow
                stop = start + nSamplesPerWindow

                for channelName in ChannelNames:
                    segment = dataset[stateName][channelName].data[start:stop]
                    table = pa.table(
                        {
                            "state": [stateName] * nSamplesPerWindow,
                            "epoch": [epoch] * nSamplesPerWindow,
                            "channel": [channelName] * nSamplesPerWindow,
                            "sample_index": sampleIndices,
                            "value": segment,
                        },
                        schema=schema,
                    )
                    writer.write_table(table)


if __name__ == "__main__":
    ratIds = sys.argv[1:]
    if not ratIds:
        ratIds = ListRatIds()
    for ratId in ratIds:
        ExportFeatures(ratId=ratId)
