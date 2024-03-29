#' @importFrom Rcpp evalCpp
#' @useDynLib kdtools, .registration = TRUE
NULL

colspec <- function(x, cols = NULL) {
  res <- switch(mode(cols),
         "call" = colspec(x, attr(stats::terms(cols), "term.labels")),
         "character" = match(cols, colnames(x)),
         "numeric" = cols,
         "logical" = (1:ncol(x))[cols],
         "NULL" = 1:ncol(x),
         stop("Invalid column specificaiton"))
  if (length(res) == 0 ||
      !all(res %in% 1:ncol(x)))
    stop("Invalid column specificaiton")
  return(res)
}

#' Sort multidimensional data
#' @param x a matrix or arrayvec object
#' @param parallel use multiple threads if true
#' @param inplace sort as a side-effect if true
#' @param cols integer or character vector or formula indicating columns
#' @param ... ignored
#' @details The algorithm used is a divide-and-conquer quicksort variant that
#'   recursively partitions an range of tuples using the median of each
#'   successive dimension. Ties are resolved by cycling over successive
#'   dimensions. The result is an ordering of tuples matching their order if
#'   they were inserted into a kd-tree.
#'
#'   \code{kd_order} returns permutation vector that will order the rows of the
#'   original matrix, exactly as \code{\link{order}}. If \code{inplace} is true,
#'   then \code{kd_order} will also sort the arrayvec object as a side effect.
#'   This can be more efficient when many subsequent queries are required.
#'
#'   \code{kd_sort} and \code{kd_order} have been extended to work directly on R
#'   native data.frame and matrix types. All vector column types are supported
#'   (even lists of objects as long as equality and comparison operators are
#'   defined). Additional, the user can specify a sequence of column indices
#'   that will be used for sorting. These can be a subset of columns and given
#'   in any order.
#' @return \tabular{ll}{\code{kd_sort} \tab the table sorted in kd-tree order
#'   \cr \code{kd_order} \tab a permutation vector \cr \code{kd_is_sorted} \tab
#'   a boolean \cr}
#' @examples
#' if (has_cxx17()) {
#' z <- data.frame(real = runif(10), lgl = runif(10) > 0.5,
#'                 int = as.integer(rpois(10, 2)), char = sample(month.name, 10),
#'                 stringsAsFactors = FALSE)
#' kd_sort(z)
#' x <- matrix(runif(200), 100)
#' y <- kd_sort(x)
#' kd_is_sorted(y)
#' kd_order(x)
#' plot(y, type = "o", pch = 19, col = "steelblue", asp = 1)
#' }
#' @seealso \code{\link{arrayvec}}
#' @rdname kdsort
#' @export
kd_sort <- function(x, ...) UseMethod("kd_sort")

#' @rdname kdsort
#' @export
kd_sort.matrix <- function(x, cols = NULL, parallel = TRUE, ...) {
  return(x[kd_order(x, cols = colspec(x, cols), parallel = parallel),, drop = FALSE])
}

#' @rdname kdsort
#' @export
kd_sort.arrayvec <- function(x, inplace = FALSE, parallel = TRUE, ...) {
  return(kd_sort_(x, inplace = inplace, parallel = parallel))
}

#' @rdname kdsort
#' @export
kd_sort.data.frame <- function(x, cols = NULL, parallel = TRUE, ...) {
  return(x[kd_order(x, cols = colspec(x, cols), parallel = parallel),, drop = FALSE])
}

#' @rdname kdsort
#' @export
kd_sort.sf <- function(x, cols = NULL, parallel = TRUE, ...) {
  if (is.null(cols))
    return(x[kd_order(sf::st_coordinates(x), parallel = parallel),, drop = FALSE])
  else {
    return(x[kd_order(sf::st_drop_geometry(x), colspec(x, cols), parallel = parallel),, drop = FALSE])
  }
}

#' @rdname kdsort
#' @export
kd_order <- function(x, ...) UseMethod("kd_order")

#' @rdname kdsort
#' @export
kd_order.matrix <- function(x, cols = NULL, parallel = TRUE, ...) {
  return(kd_order_mat(x, colspec(x, cols), parallel = parallel))
}

#' @rdname kdsort
#' @export
kd_order.arrayvec <- function(x, inplace = FALSE, parallel = TRUE, ...) {
  return(kd_order_(x, inplace = inplace, parallel = parallel))
}

#' @rdname kdsort
#' @export
kd_order.data.frame <- function(x, cols = NULL, parallel = TRUE, ...) {
  return(kd_order_df(x, colspec(x, cols), parallel = parallel))
}

