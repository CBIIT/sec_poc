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
source('hh_collapsibleTreeNetwork.R')
source('getDiseaseTreeData.R')
source('paste3.R')
source('get_lat_long_for_zipcode.R')

source('disease_tree_modal.R')
source('check_if_any.R')

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
      id = "Sidebar", # width = 3,
     # tags$head(tags$style(".modal-dialog{  overflow-y: auto;pointer-events: initial; overflow-x: auto;  max-width: 100%;}")),
  #    tags$head(tags$style(".modal-body{ min-height:700px}")),
      sidebarPanel(
        tags$style(".well {background-color:#F0F8FF;}"),
        width=3,
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
        uiOutput("disease_buttons"),
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
      id = "Main",
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
          4,
               pickerInput(
                 "match_types_picker",
                 label = 'Participant Attributes',
                 choices = c(
                   "Disease" = "disease_matches == TRUE",
                   "Gender" = "gender_matches == TRUE",
                   "Age" = "age_matches == TRUE",
                   #    "HGB" = "hgb_matches == TRUE",
                   "PLT" = " ( plt_matches == TRUE | is.na(plt_matches) ) ",
                   "WBC" = " (  wbc_matches == TRUE | is.na(wbc_matches) )  ",
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
                   
                 ),
                 selected = NULL,
                 multiple = TRUE,
                 options = list(),
                 choicesOpt = NULL,
                 width = 'auto',
                 inline = FALSE
               )
          ),        
        # column(
        #   1,
        #   style = 'padding-left:0px; padding-right:10px; ',
        #   dropdownButton(
        #     #tags$h3("List of Input"),
        #     inputId = "participant_attributes_dropdown",
        #     circle = FALSE,
        #     label = "Participant Attributes",
        #     checkboxGroupInput(
        #       "match_types_to_show_col",
        #       label = "",
        #       inline = FALSE,
        #       choices = c(
        #         "Disease" = "disease_matches == TRUE",
        #         "Gender" = "gender_matches == TRUE",
        #         "Age" = "age_matches == TRUE",
        #         #    "HGB" = "hgb_matches == TRUE",
        #         "PLT" = " ( plt_matches == TRUE | is.na(plt_matches) ) ",
        #         "WBC" = " (  wbc_matches == TRUE | is.na(wbc_matches) )  ",
        #         "Performance Status" = " (perf_matches == TRUE | is.na(perf_matches) ) ",
        #         "Immunotherapy (exclusion)" = " ( immunotherapy_matches == FALSE | is.na(immunotherapy_matches) ) ",
        #         #     "Biomarkers" = " ( biomarker_exc_matches == FALSE | is.na(biomarker_exc_matches) ) | ( biomarker_inc_matches == TRUE | is.na(biomarker_inc_matches) )  "
        #         "Biomarkers (exclusion) " = " ( biomarker_exc_matches == FALSE | is.na(biomarker_exc_matches) )   ",
        #         "Biomarkers (inclusion) " = " ( biomarker_inc_matches == TRUE | is.na(biomarker_inc_matches) )   " ,
        #         "Chemotherapy (exclusion) " = " ( chemotherapy_exc_matches == FALSE | is.na(chemotherapy_exc_matches) )   "
        #         ,
        #         "HIV Status (exclusion) " = " ( hiv_exc_matches == FALSE | is.na(hiv_exc_matches) ) "
        #         #,
        #         #"Chemotherapy (inclusion) " = " ( chemotherapy_inc_matches == TRUE | is.na(chemotherapy_inc_matches) )   "
        #         
        #       )
        #       
        #     )
        #   )
        # )
        # ,
        
        column(
          2,
          radioButtons(
            "disease_type",
            "Disease types:",
            c("Trial" = "trial",
              "Lead" = "lead"),
            inline = FALSE
          )
        )
        ,
        column(
          2,
          pickerInput(
            inputId = "phases_dropdown",
            label = "Phases",
            choices = c(
              "I  " = "  ( phase == 'O' |  phase == 'I' | phase == 'I_II')  ",
              "II " = " ( phase == 'II'| phase == 'I_II' | phase == 'II_III' ) ",
              "III" = " (  phase == 'III' | phase == 'II_III' ) ",
              "IV " = " phase == 'IV' "
            ),
            selected = NULL,
            multiple = TRUE,
            options = list(),
            choicesOpt = NULL,
            width = 'auto',
            inline = FALSE
            )
        )   
            ,
            
          
        
        
        column(
          2,
          #style='padding-left:5px; padding-right:10px; ',
          
         # offset = 1,
       
            pickerInput
            (
              "sites",
              label = "Study Sites",
              choices = c("VA" = "  ( va_matches == TRUE )  ",
                          "NIH CC" = " ( nih_cc_matches == TRUE ) "),
              selected = NULL,
              multiple = TRUE,
              options = list(),
              choicesOpt = NULL,
              width = 'auto',
              inline = FALSE
            )
            
            
            
          )
        ,
        column(
          2,
          #style='padding-left:5px; padding-right:10px; ',
          
          #offset = 1,
       
            numericInput(
              "distance_in_miles",
              label = "Distance (mi)",
              '',
              min = 1,
              max = 9999,
              step = 10 
              #,
              #width = '100px'
            )
            
            
            
          )
          
          
        
        
      ),
      fluidRow(
        column(
          width = 12,
          offset = 0,
          style = 'padding:10px;',
          DT::dataTableOutput("df_matches_data")
        )
        
      )
    )
  )
)




