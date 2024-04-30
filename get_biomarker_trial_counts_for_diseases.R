#
# R function to return the biomarkers and trial counts for a set of diseases 
#

library(RSQLite)
library(plyr)

get_biomarker_trial_counts_for_diseases  <- function(safe_query, disease_codes) {
  
  print(paste("get_biomarker_trial_counts_for_diseases = ", disease_codes))
  
  get_biomarkers_and_counts_for_one_disease <- function(c_code) {
    print(paste('get biomarkers_and_counts  - ', c_code))
    dfm <- safe_query(dbGetQuery,
                      " with biomarker_inc as (
  select nct_id, trim(unnest(string_to_array(biomarker_inc_codes, ','))) as biomarker_inc_code
  from trials)
  select count(bi.biomarker_inc_code) as num_occurences, bi.biomarker_inc_code,
   coalesce(nullif(n.display_name,''), n.pref_name) as biomarker_name 
   from trial_diseases td  join biomarker_inc bi on bi.nct_id = td.nct_id and lead_disease_indicator = TRUE 
   join ncit n on bi.biomarker_inc_code = n.code 
       where td.nci_thesaurus_concept_id = $1
   group by bi.biomarker_inc_code, coalesce(nullif(n.display_name,''), n.pref_name)
   order by count(bi.biomarker_inc_code) desc 
   ",
                      params = c(c_code)
    )
    return(dfm)
  }
  
  
  
  #
  biomarkers <- lapply(disease_codes, get_biomarkers_and_counts_for_one_disease)
  
 
  
  biomarkers_f <- unique(ldply(biomarkers, data.frame))
  print(biomarkers_f)
  return(biomarkers_f)
}
