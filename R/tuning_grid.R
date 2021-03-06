# Author: Begum Topcuoglu
# Date: 2019-01-14
######################################################################
# Description:
# This function defines:
#     1. Tuning budget as a grid for the classification methods chosen
#     2. Cross-validation method (how many repeats and folds)
#     3. Caret name for the classification method chosen
######################################################################

######################################################################
# Dependencies and Outputs:
#    Filenames to put to function:
#       1. "L2_Logistic_Regression"
#       2. "RBF_SVM"
#       3. "Decision_Tree"
#       4. "Random_Forest"
#       5. "XGBoost"

# Usage:
# Call as source when using the function. The function is:
#   tuning_grid()

# Output:
#  List of:
#     1. Tuning budget as a grid the classification methods chosen
#     2. Cross-validation method
#     3. Caret name for the classification method chosen
######################################################################


#' Title
#'
#' @param train_data TODO
#' @param model TODO
#' @param outcome TODO
#' @param hyperparameters TODO
#'
#' @return
#' @export
#' @author Begüm Topçuoğlu, \email{topcuoglu.begum@@gmail.com}
#'
#'
tuning_grid <- function(train_data, model, outcome, hyperparameters) {

  # NOTE: Hyperparameters should be a csv containing a dataframe
  # where the first column "param" is the hyperparameter name
  # and the second column "val" are the values to be tested
  # and third column "model" is the model being used
  # TODO: don't read a csv, take a df as input instead
  hyperparameters <- readr::read_csv(hyperparameters, stringsAsFactors = F)
  hyperparameters <- hyperparameters[hyperparameters$model == model, ]
  hyperparameters <- split(hyperparameters$val, hyperparameters$param)

  # set outcome as first column if null
  # if(is.null(outcome)){
  # outcome <- colnames(train_data)[1]
  # }

  # -------------------------CV method definition--------------------------------------->
  # ADDED cv index to make sure
  #     1. the internal 5-folds are stratified for diagnosis classes
  #     2. Resample the dataset 100 times for 5-fold cv to get robust hp.
  # IN trainControl function:
  #     1. Train the model with final hp decision to use model to predict
  #     2. Return 2class summary and save predictions to calculate cvROC
  #     3. Save the predictions and class probabilities/decision values.
  folds <- 5
  cvIndex <- caret::createMultiFolds(factor(train_data[, outcome]), folds, times = 100)
  cv <- caret::trainControl(
    method = "repeatedcv",
    number = folds,
    index = cvIndex,
    returnResamp = "final",
    classProbs = TRUE,
    summaryFunction = caret::twoClassSummary,
    indexFinal = NULL,
    savePredictions = TRUE
  )
  # # ----------------------------------------------------------------------->



  # -------------------Classification Method Definition---------------------->

  # ---------------------------------1--------------------------------------->
  # For linear models we are using LiblineaR package
  #
  # LiblineaR can produce 10 types of (generalized) linear models:
  # The regularization can be
  #     1. L1
  #     2. L2
  # The losses can be:
  #     1. Regular L2-loss for SVM (hinge loss),
  #     2. L1-loss for SVM
  #     3. Logistic loss for logistic regression.
  #
  # Here we will use L1 and L2 regularization and hinge loss (L2-loss) for linear SVMs
  # We will use logistic loss for L2-resularized logistic regression
  # The liblinear 'type' choioces are below:
  #
  # for classification
  # • 0 – L2-regularized logistic regression (primal)---> we use this for l2-logistic
  #  • 1 – L2-regularized L2-loss support vector classification (dual)
  #  • 2 – L2-regularized L2-loss support vector classification (primal) ---> we use this for l2-linear SVM
  #  • 3 – L2-regularized L1-loss support vector classification (dual)
  #  • 4 – support vector classification by Crammer and Singer
  #  • 5 – L1-regularized L2-loss support vector classification---> we use this for l1-linear SVM
  #  • 6 – L1-regularized logistic regression
  #  • 7 – L2-regularized logistic regression (dual)
  #
  # for regression
  #  • 11 – L2-regularized L2-loss support vector regression (primal)
  #  • 12 – L2-regularized L2-loss support vector regression (dual)
  #  • 13 – L2-regularized L1-loss support vector regression (dual)
  # ------------------------------------------------------------------------>


  # ---------------------------------2--------------------------------------->
  # We use ROC metric for all the models
  # To do that I had to make changes to the caret package functions.
  # The files 'data/caret_models/svmLinear3.R and svmLinear5.R are my functions.
  # I added 1 line to get Decision Values for linear SVMs:
  #
  #           prob = function(modelFit, newdata, submodels = NULL){
  #             predict(modelFit, newdata, decisionValues = TRUE)$decisionValues
  #           },
  #
  # This line gives decision values instead of probabilities and computes ROC in:
  #   1. train function with the cross-validataion
  #   2. final trained model
  # using decision values and saves them in the variable "prob"
  # This allows us to pass the cv function for all models:
  # cv <- trainControl(method="repeatedcv",
  #                   repeats = 100,
  #                   number=folds,
  #                   index = cvIndex,
  #                   returnResamp="final",
  #                   classProbs=TRUE,
  #                   summaryFunction=twoClassSummary,
  #                   indexFinal=NULL,
  #                   savePredictions = TRUE)
  #
  # There parameters we pass for L1 and L2 SVM:
  #                   classProbs=TRUE,
  #                   summaryFunction=twoClassSummary,
  # are actually computing ROC from decision values not probabilities
  # ------------------------------------------------------------------------>

  # Grid and caret method defined for each classification models
  # TODO: named list instead of if/else block? could probably use a quosure to delay evaluation
  if (model == "L2_Logistic_Regression") {
    grid <- expand.grid(
      cost = hyperparameters$cost,
      loss = "L2_primal",
      # This chooses type=0 for liblinear R package
      # which is logistic loss, primal solve for L2 regularized logistic regression
      epsilon = 0.01
    ) # default epsilon recommended from liblinear
    method <- "regLogistic"
  }
  else if (model == "RBF_SVM") {
    grid <- expand.grid(
      sigma = hyperparameters$sigma,
      C = hyperparameters$C
    )
    method <- "svmRadial"
  }
  else if (model == "Decision_Tree") {
    grid <- expand.grid(maxdepth = hyperparameters$maxdepth) # maybe change these default parameters?
    method <- "rpart2"
  }
  else if (model == "Random_Forest") {
    if (is.null(hyperparameters$mtry)) {
      # get number of features
      n_features <- ncol(train_data) - 1
      if (n_features > 20000) n_features <- 20000
      # if few features
      if (n_features < 19) {
        mtry <- 1:6
      } else {
        # if many features
        mtry <- floor(seq(1, n_features, length = 6))
      }
      # only keep ones with less features than you have
      hyperparameters$mtry <- mtry[mtry <= n_features]
    }
    grid <- expand.grid(mtry = hyperparameters$mtry)
    method <- "rf"
  }
  else if (model == "XGBoost") {
    grid <- expand.grid(
      nrounds = hyperparameters$nrounds,
      gamma = hyperparameters$gamma,
      eta = hyperparameters$eta,
      max_depth = hyperparameters$max_depth,
      colsample_bytree = hyperparameters$colsample_bytree,
      min_child_weight = hyperparameters$min_child_weight,
      subsample = hyperparameters$subsample
    )
    method <- "xgbTree"
  }
  else {
    print("Model not available")
  }
  # Return:
  #     1. the hyper-parameter grid to tune
  #     2. the caret function to train with
  #     3, cv method
  params <- list(grid, method, cv)
  return(params)
}
