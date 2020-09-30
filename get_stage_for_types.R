#
# R function to return the subtypes for a maintype
#

library(RSQLite)
library(plyr)

get_stage_for_types  <- function(ctrp_disease_string, con) {
  
  print(paste("stage : type  = ", ctrp_disease_string))
  ## HH 
  
  #
  # Get the c codes for the ctrp display name 
  #
  c_codes <- dbGetQuery(con,
                        "select nci_thesaurus_concept_id from distinct_trial_diseases where display_name = ?",
                        params = c(ctrp_disease_string))
  
  
  
  get_stage_for_code <- function(c_code) {
    print(paste('get_stage_for_code - ', c_code))
    dfm <- dbGetQuery(
      con,
      "with stages as (
select  nci_thesaurus_concept_id, display_name from distinct_trial_diseases where disease_type  like '%stage%' /* in ('stage', 'stage-subtype','grade-stage-subtype') */
)
,
descendants as 
(
select descendant from ncit_tc where parent = ? and descendant != ?) 
select s.display_name, n.code from ncit n join descendants d on n.code = d.descendant  
join stages s on n.code = s.nci_thesaurus_concept_id
order by s.display_name",
params = c(c_code, c_code)
    )
return(dfm)
  }
  
  
  #
  # apply the SQL statement to each participant code
  #
  
  stages <- lapply(c_codes$nci_thesaurus_concept_id, get_stage_for_code)
  
  #
  # now flatten whatever we get back in maintypes to a dataframe of one column
  # and get distinct values in case we have dups in the codes that are sent into this function
  #
  
  stages_f <- unique(ldply(stages, data.frame))
  print(stages_f)
  return(stages_f)
}
