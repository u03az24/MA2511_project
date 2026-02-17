# 1. Project Information

# Student name:
# Student ID:
# Project title:

# 2. Load Packages

library(arrow)

# 3. Load Data

inputPath <- file.path("output", "preprocessed_raw_long.parquet")

rawLong <- read_parquet(inputPath)
rawLong <- as.data.frame(rawLong)

# 4. Data Cleaning and Preprocessing

windowFeaturesLong <- aggregate(
  value ~ state + epoch + channel,
  data = rawLong,
  FUN = function(x) c(
    mean = mean(x),
    sd = sd(x),
    var = var(x),
    rms = sqrt(mean(x^2))
  )
)

windowFeaturesLong <- cbind(
  windowFeaturesLong[c("state", "epoch", "channel")],
  as.data.frame(windowFeaturesLong$value)
)

print(head(windowFeaturesLong, 12))
print(dim(windowFeaturesLong))
