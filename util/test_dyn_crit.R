library(shiny)
require(RSQLite)
library(DBI)
library(xtable)
library(DT)
library(dplyr)
library(httr)
library(maps)
library(data.table)
library(shinythemes)
library(shinydashboard)
library(shinyjs)
library(sqldf)
library(shinyWidgets)
library(stringi)
library(sjmisc)
library(shinydashboard)
library(shinyBS)
library(collapsibleTree)
library(stringi)
library(sjmisc)
library(lubridate)
library(shinyFeedback)
library(parsedate)
source('hh_collapsibleTreeNetwork.R')
source('getDiseaseTreeData.R')
source('paste3.R')
source('get_lat_long_for_zipcode.R')

source('disease_tree_modal.R')
source('check_if_any.R')
source('get_ncit_code_for_intervention.R')
source('get_api_studies_with_rvd_gte.R')
source('get_subtypes_for_maintypes.R')
source('get_stage_for_types.R')
source('get_org_families.R')
source('get_api_studies_for_cancer_centers.R')
#
#
dbinfo <- config::get()

Sys.setenv(LD_LIBRARY_PATH = "/usr/local/lib")
library(reticulate)
#use_python('/usr/bin/python3', required=TRUE )
reticulate::py_discover_config()
source_python(paste(
  dbinfo$python_file_dir,
  '/create_performance_expression.py',
  sep = ""
))
source('get_api_studies_for_disease.R')
source('fix_blood_results.R')
source('get_api_studies_for_location_and_distance.R')
source('get_maintypes_for_diseases.R')
source('eval_prior_therapy.R')
source('eval_prior_therapy_app.R')
source('eval_criteria.R')
source('get_api_studies_with_va_sites.R')
source('get_api_studies_for_postal_code.R')
source('transform_perf_status.R')

## Program to normalize and transform the existing study criteria statements to a normal form.

con = DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
# Now test the new way 
crit_sql <-
  "with site_counts as (
select count(nct_id) as number_sites, nct_id from trial_sites where org_status = 'ACTIVE' group by nct_id
)
    select
  '<a href=https://www.cancer.gov/about-cancer/treatment/clinical-trials/search/v?id=' ||  t.nct_id || '&r=1 target=\"_blank\">' || t.nct_id || '</a>' as nct_id,
  t.nct_id as clean_nct_id, age_expression, disease_names, diseases, gender, gender_expression, max_age_in_years, min_age_in_years,
  disease_names_lead, diseases_lead ,
  brief_title, phase, study_source , case study_source when 'National' then 1 when 'Institutional' then 2 when 'Externally Peer Reviewed' then 3 when 'Industrial' then 4 end study_source_sort_key ,
  sc.number_sites 
  from trials t join site_counts sc on t.nct_id = sc.nct_id "
df_crit <- dbGetQuery(con, crit_sql)


crit_types <- dbGetQuery(con, "select criteria_type_id, criteria_type_code, criteria_type_title, criteria_type_active from criteria_types  where criteria_type_active = 'Y' order by criteria_type_id ")

for (row in 1:nrow(crit_types)) {
  criteria_type_id <- crit_types[row, 'criteria_type_id']
  criteria_type_code  <- crit_types[row, 'criteria_type_code']
  criteria_type_title <- crit_types[row, 'criteria_type_title']
  
  # get the criteria by type
  
  #  "select nct_id, biomarker_ncit_code as biomarker_exc_ncit_code, name, name_2, name_3, name_4, name_5, name_6, name_7 from biomarker_exc "
  # df_crit <-
  #   merge(
  #     df_crit,
  #     df_biomarker_inc,
  #     by.x = 'clean_nct_id',
  #     by.y = 'nct_id',
  #     all.x = TRUE
  #   )
  
  cdf <- dbGetQuery(con, "select nct_id, trial_criteria_refined_text, trial_criteria_expression from trial_criteria where criteria_type_id = ? ",
                    params = c(criteria_type_id))
    
  # Now rename to the columns in cdr based upon the abbr.
  

  
  names(cdf)[names(cdf) == "trial_criteria_refined_text"] <- paste(criteria_type_code, "_refined_text", sep = "")
  names(cdf)[names(cdf) == "trial_criteria_expression"] <- paste(criteria_type_code, "_expression", sep = "")
  
  
   df_crit <-
     merge(
       df_crit,
       cdf,
       by.x = 'clean_nct_id',
       by.y = 'nct_id',
       all.x = TRUE
     )
}

DBI::dbDisconnect(con)
View(df_crit)
