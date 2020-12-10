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

ui <- fluidPage(
  useShinyjs(),
  useShinyFeedback(),
  #
  # Wire up the close button on the biomarker modal to fire a shiny event 
  # so the data can be processed 
  #
  
  tags$script('
  $( document ).ready(function() {
    $("#biomarker_bsmodal").on("hidden.bs.modal", function (event) {
    x = new Date().toLocaleString();
    // window.alert("biomarker  modal was closed at " + x);
    Shiny.onInputChange("biomarker_bsmodal_close",x);
  });
  })
  '),
  tags$head(tags$style(
    HTML("hr {border-top: 1px solid #000000;}")
  )),
  tags$style(HTML("
input:invalid {
background-color: #FFCCCC;
}")),
  
  #
  # set the shiny bsmodal to be as large as it can be.
  #
  
  tags$head(tags$style(HTML('

                        .modal-lg {
                        width: 95vw; height: 95vh;

                        }
                      '))),
 titlePanel(title = div(img(src = "SEC-logo.png"), style = "text-align: center;"), windowTitle = "Structured Eligibility Criteria Trial Search"),
 # titlePanel(title = div(img(src = "SEC-logo.png"), style = "text-align: center;"        ), span(downloadButton("downloadData", "Download Match Data", style =
#                                                                                                          'padding:4px; font-size:80%')),  windowTitle = "Structured Eligibility Criteria Trial Search"),
  
  sidebarLayout(
    div(
      id = "Sidebar", # width = 3,
     # tags$head(tags$style(".modal-dialog{  overflow-y: auto;pointer-events: initial; overflow-x: auto;  max-width: 100%;}")),
  #    tags$head(tags$style(".modal-body{ min-height:700px}")),
      sidebarPanel(
        tags$style(".well {background-color:#F0F8FF;}"),
        style = "overflow-y:scroll; max-height: 90vh; position:relative;",
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
          'patient_zipcode',
          label = 'Geolocation',
          value = "",
         
          placeholder = 'Enter five digit zip code'
         # width = '7em'
        ),
        verbatimTextOutput("city_state"),
        numericInput(
          "patient_age",
          "Age (years):",
          NULL,
          min = 0,
          max = 120,
          step = 1
        ),
        pickerInput(
          inputId = "performance_status",
          label = "Performance Status",
          choices = c(
            "Unspecified" = "C159685",
            "0: Asymptomatic" = "C105722",
            "1: Symptomatic, but fully ambulatory" = "C105723",
            "2: Symptomatic, in bed less than 50% of day" = "C105725",
            "3: Symptomatic, in bed more than 50% of day, but not bed-ridden" = "C105726",
            "4: Bed-ridden" = "C105727"
          ),
          selected =  "Unspecified",
          multiple = FALSE,
          options = list(width = "72px"),
          choicesOpt = NULL,
          width = 'auto',
          inline = FALSE
        ),
        radioGroupButtons(
          inputId = "gender",
          label = "Sex",
          choices = c("Male", "Female", "Unspecified"),
          selected = "Unspecified",
          justified = FALSE,
          status = "primary"
          # checkIcon = list(yes = icon("ok", lib = "glyphicon"), no = icon("remove", lib = "glyphicon"))
        ),
        
        radioGroupButtons(
          inputId = "hiv",
          label = "HIV",
          choices = c("Yes", "No", "Unspecified"),
          selected = "Unspecified",
          justified = FALSE,
          status = "primary"
          # checkIcon = list(yes = icon("ok", lib = "glyphicon"), no = icon("remove", lib = "glyphicon"))
        ),
        actionButton("show_cancer", "Cancer"),
        actionButton("show_gyn_disease", "Gyn"),
        actionButton("show_lung_disease", "Lung"),
        actionButton("show_solid_disease", "Solid"),
        DTOutput("diseases"),
        actionButton("show_biomarkers", "Biomarkers"),
        DTOutput('biomarkers'),
     
        numericInput(
          "patient_wbc",
          "WBC (/uL)",
           min = 0,
          value = NA
          # max = 120,
          #step = 1
        ),
        bsTooltip(
          "patient_wbc",
          'Enter the WBC in /uL -- e.g. 6000',
          placement = "bottom",
          trigger = "hover",
          options = NULL
        ),
        numericInput(
          "patient_plt",
          "Platelets (/uL)",
          value = NA,
          min = 0
          # max = 120,
          #step = 1
        ),
        bsTooltip(
          "patient_plt",
          'Enter the platlets in /uL -- e.g. 100000',
          placement = "bottom",
          trigger = "hover",
          options = NULL
        ),
     #   selectizeInput("maintype_typer", label = "Maintypes", NULL , multiple = TRUE),
    #    selectizeInput("disease_typer", label = "Diseases", NULL, multiple = TRUE),
                
        
        
    #----
    #(outputId="intervention_controls")  ,
    selectizeInput("prior_therapy", label = "Prior Therapy", NULL, multiple = TRUE),
    
    
    selectizeInput("misc_typer", label = "NCIt Search", NULL, multiple = TRUE),
    
        actionButton("search_and_match", "SEARCH AND MATCH")
      )
    )
    
    ,
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
                   "Age" = " (age_matches == TRUE | is.na(age_matches) ) ",
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
                 selected = "disease_matches == TRUE",
                 multiple = TRUE,
                 options = pickerOptions(actionsBox = TRUE),
                 choicesOpt = NULL,
                 width = 'auto',
                 inline = FALSE
               )
          ),        
 
        
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
            inputId = "phases",
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
              max = 999999
             # step = 10 
              #,
              #width = '100px'
            )
            
            
            
        )
        
        
      ),
      fluidRow(
      column(
        2,
        #style='padding-left:5px; padding-right:10px; ',
        
        #offset = 1,
        
        pickerInput
        (
          "study_source",
          label = "Study Source",

          choices = c( "National" = " ( study_source == 'National' )" ,
                       "Institutional" = " ( study_source == 'Institutional' ) ",
                       "Externally Peer Reviewed" = "  ( study_source == 'Externally Peer Reviewed' )  ",
                       "Industrial" = " ( study_source == 'Industrial' ) "
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
      column(5,
             offset = 2,
             style='padding-left:10px; padding-right:10px; ',
             selectizeInput("cancer_center_picker", label = "Cancer Center", NULL, multiple = TRUE))
      )
      ,
      fluidRow(
        column(
          width = 12,
          offset = 0,
          style = 'padding:10px;',
          DT::dataTableOutput("df_matches_data")
        )
        
      )
      ,
      fluidRow(
        column(
          width = 2,
          offset = 0,
          downloadButton("downloadData", "Download Match Data", style =
                           'padding:4px; font-size:80%')
        )
        ,
        
      )
      , 
      bsModal("gyn_bsmodal", "Select GYN Disease", "show_gyn_disease", size = "large",
              fluidPage(id = "treePanel",
                        fluidRow(column(
                          12,
                          wellPanel(
                            id = "tPanel",
                            style = "overflow-y:scroll;  max-height: 90vh; height: 70vh; overflow-x:scroll; max-width: 4000px",
                            collapsibleTreeOutput("gyn_disease_tree", height = "90vh", width =
                                                    '4500px')
                          )
                        )),
                        fluidRow(column(2, 'Disease selected:'), 
                                 column(6, align = "left", textOutput("gyn_selected")),
                                 column(2, align = 'right'), actionButton("gyn_add_disease", label='Add disease'))
                        
              )
              
    )
    ,
    bsModal("lung_bsmodal", "Select Lung Disease", "show_lung_disease", size = "large",
            fluidPage(id = "treePanel",
                      fluidRow(column(
                        12,
                        wellPanel(
                          id = "tPanel2",
                          style = "overflow-y:scroll;  max-height: 750vh; height: 70vh; overflow-x:scroll; max-width: 4000px",
                          collapsibleTreeOutput("lung_disease_tree", height = "75vh", width =
                                                  '4500px')
                        )
                      )),
                      fluidRow(column(2, 'Disease selected:'), 
                               column(6, align = "left", textOutput("lung_selected")),
                               column(2, align = 'right'), actionButton("lung_add_disease", label='Add disease'))
                      
            )
            
    )
    ,
    bsModal("solid_bsmodal", "Select Solid Neoplasm Disease", "show_solid_disease", size = "large",
            fluidPage(id = "treePanel",
                      fluidRow(column(
                        12,
                        wellPanel(
                          id = "tPanel2",
                          style = "overflow-y:scroll;  max-height: 750vh; height: 70vh; overflow-x:scroll; max-width: 4000px",
                          collapsibleTreeOutput("solid_disease_tree", height = "75vh", width =
                                                  '4000px')
                        )
                      )),
                      fluidRow(column(2, 'Disease selected:'), 
                               column(6, align = "left", textOutput("solid_selected")),
                               column(2, align = 'right'), actionButton("solid_add_disease", label='Add disease'))
                      
            )
            
    )
    ,
    bsModal("cancer_bsmodal", "Select Disease", "show_cancer", size = "large",
            fluidPage(id = "cancer_bs_modal_page",  #You are here
                      fluidRow( 
                        column( 4,
                        selectizeInput("maintype_typer", label = "Primary Cancer Type/Condition ", 
                                       NULL,  selected = NULL , multiple = FALSE
                                       )
                        )
                        ,
                        column(4, 
                        selectizeInput("subtype_typer", label = "Subtype", 
                                       NULL, multiple = TRUE))
                        ,
                        column(4, 
                               selectizeInput("stage_typer", label = "Stage", 
                                              NULL, multiple = TRUE))
            )
            ,
            fluidRow(
                     column(width=1,offset = 10,  align = 'right', 
                     actionButton("cancer_add_disease", label='Add disease'))
            
            )
    )
    )
    
    ,
    bsModal("biomarker_bsmodal", "Select biomarkers", "show_biomarkers", size = "large",
            fluidPage(sidebarLayout(
              
              sidebarPanel(
                radioGroupButtons(
                  inputId = "egfr",
                  label = "EGFR",
                  choices = c("Positive", "Negative", "Unspecified"),
                  selected = "Unspecified",
                  justified = FALSE,
                  status = "primary"
                ),
                radioGroupButtons(
                  inputId = "alk",
                  label = "ALK",
                  choices = c("Positive", "Negative", "Unspecified"),
                  selected = "Unspecified",
                  justified = FALSE,
                  status = "primary"
                ),
                radioGroupButtons(
                  inputId = "ros1",
                  label = "ROS1",
                  choices = c("Positive", "Negative", "Unspecified"),
                  selected = "Unspecified",
                  justified = FALSE,
                  status = "primary"
                )
                ,  # you are here 
                radioGroupButtons(
                  inputId = "nras",
                  label = "NRAS",
                  choices = c("Positive", "Negative", "Unspecified"),
                  selected = "Unspecified",
                  justified = FALSE,
                  status = "primary"
                
                )
                ,
                radioGroupButtons(
                  inputId = "kras",
                  label = "KRAS",
                  choices = c("Positive", "Negative", "Unspecified"),
                  selected = "Unspecified",
                  justified = FALSE,
                  status = "primary"
                  
                )
                ,
                radioGroupButtons(
                  inputId = "hras",
                  label = "HRAS",
                  choices = c("Positive", "Negative", "Unspecified"),
                  selected = "Unspecified",
                  justified = FALSE,
                  status = "primary"
                  
                )
                ,
                radioGroupButtons(
                  inputId = "her2_neu",
                  label = "HER2/Neu",
                  choices = c("Positive", "Negative", "Unspecified"),
                  selected = "Unspecified",
                  justified = FALSE,
                  status = "primary"
                )
                
              ),
              
              mainPanel(
                uiOutput(outputId="biomarker_controls")  
                #selectizeInput("biomarker_list", label = "Biomarker List", NULL, multiple = TRUE),
              )
            )

            

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
    disease_df = data.frame(matrix(ncol=3,nrow=0, dimnames=list(NULL, c("Code", "Value" , "Diseases")))),
    biomarker_df = data.frame(matrix(ncol=3,nrow=0, dimnames=list(NULL, c("Code", "Value" , "Biomarkers")))),
    distance_df = NA,
    latitude = NA,
    longitude = NA,
    ncit_search_df = data.frame(matrix(ncol=3,nrow=0, dimnames=list(NULL, c("Code", "Value" , "Biomarkers")))),
    rvd_df = NA,
    cancer_center_df = NA
    
    )
  counter <- reactiveValues(countervalue = 0)
  shinyjs::disable("subtype_typer")
  
  
  
  target_lvd <- ymd(today()) - years(2)
 #  s1 <- Sys.time()
 #  rvd_df <- get_api_studies_with_rvd_gte(target_lvd)
 #  s2 <- Sys.time()
 #  print(paste("rvd time ", s2-s1))
 #  print(paste('nrow', nrow(rvd_df)))
 # # browser()
  
  con = DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
  
  # s1 <- Sys.time()
  # 
   rvd_df <- dbGetQuery(con, paste("select nct_id from trials where record_verification_date >= '", target_lvd , "'", sep=""))
   print(paste('nrows', nrow(rvd_df)))
   
   df_number_sites <- dbGetQuery(con, "select count(nct_id) as number_sites, nct_id from trial_sites where org_status = 'ACTIVE' group by nct_id")

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
  df_misc_choice_data <-
    dbGetQuery(
      con ,
      "select code, pref_name from ncit where concept_status <> 'Obsolete_Concept' or concept_status is null order by parents, pref_name
      "
    )
  df_misc_choices <- setNames(
    as.vector(df_misc_choice_data[["code"]]),as.vector(df_misc_choice_data[["pref_name"]]))
  
  df_prior_therapy_data <-
    dbGetQuery(
      con,
      "with domain_set as (
        select tc.descendant as code  from ncit_tc tc where tc.parent in ('C16203', 'C1908')
      )      
select ds.code, n.pref_name  from domain_set ds join ncit n 
on ds.code = n.code and (n.concept_status not in ( 'Obsolete_Concept', 'Retired_Concept') or n.concept_status is null)
order by n.pref_name"
    )
  df_prior_therapy_choices <- setNames(
    as.vector(df_prior_therapy_data[["code"]]),as.vector(df_prior_therapy_data[["pref_name"]]))
  df_maintypes <-
    dbGetQuery(
      con,
      " select NULL as display_name union 
      select display_name 
      from distinct_trial_diseases ds where ds.disease_type = 'maintype' or ds.disease_type like  '%maintype-subtype%'
      order by display_name"
    )

  df_biomarker_list_s <-
    dbGetQuery(
      con,
      "with domain_set as (
        select tc.descendant as code  from ncit_tc tc where tc.parent = 'C36391'
      )      
select ds.code, n.pref_name as biomarker from domain_set ds join ncit n 
on ds.code = n.code and (n.concept_status not in ( 'Obsolete_Concept', 'Retired_Concept') or n.concept_status is null)
order by n.pref_name"
    )

  
  
  # To get around the wacko server side bug, render this thing here as a normal static selectize but with the biomarker dataframe from the server side   
  output$biomarker_controls <- renderUI({
    tagList(
      selectizeInput("biomarker_list", label = "Biomarker Search", choices = df_biomarker_list_s$biomarker, selected = NULL, multiple = TRUE) # HH you are here
    )
  })
  #-----

  
  
  crit_sql <-
    "with site_counts as (
select count(nct_id) as number_sites, nct_id from trial_sites where org_status = 'ACTIVE' group by nct_id
)
    select
  '<a href=https://www.cancer.gov/about-cancer/treatment/clinical-trials/search/v?id=' ||  t.nct_id || '&r=1 target=\"_blank\">' || t.nct_id || '</a>' as nct_id,
  t.nct_id as clean_nct_id, age_expression, disease_names, diseases, gender, gender_expression, max_age_in_years, min_age_in_years,
  'not yet' as hgb_description, 'FALSE' as hgb_criteria,
  disease_names_lead, diseases_lead ,
  brief_title, phase, study_source , case study_source when 'National' then 1 when 'Institutional' then 2 when 'Externally Peer Reviewed' then 3 when 'Industrial' then 4 end study_source_sort_key ,
  sc.number_sites 
  from trials t join site_counts sc on t.nct_id = sc.nct_id "
  df_crit <- dbGetQuery(con, crit_sql)
  
  # HH Cutting here for dynamic criteria 
  
  crit_types <- dbGetQuery(con, "select criteria_type_id, criteria_type_code, criteria_type_title, criteria_type_active from criteria_types  where criteria_type_active = 'Y' order by criteria_type_id ")
  
  for (row in 1:nrow(crit_types)) {
    criteria_type_id <- crit_types[row, 'criteria_type_id']
    criteria_type_code  <- crit_types[row, 'criteria_type_code']
    criteria_type_title <- crit_types[row, 'criteria_type_title']
    
    # get the criteria by type
    
    
    cdf <- dbGetQuery(con, "select nct_id, trial_criteria_refined_text, trial_criteria_expression from trial_criteria where criteria_type_id = ? ",
                      params = c(criteria_type_id))
    
    # Now rename to the columns in cdr based upon the abbr.
    
    
    names(cdf)[names(cdf) == "trial_criteria_refined_text"] <- paste(criteria_type_code, "_refined_text", sep = "")
    names(cdf)[names(cdf) == "trial_criteria_expression"] <- paste(criteria_type_code, "_expression", sep = "")
    
    # Now merge these columns into the df_crit dataframe with new names 
    
    df_crit <-
      merge(
        df_crit,
        cdf,
        by.x = 'clean_nct_id',
        by.y = 'nct_id',
        all.x = TRUE
      )
  }
  
  # end of cut
  
  # sort the dataframe by study source ascending and then by number of sites descending 
  
  df_crit <- df_crit[order(df_crit$study_source_sort_key, -df_crit$number_sites),]
  
  #browser()
  
  dt_gyn_tree <- getDiseaseTreeData(con, 'C4913', use_ctrp_display_name = TRUE)
  dt_lung_tree <- getDiseaseTreeData(con, 'C4878',use_ctrp_display_name = TRUE)
  dt_solid_tree <- getDiseaseTreeData(con, 'C9292',use_ctrp_display_name = TRUE)
  
  #browser()
  
  DBI::dbDisconnect(con)
  output$gyn_disease_tree <- renderCollapsibleTree({
    hh_collapsibleTreeNetwork( 
      dt_gyn_tree,
      collapsed = TRUE,
      linkLength = 500,
      zoomable = FALSE,
      inputId = "gyn_selected_node",
      nodeSize = 'nodeSize',
      #nodeSize = 14,
      aggFun = 'identity',
      fontSize = 14 #,
      #,
      #  width = '2000px',
      #  height = '1700px'
    )})
  output$lung_disease_tree <- renderCollapsibleTree({
    hh_collapsibleTreeNetwork( 
      dt_lung_tree,
      collapsed = TRUE,
      linkLength = 500,
      zoomable = FALSE,
      inputId = "lung_selected_node",
      nodeSize = 'nodeSize',
      #nodeSize = 14,
      aggFun = 'identity',
      fontSize = 14 #,
      #  width = '2000px',
      #  height = '700px'
    )})
  output$solid_disease_tree <- renderCollapsibleTree({
    hh_collapsibleTreeNetwork( 
      dt_solid_tree,
      collapsed = TRUE,
      linkLength = 450,
      zoomable = FALSE,
      inputId = "solid_selected_node",
      nodeSize = 'nodeSize',
      #nodeSize = 14,
      aggFun = 'identity',
      fontSize = 14 #,
      #  width = '2000px',
      #  height = '700px'
    )})
  
  
  updateSelectizeInput(session,
                       'maintype_typer',
                       choices = df_maintypes$display_name ,
                       server = TRUE)
  
  updateSelectizeInput(session,
                       'disease_typer',
                       choices = df_disease_choices,
                       server = TRUE)
  
  updateSelectizeInput(session,
                       'misc_typer',
                       choices = df_misc_choices ,
                       server = TRUE)
  
  updateSelectizeInput(session,
                       'prior_therapy',
                       choices = df_prior_therapy_choices ,
                       server = TRUE)
  
  
  updateSelectizeInput(session,
                       'cancer_center_picker',
                       choices = get_org_families() ,
                       server = TRUE)
  

#  updateSelectizeInput(session,
 #                      'biomarker_list',
 #                      choices = df_biomarker_list_s$biomarker ,
#                       server = TRUE)
  
  
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
  
  #
  # Clears all of the inputs 
  #
  observeEvent(input$clear_all , {
    updateTextInput(session, "patient_zipcode", value = NA)
    updateNumericInput(session, "patient_wbc", value = NA)
    updateNumericInput(session, "patient_plt", value = NA)
    updateNumericInput(session, "patient_age", value = NA)
    updateRadioGroupButtons(session, "hiv", selected = 'Unspecified')
    updateRadioGroupButtons(session, "gender", selected = 'Unspecified')
    updatePickerInput(session, "performance_status", selected = "C159685")
    sessionInfo$disease_df <- sessionInfo$disease_df[0,]
    sessionInfo$biomarker_df <-  sessionInfo$biomarker_df[0,]
    output$city_state <- NULL
    sessionInfo$latitude <- NA
    sessionInfo$longitude <- NA
    updateSelectizeInput(session, "misc_typer", selected = NA)
    updateSelectizeInput(session, "prior_therapy", selected = NA)
    
  }
  ) 
  
  observeEvent(input$intervention_search , {
    print("intervention search")
  }
  )
  
  observeEvent(input$maintype_typer, ignoreNULL = FALSE, {
    print("maintype_typer")
    if(length(input$maintype_typer) > 0  & input$maintype_typer != "" ){
      print('enabled subtype_type')
      shinyjs::enable("subtype_typer")
      shinyjs::enable("stage_typer")
      session_con <- DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
      
      df_new_subtypes <- get_subtypes_for_maintypes(input$maintype_typer, session_con)
      df_stages <- get_stage_for_types(input$maintype_typer, session_con)
      
      DBI::dbDisconnect(session_con)
     
      updateSelectizeInput(session,
                           'subtype_typer',
                           choices = df_new_subtypes$display_name ,
                           server = TRUE)
      
      updateSelectizeInput(session,
                           'stage_typer',
                           choices = df_stages$display_name ,
                           server = TRUE)
      
    } else {
      df_new_subtypes <- 
      shinyjs::disable("subtype_typer")
      shinyjs::disable("stage_typer")
      
      updateSelectizeInput(session,
                           'subtype_typer',
      choices = data.frame(matrix(ncol=1,nrow=0, dimnames=list(NULL, c("display_name"))))
      ,
      server = TRUE)
      
      
      updateSelectizeInput(session,
                           'stage_typer',
                           choices = data.frame(matrix(ncol=1,nrow=0, dimnames=list(NULL, c("display_name"))))
                           ,
                           server = TRUE)
    }
  })
  
  observeEvent(input$subtype_typer, ignoreNULL = FALSE, {
    print("subtype_typer")
    #browser()
    if(length(input$subtype_typer) > 0  ){
      print('enabled stage_typer')
      shinyjs::enable("stage_typer")
       session_con <- DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
       
       #df_stages <- get_stage_for_types(input$subtype_typer[1], session_con)
       df_stages <- get_stage_for_types(input$subtype_typer, session_con)
       
       DBI::dbDisconnect(session_con)
  
       updateSelectizeInput(session,
                            'stage_typer',
                            choices = df_stages$display_name ,
                            server = TRUE)
      
    } else  if(length(input$maintype_typer) > 0  & input$maintype_typer != "" ){
         shinyjs::enable("stage_typer")
        session_con <- DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
        
        df_stages <- get_stage_for_types(input$maintype_typer, session_con)
        DBI::dbDisconnect(session_con)
        
        updateSelectizeInput(session,
                             'stage_typer',
                             choices = df_stages$display_name ,
                             server = TRUE)
        
      } else {
        shinyjs::disable("stage_typer")
        updateSelectizeInput(session,
                             'stage_typer',
                             choices = data.frame(matrix(ncol=1,nrow=0, dimnames=list(NULL, c("display_name"))))
                             ,
                             server = TRUE)
        
      }

      
    
  })
  
  # 
  # Search and match button event handler 
  
  observeEvent(input$search_and_match, label = 'search and match', {
    print("search and match")
    print(paste("age : ", input$patient_age))
    print("diseases : ")
    print(input$disease_typer)
    print(paste("gender : ", input$gender))
   
    #
    # Make a new dataframe for the patient data 
    #
    sel <- data.frame(matrix(ncol = 2, nrow = 0))
    colnames(sel) <-  c("Code", "Value")
    
    # First check for a valid zipcode
    
    if (!is.null(input$patient_zipcode) && input$patient_zipcode != '') {
      
      has_five_digit_zip <- length(grep("^[[:digit:]]{5}$", c(input$patient_zipcode))) != 0
      print(paste("has_five_digit_zip=", has_five_digit_zip))
     # browser()
      feedbackDanger("patient_zipcode", !has_five_digit_zip, "Please enter a five digit zipcode")
      req(has_five_digit_zip, cancelOutput = TRUE)
      print("good zipcode so far ")
      geodata <- get_lat_long_for_zipcode(input$patient_zipcode)
      good_geodata <- length(geodata) == 4
      feedbackDanger("patient_zipcode", !good_geodata, "This is not a valid zipcode")
      req(good_geodata, cancelOutput = TRUE)
      # Now we have good zipcode data
      output$city_state <- renderText(paste(geodata[3], geodata[4]))
      sessionInfo$latitude <- geodata[1]
      sessionInfo$longitude <- geodata[2]
    } else {
      sessionInfo$latitude <- NA
      sessionInfo$longitude <- NA
    }

      
    withProgress(message = 'Matching Clinical Trials',  detail = 'Creating data' ,value = 0.0 , {
    
    if(!is.na(input$patient_age)) {
      print("we have an age")
      sel[nrow(sel) + 1,] = c("C25150",toString(input$patient_age))
    }
  
    # add a disease for now
    
    #sel[nrow(sel) + 1, ] = c("C8953", "YES")
    
   # browser()
    
    
    print(paste("performance status", input$performance_status))
    
    if(length(input$performance_status) > 0) {
      print("adding performance status")
      sel[nrow(sel) + 1,] = c(input$performance_status, "YES")
    }
    
    if (length(input$disease_typer) > 0) {
      for (row in 1:length(input$disease_typer)) {
        sel[nrow(sel) + 1,] = c(input$disease_typer[row], "YES")
      }
    }
    
    if (length(input$misc_typer) > 0) {
      for (row in 1:length(input$misc_typer)) {
        sel[nrow(sel) + 1,] = c(input$misc_typer[row], "YES")
      }
    }
    
    if (length(input$prior_therapy) > 0) {
      for (row in 1:length(input$prior_therapy)) {
        sel[nrow(sel) + 1,] = c(input$prior_therapy[row], "YES")
      }
    }
    # Add in any disease and biomarkers that may have been input
    
    if(nrow(sessionInfo$disease_df) > 0 ) {
      sel <- rbind(sel, sessionInfo$disease_df[c("Code", "Value")])
    }
    
    if(nrow(sessionInfo$biomarker_df) > 0 ) {
      sel <- rbind(sel, sessionInfo$biomarker_df[c("Code", "Value")])
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
    #browser()
    
    if(!is.na(input$patient_plt)) {
      print(paste("we have a platelet count ", input$patient_plt))
      sel[nrow(sel) + 1,] = c("C51951",toString(input$patient_plt))
    }
    if(!is.na(input$patient_wbc)) {
      print(paste("we have a wbc ", input$patient_wbc))
      sel[nrow(sel) + 1,] = c("C51948",toString(input$patient_wbc))
    }
    
    sel_codes <- sel$Code
    possible_disease_codes_df <-
      sel[which(sel$Value == 'YES'),]  # NOTE USE TRANSITIVE CLOSURE TO MAKE SURE IF I NEED TO
    print("---- possible disease codes -----")
    print(possible_disease_codes_df)
    sel_codes2 <- paste("'", sel$Code, "'", sep = "")
    csv_codes <- paste(sel_codes2, collapse = ",")
    print(csv_codes)
    
    setProgress(value = 0.1,  detail = 'Matching on disease')
    session_conn = DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
    
    #
    # Now get the disease matching studies
    #
    disease_df <-
      get_api_studies_for_disease(possible_disease_codes_df$Code)
    df_crit$api_disease_match <-
      df_crit$clean_nct_id %in% disease_df$nct_id  # will set T/F for each row
    
    # Get the VA studies
    setProgress(value = 0.2,  detail = 'Examing VA sites')
    
    va_df <- get_api_studies_with_va_sites()
    df_crit$va_match <- df_crit$clean_nct_id %in% va_df$nct_id
    
    #Get the NIH CC studies
    nih_cc_df <- get_api_studies_for_postal_code('20892')
    df_crit$nih_cc_match <-
      df_crit$clean_nct_id %in% nih_cc_df$nct_id
    
    setProgress(value = 0.3,  detail = 'Computing patient maintypes')
    
    # Get the patient maintypes
    patient_maintypes_df <-
      get_maintypes_for_diseases(possible_disease_codes_df$Code, session_conn)
    print(paste("patient maintypes = ", patient_maintypes_df))
    s2 <-
      paste("'", patient_maintypes_df$maintype, "'", sep = "")
    c2 <- paste(s2, collapse = ",")
    
    setProgress(value = 0.4,  detail = 'Computing trial maintypes')
    
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
    
    setProgress(value = 0.5,  detail = 'Creating match matrix')
    
    #browser()
    print("creating the full match dataframe")
    #  print(input$disease_type)
    df_matches <-
      # data.table(
      data.frame(
        'nct_id' = df_crit$nct_id,
        'brief_title' = df_crit$brief_title,
        'phase' = df_crit$phase,
        'study_source' = df_crit$study_source, 
        'num_trues' = NA,
        'disease_codes' = df_crit$diseases,
        'disease_names' = df_crit$disease_names,
        'disease_codes_lead' = df_crit$diseases_lead,
        'disease_names_lead' = df_crit$disease_names_lead,
        'disease_matches' = df_crit$api_disease_match,
        'lead_disease_matches' = df_crit$lead_disease_match,  
        'biomarker_inc_description' = df_crit$biomarker_inc_refined_text,# Start changing here 
        'biomarker_inc_ncit_code' = df_crit$biomarker_inc_expression,
        'biomarker_inc_matches' = NA,
        'biomarker_exc_description' = df_crit$biomarker_exc_refined_text,
        'biomarker_exc_ncit_code' = df_crit$biomarker_exc_expression,
        'biomarker_exc_matches' = NA,  
         # NOTE GET RID OF CHEMO INC 
        'chemotherapy_inc_description' = NA,
        'chemotherapy_inc_criteria' = NA,
        'chemotherapy_inc_matches' = NA,
         # 
        'chemotherapy_exc_description' = df_crit$chemotherapy_exc_refined_text,
        'chemotherapy_exc_criteria' = df_crit$chemotherapy_exc_expression,
        'chemotherapy_exc_matches' = NA,
        'immunotherapy_description' =  df_crit$immunotherapy_exc_refined_text,
        'immunotherapy_criteria' = df_crit$immunotherapy_exc_expression,
        'immunotherapy_matches' = NA,
        'hiv_description' = df_crit$hiv_exc_refined_text,
        'hiv_criteria' = df_crit$hiv_exc_expression,
        'hiv_exc_matches' = NA,
        
         # End of first batch 
        
        'va_matches' = df_crit$va_match,
        'nih_cc_matches' = df_crit$nih_cc_match,
        'gender' = df_crit$gender,
        'gender_criteria' = df_crit$gender_expression,
        'gender_matches' = NA,
        'min_age_in_years ' = df_crit$min_age_in_years,
        'max_age_in_years' = df_crit$max_age_in_years,
        'age_criteria' = df_crit$age_expression,
        'age_matches' = NA,
        
         # second batch 
         # skip HGB - TODO: delete this 
        'hgb_description' = NA,
        'hgb_criteria' = NA,
        'hgb_matches' = NA,
         #
        'plt_description' = df_crit$plt_refined_text,
        'plt_criteria' = df_crit$plt_expression,
        'plt_matches' = NA,
        'wbc_description' = df_crit$wbc_refined_text,
        'wbc_criteria' = df_crit$wbc_expression,
        'wbc_matches' = NA,
        'perf_description' = df_crit$perf_refined_text,
        'perf_criteria' = df_crit$perf_expression,
        'perf_matches' = NA,
         # 
        'clean_nct_id' = df_crit$clean_nct_id,
        stringsAsFactors = FALSE
      )
    
    # Once these are working -- roll them up in a master loop 
   # browser()
    setProgress(value = 0.6,  detail = 'Creating criteria matches')
    
    df_matches$immunotherapy_matches <-
      lapply(df_matches$immunotherapy_criteria,
             function(x)
               eval_prior_therapy_app(csv_codes, x, session_conn,
                                      eval_env =
                                        patient_data_env))
   # browser()
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
    df_matches$chemotherapy_inc_matches <- NA  # Get rid of this one 
    
    df_matches$chemotherapy_exc_matches <-
      lapply(df_matches$chemotherapy_exc_criteria,
             function(x)
               eval_prior_therapy_app(csv_codes, x, session_conn,
                                      eval_env =
                                        patient_data_env))
    setProgress(value = 0.7,  detail = 'Creating criteria matches')
    
    
    df_matches$age_matches <-
      lapply(df_matches$age_criteria,
             function(x)
               eval_criteria(x, eval_env = patient_data_env))
    
    df_matches$gender_matches <-
      lapply(df_matches$gender_criteria,
             function(x)
               eval_criteria(x, eval_env = patient_data_env))
    
    df_matches$hgb_matches <- NA # Get rid of this one
    
    df_matches$plt_matches <-
      lapply(df_matches$plt_criteria,
             function(x)
               eval_criteria(x, eval_env = patient_data_env))
    
    df_matches$wbc_matches <-
      lapply(df_matches$wbc_criteria,
             function(x)
               eval_criteria(x, eval_env = patient_data_env))
    setProgress(value = 0.8,  detail = 'Creating criteria matches')
    
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

    setProgress(value = 0.9,  detail = 'Creating display')
    
    
    sessionInfo$df_matches_to_show <- sessionInfo$df_matches
    counter$countervalue <- counter$countervalue + 1  
    
    observe( {
    colnames(sessionInfo$df_matches_to_show) =  c(
      'NCT ID',
      'Title',
      'Phase',
      'Study Source',
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
    criteria_columns <- c(
      'Biomarker Inclusion',
      'Biomarker Exclusion',
      'Chemotherapy Exclusion',
      'Immunotherapy Exclusion Criteria',
      'HIV Exclusion Criteria',
      'Gender',
      'Min Age',
      'Max Age',
      'PLT Criteria',
      'WBC Criteria',
      'Performance Status Criteria'
      
    )

    new_match_dt <-
      datatable(
        sessionInfo$df_matches_to_show,
        colnames = c(
          'NCT ID',
          'Title',
          'Phase',
          'Study Source',
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
        
        extensions = c('FixedColumns', 'Buttons'),
        #extensions = c('FixedColumns'),
        
        
        options = list(
          lengthMenu = c(50, 100, 500),
          processing = TRUE,
          dom =  '<"top"f<"clear">>t<"bottom"Blip <"clear">>',
          buttons = list(
            list(
              extend = 'columnToggle',
              text = 'Show Criteria' ,
              columns = match(criteria_columns, names(sessionInfo$df_matches_to_show))
            )
            # ,
            # 'excel'
          ),
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
            list(width = '300px', targets = c(2,9)),
            list(width = '200px', targets = match(criteria_columns, names(sessionInfo$df_matches_to_show))),
            
        list(className = 'dt-center', targets = c(3, 7:ncol(sessionInfo$df_matches_to_show))),
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
      ) %>% DT::formatStyle(columns = c(2,4,7,9), fontSize = '75%')
 
 
    output$df_matches_data = DT::renderDT(new_match_dt, server = TRUE)
    }
    )
    # browser()
    sessionInfo$run_count <- sessionInfo$run_count+1 
    click("toggleSidebar")
    
    }
    )
  }
  )
  
 
  
  
  # observeEvent(input$disease_selected,
  #              {
  #                print("disease selected button pressed from modal")
  #                disease_name <- input$selected_node[[length(input$selected_node)]]
  #                print(disease_name)
  #                if(is.null(sessionInfo$disease_buttons)) {
  #                  print('first disease button')
  #                  sessionInfo$disease_buttons <-  c(disease_name)
  #                } else {
  #                  print("already have some buttons")
  #                  append(sessionInfo$disease_buttons, disease_name) 
  #                }
  #                print(sessionInfo$disease_buttons)
  #                removeModal()
  #              }
  #              
  # )
  # 
  
  
  observeEvent(input$gyn_selected_node, ignoreNULL = TRUE, {
    print("gyn node selected")
    #browser()
    print(input$gyn_selected_node)
   # browser()
    if(length(input$gyn_selected_node) > 0) {
      output$gyn_selected <- renderText(input$gyn_selected_node[[length(input$gyn_selected_node)]] )
    } else {
      output$gyn_selected <- renderText('Malignant Female Reproductive System Neoplasm')
    }
    
    # browser()
    print("----------")
  })
  
  observeEvent(input$lung_selected_node, ignoreNULL = TRUE, {
    print("lung node selected")
   # print(input$lung_selected_node)
    # browser()
    if(length(input$lung_selected_node) > 0) {
      output$lung_selected <- renderText(input$lung_selected_node[[length(input$lung_selected_node)]] )
    } else {
      output$lung_selected <- renderText('Lung Cancer')
    }  
    # browser()
    print("----------")
  })
  
  observeEvent(input$solid_selected_node, ignoreNULL = TRUE, {
    print("node selected")
  
    #print(input$solid_selected_node)
    # browser()
    if(length(input$solid_selected_node) > 0) {
      output$solid_selected <- renderText(input$solid_selected_node[[length(input$solid_selected_node)]] )
    } else {
      output$solid_selected <- renderText('Solid Tumor')
    }
    # browser()
    print("----------")
  })
  
  observeEvent(input$biomarker_bsmodal_close, {
    # Clear the biomarker dataframe
    
    print("biomarker modal closed")
    sessionInfo$biomarker_df = data.frame(matrix(
      ncol = 3,
      nrow = 0,
      dimnames = list(NULL, c("Code", "Value" , "Biomarkers"))
    ))
    print(input$egfr)
    if (input$egfr == "Positive") {
      t <-
        data.frame(Code = "C134501",
                   Value = "YES",
                   Biomarkers = "EGFR Positive")
      sessionInfo$biomarker_df = rbind(sessionInfo$biomarker_df, t)
      t <-
        data.frame(Code = "C98357",
                   Value = "YES",
                   Biomarkers = "EGFR Gene Mutation")
      sessionInfo$biomarker_df = rbind(sessionInfo$biomarker_df, t)
    } else if (input$egfr == "Negative") {
      t <-
        data.frame(Code = "C150501",
                   Value = "YES",
                   Biomarkers = "EGFR Negative")
      sessionInfo$biomarker_df = rbind(sessionInfo$biomarker_df, t)
    }
    
    print(input$alk)
    if (input$alk == "Positive") {
      t <-
        data.frame(Code = "C128831",
                   Value = "YES",
                   Biomarkers = "ALK Positive")
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
      t <-
        data.frame(Code = "C81945",
                   Value = "YES",
                   Biomarkers = "ALK Gene Mutation")
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    } else if (input$alk == "Negative") {
      t <-
        data.frame(Code = "C133707",
                   Value = "YES",
                   Biomarkers = "ALK Negative")
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    }
    
    
    
    print(input$ros1)
    if (input$ros1 == "Positive") {
      t <-
        data.frame(Code = "C155991",
                   Value = "YES",
                   Biomarkers = "ROS1 Positive")
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
      t <-
        data.frame(Code = "C130952",
                   Value = "YES",
                   Biomarkers = "ROS1 Gene Mutation")
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    } else if (input$ros1 == "Negative") {
      t <-
        data.frame(Code = "C153498",
                   Value = "YES",
                   Biomarkers = "ROS1 Negative")
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    }
    
    if (input$her2_neu == "Positive") {
      t <-
        data.frame(Code = "C68748",
                   Value = "YES",
                   Biomarkers = "HER2/Neu Positive")
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    } else if (input$ros1 == "Negative") {
      t <-
        data.frame(Code = "C68749",
                   Value = "YES",
                   Biomarkers = "HER2/Neu Negative")
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    }
    
    print(input$nras)
    if (input$nras == "Positive") {
      t <-
        data.frame(Code = "C171618",
                   Value = "YES",
                   Biomarkers = "NRAS Positive")
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
      t <-
        data.frame(Code = "C41381",
                   Value = "YES",
                   Biomarkers = "NRAS Gene Mutation")
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    } else if (input$nras == "Negative") {
      t <-
        data.frame(Code = "C142837",
                   Value = "YES",
                   Biomarkers = "NRAS Negative")
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    }
    
    print(input$kras)
    if (input$kras == "Positive") {
      t <-
        data.frame(Code = "C142134",
                   Value = "YES",
                   Biomarkers = "KRAS Positive")
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
      t <-
        data.frame(Code = "C41361",
                   Value = "YES",
                   Biomarkers = "KRAS Gene Mutation")
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    } else if (input$kras == "Negative") {
      t <-
        data.frame(Code = "C142879",
                   Value = "YES",
                   Biomarkers = "KRAS Negative")
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    }
    
    print(input$hras)
    if (input$hras == "Positive") {
      t <-
        data.frame(Code = "C171617",
                   Value = "YES",
                   Biomarkers = "HRAS Positive")
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
      t <-
        data.frame(Code = "C45934",
                   Value = "YES",
                   Biomarkers = "HRAS Gene Mutation")
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    } else if (input$hras == "Negative") {
      t <-
        data.frame(Code = "C160373",
                   Value = "YES",
                   Biomarkers = "HRAS Gene Mutation Negative")
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    }
    
    print(input$biomarker_list)
    if (length(input$biomarker_list) > 0) {
      add_disease_sql <-
        "select code as Code , 'YES' as Value, pref_name as Biomarkers from ncit where pref_name = ?"
      session_conn = DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
      for (row in 1:length(input$biomarker_list)) {
        new_disease <- input$biomarker_list[row]
        df_new_disease <-
          dbGetQuery(session_conn, add_disease_sql,  params = c(new_disease))
        #browser(0)
        sessionInfo$biomarker_df <-
          rbind(sessionInfo$biomarker_df, df_new_disease)
      }
      DBI::dbDisconnect(session_conn)
    }
    print(sessionInfo$biomarker_df)
  })
  
  observeEvent(input$gyn_add_disease, {
    print("add gyn disease")
    if(length(input$gyn_selected_node) > 0) {
      new_disease <- input$gyn_selected_node[[length(input$gyn_selected_node)]]
    } else {
      new_disease <- 'Malignant Female Reproductive System Neoplasm'
    }
    
    print(paste("new disease = ", new_disease))
    add_disease_sql <- "select distinct nci_thesaurus_concept_id as Code , 'YES' as Value, preferred_name as Diseases from  trial_diseases where display_name = ?"
    session_conn = DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
    df_new_disease <- dbGetQuery(session_conn, add_disease_sql,  params = c(new_disease))
    #browser()
    DBI::dbDisconnect(session_conn)
    sessionInfo$disease_df <- rbind(sessionInfo$disease_df, df_new_disease)
    print(sessionInfo$disease_df)
    
    
  }
  )
  observeEvent(input$lung_add_disease, {
    print("add lung disease")
    if(length(input$lung_selected_node) > 0) {
      new_disease <- input$lung_selected_node[[length(input$lung_selected_node)]]
    } else {
      new_disease <- 'Lung Cancer'
    }
    
    print(paste("new disease = ", new_disease))
    add_disease_sql <- "select distinct nci_thesaurus_concept_id as Code , 'YES' as Value, preferred_name as Diseases from  trial_diseases where display_name = ?"
    session_conn = DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
    df_new_disease <- dbGetQuery(session_conn, add_disease_sql,  params = c(new_disease))
    #browser()
    DBI::dbDisconnect(session_conn)
    sessionInfo$disease_df <- rbind(sessionInfo$disease_df, df_new_disease)
    print(sessionInfo$disease_df)
    
    
  }
  )
  
  observeEvent(input$solid_add_disease, {
    print("add solid disease")
    if(length(input$solid_selected_node) > 0) {
      new_disease <- input$solid_selected_node[[length(input$solid_selected_node)]]
    } else {
      new_disease <- 'Solid Tumor'
    }
    print(paste("new disease = ", new_disease))
    add_disease_sql <- "select distinct nci_thesaurus_concept_id as Code , 'YES' as Value, preferred_name as Diseases from  trial_diseases where display_name = ?"
    session_conn = DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
    df_new_disease <- dbGetQuery(session_conn, add_disease_sql,  params = c(new_disease))
    #browser()
    DBI::dbDisconnect(session_conn)
    sessionInfo$disease_df <- rbind(sessionInfo$disease_df, df_new_disease)
    print(sessionInfo$disease_df)
    
    
  }
  )
  
  observeEvent(input$cancer_add_disease, {
    print("cancer_add_disease")
    
    #See if we have subtypes, if so use them, otherwise see if we have a maintype/subtype 
    # and use that
    if(length(input$subtype_typer) > 0  ){
      #
      # There are subtypes selected -- use those and do not use the selected maintype
      #
      add_disease_sql <- "select distinct nci_thesaurus_concept_id as Code , 'YES' as Value, preferred_name as Diseases from  trial_diseases where display_name = ?"
      session_conn = DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
      for (row in 1:length(input$subtype_typer)) {
        new_disease <- input$subtype_typer[row]
        df_new_disease <-
          dbGetQuery(session_conn, add_disease_sql,  params = c(new_disease))
        #browser()
        sessionInfo$disease_df <-
          rbind( sessionInfo$disease_df, df_new_disease)
      }
     
      DBI::dbDisconnect(session_conn)
      
    } else if(length(input$maintype_typer) > 0  & input$maintype_typer != "" ){
      # No subtype, get the maintype and add that in.
      print(paste("add maintype as disease - ", input$maintype_typer))
      add_disease_sql <- "select distinct nci_thesaurus_concept_id as Code , 'YES' as Value, preferred_name as Diseases from  trial_diseases where display_name = ?"
      session_conn = DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
      new_disease <- input$maintype_typer
      df_new_disease <-
        dbGetQuery(session_conn, add_disease_sql,  params = c(new_disease))
      sessionInfo$disease_df <-
        rbind( sessionInfo$disease_df, df_new_disease)
      DBI::dbDisconnect(session_conn)
      
      
    }
    
    #
    #Now see if we have stage diseases 
    #
    #See if we have subtypes, if so use them, otherwise see if we have a maintype/subtype 
    # and use that
    if(length(input$stage_typer) > 0  ){
      add_disease_sql <- "select distinct nci_thesaurus_concept_id as Code , 'YES' as Value, preferred_name as Diseases from  trial_diseases where display_name = ?"
      session_conn = DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
      for (row in 1:length(input$stage_typer)) {
        new_disease <- input$stage_typer[row]
        df_new_disease <-
          dbGetQuery(session_conn, add_disease_sql,  params = c(new_disease))
        #browser()
        sessionInfo$disease_df <-
          rbind( sessionInfo$disease_df, df_new_disease)
      }
      
      DBI::dbDisconnect(session_conn)
    }
    
  }
  )
  
  observe( {
  show_disease_dt <- datatable(
    sessionInfo$disease_df,
    class = 'cell-border stripe compact wrap ',
    rownames = FALSE,
    selection = "single",
    options = list(
      escape = FALSE,
      searching = FALSE,
      paging = FALSE,
      info = FALSE,
      #scrollX = TRUE,
      #scrolly = '200px',
      pageLength = 999,
      scrollY = "100px",
      lengthMenu = list(c(600, -1), c("600", "All")),
      style = "height:100px; overflow-y: scroll; overflow-x:scroll;padding:10px;",
      columnDefs = list(
        list(visible = FALSE, targets = c(0,1))
       # ,
       # list(
       #   targets = c(1),
       #   render = JS("function(data){return data.replace(/\\n/g, '<br />');}")
       # )

      )
    )
  )  %>% DT::formatStyle(columns = c(0), fontSize = '75%')
  output$diseases <- DT::renderDT(show_disease_dt)
  } )

  
  observe( {
    show_biomarker_dt <- datatable(
      sessionInfo$biomarker_df,
      class = 'cell-border stripe compact wrap ',
      rownames = FALSE,
      selection = "single",
      options = list(
        escape = FALSE,
        searching = FALSE,
        paging = FALSE,
        info = FALSE,
        #scrollX = TRUE,
        #scrolly = '200px',
        pageLength = 999,
        scrollY = "100px",
        lengthMenu = list(c(600, -1), c("600", "All")),
        style = "height:100px; overflow-y: scroll; overflow-x:scroll;padding:10px;",
        columnDefs = list(
          list(visible = FALSE, targets = c(0,1))
          # ,
          # list(
          #   targets = c(1),
          #   render = JS("function(data){return data.replace(/\\n/g, '<br />');}")
          # )
          
        )
      )
    )  %>% DT::formatStyle(columns = c(0), fontSize = '75%')
    output$biomarkers <- DT::renderDT(show_biomarker_dt)
  } )
  
  # 
  # Handle the cancer center intput
  #
  
  observeEvent(input$cancer_center_picker, ignoreNULL = FALSE, {
    print("cancer center -- ")
    print(paste(' --> ', input$cancer_center_picker))
    if (length(input$cancer_center_picker) > 0) {
      withProgress(value = 0.5, message = "Computing cancer center matches",
                   {
                     print("we have a cancer center")
                     for (row in 1:length(input$cancer_center_picker)) {
                       print(paste("row ", row , " is ", input$cancer_center_picker[row]))
                     }
                     sessionInfo$cancer_center_df <-
                       get_api_studies_for_cancer_centers(input$cancer_center_picker)
                   })
    } else {
      sessionInfo$cancer_center_df <- NA
      
      
    }
  })
  
  #
  # Handle the changing on the distance parameter by the user
  #
  observeEvent(input$distance_in_miles, ignoreNULL = FALSE, {
    print(paste('distance_in_miles=', input$distance_in_miles))
    if (is.na(input$distance_in_miles) |
        input$distance_in_miles == '') {
      print("miles is NA")
      sessionInfo$distance_in_miles <- NA
      sessionInfo$distance_df <- NA
    } else if(!is.na(sessionInfo$latitude) & !is.na(sessionInfo$longitude)) {
      withProgress(value= 0.5, message = "Computing geolocation matches",
        {
      print("computing distance_df")
      distance_df <-
        get_api_studies_for_location_and_distance(sessionInfo$latitude,
                                                  sessionInfo$longitude,
                                                  input$distance_in_miles)
     
      sessionInfo$distance_df <- distance_df
      sessionInfo$distance_in_miles <- input$distance_in_miles
 
        }
      )
    }
  })
  
  
  # This gets called whenever filtering has changed 
  
  get_filterer <- function() {
    print("get_filterer")
    match_types_string <- paste(input$match_types_picker, collapse = " & ")
    phase_string <- paste(input$phases, collapse = " | ")
    study_source_string <- paste(input$study_source, collapse = " | ")
    
    #filterer <- match_types_string
    print(paste("match_types_string = ", match_types_string))
    print(paste("phase_string = ", phase_string))
    
    if (match_types_string != '') {
      match_types_string <- paste("(", match_types_string, ")")
    }
    if (phase_string != '') {
      phase_string <- paste("(", phase_string, ")")
    }
    
    if (study_source_string != ''){
      study_source_string <- paste("(", study_source_string, ")")
    }
    
    filterer <- ""
    

    if(match_types_string != '') {
      if(phase_string != '') {
        filterer <- paste(match_types_string," & ", phase_string) 
      } else {
        filterer <- match_types_string
      }
    }
    else {
      if(phase_string != '') {
        filterer <- phase_string
      }
    }
    
    sites_search <- paste(input$sites, collapse = " | ")
    if (filterer == "") {
      if (!is_empty(sites_search)) {
        filterer <- paste(" ( " , sites_search , " ) ")
      }
    } else {
      if (!is_empty(sites_search)) {
        p2 <- paste(" ( " , sites_search , " ) ")
        filterer <- paste(filterer, p2, sep = " & ")
      }
    }
    
    if (filterer == "") {
      if (!is_empty(study_source_string)) {
        filterer <- study_source_string
      }
    } else {
      if (!is_empty(study_source_string)) {
        
        filterer <- paste(filterer, study_source_string , sep = " & ")
      }
    }
    
    print(paste("filterer =", filterer))
    
    if(!is.null(sessionInfo$df_matches_to_show)) {
      print("we have data")
      
      if (filterer != "") {
        print("there is filtering")
        if (input$disease_type == 'lead') {
          filterer <-
            gsub('disease_matches', 'lead_disease_matches', filterer)
        }
        t <- sessionInfo$df_matches
        sessionInfo$df_matches_to_show <- filter_(t, filterer)
      } else {
        print(" no filtering ")
        sessionInfo$df_matches_to_show <- sessionInfo$df_matches
      }
      
      #
      # Now match against the distance dataframe, if it exists
      #
      
      td <- sessionInfo$distance_df
      di <- sessionInfo$distance_in_miles
      #browser()
      if (!is.null(nrow(td)) && nrow(td) > 0) {
        print(paste("miles to filter by ", di))
        print(paste('original length - ', nrow(sessionInfo$df_matches_to_show) ))
        
        df_m <- sessionInfo$df_matches_to_show
        df_miles <- sessionInfo$distance_df
        t3 <-
          sqldf('select df_m.* from df_m join df_miles on df_m.clean_nct_id = df_miles.nct_id')
        sessionInfo$df_matches_to_show <- t3
        print(paste('after lrvd filter length - ', nrow(sessionInfo$df_matches_to_show) ))
        
        
      } else if (!is.na(sessionInfo$distance_in_miles)) {
        df_m <- sessionInfo$df_matches_to_show
        t3 <- sqldf('select df_m.* from df_m where 1=0')
        sessionInfo$df_matches_to_show <- t3
      }
      
      #
      # Now filter against the cancer center dataframe, if we have data there
      #
        if (!is.null(nrow(sessionInfo$cancer_center_df)) && nrow(sessionInfo$cancer_center_df) > 0) {
  
          print("filtering against the cancer center df")
          df_m <- sessionInfo$df_matches_to_show
          df_cancer_center <- sessionInfo$cancer_center_df
          t3 <- sqldf('select df_m.* from df_m join df_cancer_center on df_m.clean_nct_id = df_cancer_center.nct_id')
          sessionInfo$df_matches_to_show <- t3
        }
      
      
      #
      # Now add in the filter against RVD
      #
      #trvd <- sessionInfo$rvd_df

      
      trvd <- rvd_df
     # browser()
       if(!is.null(nrow(trvd)) && nrow(trvd) > 0 ) {
         print(paste('original length - ', nrow(sessionInfo$df_matches_to_show) ))
         
         df_m <- sessionInfo$df_matches_to_show
         
         t4 <-  sqldf('select df_m.* from df_m join trvd on df_m.clean_nct_id = trvd.nct_id')
         sessionInfo$df_matches_to_show <- t4
         print(paste('after lrvd filter length - ', nrow(sessionInfo$df_matches_to_show) ))
         
       }
      
    }
    else {
      print("no data, nothing to do")
    }
    
    return(filterer)
    
  }
    

  #
  # Note that counter$countervalue is here because it gets changed during the search and match button click to 
  # make this called upon first load of a given search
  #
  
  observeEvent(
  c(input$match_types_picker,
    input$disease_type
    ,
    sessionInfo$distance_in_miles,
    sessionInfo$cancer_center_df,
    input$phases,
    input$sites,
    input$study_source,
    counter$countervalue
  )
,
  ignoreNULL = FALSE,
  {
    
    
    filterer <- get_filterer()
    print(paste("filterer =", filterer))
  
  }
)
  
  output$downloadData <- downloadHandler(
    filename = function() {
      paste('fctc_boolean_match_csv_', Sys.Date(), '.csv', sep = "")
    },
    content = function(file) {
      write.csv(sessionInfo$df_matches_to_show, file, row.names = FALSE)
    }
  )
  
}
shinyApp(ui, server)