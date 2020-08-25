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
source('hh_collapsibleTreeNetwork.R')
source('getDiseaseTreeData.R')
source('paste3.R')
source('get_lat_long_for_zipcode.R')

source('disease_tree_modal.R')


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

ui <- fluidPage(
  useShinyjs(),
  tags$head(tags$style(
    HTML("hr {border-top: 1px solid #000000;}")
  )),
  
  titlePanel(title = div(img(src = "SEC-logo.png"), style = "text-align: center;")),
  sidebarLayout(
    div(
      id = "Sidebar",  #width:1000px;
      tags$head(tags$style(".modal-dialog{  overflow-y: auto;pointer-events: initial; overflow-x: auto'  max-width: 100%;}")),
      tags$head(tags$style(".modal-body{ min-height:600px}")),
      sidebarPanel(
        tags$style(".well {background-color:#F0F8FF;}"),
        fluidRow(
          column(8, align = 'left', h4("Search Criteria")),
          column(
            4,
            alight = 'right',
            style = "display:inline-block; margin-top: 10px; ",
            actionLink('clear_all', label = 'Clear All')
          )
        ),
        hr(),
        textInput(
          'postal_code',
          label = 'Geolocation',
          value = "",
          width = NULL,
          placeholder = 'Enter five digit zip code'
        ),
        numericInput(
          "patient_age",
          "Age (years):",
          NULL,
          min = 0,
          max = 120,
          step = 1
        ),
        radioGroupButtons(
          inputId = "gender",
          label = "Gender",
          choices = c("Male", "Female", "Unspecified"),
          selected = "Unspecified",
          justified = FALSE,
          status = "primary"
          # checkIcon = list(yes = icon("ok", lib = "glyphicon"), no = icon("remove", lib = "glyphicon"))
        ),
        
        actionButton("gyn_disease_button", "Gyn diseases"),
        
        selectizeInput("maintype_typer", label = "Maintypes", NULL , multiple = TRUE),
        selectizeInput("disease_typer", label = "Diseases", NULL, multiple = TRUE),
        selectizeInput("misc_typer", label = "Misc", NULL, multiple = TRUE),
        
        radioGroupButtons(
          inputId = "hiv",
          label = "HIV",
          choices = c("Yes", "No", "Unspecified"),
          selected = "Unspecified",
          justified = FALSE,
          status = "primary"
          # checkIcon = list(yes = icon("ok", lib = "glyphicon"), no = icon("remove", lib = "glyphicon"))
        ),
        actionButton("search_and_match", "SEARCH AND MATCH")
      )
    ),
    
    
    mainPanel(
      #actionButton("toggleSidebar", "<-")
      actionLink("toggleSidebar", NULL, icon("arrow-left"), style = "text-align: left;"),
      bsTooltip(
        "toggleSidebar",
        'Hide/show the search criteria',
        placement = "bottom",
        trigger = "hover",
        options = NULL
      ),
      
      
      fluidRow(
        column(
          1,
          style = 'padding-left:0px; padding-right:10px; ',
          dropdownButton(
            #tags$h3("List of Input"),
            inputId = "participant_attributes_dropdown",
            circle = FALSE,
            label = "Participant Attributes",
            checkboxGroupInput(
              "match_types_to_show_col2",
              label = "",
              inline = FALSE,
              choices = c(
                "Performance Status" = " (perf_matches == TRUE | is.na(perf_matches) ) ",
                "Immunotherapy (exclusion)" = " ( immunotherapy_matches == FALSE | is.na(immunotherapy_matches) ) ",
                #     "Biomarkers" = " ( biomarker_exc_matches == FALSE | is.na(biomarker_exc_matches) ) | ( biomarker_inc_matches == TRUE | is.na(biomarker_inc_matches) )  "
                "Biomarkers (exclusion) " = " ( biomarker_exc_matches == FALSE | is.na(biomarker_exc_matches) )   ",
                "Biomarkers (inclusion) " = " ( biomarker_inc_matches == TRUE | is.na(biomarker_inc_matches) )   " ,
                "Chemotherapy (exclusion) " = " ( chemotherapy_exc_matches == FALSE | is.na(chemotherapy_exc_matches) )   "
                ,
                "HIV Status (exclusion) " = " ( hiv_exc_matches == FALSE | is.na(hiv_exc_matches) ) "
                #,
                #"Chemotherapy (inclusion) " = " ( chemotherapy_inc_matches == TRUE | is.na(chemotherapy_inc_matches) )   "
                
              )
              
            )
          )
        )
        ,
        column(
          1,
          offset = 1,
          # style = 'padding-left:10px; padding-right:10px; ',
          dropdownButton(
            #tags$h3("List of Input"),
            inputId = "disease_type_dropdown",
            circle = FALSE,
            label = "Disease Type",
            radioButtons("disease_type",
                         #  "Disease types to match:",
                         "",
                         c("Trial" = "trial",
                           "Lead" = "lead"),
                         inline = TRUE)
            
          )
        )
        ,
        column(
          1,
          #style='padding-left:5px; padding-right:10px; ',
          
          offset = 1,
          dropdownButton(
            #tags$h3("List of Input"),
            inputId = "phases_dropdown",
            circle = FALSE,
            label = "Phases",
            checkboxGroupInput(
              "phases",
              label = "",
              inline = FALSE,
              choices = c(
                "I  " = "  ( phase == 'O' |  phase == 'I' | phase == 'I_II')  ",
                "II " = " ( phase == 'II'| phase == 'I_II' | phase == 'II_III' ) ",
                "III" = " (  phase == 'III' | phase == 'II_III' ) ",
                "IV " = " phase == 'IV' "
              )
              
              
            )
            
            
            
          )
        )
        ,
        column(
          1,
          #style='padding-left:5px; padding-right:10px; ',
          
          offset = 1,
          dropdownButton(
            #tags$h3("List of Input"),
            inputId = "study_sites_dropdown",
            circle = FALSE,
            label = "Study Sites",
            checkboxGroupInput(
              "sites",
              label = "",
              inline = TRUE,
              choices = c("VA" = "  ( va_matches == TRUE )  ",
                          "NIH CC" = " ( nih_cc_matches == TRUE ) ")
            )
            
            
            
          )
        ),
        column(
          1,
          #style='padding-left:5px; padding-right:10px; ',
          
          offset = 1,
          dropdownButton(
            #tags$h3("List of Input"),
            inputId = "Distance_dropdown",
            circle = FALSE,
            label = "Distance (miles)",
            numericInput(
              "distance_in_miles",
              "",
              '',
              min = 1,
              max = 9999,
              step = 10,
              width = '100px'
            )
            
            
            
          )
          
          
        )
        
      )
    )
  )
)




