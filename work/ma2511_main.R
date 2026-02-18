# 1. Project Information

# Student name:
# Student ID:
# Project title:

saveFigures <- TRUE
figuresDir <- file.path("output", "figures")

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

# 5. Exploratory Plots

representativeFeature <- "BOr_sd"
DrawExploratoryBoxplots <- function() {
  par(mfrow = c(1, 2))
  boxplot(
    windowFeaturesWideR1[[representativeFeature]] ~ windowFeaturesWideR1$state,
    xlab = "State",
    ylab = representativeFeature,
    main = "R1: BOr_sd by State"
  )
  boxplot(
    windowFeaturesWideR3[[representativeFeature]] ~ windowFeaturesWideR3$state,
    xlab = "State",
    ylab = representativeFeature,
    main = "R3: BOr_sd by State"
  )
  par(mfrow = c(1, 1))
}

DrawExploratoryBoxplots()

representativeCols <- c("BOr_sd", "M1l_sd", "V2r_rms")
representativeTableR1 <- aggregate(
  windowFeaturesWideR1[, representativeCols],
  by = list(state = windowFeaturesWideR1$state),
  FUN = mean
)
representativeTableR3 <- aggregate(
  windowFeaturesWideR3[, representativeCols],
  by = list(state = windowFeaturesWideR3$state),
  FUN = mean
)

print("Representative feature table (R1 means by state):")
print(representativeTableR1)
print("Representative feature table (R3 means by state):")
print(representativeTableR3)

DrawTablePlot <- function(tableDf, titleText) {
  tableLines <- capture.output(print(tableDf, row.names = FALSE))
  nLines <- length(tableLines)
  par(mar = c(1, 1, 3, 1))
  plot.new()
  title(main = titleText, line = 1)
  yTop <- 0.9
  yBottom <- 0.35
  yPos <- seq(yTop, yBottom, length.out = nLines)
  text(0.05, yPos, labels = tableLines, adj = c(0, 1), family = "mono", cex = 1.2)
}

exploratoryObjects <- list(
  representativeTableR1 = representativeTableR1,
  representativeTableR3 = representativeTableR3,
  DrawExploratoryBoxplots = DrawExploratoryBoxplots,
  DrawRepresentativeTableR1 = function() DrawTablePlot(representativeTableR1, "Representative Feature Table (R1 means by state)"),
  DrawRepresentativeTableR3 = function() DrawTablePlot(representativeTableR3, "Representative Feature Table (R3 means by state)")
)

featureCols <- setdiff(names(windowFeaturesWideR1), c("state", "epoch"))

# 6. Linear Algebra Methods

FitLeastSquares <- function(trainWide, featureCols) {
  stateLabelsTrain <- trainWide$state
  XTrainRaw <- as.matrix(trainWide[, featureCols])
  XMean <- colMeans(XTrainRaw)
  XSD <- apply(XTrainRaw, 2, sd)
  XSD[XSD == 0] <- 1.0
  XTrain <- sweep(XTrainRaw, 2, XMean, "-")
  XTrain <- sweep(XTrain, 2, XSD, "/")
  ATrain <- cbind(1, XTrain)
  yAW <- as.numeric(stateLabelsTrain == "AW")
  yNREM <- as.numeric(stateLabelsTrain == "NREM")
  yREM <- as.numeric(stateLabelsTrain == "REM")
  weightsAW <- qr.solve(ATrain, yAW)
  weightsNREM <- qr.solve(ATrain, yNREM)
  weightsREM <- qr.solve(ATrain, yREM)
  list(
    XMean = XMean,
    XSD = XSD,
    weightsAW = weightsAW,
    weightsNREM = weightsNREM,
    weightsREM = weightsREM
  )
}

PredictLeastSquares <- function(model, testWide, featureCols) {
  stateLabelsTest <- testWide$state
  XTestRaw <- as.matrix(testWide[, featureCols])
  XTest <- sweep(XTestRaw, 2, model$XMean, "-")
  XTest <- sweep(XTest, 2, model$XSD, "/")
  ATest <- cbind(1, XTest)
  scoreAWTest <- as.vector(ATest %*% model$weightsAW)
  scoreNREMTest <- as.vector(ATest %*% model$weightsNREM)
  scoreREMTest <- as.vector(ATest %*% model$weightsREM)
  scoreMatrixTest <- cbind(AW = scoreAWTest, NREM = scoreNREMTest, REM = scoreREMTest)
  predictedStateTest <- colnames(scoreMatrixTest)[max.col(scoreMatrixTest, ties.method = "first")]
  confusionTest <- table(actual = stateLabelsTest, predicted = predictedStateTest)
  accuracyTest <- mean(predictedStateTest == stateLabelsTest)
  list(confusion = confusionTest, accuracy = accuracyTest)
}

