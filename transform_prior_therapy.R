transform_prior_therapy  <- function(therapy_string, csv_codes) {
  new_string <- gsub(
    "check_if_any\\(",
    paste("check_if_any(\"", csv_codes, "\",session_conn
          ,  "),
    therapy_string
    )
 # new_string <- gsub('&', ' && ',
#                     gsub('|', '||',
#                          gsub("=", " == ", new_string, fixed = TRUE)
#                          , fixed = TRUE),
#                     fixed = TRUE)
 # print(paste('orig = ', therapy_string))
 # print(paste('new = ', new_string))
  return(new_string)
}