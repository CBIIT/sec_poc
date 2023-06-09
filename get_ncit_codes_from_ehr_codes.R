#
# R function to return the the NCIt codes from a list of SNOMEDCT, ICD10CM, or LOINC codes 
# 
#

library(plyr)

get_ncit_codes_from_ehr_codes  <- function(ehr_codes, safe_query) {
  
  print(paste("ehr_codes = ", ehr_codes))
  
  get_ncit_codes_for_code <- function(ehr_code) {
    print(paste('get_ncit_codes_for_code - ', ehr_code))
    dfm <- safe_query(dbGetQuery,
                      "
                      with minlevel as
      (select min(level) as min_level from fhirops.ncit_tc_with_path_all p
      where p.descendant = $1 and p.parent like 'C%'
      )
      select distinct np.parent 
      from fhirops.ncit_tc_with_path_all np 
      join minlevel ml on np.level=ml.min_level
      where np.descendant = $2 and np.parent like 'C%'",
                      params = c(ehr_code, ehr_code)
    )
    return(dfm)
  }
  
  
  #
  # apply the SQL statement to each participant code
  #
  ncit_codes <- lapply(ehr_codes, get_ncit_codes_for_code)
  
  #
  # now flatten whatever we get back in maintypes to a dataframe of one column
  # and get distinct values in case we have dups in the codes that are sent into this function
  #
  
  ncit_codes_f <- unique(ldply(ncit_codes, data.frame))
  print(ncit_codes_f)
  return(ncit_codes_f)
}
