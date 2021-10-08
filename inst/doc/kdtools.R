## ----setup, include=FALSE-----------------------------------------------------
can_run = require(kdtools) && kdtools::has_cxx17()
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = can_run
)

## ----eval=!can_run, echo=FALSE------------------------------------------------
#  if (has_cxx17()) {
#    message("kdtools package not available, code will not be evaluated")
#  } else {
#    message("kdtools needs C++17 for full functionality, code will not be evaluated")
#  }

## -----------------------------------------------------------------------------
# sort by weight, miles-per-gallon and displacement
mtcars_sorted <- kd_sort(mtcars, cols = ~ wt + mpg + disp);
head(mtcars_sorted, 3)
tail(mtcars_sorted, 3)

## -----------------------------------------------------------------------------
lower <- c(2.5, 17, 120)
upper <- c(3.6, 22, 330)
kd_range_query(mtcars_sorted, lower, upper, cols = ~ wt + mpg + disp)
kd_nearest_neighbors(mtcars_sorted, lower, 2, cols = ~ wt + mpg + disp)

## -----------------------------------------------------------------------------
library(kdtools)
x = matrix(runif(3e3), nc = 3)
y = matrix_to_tuples(x)
y[1:3, c(1, 3)]

## -----------------------------------------------------------------------------
kd_sort(y, inplace = TRUE, parallel = TRUE)

## -----------------------------------------------------------------------------
rq = kd_range_query(y, c(0, 0, 0), c(1/4, 1/4, 1/4)); rq
i = kd_nearest_neighbor(y, c(0, 0, 0)); y[i, ]
nns = kd_nearest_neighbors(y, c(0, 0, 0), 100); nns
nni = kd_nn_indices(y, c(0, 0, 0), 10); nni

## -----------------------------------------------------------------------------
head(tuples_to_matrix(rq))
head(tuples_to_matrix(nns))

