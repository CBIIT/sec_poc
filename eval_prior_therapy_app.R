#
# function that evaluates prior therapy - note it calls the transform_prior_therapy_function t
#


source('transform_prior_therapy.R')

#testFunc <- function(a, b) a + b
#apply(dat[,c('x','z')], 1, function(y) testFunc(y['z'],y['x']))
#shareimprove this answer

eval_prior_therapy_app  <-
  function(csv_codes,
           x,
           session_conn,
           eval_env = .GlobalEnv,
           ignore_errors = FALSE,
           FUN = transform_prior_therapy) {
    #  browser()
    #    print(paste("eval_prior_therapy_app",  csv_codes, x))
    #   print("---")
    #    print(x)
    #    print("---")
    if (is.na(x)) {
      NA
    } else {
      tryCatch({
       #  print(paste('eval_prior_therapy_app - found crit', x))
       #  browser()
       # tt <<- transform_prior_therapy(x,
      #                                 csv_codes)
        tt <<- FUN(x,
                                       csv_codes)
     #  print(paste('eval of tt ', tt))
        eval(parse(text = tt), envir = eval_env)
        
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
