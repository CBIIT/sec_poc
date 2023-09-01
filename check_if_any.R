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


# Returns true ('YES') if check_if_any would return true for any parent of ncit_code.
# In other words, starts looking one level up.
check_if_any_parent <- function(participant_codes, safe_query, ncit_code) {
  sql <- paste0("select parent from ncit_tc where descendant = $1")
  result_set = safe_query(dbGetQuery, sql, params = ncit_code)
  for (code in result_set$parent) {
    if (check_if_any(participant_codes, safe_query, code) == 'YES') {
      return('YES')
    }
  }
  return('NO')
}
