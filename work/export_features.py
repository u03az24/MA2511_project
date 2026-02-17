from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq

from preprocess import BuildPreprocessedDataset, SampleFreq, StateNames, ChannelNames

WindowSeconds = 10.0
OutputParquet = Path(__file__).resolve().parents[1] / "output" / "preprocessed_raw_long.parquet"


def ExportFeatures(outputParquet: str | Path = OutputParquet, windowSeconds: float = WindowSeconds) -> None:
    dataset = BuildPreprocessedDataset()
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
    ExportFeatures()