StratifiedSplit <- function(wide, trainFraction = 0.7, seed = 2511) {
  set.seed(seed)
  states <- unique(wide$state)
  trainIdx <- c()
  for (stateName in states) {
    idx <- which(wide$state == stateName)
    nTrain <- floor(length(idx) * trainFraction)
    trainIdx <- c(trainIdx, sample(idx, nTrain))
  }
  trainWide <- wide[sort(trainIdx), ]
  testWide <- wide[-sort(trainIdx), ]
  list(train = trainWide, test = testWide)
}

modelR1 <- FitLeastSquares(windowFeaturesWideR1, featureCols)
withinR1 <- PredictLeastSquares(modelR1, windowFeaturesWideR1, featureCols)

modelR3 <- FitLeastSquares(windowFeaturesWideR3, featureCols)
withinR3 <- PredictLeastSquares(modelR3, windowFeaturesWideR3, featureCols)

crossR1toR3 <- PredictLeastSquares(modelR1, windowFeaturesWideR3, featureCols)
crossR3toR1 <- PredictLeastSquares(modelR3, windowFeaturesWideR1, featureCols)

splitR3 <- StratifiedSplit(windowFeaturesWideR3, trainFraction = 0.7, seed = 2511)
modelR3Split <- FitLeastSquares(splitR3$train, featureCols)
withinR3Split <- PredictLeastSquares(modelR3Split, splitR3$test, featureCols)

evaluationResults <- list(
  withinR1 = withinR1,
  withinR3 = withinR3,
  crossR1toR3 = crossR1toR3,
  crossR3toR1 = crossR3toR1,
  withinR3Split = withinR3Split
)

accuracySummary <- data.frame(
  scenario = c(
    "Within R1 (train=test)",
    "Within R3 (train=test)",
    "Cross R1 -> R3",
    "Cross R3 -> R1",
    "Within R3 (70/30 split)"
  ),
  accuracy = c(
    evaluationResults$withinR1$accuracy,
    evaluationResults$withinR3$accuracy,
    evaluationResults$crossR1toR3$accuracy,
    evaluationResults$crossR3toR1$accuracy,
    evaluationResults$withinR3Split$accuracy
  )
)

print("Accuracies:")
print(accuracySummary)

print("Confusion: Within R1")
print(evaluationResults$withinR1$confusion)
print("Confusion: Within R3")
print(evaluationResults$withinR3$confusion)
print("Confusion: Cross R1 -> R3")
print(evaluationResults$crossR1toR3$confusion)
print("Confusion: Cross R3 -> R1")
print(evaluationResults$crossR3toR1$confusion)
print("Confusion: Within R3 (70/30 split)")
print(evaluationResults$withinR3Split$confusion)

# 7. Visualisation of Results

DrawAccuracySummaryPlot <- function() {
  par(mar = c(5, 12, 4, 2))
  scenarioLabels <- c(
    "Within R1",
    "Within R3",
    "Cross R1 -> R3",
    "Cross R3 -> R1",
    "R3 split (70/30)"
  )
  barPos <- barplot(
    accuracySummary$accuracy,
    names.arg = scenarioLabels,
    horiz = TRUE,
    las = 1,
    xlim = c(0, 1.05),
    xlab = "Accuracy",
    main = "Least-Squares Accuracy by Scenario"
  )
  text(
    x = pmin(accuracySummary$accuracy + 0.03, 1.03),
    y = barPos,
    labels = sprintf("%.3f", accuracySummary$accuracy),
    cex = 0.9
  )
}

DrawAccuracySummaryPlot()

# 8. Save Figures (Optional)

if (saveFigures) {
  dir.create(figuresDir, showWarnings = FALSE, recursive = TRUE)

  png(file.path(figuresDir, "exploratory_boxplots_r1_r3.png"), width = 1400, height = 650)
  exploratoryObjects$DrawExploratoryBoxplots()
  dev.off()

  png(file.path(figuresDir, "representative_table_r1.png"), width = 900, height = 280)
  exploratoryObjects$DrawRepresentativeTableR1()
  dev.off()

  png(file.path(figuresDir, "representative_table_r3.png"), width = 900, height = 280)
  exploratoryObjects$DrawRepresentativeTableR3()
  dev.off()

  png(file.path(figuresDir, "accuracy_summary.png"), width = 1000, height = 600)
  DrawAccuracySummaryPlot()
  dev.off()
}