server <- function(input, output, session) {
  dbinfo <- config::get()
  
  sessionInfo <- reactiveValues(
    df_matches_to_show = NULL,
    df_matches = NULL,
    sidebar_shown = TRUE,
    disease_buttons = NULL
  )

  con = DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
  
  df_disease_choice_data <-
    dbGetQuery(
      con,
      "with preferred_names as (
select  preferred_name, count(preferred_name) as name_count
      from trial_diseases ds where ds.disease_type like '%maintype%' or ds.disease_type like  '%subtype%'
      group by preferred_name
      )
select n.code, pn.preferred_name from preferred_names pn join ncit n on pn.preferred_name = n.pref_name	  
      order by name_count desc"
    )
  
  df_disease_choices <- setNames(
      as.vector(df_disease_choice_data[["code"]]),as.vector(df_disease_choice_data[["preferred_name"]]))
  
  #browser()
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
                       #choices = df_disease_choices$preferred_name ,
                       choices = df_disease_choices,
                       server = TRUE)
  updateSelectizeInput(session,
                       'misc_typer',
                       choices = df_misc_choices$pref_name ,
                       server = TRUE)
  
  
  observeEvent(input$toggleSidebar, {
 
    if(sessionInfo$sidebar_shown) {
      print("hiding sidebar")
      sessionInfo$sidebar_shown <- FALSE
      removeCssClass("Main", "col-sm-8")
      addCssClass("Main", "col-sm-12")
      shinyjs::hide(id = "Sidebar")
    }  
    else {
      print("showing sidebar")
      sessionInfo$sidebar_shown <- TRUE
      removeCssClass("Main", "col-sm-12")
      addCssClass("Main", "col-sm-8")
      shinyjs::show(id = "Sidebar")
      shinyjs::enable(id = "Sidebar")
    }  
  #  shinyjs::toggle(id = "Sidebar")
    
    

    
  })
  
  observeEvent(input$search_and_match, {
    print("search and match")
    print(paste("age : ", input$patient_age))
    print("diseases : ")
    print(input$disease_typer)
    print(paste("gender : ", input$gender))
    click("toggleSidebar")
    
    #
    # Make a new dataframe for the patient data 
    #
    sel <- data.frame(matrix(ncol = 2, nrow = 0))
    colnames(sel) <-  c("Code", "Value")
    
    if(!is.na(input$patient_age)) {
      print("we have an age")
      sel[nrow(sel) + 1,] = c("C25150",toString(input$patient_age))
    }
  
    # add a disease for now
    
    #sel[nrow(sel) + 1, ] = c("C8953", "YES")
    
   # browser()
    if (length(input$disease_typer) > 0) {
      for (row in 1:length(input$disease_typer)) {
        sel[nrow(sel) + 1,] = c(input$disease_typer[row], "YES")
      }
    }
    
    if (input$gender == 'Male') {
      sel[nrow(sel) + 1,] = c('C46109', "YES")
    } else if (input$gender == 'Female') {
      sel[nrow(sel) + 1,] = c('C46110', "YES")
    }
    
    if(input$hiv == 'Yes') {
      sel[nrow(sel) + 1,] = c('C15175', "YES")
    } #else if (input$hiv == 'No') {
     # sel[nrow(sel) + 1,] = c('C15175', "NO")
      
  #  }
   # browser()
    sel_codes <- sel$Code
    possible_disease_codes_df <-
      sel[which(sel$Value == 'YES'),]  # NOTE USE TRANSITIVE CLOSURE TO MAKE SURE IF I NEED TO
    print("---- possible disease codes -----")
    print(possible_disease_codes_df)
    sel_codes2 <- paste("'", sel$Code, "'", sep = "")
    csv_codes <- paste(sel_codes2, collapse = ",")
    print(csv_codes)
    
    session_conn = DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
    
    #
    # Now get the disease matching studies
    #
    disease_df <-
      get_api_studies_for_disease(possible_disease_codes_df$Code)
    df_crit$api_disease_match <-
      df_crit$clean_nct_id %in% disease_df$nct_id  # will set T/F for each row
    
    # Get the VA studies
    va_df <- get_api_studies_with_va_sites()
    df_crit$va_match <- df_crit$clean_nct_id %in% va_df$nct_id
    
    #Get the NIH CC studies
    nih_cc_df <- get_api_studies_for_postal_code('20892')
    df_crit$nih_cc_match <-
      df_crit$clean_nct_id %in% nih_cc_df$nct_id
    
    # Get the patient maintypes
    patient_maintypes_df <-
      get_maintypes_for_diseases(possible_disease_codes_df$Code, session_conn)
    print(paste("patient maintypes = ", patient_maintypes_df))
    s2 <-
      paste("'", patient_maintypes_df$maintype, "'", sep = "")
    c2 <- paste(s2, collapse = ",")
    
    
    maintype_studies_all_sql <-
      paste(
        'select distinct nct_id from trial_maintypes where nci_thesaurus_concept_id in (',
        c2,
        ')'
      )
    
    maintype_studies_all <- dbGetQuery(session_conn,
                                       maintype_studies_all_sql)
    
    #
    # Logic for the lead disease match is to check that the study matches per api AND matches for lead disease maintype
    #
    df_crit$lead_disease_match <-
      df_crit$clean_nct_id %in% disease_df$nct_id &
      df_crit$clean_nct_id %in% maintype_studies_all$nct_id
    
    patient_data_env <- new.env(size = 200L)
    
    print("Instantiating patient data")
    for (row in 1:nrow(sel)) {
      code <- sel[row, 'Code']
      codeVal <- sel[row, 'Value']
      #   #   print(code)
      if (!is.na(suppressWarnings(as.numeric(codeVal)))) {
        eval(parse(text = paste(code , '<-', codeVal)))
        eval(parse(text = paste(code , '<-', codeVal)), envir = patient_data_env)
        
        print(paste(code , '<-', codeVal))
      }  else {
        eval(parse(text = paste(
          code , '<-' , "'",  trimws(codeVal), "'", sep = ""
        )), envir = patient_data_env)
        print(paste(code , '<-' , "'",  trimws(codeVal), "'", sep = ""))
        
      }
  #    incProgress(amount = step,
  #                message = 'Computing Matches',
  #                'Evaluating patient data')
    }
    
    #browser()
    print("creating the full match dataframe")
    #  print(input$disease_type)
    df_matches <-
      # data.table(
      data.frame(
        'nct_id' = df_crit$nct_id,
        'brief_title' = df_crit$brief_title,
        'phase' = df_crit$phase,
        'num_trues' = NA,
        'disease_codes' = df_crit$diseases,
        'disease_names' = df_crit$disease_names,
        'disease_codes_lead' = df_crit$diseases_lead,
        'disease_names_lead' = df_crit$disease_names_lead,
        'disease_matches' = df_crit$api_disease_match,
        'lead_disease_matches' = df_crit$lead_disease_match,
        'biomarker_inc_description' = df_crit$biomarker_inc_description,
        'biomarker_inc_ncit_code' = df_crit$biomarker_inc_ncit_code,
        'biomarker_inc_matches' = NA,
        'biomarker_exc_description' = df_crit$biomarker_exc_description,
        'biomarker_exc_ncit_code' = df_crit$biomarker_exc_ncit_code,
        'biomarker_exc_matches' = NA,
        'chemotherapy_inc_description' = df_crit$chemotherapy_inc_text,
        'chemotherapy_inc_criteria' = df_crit$chemotherapy_inc_code,
        'chemotherapy_inc_matches' = NA,
        'chemotherapy_exc_description' = df_crit$chemotherapy_exc_text,
        'chemotherapy_exc_criteria' = df_crit$chemotherapy_exc_code,
        'chemotherapy_exc_matches' = NA,
        'immunotherapy_description' =  df_crit$imm_description,
        'immunotherapy_criteria' = df_crit$imm_criteria,
        'immunotherapy_matches' = NA,
        'hiv_description' = df_crit$hiv_exc_text,
        'hiv_criteria' = df_crit$hiv_exc_code,
        'hiv_exc_matches' = NA,
        'va_matches' = df_crit$va_match,
        'nih_cc_matches' = df_crit$nih_cc_match,
        'gender' = df_crit$gender,
        'gender_criteria' = df_crit$gender_expression,
        'gender_matches' = NA,
        'min_age_in_years ' = df_crit$min_age_in_years,
        'max_age_in_years' = df_crit$max_age_in_years,
        'age_criteria' = df_crit$age_expression,
        'age_matches' = NA,
        'hgb_description' = df_crit$hgb_description,
        'hgb_criteria' = df_crit$hgb_criteria,
        'hgb_matches' = NA,
        'plt_description' = df_crit$plt_description,
        'plt_criteria' = df_crit$plt_criteria,
        'plt_matches' = NA,
        'wbc_description' = df_crit$wbc_description,
        'wbc_criteria' = df_crit$wbc_criteria,
        'wbc_matches' = NA,
        'perf_description' = df_crit$perf_description,
        'perf_criteria' = df_crit$perf_criteria,
        'perf_matches' = NA,
        'clean_nct_id' = df_crit$clean_nct_id,
        stringsAsFactors = FALSE
      )
    
    df_matches$immunotherapy_matches <-
      lapply(df_matches$immunotherapy_criteria,
             function(x)
               eval_prior_therapy_app(csv_codes, x, session_conn,
                                      eval_env =
                                        patient_data_env))
    
    df_matches$biomarker_inc_matches <-
      lapply(df_matches$biomarker_inc_ncit_code,
             function(x)
               eval_prior_therapy_app(csv_codes, x, session_conn,
                                      eval_env =
                                        patient_data_env))
    df_matches$biomarker_exc_matches <-
      lapply(df_matches$biomarker_exc_ncit_code,
             function(x)
               eval_prior_therapy_app(csv_codes, x, session_conn,
                                      eval_env =
                                        patient_data_env))
    df_matches$chemotherapy_inc_matches <-
      lapply(df_matches$chemotherapy_inc_criteria,
             function(x)
               eval_prior_therapy_app(csv_codes, x, session_conn,
                                      eval_env =
                                        patient_data_env))
    
    df_matches$chemotherapy_exc_matches <-
      lapply(df_matches$chemotherapy_exc_criteria,
             function(x)
               eval_prior_therapy_app(csv_codes, x, session_conn,
                                      eval_env =
                                        patient_data_env))
    
    df_matches$age_matches <-
      lapply(df_matches$age_criteria,
             function(x)
               eval_criteria(x, eval_env = patient_data_env))
    
    df_matches$gender_matches <-
      lapply(df_matches$gender_criteria,
             function(x)
               eval_criteria(x, eval_env = patient_data_env))
    
    df_matches$hgb_matches <-
      lapply(df_matches$hgb_criteria,
             function(x)
               eval_criteria(x, eval_env = patient_data_env))
    
    df_matches$plt_matches <-
      lapply(df_matches$plt_criteria,
             function(x)
               eval_criteria(x, eval_env = patient_data_env))
    
    df_matches$wbc_matches <-
      lapply(df_matches$wbc_criteria,
             function(x)
               eval_criteria(x, eval_env = patient_data_env))
    
    df_matches$perf_matches <-
      #        lapply(df_matches$perf_criteria,
      #               function(x)
      #                 eval_criteria(x, eval_env = patient_data_env))
      lapply(df_matches$perf_criteria,
             function(x)
               eval_prior_therapy_app(csv_codes, x, session_conn,
                                      eval_env =
                                        patient_data_env,
                                      FUN = transform_perf_status))
    
    df_matches$hiv_exc_matches <-
      lapply(df_matches$hiv_criteria,
             function(x)
               eval_prior_therapy_app(csv_codes, x, session_conn,
                                      eval_env =
                                        patient_data_env))
    
    # Magic call to fix up the dataframe after the lapply calls which creates lists....
    df_matches <- as.data.frame(lapply(df_matches, unlist))
    print(Sys.time())
    DBI::dbDisconnect(session_conn)
    sessionInfo$df_matches <- df_matches
    print("creating table to display")
  
    sessionInfo$df_matches_to_show <- sessionInfo$df_matches
    colnames(sessionInfo$df_matches_to_show) =  c(
      'NCT ID',
      'Title',
      'Phase',
      '# Matches',
      'Disease Codes',
      'Disease Names',
      'Lead Disease Codes',
      'Lead Disease Names',
      'Disease Match',
      'Lead Disease Match',
      'Biomarker Inclusion',
      'Biomarker Inclusion Expression',
      'Biomarker Inclusion Match',
      'Biomarker Exclusion',
      'Biomarker Exclusion Expression',
      'Biomarker Exclusion Match',
      'Chemotherapy Inclusion',
      'Chemotherapy Inclusion Expression',
      'Chemotherapy Inclusion Match',
      'Chemotherapy Exclusion',
      'Chemotherapy Exclusion Expression',
      'Chemotherapy Exclusion Match',
      'Immunotherapy Exclusion Criteria',
      'Immunotherapy Exclusion Expression',
      'Immunotherapy Exclusion Match',
      'HIV Exclusion Criteria',
      'HIV Exclusion Expression',
      'HIV Exclusion Match',
      'VA Sites',
      'NIH CC',
      'Gender',
      'Gender Expression',
      'Gender Match',
      'Min Age',
      'Max Age',
      'Age Expression',
      'Age Match',
      'HGB Criteria',
      'HGB Expression',
      'HGB Match',
      'PLT Criteria',
      'PLT Expression',
      'PLT Match',
      'WBC Criteria',
      'WBC Expression',
      'WBC Match',
      'Performance Status Criteria',
      'Performance Status Expression',
      'Performance Status Match',
      'clean_nct_id'
    )
    
    initially_hidden_columns <- c('clean_nct_id',  '# Matches',
                                  'Disease Codes',  'Lead Disease Codes', 'Biomarker Inclusion',
                                  'Biomarker Inclusion Expression','Biomarker Exclusion',
                                  'Biomarker Exclusion Expression', 'Chemotherapy Inclusion',
                                  'Chemotherapy Inclusion Expression',     'Chemotherapy Exclusion',
                                  'Chemotherapy Exclusion Expression','Immunotherapy Exclusion Criteria',
                                  'Immunotherapy Exclusion Expression', 'HIV Exclusion Criteria',
                                  'HIV Exclusion Expression',    'Gender',
                                  'Gender Expression', 'Min Age',
                                  'Max Age',
                                  'Age Expression',   'HGB Criteria','HGB Match',
                                  'HGB Expression','PLT Criteria',
                                  'PLT Expression',  'WBC Criteria',
                                  'WBC Expression','Performance Status Criteria',
                                  'Performance Status Expression')
    columns_with_tooltips <- c("Disease Names")
    new_match_dt <-
      datatable(
        sessionInfo$df_matches_to_show,
        colnames = c(
          'NCT ID',
          'Title',
          'Phase',
          '# Matches',
          'Disease Codes',
          'Disease Names',
          'Lead Disease Codes',
          'Lead Disease Names',
          'Disease Match',
          'Lead Disease Match',
          'Biomarker Inclusion',
          'Biomarker Inclusion Expression',
          'Biomarker Inclusion Match',
          'Biomarker Exclusion',
          'Biomarker Exclusion Expression',
          'Biomarker Exclusion Match',
          'Chemotherapy Inclusion',
          'Chemotherapy Inclusion Expression',
          'Chemotherapy Inclusion Match',
          'Chemotherapy Exclusion',
          'Chemotherapy Exclusion Expression',
          'Chemotherapy Exclusion Match',
          'Immunotherapy Exclusion Criteria',
          'Immunotherapy Exclusion Expression',
          'Immunotherapy Exclusion Match',
          'HIV Exclusion Criteria',
          'HIV Exclusion Expression',
          'HIV Exclusion Match',
          'VA Sites',
          'NIH CC',
          'Gender',
          'Gender Expression',
          'Gender Match',
          'Min Age',
          'Max Age',
          'Age Expression',
          'Age Match',
          'HGB Criteria',
          'HGB Expression',
          'HGB Match',
          'PLT Criteria',
          'PLT Expression',
          'PLT Match',
          'WBC Criteria',
          'WBC Expression',
          'WBC Match',
          'Performance Status Criteria',
          'Performance Status Expression',
          'Performance Status Match',
          'clean_nct_id'
        ),
        # true_disease,
        # filter='top',
        escape = FALSE,
        class = 'cell-border stripe compact wrap hover',
        # class = 'cell-border stripe compact nowrap hover',
        
        #extensions = c('FixedColumns', 'Buttons'),
        extensions = c('FixedColumns'),
        
        
        options = list(
          lengthMenu = c(50, 100, 500),
          processing = TRUE,
          dom =  '<"top"f<"clear">>t<"bottom"Blip <"clear">>',
         
          #    dom = 'ft',
          searching = TRUE,
          autoWidth = TRUE,
          scrollX = TRUE,
          deferRender = TRUE,
          # scrollY = "400px",
          scrollY = "45vh",
          scrollCollapse = TRUE,
          paging = TRUE,
          #paging = TRUE,
          fixedColumns = list(leftColumns = 3),
          style = "overflow-y: scroll",
          
        
          
          columnDefs = list(
            # Initially hidden columns
            list(
              visible = FALSE,
              targets = match(
                initially_hidden_columns,
                names(sessionInfo$df_matches_to_show)
              )
              #targets = c(4,  5,7,  11,12,14,15,17,18,19, 20  , 21,23,24,   26,27,30,31,33,34,35 ,37,38,40,41,43,44, 46,47,49)
            ),
            # 17,18,19 are chemo inclusion, ignore for now
          #  list(width = '150px', targets = c(10)),
            list(width = '300px', targets = c(2,8)),
            
        list(className = 'dt-center', targets = c(3, 6:ncol(sessionInfo$df_matches_to_show))),
            # Columns with hover tooltips
            
            list(
              targets = match(
                columns_with_tooltips,
                names(sessionInfo$df_matches_to_show)
              ),
              render = JS(
                "function(data, type, row, meta) { if (data === null) { return \"\" } ",
                "return type === 'display' && data.length > 30 ?",
                "'<span title=\"' + data + '\">' + data.substr(0, 30) + '...</span>' : data;",
                "}"
              )
            )
          ,
          
        list(
            targets = match(
              c('Lead Disease Match', 'Disease Match', 'VA Sites',
                'NIH CC',
                'Gender Match',
                'Age Match',
                'Biomarker Inclusion Match',
                'Chemotherapy Inclusion Match',
                'PLT Match',
                'WBC Match',
                'Performance Status Match'),
              names(sessionInfo$df_matches_to_show)
            ),
            render = JS(
              "function(data, type, row, meta) {  if (data === null) { return \"\" } ",
              "else if (type == 'display' && data == true ) { return '<img src=\"checkmark-32.png\" />'} ",
              "else if (type == 'display' && data == false ) {  return  '<img src=\"x-mark-32.png\" />';}" , 
              "else  { return \"\" ; }",
              "}"
            )
          )
        ,
        list(
          targets = match(
            c(
              'Biomarker Exclusion Match',
              'Immunotherapy Exclusion Match',
              'HIV Exclusion Match',
              'Chemotherapy Exclusion Match'
          ),
            names(sessionInfo$df_matches_to_show)
          ),
          render = JS(
            "function(data, type, row, meta) {  if (data === null) { return \"\" } ",
            "else if (type == 'display' && data == false ) { return '<img src=\"checkmark-32.png\" />'} ",
            "else if (type == 'display' && data == true ) {  return  '<img src=\"x-mark-32.png\" />';}" , 
            "else  { return \"\" ; }",
            "}"
          )
        )
        
          
        )
       )  
      ) %>% DT::formatStyle(columns = c(2,6,8), fontSize = '75%')
 
    
    output$df_matches_data = DT::renderDT(new_match_dt, server = TRUE)
    
    # browser()
    
  },
  label = 'search and match'
  )
  
 
  
  
  observeEvent(input$disease_selected,
               {
                 print("disease selected button pressed from modal")
                 disease_name <- input$selected_node[[length(input$selected_node)]]
                 print(disease_name)
                 if(is.null(sessionInfo$disease_buttons)) {
                   print('first disease button')
                   sessionInfo$disease_buttons <-  c(disease_name)
                 } else {
                   print("already have some buttons")
                   append(sessionInfo$disease_buttons, disease_name) 
                 }
                 print(sessionInfo$disease_buttons)
                 removeModal()
               }
               
  )
  
  observeEvent(input$gyn_disease_button,
               {
                 print("gyn button")
                 ev_conn = DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
                 dt_df <- getDiseaseTreeData(ev_conn, 'C4913')
                 DBI::dbDisconnect(ev_conn)
                 output$disease_tree <- renderCollapsibleTree({
                   hh_collapsibleTreeNetwork( 
                     dt_df,
                     collapsed = TRUE,
                     linkLength = 450,
                     zoomable = FALSE,
                     inputId = "selected_node",
                     nodeSize = 'nodeSize',
                     #nodeSize = 14,
                     aggFun = 'identity',
                     fontSize = 14 #,
                     #  width = '2000px',
                     #  height = '700px'
                   )})
                
                # browser()
                 showModal(diseaseTreeModal(failed = FALSE, msg = '',  
                                            init_code = 'C4913', input_df = dt_df)
                          
                           )
                 
                 
               })
  
  observeEvent(input$selected_node, ignoreNULL = FALSE, {
    print("node selected")
    print(input$selected_node)
   # browser()
    output$gyn_selected <- renderText(input$selected_node[[length(input$selected_node)]] )
    # browser()
    print("----------")
  })
  
  observeEvent(c(input$match_types_to_show,input$participant_attributes_dropdown),
               ignoreNULL = FALSE,
     {
    print("checkbox")
    }
  )
    
  observeEvent(
  input$match_types_picker,
  ignoreNULL = FALSE,
  {
    print("match types picker")
  }
  )
}
shinyApp(ui, server)