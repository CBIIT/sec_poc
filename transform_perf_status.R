transform_perf_status  <- function(perf_string, csv_codes) {
  new_string <- gsub(
    "check_if_any\\(",
    paste("check_if_any(\"", csv_codes, "\",session_conn  ,  "),
    perf_string
  )
 
 #  print(paste('orig = ', perf_string))
  # print(paste('new = ', new_string))
  return(new_string)
}