#' @rdname kdsort
#' @export
kd_is_sorted <- function(x, ...) UseMethod("kd_is_sorted")

#' @export
kd_is_sorted.matrix <- function(x, cols = NULL, parallel = FALSE, ...) {
  return(kd_is_sorted_mat(x, colspec(x, cols), parallel))
}

#' @export
kd_is_sorted.data.frame <- function(x, cols = NULL, parallel = FALSE, ...) {
  return(kd_is_sorted_df(x, colspec(x, cols), parallel))
}

#' @export
kd_is_sorted.arrayvec <- function(x, parallel = FALSE, ...) {
  return(kd_is_sorted_(x, parallel))
}

#' Sort a matrix into lexicographical order
#' @param x a matrix or arrayvec object
#' @param ... other parameters
#' @details Sorts a range of tuples into lexicographical order.
#' @return the input type sorted
#' @examples
#' if (has_cxx17()) {
#' x = lex_sort(matrix(runif(200), 100))
#' plot(x, type = "o", pch = 19, col = "steelblue", asp = 1)
#' }
#' @rdname lexsort
#' @export
lex_sort <- function(x, ...) UseMethod("lex_sort")

#' @export
lex_sort.matrix <- function(x, ...) {
  y <- matrix_to_tuples(x)
  lex_sort_(y, inplace = TRUE)
  return(tuples_to_matrix(y))
}

#' @export
lex_sort.arrayvec <- function(x, inplace = FALSE, ...) {
  return(lex_sort_(x, inplace = inplace))
}

#' Search sorted data
#' @param x an object sorted by \code{\link{kd_sort}}
#' @param v a vector specifying where to look
#' @param l lower left corner of search region
#' @param u upper right corner of search region
#' @param cols integer or character vector or formula indicating columns
#' @param ... ignored
#' @return \tabular{ll}{\code{kd_lower_bound} \tab a row of values (vector) \cr
#'   \code{kd_upper_bound} \tab a row of values (vector) \cr
#'   \code{kd_range_query} \tab a set of rows in the same format as the sorted input \cr
#'   \code{kd_rq_indices} \tab a vector of integer indices specifying rows in the input \cr
#'   \code{kd_binary_search} \tab a boolean \cr}
#' @examples
#' if (has_cxx17()) {
#' x = matrix(runif(200), 100)
#' y = matrix_to_tuples(x)
#' kd_sort(y, inplace = TRUE)
#' y[kd_lower_bound(y, c(1/2, 1/2)),]
#' y[kd_upper_bound(y, c(1/2, 1/2)),]
#' kd_binary_search(y, c(1/2, 1/2))
#' kd_range_query(y, c(1/3, 1/3), c(2/3, 2/3))
#' kd_rq_indices(y, c(1/3, 1/3), c(2/3, 2/3))
#' }
#' @aliases kd_lower_bound
#' @rdname search
#' @export
kd_lower_bound <- function(x, v) UseMethod("kd_lower_bound")

#' @export
kd_lower_bound.matrix <- function(x, v) {
  y <- matrix_to_tuples(x)
  return(kd_lower_bound_(y, v))
}

#' @export
kd_lower_bound.arrayvec <- function(x, v) {
  return(kd_lower_bound_(x, v))
}

#' @rdname search
#' @export
kd_upper_bound <- function(x, v) UseMethod("kd_upper_bound")

#' @export
kd_upper_bound.matrix <- function(x, v) {
  y <- matrix_to_tuples(x)
  return(kd_upper_bound_(y, v))
}

#' @export
kd_upper_bound.arrayvec <- function(x, v) {
  return(kd_upper_bound_(x, v))
}

#' @rdname search
#' @export
kd_range_query <- function(x, l, u, ...) UseMethod("kd_range_query")

#' @rdname search
#' @export
kd_range_query.matrix <- function(x, l, u, cols = NULL, ...) {
  return(x[kd_rq_indices(x, l, u, colspec(x, cols)),, drop = FALSE])
}

#' @rdname search
#' @export
kd_range_query.arrayvec <- function(x, l, u, ...) {
  return(kd_range_query_(x, l, u))
}

#' @rdname search
#' @export
kd_range_query.data.frame <- function(x, l, u, cols = NULL, ...) {
  return(x[kd_rq_indices(x, l, u, colspec(x, cols)),, drop = FALSE])
}

#' @rdname search
#' @export
kd_rq_indices <- function(x, l, u, ...) UseMethod("kd_rq_indices")

#' @rdname search
#' @export
kd_rq_indices.matrix <- function(x, l, u, cols = NULL, ...) {
  return(kd_rq_mat(x, colspec(x, cols), l, u))
}

