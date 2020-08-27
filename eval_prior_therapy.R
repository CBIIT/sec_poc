source('transform_prior_therapy.R')

eval_prior_therapy  <-
  function(criteria,
           column_name,
           csv_codes,
           df_matches,
           crit_row,
           session_conn,
           envir = .GlobalEnv) {
    if (is.na(criteria)) {
      df_matches[crit_row, column_name] <- NA
    } else {
      df_matches[crit_row, column_name] <-
        tryCatch({
          tt <<- transform_prior_therapy(criteria,
                                        csv_codes)
          eval(parse(text = tt))
          
        },
        
        error = function(e) {
          print(paste("eval error - row:",crit_row, "column", column_name))
          print(paste("eval error - ", criteria))
          print(paste("eval error - ",e))
          return(NA)
        })
      
    }
  }
