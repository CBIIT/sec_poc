#
# R function to return the maintypes for a list of NCIT codes
#

library(RSQLite)
library(plyr)

get_maintypes_for_diseases  <- function(participant_codes, con) {
 
  #print(paste("participant_codes = ", participant_codes))
  
  get_maintype_for_code <- function(c_code) {
    print(paste('get_maintype_for_code - ', c_code))
    dfm <- dbGetQuery(
      con,
      '
      with minlevel as
      (select min(level) as min_level from ncit_tc_with_path np join maintypes m
      on np.parent = m.nci_thesaurus_concept_id
      join ncit n on np.parent = n.code
      join ncit nc on np.descendant = nc.code
      where np.descendant = $1
      )
      select distinct np.parent as maintype
      from ncit_tc_with_path np join maintypes m
      on np.parent = m.nci_thesaurus_concept_id
      join ncit n on np.parent = n.code
      join ncit nc on np.descendant = nc.code
      join minlevel ml on np.level=ml.min_level
      where np.descendant = $2',
      params = c(c_code, c_code)
    )
    return(dfm)
  }
  
  
  #
  # apply the SQL statement to each participant code
  #
  maintypes <- lapply(participant_codes, get_maintype_for_code)
  
  #
  # now flatten whatever we get back in maintypes to a dataframe of one column
  # and get distinct values in case we have dups in the codes that are sent into this function
  #
  
  maintypes_f <- unique(ldply(maintypes, data.frame))
  print(maintypes_f)
  return(maintypes_f)
}
