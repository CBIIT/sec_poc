Queue <- R6::R6Class(
  "Queue",
  public = list(
    items = NULL,
    initialize = function() {
      self$items <- list()
    },
    enqueue = function(item) {
      self$items <- c(self$items, list(item))
    },
    dequeue = function() {
      if (self$is_empty()) {
        stop("Queue is empty")
      }
      item <- self$items[[1]]
      self$items <- self$items[-1]
      return(item)
    },
    is_empty = function() {
      return(self$size() == 0)
    },
    size = function() {
      return(length(self$items))
    }
  )
)
