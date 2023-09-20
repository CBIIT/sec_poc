#
# R Function to check the list of descendants of a code (transitive closure of the code)
# to see if the participant has any of these codes
#


check_if_any  <- function( participant_codes, safe_query,ncit_code) {
 #print(paste('in check_if_any', ncit_code))
  sql_tc <-
    paste0(
      "select count(*) as num_descendants from ncit_tc tc where tc.parent = $1 and tc.descendant in ("
      ,
      participant_codes,
      ")"
      )
  
 # print(sql_tc)
  df_c <- safe_query(dbGetQuery, sql_tc,
                     params = ncit_code)
 # print(df_c)
 # print(df_c$num_descendants[[1]])
  
  if (df_c$num_descendants[[1]] > 0) {
    r <- 'YES'
  #  print("setting val to YES")
  }
  else {
    r <- 'NO'
 #   print("setting val to NO")
  }
  return(r)
}


# TODO(jcallaway): implement the new prior therapy matching logic correctly, instead of
# just calling chech_if_any(), as this function does.
check_if_any_with_ancestors <- function(patient_thesaurus_codes, safe_query, trial_codes) {
  if ((is.null(trial_codes) || is.na(trial_codes))
      || (is.null(patient_thesaurus_codes) || length(patient_thesaurus_codes) == 0)) {
    return(NA)
    
  } else {
    quoted_patient_codes <- toString(shQuote(patient_thesaurus_codes))
    trial_code_v <- unlist(strsplit(trial_codes, ','))
    for (i in 1:length(trial_code_v)) {
      result <- check_if_any(quoted_patient_codes, safe_query, trial_code_v[i])
      if (result == 'YES') {
        return(TRUE)
      }
    }
    return(FALSE)
  }
}


# Returns 'YES' if any of the descendants of ncit_code are present in participant_codes,
# OR any of the direct parents of level one of ncit_code are present in
# participant_codes.  The difference between this function and check_if_any() is that
# check_if_any() just checks the descendants, not the direct parents.
check_if_any_in_descendants_or_parents <- function(participant_codes, safe_query, ncit_code) {

  # This can be done as a single SQL query, but this approach seems
  # more intuitive...

  # If check_if_any returns true, no need to look at parents.
  if (check_if_any(participant_codes, safe_query, ncit_code) == 'YES') {
    return('YES')
  } else {

    # Need to check direct parents.
    sql <- paste0(
      "select count(*) as c from ncit_tc_with_path where level = 1 and descendant = $1 and parent in (",
      participant_codes,
      ")")
    result_set = safe_query(dbGetQuery, sql, params = ncit_code)
    if (result_set$c[[1]] > 0) {
      return('YES')
    } else {
      return('NO')
    }
  }
}
