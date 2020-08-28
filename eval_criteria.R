# Eval function for criteria that does not need to be transformed
# (age, etc)
#
eval_criteria  <-
  function(x,
           eval_env = .GlobalEnv,
           ignore_errors = TRUE) {
   
    if (is.na(x)) {
      NA
    } else {
      tryCatch({
       # browser()
        eval(parse(text = x), envir = eval_env)
        
      },
      
      error = function(e) {
        par_env=parent.env(environment())
        if (par_env$ignore_errors == FALSE) {
          print(paste("eval error - ", x))
          print(paste("eval error - ", e))
        }
        NA
      })
      
    }
  }
