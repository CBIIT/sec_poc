#
# R function to return the subtypes for a maintype
#

library(RSQLite)
library(plyr)

get_subtypes_for_maintypes  <- function(ctrp_disease_string, safe_query) {
  
  print(paste("maintype = ", ctrp_disease_string))
  ## HH 
  
  #
  # Get the c codes for the ctrp display name 
  #
  c_codes <- safe_query(dbGetQuery,
                        "select nci_thesaurus_concept_id from distinct_trial_diseases where display_name = $1",
                        params = c(ctrp_disease_string))
  
  

  get_subtype_for_code <- function(c_code) {
    print(paste('get_subtype_for_code - ', c_code))
    dfm <- safe_query(dbGetQuery,
      "with subtypes as (
 select  nci_thesaurus_concept_id, display_name from distinct_trial_diseases where disease_type 
 in ('subtype', 'grade-subtype','grade-stage-subtype', 'maintype-subtype') 
 )
,
descendants as 
(
select descendant from ncit_tc where parent = $1) 

select s.display_name from ncit n join descendants d on n.code = d.descendant 
join subtypes s on n.code = s.nci_thesaurus_concept_id
order by s.display_name",
      params = c(c_code)
    )
    return(dfm)
  }
  
  
  #
  # apply the SQL statement to each participant code
  #
  
  subtypes <- lapply(c_codes$nci_thesaurus_concept_id, get_subtype_for_code)
  
  #
  # now flatten whatever we get back in maintypes to a dataframe of one column
  # and get distinct values in case we have dups in the codes that are sent into this function
  #
  
  subtypes_f <- unique(ldply(subtypes, data.frame))
  #print(subtypes_f)
  return(subtypes_f)
}
