# 1. Project Information

# Student name:
# Student ID:
# Project title:

# 2. Load Packages

library(arrow)

# 3. Load Data

BuildInputPath <- function(ratId) {
  file.path("output", paste0("preprocessed_raw_long_", ratId, ".parquet"))
}

LoadRawLong <- function(ratId) {
  inputPath <- BuildInputPath(ratId)
  rawLong <- read_parquet(inputPath)
  as.data.frame(rawLong)
}

# 4. Data Cleaning and Preprocessing

BuildWindowFeaturesLong <- function(rawLong) {
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
  cbind(
    windowFeaturesLong[c("state", "epoch", "channel")],
    as.data.frame(windowFeaturesLong$value)
  )
}

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

BuildWindowFeaturesWide <- function(rawLong) {
  windowFeaturesLong <- BuildWindowFeaturesLong(rawLong)
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
  windowFeaturesWide
}

rawLongR1 <- LoadRawLong("R1")
rawLongR3 <- LoadRawLong("R3")

windowFeaturesWideR1 <- BuildWindowFeaturesWide(rawLongR1)
windowFeaturesWideR3 <- BuildWindowFeaturesWide(rawLongR3)

print(dim(windowFeaturesWideR1))
print(dim(windowFeaturesWideR3))

stateLabelsTrain <- windowFeaturesWideR1$state
featureCols <- setdiff(names(windowFeaturesWideR1), c("state", "epoch"))
XTrainRaw <- as.matrix(windowFeaturesWideR1[, featureCols])
XMean <- colMeans(XTrainRaw)
XSD <- apply(XTrainRaw, 2, sd)
XTrain <- sweep(XTrainRaw, 2, XMean, "-")
XTrain <- sweep(XTrain, 2, XSD, "/")

# 6. Linear Algebra Methods

ATrain <- cbind(1, XTrain)
yAW <- as.numeric(stateLabelsTrain == "AW")
yNREM <- as.numeric(stateLabelsTrain == "NREM")
yREM <- as.numeric(stateLabelsTrain == "REM")

weightsAW <- qr.solve(ATrain, yAW)
weightsNREM <- qr.solve(ATrain, yNREM)
weightsREM <- qr.solve(ATrain, yREM)

scoreAW <- as.vector(ATrain %*% weightsAW)
scoreNREM <- as.vector(ATrain %*% weightsNREM)
scoreREM <- as.vector(ATrain %*% weightsREM)

scoreMatrix <- cbind(AW = scoreAW, NREM = scoreNREM, REM = scoreREM)
predictedState <- colnames(scoreMatrix)[max.col(scoreMatrix, ties.method = "first")]

confusionTrain <- table(actual = stateLabelsTrain, predicted = predictedState)
accuracyTrain <- mean(predictedState == stateLabelsTrain)

print(confusionTrain)
print(accuracyTrain)

stateLabelsTest <- windowFeaturesWideR3$state
XTestRaw <- as.matrix(windowFeaturesWideR3[, featureCols])
XTest <- sweep(XTestRaw, 2, XMean, "-")
XTest <- sweep(XTest, 2, XSD, "/")

ATest <- cbind(1, XTest)
scoreAWTest <- as.vector(ATest %*% weightsAW)
scoreNREMTest <- as.vector(ATest %*% weightsNREM)
scoreREMTest <- as.vector(ATest %*% weightsREM)

scoreMatrixTest <- cbind(AW = scoreAWTest, NREM = scoreNREMTest, REM = scoreREMTest)
predictedStateTest <- colnames(scoreMatrixTest)[max.col(scoreMatrixTest, ties.method = "first")]

confusionTest <- table(actual = stateLabelsTest, predicted = predictedStateTest)
accuracyTest <- mean(predictedStateTest == stateLabelsTest)

print(confusionTest)
print(accuracyTest)
