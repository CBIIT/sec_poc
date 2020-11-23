library(shiny)
require(RSQLite)
library(DBI)
library(xtable)
library(DT)
library(dplyr)
library(httr)
library(leaflet)
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
df_biomarker_exc_sql <-
  "select nct_id, biomarker_ncit_code as biomarker_exc_ncit_code, name, name_2, name_3, name_4, name_5, name_6, name_7 from biomarker_exc "
df_biomarker_exc <- dbGetQuery(con, df_biomarker_exc_sql)
df_biomarker_exc$biomarker_exc_description <-
  paste3(
    df_biomarker_exc$name,
    df_biomarker_exc$name_2,
    df_biomarker_exc$name_3,
    df_biomarker_exc$name_4,
    df_biomarker_exc$name_5,
    df_biomarker_exc$name_6,
    df_biomarker_exc$name_7,
    sep = "; "
  )

View(df_biomarker_exc)



transform_prior_therapy_conv  <- function(therapy_string) {

  new_string <- gsub('&', ' && ',
                     gsub('|', '||',
                          gsub("=", " == ", therapy_string, fixed = TRUE)
                          , fixed = TRUE),
                     fixed = TRUE)
  # print(paste('orig = ', therapy_string))
  # print(paste('new = ', new_string))
  return(new_string)
}




ret <- dbExecute(con, "delete from criteria_types")
# crit_type_df = data.frame(matrix(
#   ncol = 3,
#   nrow = 0,
#   dimnames = list(NULL, c("criteria_type_id", "criteria_type_code" , "criteria_type_title", "criteria_type_desc", "criteria_type_active"))
# ))

ret <- dbWriteTable(con,"criteria_types"  , "db_api_etl/criteria_types.csv", overwrite = TRUE)

df_biomarker_exc$biomarker_exc_fixed <-
  lapply(df_biomarker_exc$biomarker_exc_ncit_code,
         function(x)
           transform_prior_therapy_conv(x))

df_biomarker_exc <- as.data.frame(lapply(df_biomarker_exc, unlist))

new_biomarker_exc_df <- data.frame( "ncit_id" = df_biomarker_exc$nct_id, 
                                "criteria_type_id" = as.integer(1) ,
                                "trial_criteria_orig_text" = NA,
                                "trial_criteria_refined_text" = df_biomarker_exc$name,
                                "trial_criteria_expression" = df_biomarker_exc$biomarker_exc_fixed,
                                "update_date" = format_iso_8601(Sys.time()), 
                                "update_by" = "hickmanhb",
                                stringsAsFactors = FALSE)


df_biomarker_inc_sql <-
  "select nct_id, biomarker_ncit_code as biomarker_inc_ncit_code, name as biomarker_inc_description
  from biomarker_inc where biomarker_ncit_code is not null"
df_biomarker_inc <- dbGetQuery(con, df_biomarker_inc_sql)

df_biomarker_inc$biomarker_inc_fixed <-
  lapply(df_biomarker_inc$biomarker_inc_ncit_code,
         function(x)
           transform_prior_therapy_conv(x))
df_biomarker_inc <- as.data.frame(lapply(df_biomarker_inc, unlist))
View(df_biomarker_inc)

new_biomarker_inc_df <- data.frame( "ncit_id" = df_biomarker_inc$nct_id, 
                                    "criteria_type_id" = 2 ,
                                    "trial_criteria_orig_text" = NA,
                                    "trial_criteria_refined_text" = df_biomarker_inc$biomarker_inc_description,
                                    "trial_criteria_expression" = df_biomarker_inc$biomarker_inc_fixed,
                                    "update_date" = format_iso_8601(Sys.time()), 
                                    "update_by" = "hickmanhb",
                                    stringsAsFactors = FALSE)

View(new_biomarker_inc_df)
#
# get subsets of the dataframes to write out the required fields of the generalized criteria tables.
#
ret <- dbWriteTable(con, 'trial_criteria', new_biomarker_exc_df, overwrite = TRUE)
ret <- dbWriteTable(con, 'trial_criteria', new_biomarker_inc_df, overwrite = FALSE, append = TRUE)



DBI::dbDisconnect(con)


