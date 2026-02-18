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

MakeWideByFeature <- function(data, featureName) {
  longFeature <- data[c("state", "epoch", "channel", featureName)]
  wideFeature <- reshape(
    longFeature,
    idvar = c("state", "epoch"),
    timevar = "channel",
    direction = "wide"
  )
  featureCols <- names(wideFeature)
  channelCols <- featureCols[!(featureCols %in% c("state", "epoch"))]
  names(wideFeature)[names(wideFeature) %in% channelCols] <- paste0(
    sub(paste0("^", featureName, "\\."), "", channelCols),
    "_",
    featureName
  )
  wideFeature
}

meanWide <- MakeWideByFeature(windowFeaturesLong, "mean")
sdWide <- MakeWideByFeature(windowFeaturesLong, "sd")
varWide <- MakeWideByFeature(windowFeaturesLong, "var")
rmsWide <- MakeWideByFeature(windowFeaturesLong, "rms")

windowFeaturesWide <- Reduce(
  function(left, right) merge(left, right, by = c("state", "epoch")),
  list(meanWide, sdWide, varWide, rmsWide)
)

windowFeaturesWide <- windowFeaturesWide[order(windowFeaturesWide$state, windowFeaturesWide$epoch), ]
rownames(windowFeaturesWide) <- NULL

print(dim(windowFeaturesWide))

stateLabels <- windowFeaturesWide$state
featureCols <- setdiff(names(windowFeaturesWide), c("state", "epoch"))
X <- as.matrix(windowFeaturesWide[, featureCols])
X <- scale(X, center = TRUE, scale = TRUE)

# 6. Linear Algebra Methods

A <- cbind(1, X)
yAW <- as.numeric(stateLabels == "AW")
yNREM <- as.numeric(stateLabels == "NREM")
yREM <- as.numeric(stateLabels == "REM")

weightsAW <- qr.solve(A, yAW)
weightsNREM <- qr.solve(A, yNREM)
weightsREM <- qr.solve(A, yREM)

scoreAW <- as.vector(A %*% weightsAW)
scoreNREM <- as.vector(A %*% weightsNREM)
scoreREM <- as.vector(A %*% weightsREM)

scoreMatrix <- cbind(AW = scoreAW, NREM = scoreNREM, REM = scoreREM)
predictedState <- colnames(scoreMatrix)[max.col(scoreMatrix, ties.method = "first")]

confusion <- table(actual = stateLabels, predicted = predictedState)
accuracy <- mean(predictedState == stateLabels)

print(confusion)
print(accuracy)