#' @rdname search
#' @export
kd_rq_indices.arrayvec <- function(x, l, u, ...) {
  return(kd_rq_indices_(x, l, u))
}

#' @rdname search
#' @export
kd_rq_indices.data.frame <- function(x, l, u, cols = NULL, ...) {
  return(kd_rq_df(x, colspec(x, cols), l, u))
}

#' @rdname search
#' @export
kd_binary_search <- function(x, v) UseMethod("kd_binary_search")

#' @rdname search
#' @export
kd_binary_search.matrix <- function(x, v) {
  y <- matrix_to_tuples(x)
  return(kd_binary_search_(y, v))
}

#' @rdname search
#' @export
kd_binary_search.arrayvec <- function(x, v) {
  return(kd_binary_search_(x, v))
}

#' Find nearest neighbors
#' @param x an object sorted by \code{\link{kd_sort}}
#' @param v a vector specifying where to look
#' @param n the number of neighbors to return
#' @param cols integer or character vector or formula indicating columns
#' @param w distance weights
#' @param alpha approximate neighbors within (1 + alpha)
#' @param ... ignored
#' @return \tabular{ll}{
#' \code{kd_nearest_neighbors} \tab one or more rows from the sorted input \cr
#' \code{kd_nn_indices} \tab a vector of row indices indicating the result \cr
#' \code{kd_nearest_neighbor} \tab the row index of the neighbor \cr
#' }
#'
#' @examples
#' if (has_cxx17()) {
#' x = matrix(runif(200), 100)
#' y = matrix_to_tuples(x)
#' kd_sort(y, inplace = TRUE)
#' y[kd_nearest_neighbor(y, c(1/2, 1/2)),]
#' kd_nearest_neighbors(y, c(1/2, 1/2), 3)
#' y[kd_nn_indices(y, c(1/2, 1/2), 5),]
#' }
#' @rdname nneighb
#' @export
kd_nearest_neighbors <- function(x, v, n, ...) UseMethod("kd_nearest_neighbors")

#' @rdname nneighb
#' @export
kd_nearest_neighbors.matrix <- function(x, v, n, cols = NULL, alpha = 0, ...) {
  return(x[kd_nn_indices(x, v, n, colspec(x, cols), alpha = alpha),, drop = FALSE])
}

#' @rdname nneighb
#' @export
kd_nearest_neighbors.arrayvec <- function(x, v, n, ...) {
  return(kd_nearest_neighbors_(x, v, n))
}

#' @rdname nneighb
#' @export
kd_nearest_neighbors.data.frame <- function(x, v, n, cols = NULL, w = NULL, ...) {
  return(x[kd_nn_indices(x, v, n, colspec(x, cols), w),, drop = FALSE])
}

#' @rdname nneighb
#' @export
kd_nn_indices <- function(x, v, n, ...) UseMethod("kd_nn_indices")

#' @param distances return distances as attribute if true
#' @rdname nneighb
#' @export
kd_nn_indices.arrayvec <- function(x, v, n, distances = FALSE, ...) {
  if (distances)
    return(as.data.frame(kd_nn_dist_(x, v, n)))
  return(kd_nn_indices_(x, v, n))
}

#' @rdname nneighb
#' @export
kd_nn_indices.matrix <- function(x, v, n, cols = NULL, distances = FALSE, alpha = 0, ...) {
  if (distances)
    return(as.data.frame(kd_nn_dist_mat(x, colspec(x, cols), v, alpha, n)))
  return(kd_nn_mat(x, colspec(x, cols), v, alpha, n))
}

#' @rdname nneighb
#' @export
kd_nn_indices.data.frame <- function(x, v, n, cols = NULL, w = NULL, distances = FALSE, ...) {
  cols <- colspec(x, cols)
  if (is.null(w)) w <- rep_len(1, length(cols))
  if (distances)
    return(as.data.frame(kd_nn_dist_df(x, cols, w, v, n)))
  return(kd_nn_df(x, cols, w, v, n))
}

#' @rdname nneighb
#' @export
kd_nearest_neighbor <- function(x, v) UseMethod("kd_nearest_neighbor")

#' @rdname nneighb
#' @export
kd_nearest_neighbor.matrix <- function(x, v) {
  y <- matrix_to_tuples(x)
  return(kd_nearest_neighbor_(y, v))
}

#' @rdname nneighb
#' @export
kd_nearest_neighbor.arrayvec <- function(x, v) {
  return(kd_nearest_neighbor_(x, v))
}
