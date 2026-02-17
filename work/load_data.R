library(arrow)

parquetPath <- file.path("output", "preprocessed_raw_long.parquet")
if (!file.exists(parquetPath)) {
  parquetPath <- file.path("..", "output", "preprocessed_raw_long.parquet")
}

rawLong <- read_parquet(parquetPath)
rawLong <- as.data.frame(rawLong)

rawLongPreview <- rawLong[rawLong$sample_index < 5, ]
print(head(rawLongPreview, 20))
print(dim(rawLong))