server <- function(input, output, session) {
  dbinfo <- config::get()
  con = DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
  
  df_disease_choices <-
    dbGetQuery(
      con,
      "select  preferred_name
      from trial_diseases ds where ds.disease_type like '%maintype%' or ds.disease_type like  '%subtype%'
      group by preferred_name
      order by count(preferred_name) desc"
    )
  
  df_misc_choices <-
    dbGetQuery(
      con ,
      "select pref_name from ncit where concept_status <> 'Obsolete_Concept' or concept_status is null order by parents, pref_name
      "
    )
  
  df_maintypes <-
    dbGetQuery(
      con,
      "select preferred_name, count(preferred_name) as disease_count
      from trial_diseases ds where ds.disease_type = 'maintype' or ds.disease_type like  '%maintype-subtype%'
      group by preferred_name
      order by count(preferred_name) desc"
    )
  
  crit_sql <-
    "select
  '<a href=https://www.cancer.gov/about-cancer/treatment/clinical-trials/search/v?id=' ||  nct_id || '&r=1 target=\"_blank\">' || nct_id || '</a>' as nct_id,
  nct_id as clean_nct_id, age_expression, disease_names, diseases, gender, gender_expression, max_age_in_years, min_age_in_years,
  'not yet' as hgb_description, 'FALSE' as hgb_criteria,
  disease_names_lead, diseases_lead ,
  brief_title, phase
  from trials"
  df_crit <- dbGetQuery(con, crit_sql)
  
  plt_sql <- "select nct_id,
  curated_description as plt_description from refined_platelets
  where curated_description not like '%institutional%'
  "
  
  df_plt <- dbGetQuery(con, plt_sql)
  df_plt$plt_criteria <- fix_blood_results(df_plt$plt_description)
  
  wbc_sql <-
    "select nct_id, clean_inclusion_wbc_criteria as wbc_description from refined_wbc_report"
  df_wbc <- dbGetQuery(con, wbc_sql)
  df_wbc$wbc_criteria <- fix_blood_results(df_wbc$wbc_description)
  
  perf_sql <-
    "select nct_id,curated_inclusion_performance_statement as perf_description,
  cast(NULL as text) perf_criteria
  
  from refined_performance_report"
  df_perf <- dbGetQuery(con, perf_sql)
  
  df_perf_new <- parse_dataframe(df_perf['perf_description'])
  df_perf_new <- subset(df_perf_new, select = c(perf_criteria))
  df_perf$perf_criteria <- df_perf_new$perf_criteria
  
  
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
  
  df_biomarker_inc_sql <-
    "select nct_id, biomarker_ncit_code as biomarker_inc_ncit_code, name as biomarker_inc_description
  from biomarker_inc where biomarker_ncit_code is not null"
  df_biomarker_inc <- dbGetQuery(con, df_biomarker_inc_sql)
  
  
  #browser()
  
  imm_sql <-
    "select nct_id, immunotherapy_ncit_codes__text as imm_description ,
  immunotherapy_ncit_codes__clean as imm_criteria
  from lung_prior_therapy
  where immunotherapy_ncit_codes__clean is not null and  inc_exc_indicator_immuno = 0 "
  
  df_imm <- dbGetQuery(con, imm_sql)
  
  
  #
  # Prior therapy / chemotherapy
  #
  
  chemo_exc_sql <-
    "select nct_id, chemotherapy_ncit_codes__text as chemotherapy_exc_text , chemotherapy_ncit_codes__clean as chemotherapy_exc_code from lung_prior_therapy_chemo
  where chemotherapy_ncit_codes__clean is not null and inc_exc_indicator = 0"
  chemo_inc_sql <-
    "select nct_id, chemotherapy_ncit_codes__text as chemotherapy_inc_text,
  chemotherapy_ncit_codes__clean as chemotherapy_inc_code from lung_prior_therapy_chemo
  where chemotherapy_ncit_codes__clean is not null and inc_exc_indicator = 1"
  df_chemo_exc <- dbGetQuery(con, chemo_exc_sql)
  df_chemo_inc <- dbGetQuery(con, chemo_inc_sql)
  
  
  hiv_exc_sql <-
    "select nct_id, hiv_ncit_codes__text as hiv_exc_text, hiv_ncit_codes__clean as hiv_exc_code from hiv_exclusion"
  df_hiv_exc <- dbGetQuery(con, hiv_exc_sql)
  
  #browser()
  
  df_crit <-
    merge(df_crit,
          df_plt,
          by.x = 'clean_nct_id',
          by.y = 'nct_id' ,
          all.x = TRUE)
  df_crit <-
    merge(df_crit,
          df_wbc,
          by.x = 'clean_nct_id',
          by.y = 'nct_id' ,
          all.x = TRUE)
  
  df_crit <-
    merge(df_crit,
          df_perf,
          by.x = 'clean_nct_id',
          by.y = 'nct_id',
          all.x = TRUE)
  
  df_crit <-
    merge(df_crit,
          df_imm,
          by.x = 'clean_nct_id',
          by.y = 'nct_id',
          all.x = TRUE)
  
  df_crit <-
    merge(
      df_crit,
      df_biomarker_inc,
      by.x = 'clean_nct_id',
      by.y = 'nct_id',
      all.x = TRUE
    )
  df_crit <-
    merge(
      df_crit,
      df_biomarker_exc,
      by.x = 'clean_nct_id',
      by.y = 'nct_id',
      all.x = TRUE
    )
  df_crit <-
    merge(
      df_crit,
      df_chemo_exc,
      by.x = 'clean_nct_id',
      by.y = 'nct_id',
      all.x = TRUE
    )
  df_crit <-
    merge(
      df_crit,
      df_chemo_inc,
      by.x = 'clean_nct_id',
      by.y = 'nct_id',
      all.x = TRUE
    )
  
  df_crit <-
    merge(
      df_crit,
      df_hiv_exc,
      by.x = 'clean_nct_id',
      by.y = 'nct_id',
      all.x = TRUE
    )
  
  
  
  DBI::dbDisconnect(con)
  
  updateSelectizeInput(session,
                       'maintype_typer',
                       choices = df_maintypes$preferred_name ,
                       server = TRUE)
  
  updateSelectizeInput(session,
                       'disease_typer',
                       choices = df_disease_choices$preferred_name ,
                       server = TRUE)
  updateSelectizeInput(session,
                       'misc_typer',
                       choices = df_misc_choices$pref_name ,
                       server = TRUE)
  
  
  observeEvent(input$toggleSidebar, {
    shinyjs::toggle(id = "Sidebar")
  })
  
  observeEvent(input$gyn_disease_button,
               {
                 print("gyn button")
                 ev_conn = DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
                 dt_df <- getDiseaseTreeData(ev_conn, 'C4913')
                 DBI::dbDisconnect(ev_conn)
                # browser()
                 showModal(diseaseTreeModal(failed = FALSE, msg = '',  
                                            init_code = 'C4913', input_df = dt_df)
                          
                           )
                 
                 
               })
  
}
shinyApp(ui, server)