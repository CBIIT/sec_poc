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







ret <- dbExecute(con, "delete from criteria_types")
# crit_type_df = data.frame(matrix(
#   ncol = 3,
#   nrow = 0,
#   dimnames = list(NULL, c("criteria_type_id", "criteria_type_code" , "criteria_type_title", "criteria_type_desc", "criteria_type_active"))
# ))

ret <- dbWriteTable(con,"criteria_types"  , "db_api_etl/criteria_types.csv", overwrite = TRUE)
ret <- dbExecute(con, "update criteria_types set criteria_type_active =  replace(criteria_type_active, CHAR(13), '')" )

df_biomarker_exc$biomarker_exc_fixed <-
  lapply(df_biomarker_exc$biomarker_exc_ncit_code,
         function(x)
           transform_prior_therapy_conv(x))

df_biomarker_exc <- as.data.frame(lapply(df_biomarker_exc, unlist))

new_biomarker_exc_df <- data.frame( "nct_id" = df_biomarker_exc$nct_id, 
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

new_biomarker_inc_df <- data.frame( "nct_id" = df_biomarker_inc$nct_id, 
                                    "criteria_type_id" = 2 ,
                                    "trial_criteria_orig_text" = NA,
                                    "trial_criteria_refined_text" = df_biomarker_inc$biomarker_inc_description,
                                    "trial_criteria_expression" = df_biomarker_inc$biomarker_inc_fixed,
                                    "update_date" = format_iso_8601(Sys.time()), 
                                    "update_by" = "hickmanhb",
                                    stringsAsFactors = FALSE)


# immunotherapy exclusion

imm_exc_sql <-
  "select nct_id, immunotherapy_ncit_codes__text as imm_description ,
  immunotherapy_ncit_codes__clean as imm_criteria
  from lung_prior_therapy
  where immunotherapy_ncit_codes__clean is not null and  inc_exc_indicator_immuno = 0 "

df_imm_exc <- dbGetQuery(con, imm_exc_sql)

df_imm_exc$imm_criteria_fixed <-
  lapply(df_imm_exc$imm_criteria,
         function(x)
           transform_prior_therapy_conv(x))
df_imm_exc <- as.data.frame(lapply(df_imm_exc, unlist))


new_imm_exc_df <- data.frame( "nct_id" = df_imm_exc$nct_id, 
                                    "criteria_type_id" = 3 ,
                                    "trial_criteria_orig_text" = NA,
                                    "trial_criteria_refined_text" = df_imm_exc$imm_description,
                                    "trial_criteria_expression" = df_imm_exc$imm_criteria_fixed,
                                    "update_date" = format_iso_8601(Sys.time()), 
                                    "update_by" = "hickmanhb",
                                    stringsAsFactors = FALSE)

chemo_exc_sql <-
  "select nct_id, chemotherapy_ncit_codes__text as chemotherapy_exc_text , chemotherapy_ncit_codes__clean as chemotherapy_exc_code from lung_prior_therapy_chemo
  where chemotherapy_ncit_codes__clean is not null and inc_exc_indicator = 0"

df_chemo_exc <- dbGetQuery(con, chemo_exc_sql)
df_chemo_exc$chemo_exc_criteria_fixed <-
  lapply(df_chemo_exc$chemotherapy_exc_code,
         function(x)
           transform_prior_therapy_conv(x))
df_chemo_exc <- as.data.frame(lapply(df_chemo_exc, unlist))

new_chemo_exc_df <- data.frame( "nct_id" = df_chemo_exc$nct_id, 
                              "criteria_type_id" = 4 ,
                              "trial_criteria_orig_text" = NA,
                              "trial_criteria_refined_text" = df_chemo_exc$chemotherapy_exc_text,
                              "trial_criteria_expression" = df_chemo_exc$chemo_exc_criteria_fixed,
                              "update_date" = format_iso_8601(Sys.time()), 
                              "update_by" = "hickmanhb",
                              stringsAsFactors = FALSE)

hiv_exc_sql <-
  "select nct_id, hiv_ncit_codes__text as hiv_exc_text, hiv_ncit_codes__clean as hiv_exc_code from hiv_exclusion"
df_hiv_exc <- dbGetQuery(con, hiv_exc_sql)
df_hiv_exc$hiv_exc_criteria_fixed <-
  lapply(df_hiv_exc$hiv_exc_code,
         function(x)
           transform_prior_therapy_conv(x))
df_hiv_exc <- as.data.frame(lapply(df_hiv_exc, unlist))

new_hiv_exc_df <- data.frame( "nct_id" = df_hiv_exc$nct_id, 
                                "criteria_type_id" = 5 ,
                                "trial_criteria_orig_text" = NA,
                                "trial_criteria_refined_text" = df_hiv_exc$hiv_exc_text,
                                "trial_criteria_expression" = df_hiv_exc$hiv_exc_criteria_fixed,
                                "update_date" = format_iso_8601(Sys.time()), 
                                "update_by" = "hickmanhb",
                                stringsAsFactors = FALSE)

#---
  plt_sql <- "  select nct_id, original_description_1 as trial_criteria_orig_text, 
        curated_description as trial_criteria_refined_text from refined_platelets where curated_description 
		not like  '%institutional%' and nct_id is not null
  "

df_plt <- dbGetQuery(con, plt_sql)
df_plt$trial_criteria_expression <- fix_blood_results(df_plt$trial_criteria_refined_text)  
df_plt$criteria_type_id <- 6
df_plt$update_date <- format_iso_8601(Sys.time())
df_plt$update_by <- 'hickmanhb'
#----
wbc_sql <-
  "select nct_id, clean_inclusion_wbc_criteria as trial_criteria_refined_text from refined_wbc_report where nct_id is not null"
df_wbc <- dbGetQuery(con, wbc_sql)
df_wbc$trial_criteria_expression <- fix_blood_results(df_wbc$trial_criteria_refined_text)
df_wbc$criteria_type_id <- 7
df_wbc$update_date <- format_iso_8601(Sys.time())
df_wbc$update_by <- 'hickmanhb'
df_wbc$trial_criteria_orig_text <- NA


#----
perf_sql <-
  "select nct_id,curated_inclusion_performance_statement as perf_description, original_performance_statement as trial_criteria_orig_text,
  cast(NULL as text) perf_criteria
  
  from refined_performance_report"
df_perf <- dbGetQuery(con, perf_sql)

df_perf_new <- parse_dataframe(df_perf['perf_description'])
df_perf_new <- subset(df_perf_new, select = c(perf_criteria))
df_perf$trial_criteria_expression <- df_perf_new$perf_criteria
  
df_perf$trial_criteria_refined_text <- df_perf$perf_description

df_perf_2 <- df_perf[, c("nct_id", "trial_criteria_orig_text", "trial_criteria_expression","trial_criteria_refined_text")]
df_perf_2$criteria_type_id <- 8
df_perf_2$update_date <- format_iso_8601(Sys.time())
df_perf_2$update_by <- 'hickmanhb'


#
# get subsets of the dataframes to write out the required fields of the generalized criteria tables.
#
ret <- dbWriteTable(con, 'trial_criteria', new_biomarker_exc_df, overwrite = TRUE)
ret <- dbWriteTable(con, 'trial_criteria', new_biomarker_inc_df, overwrite = FALSE, append = TRUE)
ret <- dbWriteTable(con, 'trial_criteria', new_imm_exc_df, overwrite = FALSE, append = TRUE)
ret <- dbWriteTable(con, 'trial_criteria', new_chemo_exc_df, overwrite = FALSE, append = TRUE)
ret <- dbWriteTable(con, 'trial_criteria', new_hiv_exc_df, overwrite = FALSE, append = TRUE)
ret <- dbWriteTable(con, 'trial_criteria', df_plt, overwrite = FALSE, append = TRUE)
ret <- dbWriteTable(con, 'trial_criteria', df_wbc, overwrite = FALSE, append = TRUE)
ret <- dbWriteTable(con, 'trial_criteria', df_perf_2, overwrite = FALSE, append = TRUE)




DBI::dbDisconnect(con)


