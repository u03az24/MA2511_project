# 1. Project Information

# Student name:
# Student ID:
# Project title:

saveFigures <- TRUE
figuresDir <- file.path("output", "figures")
printSessionInfo <- FALSE

# 2. Load Packages

library(arrow)

# 3. Load Data

BuildInputPath <- function(ratId) {
  file.path("output", paste0("preprocessed_raw_long_", ratId, ".parquet"))
}

LoadRawLong <- function(ratId) {
  as.data.frame(read_parquet(BuildInputPath(ratId)))
}

LoadWideByRat <- function(ratIds) {
  wideByRat <- list()
  for (ratId in ratIds) {
    rawLong <- LoadRawLong(ratId)
    wideByRat[[ratId]] <- BuildWindowFeaturesWide(rawLong)
  }
  wideByRat
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

MakeWideByFeature <- function(longData, featureName) {
  longFeature <- longData[c("state", "epoch", "channel", featureName)]
  wideFeature <- reshape(
    longFeature,
    idvar = c("state", "epoch"),
    timevar = "channel",
    direction = "wide"
  )
  channelCols <- setdiff(names(wideFeature), c("state", "epoch"))
  newCols <- paste0(sub(paste0("^", featureName, "\\."), "", channelCols), "_", featureName)
  names(wideFeature)[match(channelCols, names(wideFeature))] <- newCols
  wideFeature
}

BuildWindowFeaturesWide <- function(rawLong) {
  windowFeaturesLong <- BuildWindowFeaturesLong(rawLong)
  featureNames <- c("mean", "sd", "var", "rms")
  wideList <- list()
  for (featureName in featureNames) {
    wideList[[featureName]] <- MakeWideByFeature(windowFeaturesLong, featureName)
  }
  windowFeaturesWide <- Reduce(
    function(left, right) merge(left, right, by = c("state", "epoch")),
    wideList
  )
  windowFeaturesWide <- windowFeaturesWide[order(windowFeaturesWide$state, windowFeaturesWide$epoch), ]
  rownames(windowFeaturesWide) <- NULL
  windowFeaturesWide
}

ratIds <- c("R1", "R3")
wideByRat <- LoadWideByRat(ratIds)
windowFeaturesWideR1 <- wideByRat$R1
windowFeaturesWideR3 <- wideByRat$R3

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

exploratoryObjects <- list(
  DrawExploratoryBoxplots = DrawExploratoryBoxplots
)

featureCols <- setdiff(names(windowFeaturesWideR1), c("state", "epoch"))

# 6. Linear Algebra Methods

FitLeastSquares <- function(trainWide, featureCols) {
  yTrain <- trainWide$state
  XTrainRaw <- as.matrix(trainWide[, featureCols])
  XMean <- colMeans(XTrainRaw)
  XSD <- apply(XTrainRaw, 2, sd)
  XSD[XSD == 0] <- 1.0

  XTrain <- sweep(XTrainRaw, 2, XMean, "-")
  XTrain <- sweep(XTrain, 2, XSD, "/")
  ATrain <- cbind(1, XTrain)

  yAW <- as.numeric(yTrain == "AW")
  yNREM <- as.numeric(yTrain == "NREM")
  yREM <- as.numeric(yTrain == "REM")

  list(
    XMean = XMean,
    XSD = XSD,
    weightsAW = qr.solve(ATrain, yAW),
    weightsNREM = qr.solve(ATrain, yNREM),
    weightsREM = qr.solve(ATrain, yREM)
  )
}

PredictLeastSquares <- function(model, testWide, featureCols) {
  yTest <- testWide$state
  XTestRaw <- as.matrix(testWide[, featureCols])
  XTest <- sweep(XTestRaw, 2, model$XMean, "-")
  XTest <- sweep(XTest, 2, model$XSD, "/")
  ATest <- cbind(1, XTest)

  scoreMatrix <- cbind(
    AW = as.vector(ATest %*% model$weightsAW),
    NREM = as.vector(ATest %*% model$weightsNREM),
    REM = as.vector(ATest %*% model$weightsREM)
  )
  predicted <- colnames(scoreMatrix)[max.col(scoreMatrix, ties.method = "first")]
  list(
    confusion = table(actual = yTest, predicted = predicted),
    accuracy = mean(predicted == yTest)
  )
}

StratifiedSplit <- function(wideData, trainFraction = 0.7, seed = 2511) {
  set.seed(seed)
  trainIdx <- c()
  for (stateName in unique(wideData$state)) {
    idx <- which(wideData$state == stateName)
    nTrain <- floor(length(idx) * trainFraction)
    trainIdx <- c(trainIdx, sample(idx, nTrain))
  }
  trainIdx <- sort(trainIdx)
  list(
    train = wideData[trainIdx, ],
    test = wideData[-trainIdx, ]
  )
}

modelR1 <- FitLeastSquares(windowFeaturesWideR1, featureCols)
modelR3 <- FitLeastSquares(windowFeaturesWideR3, featureCols)
splitR3 <- StratifiedSplit(windowFeaturesWideR3, trainFraction = 0.7, seed = 2511)
modelR3Split <- FitLeastSquares(splitR3$train, featureCols)

evaluationResults <- list(
  withinR1 = PredictLeastSquares(modelR1, windowFeaturesWideR1, featureCols),
  withinR3 = PredictLeastSquares(modelR3, windowFeaturesWideR3, featureCols),
  crossR1toR3 = PredictLeastSquares(modelR1, windowFeaturesWideR3, featureCols),
  crossR3toR1 = PredictLeastSquares(modelR3, windowFeaturesWideR1, featureCols),
  withinR3Split = PredictLeastSquares(modelR3Split, splitR3$test, featureCols)
)

scenarioOrder <- c("withinR1", "withinR3", "crossR1toR3", "crossR3toR1", "withinR3Split")
scenarioLabels <- c(
  withinR1 = "Within R1 (train=test)",
  withinR3 = "Within R3 (train=test)",
  crossR1toR3 = "Cross R1 -> R3",
  crossR3toR1 = "Cross R3 -> R1",
  withinR3Split = "Within R3 (70/30 split)"
)

accuracySummary <- data.frame(
  scenario = unname(scenarioLabels[scenarioOrder]),
  accuracy = sapply(scenarioOrder, function(name) evaluationResults[[name]]$accuracy)
)
rownames(accuracySummary) <- NULL

print("Accuracies:")
print(accuracySummary)

for (name in scenarioOrder) {
  print(paste("Confusion:", scenarioLabels[[name]]))
  print(evaluationResults[[name]]$confusion)
}

# 7. Visualisation of Results

DrawAccuracySummaryPlot <- function() {
  par(mar = c(5, 12, 4, 2))
  shortLabels <- c("Within R1", "Within R3", "Cross R1 -> R3", "Cross R3 -> R1", "R3 split (70/30)")
  barPos <- barplot(
    accuracySummary$accuracy,
    names.arg = shortLabels,
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

  png(file.path(figuresDir, "accuracy_summary.png"), width = 1000, height = 600)
  DrawAccuracySummaryPlot()
  dev.off()
}

# 9. Session Information (Optional)

if (printSessionInfo) {
  sessionInfo()
}
