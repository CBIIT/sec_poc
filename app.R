library(shiny)
library(DBI)
library(xtable)
library(DT)
library(plyr)
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
library(shinyalert)
library(shinyWidgets)
library(pool)
library(RPostgres)

# options(
#   shiny.launch.browser = FALSE,
#   shiny.port = 8080
# )

#
#
dbinfo <- config::get()

# Sys.setenv(LD_LIBRARY_PATH = "/usr/local/lib")

local_dbname <- dbinfo$dbname
local_host <- dbinfo$host
local_user <- dbinfo$user
local_password <- dbinfo$password
local_port <- dbinfo$port
pool_idleTimeout <- 300 # 5 minute pool timeout default
pool_minSize <- 0
pool_maxSize <- 3
pool_validationInterval <- 60000000000

pool_con <- dbPool( # drv = RPostgreSQL::PostgreSQL(),
  drv = RPostgres::Postgres(),
  dbname = local_dbname,
  host = local_host,
  user = local_user,
  password = local_password,
  port = local_port,
  idleTimeout = pool_idleTimeout,
  minSize = pool_minSize,
  maxSize = pool_maxSize,
  validationInterval = pool_validationInterval
)

print(pool_con)

#
# generate_safe_query ----
# This is a function that takes the database connection pool as an argument.  It returns
# a function that takes a given R dbapi function (like dbGetQuery) and arguments and tries to run that
# statement given the passed in function. If the statement fails, it sleeps for the
# designated time, recreates the pool, and tries again.  If the error condition is
# transient in nature, (for example, network connectivity is lost, or the AWS database goes dormant and needs to be spun back up)
# this will successful recover from that.
#
# Other errors won't recover but will be noted before bailing out.
#
#
wait_times <- c(2, 2)

generate_safe_query <- function(pool) {
  function(db_function, ...) {
    # print("in safe query")
    tryCatch(
      {
        #  xx<-lapply(sys.call()[-1], deparse)
        #  print(paste0(ifelse(nchar(names(xx))>0, paste0(names(xx),"="), ""), unlist(xx), collapse=", "))
        db_function(pool, ...)
      },
      error = function(e) {
        print("ERROR IN safe_query ")
        print(e$message)
        # browser()
        print("error - going to try to recreate the pool")
        tryCatch(
          {
            Sys.sleep(wait_times[1]) # Sleep two seconds
            # poolClose(pool_con)
            pool_con <<- dbPool(
              drv = RPostgres::Postgres(),
              dbname = local_dbname,
              host = local_host,
              user = local_user,
              password = local_password,
              idleTimeout = pool_idleTimeout,
              minSize = pool_minSize,
              maxSize = pool_maxSize,
              validationInterval = pool_validationInterval
            )
            db_function(pool, ...)
          },
          error = function(e) {
            # Unexpected error
            print(paste("cannot recreate pool - going to sleep and try one more time  ", e$message))
            tryCatch(
              {
                Sys.sleep(wait_times[2]) # Sleep two seconds
                # poolClose(pool_con)
                pool_con <<- dbPool(
                  drv = RPostgres::Postgres(),
                  dbname = local_dbname,
                  host = local_host,
                  user = local_user,
                  password = local_password,
                  idleTimeout = pool_idleTimeout,
                  minSize = pool_minSize,
                  maxSize = pool_maxSize,
                  validationInterval = pool_validationInterval
                )
                db_function(pool, ...)
              },
              error = function(e) {
                # Unexpected error
                print(paste("cannot recreate pool - bailing out ", e$message))
                stop(e)
              }
            )
          }
        )
      }
    )
  }
}
############

safe_query <<- generate_safe_query(pool_con)

source("get_api_studies_for_biomarkers.R")
source("hh_collapsibleTreeNetwork.R")
source("getDiseaseTreeData.R")
source("paste3.R")
source("get_lat_long_for_zipcode.R")

source("disease_tree_modal.R")
source("check_if_any.R")
source("get_ncit_code_for_intervention.R")
source("get_api_studies_with_rvd_gte.R")
source("get_subtypes_for_maintypes.R")
source("get_stage_for_types.R")
source("get_org_families.R")
source("get_api_studies_for_cancer_centers.R")

source("get_umls_crosswalk.R")
source("get_api_studies_for_disease_v2.R")
source("fix_blood_results.R")
source("get_api_studies_for_location_and_distance.R")
source("get_maintypes_for_diseases.R")
source("eval_prior_therapy.R")
source("eval_prior_therapy_app.R")
source("eval_criteria.R")
source("get_api_studies_with_va_sites.R")
source("get_api_studies_for_postal_code.R")
source("transform_perf_status.R")
source("get_biomarkers_from_evs.R")
source("get_ncit_codes_from_ehr_codes.R")
source("prior_therapy.R")
# source('get_biomarker_trial_counts_for_diseases.R')

source("guided_questions.R")


ui <- fluidPage(
  useShinyjs(),
  useShinyFeedback(),
  useSweetAlert(),
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
  tags$script('
  $( document ).ready(function() {
    $("#crosswalk_bsmodal").on("hidden.bs.modal", function (event) {
    x = new Date().toLocaleString();
    // window.alert("biomarker  modal was closed at " + x);
    Shiny.onInputChange("crosswalk_bsmodal_close",x);
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
  tags$style(HTML(".text-truncate {
  max-width: 40ch;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}")),

  #
  # set the shiny bsmodal to be as large as it can be.
  #

  tags$head(tags$style(HTML("

                        .modal-lg {
                        width: 95vw; height: 95vh;

                        }
                      "))),
  titlePanel(title = div(img(src = "SEC-logo.png"), style = "text-align: center;"), windowTitle = "Structured Eligibility Criteria Trial Search"),
  sidebarLayout(
    div(
      id = "Sidebar", # width = 3,
      # tags$head(tags$style(".modal-dialog{  overflow-y: auto;pointer-events: initial; overflow-x: auto;  max-width: 100%;}")),
      #    tags$head(tags$style(".modal-body{ min-height:700px}")),
      sidebarPanel(
        tags$style(".well {background-color:#F0F8FF;}"),
        style = "overflow-y:scroll; max-height: 90vh; position:relative;",
        width = 3,
        fluidRow(
          column(8, align = "left", h4("Search Criteria")),
          column(
            4,
            alight = "right",
            style = "display:inline-block; margin-top: 10px; ",
            actionLink("clear_all", label = "Clear All")
          )
        ),
        actionButton("show_guided_questions", "Guided Search Criteria"),
        hr(),
        textInput(
          "patient_zipcode",
          label = "Geolocation",
          value = "",
          placeholder = "Enter five digit zip code"
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
          selected = "Unspecified",
          multiple = FALSE,
          options = list(width = "72px"),
          choicesOpt = NULL,
          width = "auto",
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
        selectizeInput("disease_tree_typer",
          label = "Disease Trees",
          NULL, selected = NULL, multiple = FALSE
        ),
        checkboxInput("show_staging_checkbox", "Show staging", FALSE),
        actionButton("show_disease_tree_button", "Show Tree"),
        hr(),
        DTOutput("diseases"),
        actionButton("show_biomarkers", "Biomarkers"),
        DTOutput("biomarkers"),
        radioGroupButtons(
          inputId = "brain_mets",
          label = "Brain/CNS metastases",
          choices = c("Yes", "No", "Unspecified"),
          selected = "Unspecified",
          justified = FALSE,
          status = "primary"
        ),
        numericInput(
          "patient_wbc",
          "WBC (/uL)",
          min = 0,
          value = NA
          # max = 120,
          # step = 1
        ),
        bsTooltip(
          "patient_wbc",
          "Enter the WBC in /uL -- e.g. 6000",
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
          # step = 1
        ),
        bsTooltip(
          "patient_plt",
          "Enter the platlets in /uL -- e.g. 100000",
          placement = "bottom",
          trigger = "hover",
          options = NULL
        ),
        #   selectizeInput("maintype_typer", label = "Maintypes", NULL , multiple = TRUE),
        #    selectizeInput("disease_typer", label = "Diseases", NULL, multiple = TRUE),



        #----
        # (outputId="intervention_controls")  ,
        selectizeInput("prior_therapy", label = "Prior Therapy", NULL, multiple = TRUE),
        selectizeInput("misc_typer", label = "NCIt Search", NULL, multiple = TRUE),
        actionButton("show_crosswalk", "Add non-NCI codes"),
        DTOutput("crosswalk_codes"),
        actionButton("search_and_match", "SEARCH AND MATCH"),
        tags$p(""),
        tags$p("Search over active treatment or screening trials with at least 1 site recruiting patients",
          style = "font-size:10px;"
        )
      ),
      actionButton("show_generic_disease_tree_modal", "s")
    ),
    mainPanel(
      id = "Main",
      # actionButton("toggleSidebar", "<-")
      actionLink("toggleSidebar", NULL, icon("arrow-left"), style = "text-align: left;"),
      bsTooltip(
        "toggleSidebar",
        "Hide/show the search criteria",
        placement = "bottom",
        trigger = "hover",
        options = NULL
      ),

      #   guidedQuestionsUI("modalExample"),

      fluidRow(
        column(
          4,
          pickerInput(
            "match_types_picker",
            label = "Participant Attributes",
            choice = NULL,
            multiple = TRUE,
            options = pickerOptions(actionsBox = TRUE),
            choicesOpt = NULL,
            width = "auto",
            inline = FALSE
          )
        ),
        column(
          2,
          radioButtons(
            "disease_type",
            "Disease types:",
            c(
              "Trial" = "trial",
              "Lead" = "lead"
            ),
            inline = FALSE
          )
        ),
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
            width = "auto",
            inline = FALSE
          )
        ),
        column(
          2,
          # style='padding-left:5px; padding-right:10px; ',

          # offset = 1,

          pickerInput
          (
            "sites",
            label = "Study Sites",
            choices = c(
              "VA" = "  ( va_matches == TRUE )  ",
              "NIH CC" = " ( nih_cc_matches == TRUE ) "
            ),
            selected = NULL,
            multiple = TRUE,
            options = list(),
            choicesOpt = NULL,
            width = "auto",
            inline = FALSE
          )
        ),
        column(
          2,
          # style='padding-left:5px; padding-right:10px; ',

          # offset = 1,

          numericInput(
            "distance_in_miles",
            label = "Distance (mi)",
            "",
            min = 1,
            max = 999999
            # step = 10
            # ,
            # width = '100px'
          )
        )
      ),
      fluidRow(
        column(
          2,
          # style='padding-left:5px; padding-right:10px; ',

          # offset = 1,

          pickerInput
          (
            "study_source",
            label = "Study Source",
            choices = c(
              "National" = " ( study_source == 'National' )",
              "Institutional" = " ( study_source == 'Institutional' ) ",
              "Externally Peer Reviewed" = "  ( study_source == 'Externally Peer Reviewed' )  ",
              "Industrial" = " ( study_source == 'Industrial' ) "
            ),
            selected = NULL,
            multiple = TRUE,
            options = list(),
            choicesOpt = NULL,
            width = "auto",
            inline = FALSE
          )
        ),
        column(5,
          offset = 2,
          style = "padding-left:10px; padding-right:10px; ",
          selectizeInput("cancer_center_picker", label = "Cancer Center", NULL, multiple = TRUE)
        )
      ),
      fluidRow(
        column(
          width = 12,
          offset = 0,
          style = "padding:10px;",
          DT::dataTableOutput("df_matches_data")
        )
      ),
      fluidRow(
        column(
          width = 2,
          offset = 0,
          downloadButton("downloadData", "Download Match Data",
            style =
              "padding:4px; font-size:80%"
          )
        )
      ),
      fluidRow(
        column(
          width = 12,
          offset = 0,
          style = "padding:10px;",
          uiOutput("df_trial_diseases_header"),
          DT::dataTableOutput("df_trial_diseases")
        )
      ),
      # Generic disease tree bsmodal ----
      bsModal("disease_tree_bsmodal", "Select Disease", "show_generic_disease_tree_modal",
        size = "large",
        fluidPage(
          id = "treePanel_gen",
          fluidRow(column(
            12,
            wellPanel(
              id = "tPanel_gen",
              # style = "overflow-y:scroll;  max-height: 750vh; height: 70vh; overflow-x:scroll; max-width: 4000px",
              # style = "overflow-y:scroll;  max-height: 750vh; height: 70vh; overflow-x:scroll;",

              # collapsibleTreeOutput("generic_disease_tree", height = "75vh", width =
              #                         '4000px')
              collapsibleTreeOutput("generic_disease_tree", height = "75vh")
            )
          )),
          fluidRow(
            column(2, "Disease selected:"),
            column(6, align = "left", textOutput("generic_disease_tree_disease_selected")),
            column(2, align = "right"), actionButton("generic_disease_tree_add_disease", label = "Add disease")
          ),
          fluidRow(textOutput("hidden_root_node"))
        )
      ),
      bsModal("cancer_bsmodal", "Select Disease", "show_cancer",
        size = "large",
        fluidPage(
          id = "cancer_bs_modal_page", # You are here
          fluidRow(
            column(
              4,
              selectizeInput("maintype_typer",
                label = "Primary Cancer Type/Condition ",
                NULL, selected = NULL, multiple = FALSE
              )
            ),
            column(
              4,
              selectizeInput("subtype_typer",
                label = "Subtype",
                NULL, multiple = TRUE
              )
            ),
            column(
              4,
              selectizeInput("stage_typer",
                label = "Stage",
                NULL, multiple = TRUE
              )
            )
          ),
          fluidRow(
            column(
              width = 1, offset = 10, align = "right",
              actionButton("cancer_add_disease", label = "Add disease")
            )
          )
        )
      ),
      bsModal("crosswalk_bsmodal", "Enter non-NCI codes", "show_crosswalk",
        size = "medium",
        fluidPage(
          id = "crosswalk_bsmodal_page",
          bsAlert("crosswalk_modal_alert"),
          fluidRow(radioButtons("crosswalk_ontology", "Ontology ",
            choices = c(
              "ICD10CM" = "ICD10CM", "LOINC" = "LOINC", "SNOMEDCT" = "SNOMEDCT"
              # ,
              # "RXNORM" = "RXNORM"
            )
          )),
          fluidRow(textInput("crosswalk_code", "Code")),
          fluidRow("Name:", textOutput("crosswalk_name", inline = TRUE)),
          fluidRow("Best NCIt code match:", textOutput("matched_ncit_name", inline = TRUE)),
          fluidRow(actionButton("find_crosswalk_codes", "Add Code"))
        )
      ),
      bsModal("biomarker_bsmodal", "Select biomarkers", "show_biomarkers",
        size = "large",
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
            ),
            # you are here
            radioGroupButtons(
              inputId = "nras",
              label = "NRAS",
              choices = c("Positive", "Negative", "Unspecified"),
              selected = "Unspecified",
              justified = FALSE,
              status = "primary"
            ),
            radioGroupButtons(
              inputId = "kras",
              label = "KRAS",
              choices = c("Positive", "Negative", "Unspecified"),
              selected = "Unspecified",
              justified = FALSE,
              status = "primary"
            ),
            radioGroupButtons(
              inputId = "hras",
              label = "HRAS",
              choices = c("Positive", "Negative", "Unspecified"),
              selected = "Unspecified",
              justified = FALSE,
              status = "primary"
            ),
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
            uiOutput(outputId = "biomarker_controls")
            # selectizeInput("biomarker_list", label = "Biomarker List", NULL, multiple = TRUE),
          )
        ))
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
    disease_df = data.frame(matrix(ncol = 3, nrow = 0, dimnames = list(NULL, c("Code", "Value", "Diseases")))),
    idisease_df = data.frame(matrix(ncol = 3, nrow = 0, dimnames = list(NULL, c("Code", "Value", "Diseases")))),
    biomarker_df = data.frame(matrix(ncol = 3, nrow = 0, dimnames = list(NULL, c("Code", "Value", "Biomarkers")))),
    distance_df = NA,
    latitude = NA,
    longitude = NA,
    ncit_search_df = data.frame(matrix(ncol = 3, nrow = 0, dimnames = list(NULL, c("Code", "Value", "Biomarkers")))),
    rvd_df = NA,
    cancer_center_df = NA,
    crosswalk_df = data.frame(matrix(ncol = 3, nrow = 0, dimnames = list(NULL, c("Code", "Value", "Description")))),
    session_id = NA,
    prior_therapy_data_df = NA,
    disease_tree_root_node = NA,
    df_disease_tree_choices = NA,
    disease_tree_c_code_from_button = NULL
  )



  tgt <- NA
  shinyjs::hide("show_generic_disease_tree_modal")
  shinyjs::hide("hidden_root_node")
  shinyjs::hide("show_guided_questions")


  progress <- Progress$new(session, min = 1, max = 10)
  progress$set(
    message = "Initializing SEC POC",
    detail = ""
  )

  # get a TGT from UMLS
  if (dbinfo$enable_umls) {
    print("enabling UMLS calls")
    d <- POST(
      "https://utslogin.nlm.nih.gov/cas/v1/api-key",
      body = list(
        apikey = dbinfo$api_key
      ),
      accept_json(),
      encode = "form"
    )

    if (d$status_code == 201) {
      text_data <- content(d, "text")
      print("getting tgt")
      left <- str_locate(text_data, "https")
      right <- str_locate(text_data, '\" method')
      tgt <- substr(text_data, left[1], right[1] - 1)
      print(paste("tgt = ", tgt))
    } else {
      shinyalert("UMLS Error", paste("UMLS Crosswalk is not available at this time.-- ", d$status_code), type = "error")
    }
  }

  counter <- reactiveValues(countervalue = 0)
  shinyjs::disable("subtype_typer")
  shinyjs::disable("show_disease_tree_button")

  target_lvd <- ymd(today()) - years(2)
  con <- pool_con

  rvd_df <- safe_query(dbGetQuery, paste("select nct_id from trials where record_verification_date >= '", target_lvd, "'", sep = ""))
  print(paste("nrows", nrow(rvd_df)))

  df_number_sites <- safe_query(dbGetQuery, "select count(nct_id) as number_sites, nct_id from trial_sites where org_status = 'ACTIVE' group by nct_id")

  df_disease_choice_data <-
    safe_query(
      dbGetQuery,
      "with preferred_names as (
select  preferred_name, count(preferred_name) as name_count
      from trial_diseases ds where ds.disease_type like '%maintype%' or ds.disease_type like  '%subtype%'
      group by preferred_name
      )
select n.code, pn.preferred_name from preferred_names pn join ncit n on pn.preferred_name = n.pref_name
      order by name_count desc"
    )

  df_disease_choices <- setNames(
    as.vector(df_disease_choice_data[["code"]]), as.vector(df_disease_choice_data[["preferred_name"]])
  )

  guided_disease_choices_data <- safe_query(
    dbGetQuery,
    "select distinct nci_thesaurus_concept_id, preferred_name from trial_diseases;"
    # select * from trials inner join trial_diseases on trials.nct_id = trial_diseases.nct_id where trials.max_age_in_years >= 45 and trial_diseases.nci_thesaurus_concept_id in ('C132886') limit 1;
  )

  guided_disease_choices <- setNames(
    as.vector(guided_disease_choices_data[["nci_thesaurus_concept_id"]]), as.vector(guided_disease_choices_data[["preferred_name"]])
  )

  # browser()
  df_misc_choice_data <-
    safe_query(
      dbGetQuery,
      "select code, pref_name from ncit where concept_status <> 'Obsolete_Concept' or concept_status is null order by parents, pref_name
      "
    )
  df_misc_choices <- setNames(
    as.vector(df_misc_choice_data[["code"]]), as.vector(df_misc_choice_data[["pref_name"]])
  )

  progress$set(value = 2)

  df_disease_tree_choices_raw <-
    safe_query(
      dbGetQuery,
      "with real_tree_data as (
select nci_thesaurus_concept_id, display_name
    from distinct_trial_diseases ds
    where (ds.disease_type = 'maintype' or ds.disease_type like  '%maintype-subtype%' or ds.nci_thesaurus_concept_id =
'C4913' )
    and nci_thesaurus_concept_id not in ('C2991', 'C2916')
    and not display_name like 'Other %'
 UNION
   select '' as ncit_thesaurus_concept_id, '' as display_name
  )
 select nci_thesaurus_concept_id, display_name from real_tree_data
	order by display_name"
    )
  sessionInfo$df_disease_tree_choices <- setNames(
    as.vector(df_disease_tree_choices_raw[["nci_thesaurus_concept_id"]]), as.vector(df_disease_tree_choices_raw[["display_name"]])
  )

  df_disease_tree_choices <- setNames(
    as.vector(df_disease_tree_choices_raw[["nci_thesaurus_concept_id"]]), as.vector(df_disease_tree_choices_raw[["display_name"]])
  )

  updateSelectizeInput(session,
    "disease_tree_typer",
    choices = df_disease_tree_choices,
    selected = NULL,
    server = FALSE
  )

  df_prior_therapy_data <- safe_query(dbGetQuery, "with descendants as
  (
    select descendant from ncit_tc where parent in ('C25218', 'C1908', 'C62634', 'C163758')
  ),
  descendants_to_remove as
  (
    select descendant from ncit_tc where parent in ('C25294')
  )
  ,
  good_codes as (
    select descendant from descendants
    except
    select descendant from descendants_to_remove)

  select gc.descendant as code, n.pref_name
  from good_codes gc join ncit n on gc.descendant = n.code")



  df_prior_therapy_choices <- setNames(
    as.vector(df_prior_therapy_data[["code"]]), as.vector(df_prior_therapy_data[["pref_name"]])
  )

  sessionInfo$prior_therapy_data_df <- df_prior_therapy_choices

  progress$set(value = 3)

  df_maintypes <-
    safe_query(
      dbGetQuery,
      " select NULL as display_name union
      select display_name
      from distinct_trial_diseases ds where ds.disease_type = 'maintype' or ds.disease_type like  '%maintype-subtype%'
      order by display_name"
    )

  #   df_biomarker_list_s <-
  #     safe_query(dbGetQuery,
  #
  #       "with domain_set as (
  #         select tc.descendant as code  from ncit_tc tc where tc.parent in ( 'C36391',  -- Molecular Genetic Variation
  # 		                                                                   'C158948', -- Rearrangement detected
  # 																		   'C158949' -- Rearragement negative
  # 																			)
  # 		union
  #         select  n.code as code  from ncit n  where   (n.concept_status not in ( 'Obsolete_Concept', 'Retired_Concept') or n.concept_status is null)
  # 		   and n.semantic_type = 'Cell or Molecular Dysfunction'
  #
  #       )
  # 	,
  # biomarkers as (select ds.code, coalesce(nullif(display_name,''), pref_name) as biomarker from domain_set ds join ncit n
  # on ds.code = n.code and (n.concept_status not in ( 'Obsolete_Concept', 'Retired_Concept') or n.concept_status is null)
  # )
  # select * from biomarkers
  # order by biomarker
  #       "
  #     )

  df_biomarker_list_t <- get_biomarkers_from_evs()
  colnames(df_biomarker_list_t) <- c("type", "code", "biomarker")
  df_biomarker_list_s <- subset(df_biomarker_list_t, select = -c(type))

  # To get around the wacko server side bug, render this thing here as a normal static selectize but with the biomarker dataframe from the server side
  output$biomarker_controls <- renderUI({
    tagList(
      selectizeInput("biomarker_list", label = "Biomarker Search", choices = df_biomarker_list_s$biomarker, selected = NULL, multiple = TRUE) # HH you are here
    )
  })
  #-----

  #
  ## Get the info for the patient attributes picker input
  #

  df_criteria_picker_data <-
    safe_query(
      dbGetQuery,
      "with all_crit_types as (
        select 'disease_matches == TRUE'  as criteria_match_code , 'Diseases' as criteria_type_title, -100 as criteria_column_index
        UNION
        select 'gender_matches == TRUE'  as criteria_match_code , 'Gender' as criteria_type_title, -50 as criteria_column_index
        union
        select ' (age_matches == TRUE | is.na(age_matches) ) '  as criteria_match_code , 'Age' as criteria_type_title, -10 as criteria_column_index
        union
        select ' ( biomarker_api_exc_matches == FALSE | is.na(biomarker_api_exc_matches) ) ' as criteria_match_code,
              'Biomarker Exclusion' as criteria_type_title, -5 as criteria_column_index
        union
         select ' ( biomarker_api_inc_matches == TRUE | is.na(biomarker_api_inc_matches) ) ' as criteria_match_code,
              'Biomarker Inclusion' as criteria_type_title, -3 as criteria_column_index
        union
        select
		case criteria_type_sense
		   when 'Inclusion' then ' ( ' || criteria_type_code || '_matches == TRUE | is.na(' || criteria_type_code || '_matches) )   '
		   when 'Exclusion' then ' ( ' || criteria_type_code || '_matches == FALSE | is.na(' || criteria_type_code || '_matches) )   '
		end as criteria_match_code ,
     	criteria_type_title, criteria_column_index from criteria_types
        where criteria_type_active = 'Y'
      )
      select criteria_match_code, criteria_type_title from all_crit_types order by criteria_column_index"
    )

  criteria_picker_vec <- setNames(
    as.vector(df_criteria_picker_data[["criteria_match_code"]]), as.vector(df_criteria_picker_data[["criteria_type_title"]])
  )

  ###
  updatePickerInput(
    session,
    "match_types_picker",
    choices = criteria_picker_vec,
    selected = c("disease_matches == TRUE")
  )

  progress$set(value = 4)
  # browser()

  crit_sql <-
    "with site_counts as (
select count(nct_id) as number_sites, nct_id from trial_sites where org_status = 'ACTIVE' group by nct_id
)
    select
  '<a href=https://www.cancer.gov/about-cancer/treatment/clinical-trials/search/v?id=' ||  t.nct_id || '&r=1 target=\"_blank\">' || t.nct_id || '</a>' as nct_id,
  t.nct_id as clean_nct_id, age_expression, disease_names, diseases, gender, gender_expression, max_age_in_years, min_age_in_years,

  disease_names_lead, diseases_lead ,
  biomarker_exc_codes, biomarker_exc_names,
  biomarker_inc_codes, biomarker_inc_names,
  brief_title, phase, study_source , case study_source when 'National' then 1 when 'Institutional' then 2 when 'Externally Peer Reviewed' then 3 when 'Industrial' then 4 end study_source_sort_key ,
  sc.number_sites
  from trials t join site_counts sc on t.nct_id = sc.nct_id "
  df_crit <- safe_query(dbGetQuery, crit_sql)

  # HH Cutting here for dynamic criteria

  crit_types <- safe_query(
    dbGetQuery,
    "select criteria_type_id, criteria_type_code, criteria_type_title, criteria_type_active from criteria_types  where criteria_type_active = 'Y' order by criteria_type_id "
  )

  for (row in 1:nrow(crit_types)) {
    criteria_type_id <- crit_types[row, "criteria_type_id"]
    criteria_type_code <- crit_types[row, "criteria_type_code"]
    criteria_type_title <- crit_types[row, "criteria_type_title"]

    # get the criteria by type


    cdf <- safe_query(dbGetQuery, "select nct_id, trial_criteria_refined_text, trial_criteria_expression from trial_criteria where criteria_type_id = $1
                       and  trial_criteria_expression is not null and trial_criteria_expression <> '' ",
      params = c(criteria_type_id)
    )

    # Now rename to the columns in cdr based upon the abbr.


    names(cdf)[names(cdf) == "trial_criteria_refined_text"] <- paste(criteria_type_code, "_refined_text", sep = "")
    names(cdf)[names(cdf) == "trial_criteria_expression"] <- paste(criteria_type_code, "_expression", sep = "")

    # Now merge these columns into the df_crit dataframe with new names

    df_crit <-
      merge(
        df_crit,
        cdf,
        by.x = "clean_nct_id",
        by.y = "nct_id",
        all.x = TRUE
      )
  }

  # end of cut

  # sort the dataframe by study source ascending and then by number of sites descending

  df_crit <- df_crit[order(df_crit$study_source_sort_key, -df_crit$number_sites), ]

  progress$set(value = 5)

  # browser()

  dt_gyn_tree <- getDiseaseTreeData(safe_query, "C4913", use_ctrp_display_name = TRUE)
  dt_lung_tree <- getDiseaseTreeData(safe_query, "C4878", use_ctrp_display_name = TRUE)
  dt_solid_tree <- getDiseaseTreeData(safe_query, "C9292", use_ctrp_display_name = TRUE)


  # DBI::dbDisconnect(con)
  output$gyn_disease_tree <- renderCollapsibleTree({
    hh_collapsibleTreeNetwork(
      dt_gyn_tree,
      collapsed = TRUE,
      linkLength = 500,
      zoomable = FALSE,
      inputId = "gyn_selected_node",
      nodeSize = "nodeSize",
      # nodeSize = 14,
      aggFun = "identity",
      fontSize = 14 # ,
      # ,
      #  width = '2000px',
      #  height = '1700px'
    )
  })
  output$lung_disease_tree <- renderCollapsibleTree({
    hh_collapsibleTreeNetwork(
      dt_lung_tree,
      collapsed = TRUE,
      linkLength = 500,
      zoomable = FALSE,
      inputId = "lung_selected_node",
      nodeSize = "nodeSize",
      # nodeSize = 14,
      aggFun = "identity",
      fontSize = 14 # ,
      #  width = '2000px',
      #  height = '700px'
    )
  })
  output$solid_disease_tree <- renderCollapsibleTree({
    hh_collapsibleTreeNetwork(
      dt_solid_tree,
      collapsed = TRUE,
      linkLength = 450,
      zoomable = FALSE,
      inputId = "solid_selected_node",
      nodeSize = "nodeSize",
      # nodeSize = 14,
      aggFun = "identity",
      fontSize = 14 # ,
      #  width = '2000px',
      #  height = '700px'
    )
  })


  progress$set(value = 6)

  updateSelectizeInput(session,
    "maintype_typer",
    choices = df_maintypes$display_name,
    server = TRUE
  )

  updateSelectizeInput(session,
    "disease_typer",
    choices = df_disease_choices,
    server = TRUE
  )

  updateSelectizeInput(session,
    "misc_typer",
    choices = df_misc_choices,
    server = TRUE
  )

  #   updateSelectizeInput(session,
  #                        'ncit_search',
  #                        choices = df_misc_choices ,
  #                        server = TRUE)

  updateSelectizeInput(session,
    "prior_therapy",
    choices = df_prior_therapy_choices,
    server = TRUE
  )


  updateSelectizeInput(session,
    "cancer_center_picker",
    choices = get_org_families(),
    server = TRUE
  )
  progress$set(value = 7)
  progress$close()

  #  updateSelectizeInput(session,
  #                      'biomarker_list',
  #                      choices = df_biomarker_list_s$biomarker ,
  #                       server = TRUE)



  # Events from this point forward ----

  # Process passed in session data ----

  nextModal <- function(id, question, answeres, next_button_id) {
    modalDialog(
      title = "Guided Questions",
      selectInput(id, question, answeres),
      fluidRow(
        column(
          width = 8,
          textOutput("guided_total_trials")
        )
      ),
      footer = tagList(
        modalButton("Cancel"),
        actionButton(next_button_id, "Next"),
        actionButton("search_and_match_guided_select", "Finish and Search")
      ),
      easyClose = TRUE
    )
  }
  nextTextModal <- function(id, question, next_button_id) {
    modalDialog(
      title = "Guided Questions",
      textInput(
        id,
        label = question,
        value = ""
      ),
      fluidRow(
        column(
          width = 8,
          textOutput("guided_total_trials")
        )
      ),
      footer = tagList(
        modalButton("Cancel"),
        actionButton(next_button_id, "Next"),
        actionButton("search_and_match_guided_text", "Finish and Search")
      ),
      easyClose = TRUE
    )
  }
  nextSelectizeModal <- function(id, question, next_button_id) {
    modalDialog(
      title = "Guided Questions",
      selectizeInput(id, label = question, NULL, multiple = TRUE),
      fluidRow(
        column(
          width = 8,
          textOutput("guided_total_trials")
        )
      ),
      footer = tagList(
        modalButton("Cancel"),
        actionButton(next_button_id, "Next"),
        actionButton("search_and_match_guided_selectize", "Finish and Search")
      ),
      easyClose = TRUE
    )
  }
  # Return from this will contain each model setup
  testList <- getGuidedQuestionDataFrames(safe_query)
  testDf1 <- reactiveVal(testList[1])
  testDf2 <- reactiveVal(testList[[2]])
  holder <- reactiveVal(NULL)
  observeEvent(input$show_guided_questions, {
    if (testList[[1]][[1]][[4]] == TRUE) {
      updateSelectizeInput(session,
        testList[[1]][[1]][[3]][[1]],
        choices = testList[[1]][[1]][[6]],
        server = TRUE
      )
    }
    showModal(
      do.call(
        testList[[1]][[1]][[2]],
        testList[[1]][[1]][[3]]
      )
    )
  })
  observeEvent(input$guided_question1, {
    testDf1(recalculate_freq_from_dataframe(holder(), testDf1()[[1]], 1))
    testDf2(testList[[1]][[1]][[5]](testList[[2]], input[[testDf1()[[1]][[1]][[3]][[1]]]]))
    if (testDf1()[[1]][[2]][[4]] == TRUE) {
      updateSelectizeInput(session,
        testDf1()[[1]][[2]][[3]][[1]],
        choices = testDf1()[[1]][[2]][[6]],
        server = TRUE
      )
    }
    showModal(
      do.call(
        testDf1()[[1]][[2]][[2]],
        testDf1()[[1]][[2]][[3]]
      )
    )
  })
  observeEvent(input$guided_question2, {
    testDf1(recalculate_freq_from_dataframe(holder(), testDf1()[[1]], 2))
    testDf2(testList[[1]][[2]][[5]](testDf2(), input[[testDf1()[[1]][[2]][[3]][[1]]]]))
    if (testDf1()[[1]][[3]][[4]] == TRUE) {
      updateSelectizeInput(session,
        testDf1()[[1]][[3]][[3]][[1]],
        choices = testDf1()[[1]][[3]][[6]],
        server = TRUE
      )
    }
    showModal(
      do.call(
        testDf1()[[1]][[3]][[2]],
        testDf1()[[1]][[3]][[3]]
      )
    )
  })
  observeEvent(input$guided_question3, {
    testDf1(recalculate_freq_from_dataframe(holder(), testDf1()[[1]], 3))
    testDf2(testList[[1]][[3]][[5]](testDf2(), input[[testDf1()[[1]][[3]][[3]][[1]]]]))
    if (testDf1()[[1]][[4]][[4]] == TRUE) {
      updateSelectizeInput(session,
        testDf1()[[1]][[4]][[3]][[1]],
        choices = testDf1()[[1]][[4]][[6]],
        server = TRUE
      )
    }
    showModal(
      do.call(
        testDf1()[[1]][[4]][[2]],
        testDf1()[[1]][[4]][[3]]
      )
    )
  })
  observeEvent(input$guided_question4, {
    testDf1(recalculate_freq_from_dataframe(holder(), testDf1()[[1]], 4))
    testDf2(testList[[1]][[4]][[5]](testDf2(), input[[testDf1()[[1]][[4]][[3]][[1]]]]))
    if (testDf1()[[1]][[5]][[4]] == TRUE) {
      updateSelectizeInput(session,
        testDf1()[[1]][[5]][[3]][[1]],
        choices = testDf1()[[1]][[5]][[6]],
        server = TRUE
      )
    }
    showModal(
      do.call(
        testDf1()[[1]][[5]][[2]],
        testDf1()[[1]][[5]][[3]]
      )
    )
  })
  observeEvent(input$update_guided_question1, {
    holder(testList[[1]][[1]][[5]](testList[[2]], input$update_guided_question1))
    output$guided_total_trials <- renderText({
      paste(sprintf("%s Trials match your criteria", nrow(holder())))
    })
    add_biomarker_sql <- "select code as \"Code\" , 'YES' as \"Value\", pref_name as \"Biomarkers\" from ncit where code in (%s);"
    biomarker_search_str <- ""
    for (code in input$update_guided_question1) {
      biomarker_search_str <- paste(biomarker_search_str, paste("'", code, sed = "',"))
    }
    biomarker_search_str <- gsub(" ", "", biomarker_search_str)
    biomarker_search_str <- substring(biomarker_search_str, 1, nchar(biomarker_search_str) - 1)
    df_new_biomarkers <- safe_query(
      dbGetQuery,
      sprintf(add_biomarker_sql, biomarker_search_str)
    )
    sessionInfo$biomarker_df <- df_new_biomarkers
  })
  observeEvent(input$age_guided, {
    holder(testList[[1]][["age"]][[5]](testDf2(), input$age_guided))
    output$guided_total_trials <- renderText({
      paste(sprintf("%s Trials match your criteria", nrow(holder())))
    })
    updateTextInput(session, "patient_age", value = input$age_guided)
  })
  observeEvent(input$performance_guided, {
    holder(testList[[1]][["performanceStatus"]][[5]](testDf2(), input$performance_guided))
    output$guided_total_trials <- renderText({
      paste(sprintf("%s Trials match your criteria", nrow(holder())))
    })
  })
  observeEvent(input$gender_guided, {
    holder(testList[[1]][["gender"]][[5]](testDf2(), input$gender_guided))
    output$guided_total_trials <- renderText({
      paste(sprintf("%s Trials match your criteria", nrow(holder())))
    })
    if (input$gender_guided == "BOTH") {
      updateRadioGroupButtons(session, "gender", selected = "Unspecified")
    } else {
      updateRadioGroupButtons(session, "gender", selected = str_to_title(input$gender_guided))
    }
  })

  observeEvent(input$disease_search_guided, {
    holder(testList[[1]][["diseases"]][[5]](testDf2(), input$disease_search_guided))
    output$guided_total_trials <- renderText({
      paste(sprintf("%s Trials match your criteria", nrow(holder())))
    })
    diseaseString <- ""
    for (code in input$disease_search_guided) {
      diseaseString <- paste(diseaseString, paste("'", code, sed = "',"))
    }
    diseaseString <- gsub(" ", "", diseaseString)
    diseaseString <- substring(diseaseString, 1, nchar(diseaseString) - 1)
    add_disease_sql <- "select distinct code as \"Code\" , 'YES' as \"Value\", pref_name as \"Diseases\" from  ncit where code in (%s);"
    df_new_disease <- safe_query(
      dbGetQuery,
      sprintf(add_disease_sql, diseaseString)
    )
    # rbind is another option but if done than we dont remove values if the deselect
    sessionInfo$disease_df <- df_new_disease
  })

  observe(label = "Get Session UUID", {
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[["show_guided_search"]])) {
      shinyjs::show("show_guided_questions")
    }

    if (!is.null(query[["session_id"]])) {
      prior_therapy_list <- c()
      disease_list <- c()
      df_diseases <- data.frame(matrix(ncol = 3, nrow = 0, dimnames = list(NULL, c("Code", "Value", "Diseases"))))
      sessionInfo$session_id <- query[["session_id"]]
      print(paste("session_id is ", sessionInfo$session_id))
      df_prior_therapy_interop_sql <- "
      with descendants as
            (
                select descendant from ncit_tc where parent in ('C25218', 'C1908', 'C62634', 'C163758')
            ),
        descendants_to_remove as
            (
                select descendant from ncit_tc where parent in ('C25294')
            )
			,
		good_codes as (
	      select descendant from descendants
		  except
		  select descendant from descendants_to_remove)

		select gc.descendant as code, n.pref_name
		from good_codes gc join ncit n on gc.descendant = n.code
        where n.code = $1
    "

      df_cancer_interop_sql <- "select tc.descendant from ncit_tc tc where tc.parent = 'C2991' and tc.descendant = $1 and tc.descendant <> 'C2991'"


      # browser()
      session_nodename <- safe_query(dbGetQuery,
        "select coalesce(nodename,'') as nodename from fhirops.search_session where session_uuid = $1",
        params = c(sessionInfo$session_id)
      )
      if (nrow(session_nodename) > 0 && nchar(session_nodename$nodename) > 0) {
        progress_title <- paste("Importing data from", session_nodename$nodename)
      } else {
        progress_title <- "Retrieving data"
      }

      session_data <-
        safe_query(dbGetQuery,
          "select concept_cd, valtype_cd, tval_char, nval_num,
                                         units_cd from fhirops.search_session_data where session_uuid = $1
                                         and concept_cd is not null",
          params = c(sessionInfo$session_id)
        )

      print(session_data)

      if (nrow(session_data) > 0) {
        progressSweetAlert(
          session = session, id = "myprogress",
          title = progress_title,
          display_pct = TRUE, value = 0
        )
        # Sys.sleep(1.0)
        progress_step <- 100 / nrow(session_data)
        for (row in 1:nrow(session_data)) {
          updateProgressBar(
            session = session,
            id = "myprogress",
            value = row * progress_step
          )
          #  Sys.sleep(2/nrow(session_data))
          concept_cd <- session_data[row, "concept_cd"]
          valtype_cd <- session_data[row, "valtype_cd"]
          tval_char <- session_data[row, "tval_char"]
          nval_num <- session_data[row, "nval_num"]

          if (concept_cd == "C25150") {
            # age
            if (valtype_cd == "N") {
              updateNumericInput(session, "patient_age", value = nval_num)
            }
          }
          if (concept_cd == "C51948") {
            # wbc
            #  if (valtype_cd == 'N') {
            updateNumericInput(session, "patient_wbc", value = nval_num)
            #  }
          }
          if (concept_cd == "C51951") {
            # platelets
            #   if (valtype_cd == 'N') {
            updateNumericInput(session, "patient_plt", value = nval_num)
            #  }
          }
          if (concept_cd == "C25720") {
            # zip code
            if (valtype_cd == "T") {
              updateTextInput(session, "patient_zipcode", value = tval_char)
            } else if (valtype_cd == "N") {
              updateTextInput(session, "patient_zipcode", value = toString(as.integer(nval_num)))
            }
          }
          if (concept_cd == "C46109") {
            # male
            updateRadioGroupButtons(session, "gender", selected = "Male")
          }
          if (concept_cd == "C46110") {
            # female
            updateRadioGroupButtons(session, "gender", selected = "Female")
          }

          concept_cds <- unlist(strsplit(concept_cd, ","))

          # Check for prior therapy (NLP )
          for (r in (1:length(concept_cds))) {
            df_prior_therapy_interop <-
              safe_query(dbGetQuery, df_prior_therapy_interop_sql, params = c(concept_cds[r]))
            if (nrow(df_prior_therapy_interop) > 0) {
              # browser()
              prior_therapy_list <- append(prior_therapy_list, df_prior_therapy_interop$code) # or pref name
            }
          }
          # See if concept_cd has commas in it
          # NLP Diseases - Experimental


          for (r in (1:length(concept_cds))) {
            print(paste("disease row : ", r, " concept_cd ", concept_cds[r]))

            df_cancer_interop <-
              safe_query(dbGetQuery, df_cancer_interop_sql, params = c(concept_cds[r]))
            print(df_cancer_interop)
            if (nrow(df_cancer_interop) > 0) {
              # browser()
              disease_list <- append(disease_list, concept_cd)
              # browser()
              #  add_disease_sql <- "select distinct nci_thesaurus_concept_id
              #            as \"Code\" , 'YES' as \"Value\",
              #            preferred_name as \"Diseases\" from  trial_diseases where nci_thesaurus_concept_id = $1"
              add_disease_sql <- "select distinct code
                        as \"Code\" , 'YES' as \"Value\",
                        pref_name as \"Diseases\" from  ncit where code = $1"
              df_new_disease <- safe_query(dbGetQuery, add_disease_sql, params = c(concept_cds[r]))
              df_diseases <- rbind(df_diseases, df_new_disease)
              print(paste("df_diseases ", df_diseases))
              # browser()
            }
          }
        }
        if (length(prior_therapy_list) > 0) {
          prior_therapy_list <- unique(prior_therapy_list)
          # browser()
          # updateSelectizeInput(session, "prior_therapy", selected = prior_therapy_list)
          updateSelectizeInput(session, "prior_therapy",
            selected = prior_therapy_list,
            choices = sessionInfo$prior_therapy_data_df,
            server = TRUE
          )
        }
        if (nrow(df_diseases) > 0) {
          sessionInfo$disease_df <- distinct(df_diseases)
        }
        closeSweetAlert(session = session)
      }
    }
    # output$session_string <-
    #  renderText(sessionInfo$session_id)
  })


  observeEvent(input$toggleSidebar, {
    if (sessionInfo$sidebar_shown) {
      print("hiding sidebar")
      sessionInfo$sidebar_shown <- FALSE
      removeCssClass("Main", "col-sm-8")
      addCssClass("Main", "col-sm-12")
      shinyjs::hide(id = "Sidebar")
    } else {
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
  observeEvent(input$clear_all, {
    updateTextInput(session, "patient_zipcode", value = NA)
    updateNumericInput(session, "patient_wbc", value = NA)
    updateNumericInput(session, "patient_plt", value = NA)
    updateNumericInput(session, "patient_age", value = NA)
    updateRadioGroupButtons(session, "hiv", selected = "Unspecified")
    updateRadioGroupButtons(session, "gender", selected = "Unspecified")
    updateRadioGroupButtons(session, "brain_mets", selected = "Unspecified")
    updatePickerInput(session, "performance_status", selected = "C159685")
    sessionInfo$disease_df <- sessionInfo$disease_df[0, ]
    sessionInfo$biomarker_df <- sessionInfo$biomarker_df[0, ]
    sessionInfo$crosswalk_df <- sessionInfo$crosswalk_df[0, ]
    output$city_state <- NULL
    sessionInfo$latitude <- NA
    sessionInfo$longitude <- NA
    updateSelectizeInput(session, "misc_typer", selected = NA)
    updateSelectizeInput(session, "prior_therapy", selected = NA)
  })

  observeEvent(input$intervention_search, {
    print("intervention search")
  })

  observeEvent(input$maintype_typer, ignoreNULL = FALSE, {
    print("maintype_typer")
    if (length(input$maintype_typer) > 0 & input$maintype_typer != "") {
      print("enabled subtype_type")
      shinyjs::enable("subtype_typer")
      shinyjs::enable("stage_typer")


      df_new_subtypes <- get_subtypes_for_maintypes(input$maintype_typer, safe_query)
      df_stages <- get_stage_for_types(input$maintype_typer, safe_query)



      updateSelectizeInput(session,
        "subtype_typer",
        choices = df_new_subtypes$display_name,
        server = TRUE
      )

      updateSelectizeInput(session,
        "stage_typer",
        choices = df_stages$display_name,
        server = TRUE
      )
    } else {
      df_new_subtypes <-
        shinyjs::disable("subtype_typer")
      shinyjs::disable("stage_typer")

      updateSelectizeInput(session,
        "subtype_typer",
        choices = data.frame(matrix(ncol = 1, nrow = 0, dimnames = list(NULL, c("display_name")))),
        server = TRUE
      )


      updateSelectizeInput(session,
        "stage_typer",
        choices = data.frame(matrix(ncol = 1, nrow = 0, dimnames = list(NULL, c("display_name")))),
        server = TRUE
      )
    }
  })

  observeEvent(input$subtype_typer, ignoreNULL = FALSE, {
    print("subtype_typer")
    # browser()
    if (length(input$subtype_typer) > 0) {
      print("enabled stage_typer")
      shinyjs::enable("stage_typer")


      # df_stages <- get_stage_for_types(input$subtype_typer[1], session_con)
      df_stages <- get_stage_for_types(input$subtype_typer, safe_query)



      updateSelectizeInput(session,
        "stage_typer",
        choices = df_stages$display_name,
        server = TRUE
      )
    } else if (length(input$maintype_typer) > 0 & input$maintype_typer != "") {
      shinyjs::enable("stage_typer")


      df_stages <- get_stage_for_types(input$maintype_typer, safe_query)

      updateSelectizeInput(session,
        "stage_typer",
        choices = df_stages$display_name,
        server = TRUE
      )
    } else {
      shinyjs::disable("stage_typer")
      updateSelectizeInput(session,
        "stage_typer",
        choices = data.frame(matrix(ncol = 1, nrow = 0, dimnames = list(NULL, c("display_name")))),
        server = TRUE
      )
    }
  })

  ### search_for_trials
  search_for_trials <- function() {
    print("search and match")
    print(paste("age : ", input$patient_age))
    print("diseases : ")
    print(input$disease_typer)
    print(paste("gender : ", input$gender))
    # browser()
    #
    # Make a new dataframe for the patient data
    #
    sel <- data.frame(matrix(ncol = 2, nrow = 0))
    colnames(sel) <- c("Code", "Value")

    print(paste("performance status", input$performance_status))

    # First check for a valid zipcode

    if (!is.null(input$patient_zipcode) && input$patient_zipcode != "") {
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


    withProgress(message = "Matching Clinical Trials", detail = "Creating data", value = 0.0, {
      if (!is.na(input$patient_age)) {
        print("we have an age")
        sel[nrow(sel) + 1, ] <- c("C25150", toString(input$patient_age))
      }

      # add a disease for now

      # sel[nrow(sel) + 1, ] = c("C8953", "YES")

      # browser()


      print(paste("performance status", input$performance_status))

      if (length(input$performance_status) > 0) {
        print("adding performance status")
        sel[nrow(sel) + 1, ] <- c(input$performance_status, "YES")
      }

      if (length(input$disease_typer) > 0) {
        for (row in 1:length(input$disease_typer)) {
          sel[nrow(sel) + 1, ] <- c(input$disease_typer[row], "YES")
        }
      }

      if (length(input$misc_typer) > 0) {
        for (row in 1:length(input$misc_typer)) {
          sel[nrow(sel) + 1, ] <- c(input$misc_typer[row], "YES")
        }
      }

      if (length(input$prior_therapy) > 0) {
        for (row in 1:length(input$prior_therapy)) {
          sel[nrow(sel) + 1, ] <- c(input$prior_therapy[row], "YES")
        }
      }
      # Add in any disease and biomarkers that may have been input

      if (nrow(sessionInfo$disease_df) > 0) {
        sel <- rbind(sel, sessionInfo$disease_df[c("Code", "Value")])
      }

      if (nrow(sessionInfo$biomarker_df) > 0) {
        sel <- rbind(sel, sessionInfo$biomarker_df[c("Code", "Value")])
      }

      # Add in crosswalk codes
      if (nrow(sessionInfo$crosswalk_df) > 0) {
        sel <- rbind(sel, sessionInfo$crosswalk_df[c("Code", "Value")])
      }

      if (input$gender == "Male") {
        sel[nrow(sel) + 1, ] <- c("C46109", "YES")
      } else if (input$gender == "Female") {
        sel[nrow(sel) + 1, ] <- c("C46110", "YES")
      }

      if (input$hiv == "Yes") {
        sel[nrow(sel) + 1, ] <- c("C15175", "YES")
      } # else if (input$hiv == 'No') {
      # sel[nrow(sel) + 1,] = c('C15175', "NO")

      #  }
      # browser()

      if (input$brain_mets == "Yes") {
        sel[nrow(sel) + 1, ] <- c("C4015", "YES")
      }


      if (!is.na(input$patient_plt)) {
        print(paste("we have a platelet count ", input$patient_plt))
        sel[nrow(sel) + 1, ] <- c("C51951", toString(input$patient_plt))
      }
      if (!is.na(input$patient_wbc)) {
        print(paste("we have a wbc ", input$patient_wbc))
        sel[nrow(sel) + 1, ] <- c("C51948", toString(input$patient_wbc))
      }

      sel_codes <- sel$Code
      possible_disease_codes_df <- sessionInfo$disease_df
      # sel[which(sel$Value == 'YES'),]  # NOTE USE TRANSITIVE CLOSURE TO MAKE SURE IF I NEED TO
      print("---- possible disease codes -----")
      print(possible_disease_codes_df)
      sel_codes2 <- paste("'", sel$Code, "'", sep = "")
      csv_codes <- paste(sel_codes2, collapse = ",")
      print(csv_codes)

      setProgress(value = 0.1, detail = "Matching on disease")

      #
      # Now get the disease matching studies
      #
      disease_df <-
        get_api_studies_for_disease_v2(possible_disease_codes_df$Code)
      # browser()
      df_crit$api_disease_match <-
        df_crit$clean_nct_id %in% disease_df$nct_id # will set T/F for each row

      # Get the VA studies
      setProgress(value = 0.2, detail = "Examining VA sites")

      va_df <- get_api_studies_with_va_sites()
      print(va_df)
      df_crit$va_match <- df_crit$clean_nct_id %in% va_df$nct_id
      # print(df_crit$va_match)

      # Get the NIH CC studies
      nih_cc_df <- get_api_studies_for_postal_code("20892")
      df_crit$nih_cc_match <-
        df_crit$clean_nct_id %in% nih_cc_df$nct_id

      setProgress(value = 0.3, detail = "Computing biomarker matches ")
      if (nrow(sessionInfo$biomarker_df) > 0) {
        biomarker_exc_df <- get_api_studies_for_biomarkers(sessionInfo$biomarker_df$Code, "exclusion")
        biomarker_inc_df <- get_api_studies_for_biomarkers(sessionInfo$biomarker_df$Code, "inclusion")
        trials_with_biomaker_inc_df <- safe_query(
          dbGetQuery,
          "select nct_id from trials where biomarker_inc_codes is not null"
        )
        trials_with_biomaker_exc_df <- safe_query(
          dbGetQuery,
          "select nct_id from trials where biomarker_exc_codes is not null"
        )

        # df_crit$biomarker_api_exc_matches <- df_crit$clean_nct_id %in% biomarker_exc_df$nct_id

        #
        # These next two lines are a bit tricky
        # First, if there the API returns the NCT ID for the inclusion or exclusion, then the sum will be two and TRUE is set
        # Otherwise -- see if there is a criteria of the type for a NCT ID -- sum will be one.  Else - no criteria of a type for a trial
        # set the result to NA (null) so we don't toss out NULL values vacuously
        #
        df_crit <- transform(df_crit, biomarker_api_inc_matches = ifelse(clean_nct_id %in% biomarker_inc_df$nct_id +
          clean_nct_id %in% trials_with_biomaker_inc_df$nct_id == 2, TRUE,
        ifelse(clean_nct_id %in% biomarker_inc_df$nct_id +
          clean_nct_id %in% trials_with_biomaker_inc_df$nct_id == 1, FALSE,
        NA
        )
        ))
        df_crit <- transform(df_crit, biomarker_api_exc_matches = ifelse(clean_nct_id %in% biomarker_exc_df$nct_id +
          clean_nct_id %in% trials_with_biomaker_exc_df$nct_id == 2, TRUE,
        ifelse(clean_nct_id %in% biomarker_exc_df$nct_id +
          clean_nct_id %in% trials_with_biomaker_exc_df$nct_id == 1, FALSE,
        NA
        )
        ))
        # browser()
      } else {
        df_crit$biomarker_api_exc_matches <- NA
        df_crit$biomarker_api_inc_matches <- NA
      }
      # browser()

      # Load prior therapy previously saved by ETL job.

      # Select thesaurus codes as a comma-delimited list.
      inc_sql <- "select nct_id, string_agg(nci_thesaurus_concept_id, ',') as pt_api_inc_codes
      from trial_prior_therapies where eligibility_criterion = 'inclusion' and inclusion_indicator='TRIAL'
      group by nct_id"
      trials_with_prior_therapy_inc_df <- safe_query(dbGetQuery, inc_sql)
      exc_sql <- "select nct_id, string_agg(nci_thesaurus_concept_id, ',') as pt_api_exc_codes
      from trial_prior_therapies where eligibility_criterion='exclusion' and inclusion_indicator='TRIAL'
      group by nct_id"
      trials_with_prior_therapy_exc_df <- safe_query(dbGetQuery, exc_sql)

      df_crit <- merge(df_crit, trials_with_prior_therapy_inc_df, by.x = "clean_nct_id", by.y = "nct_id", all.x = TRUE)
      df_crit <- merge(df_crit, trials_with_prior_therapy_exc_df, by.x = "clean_nct_id", by.y = "nct_id", all.x = TRUE)

      setProgress(value = 0.3, detail = "Computing patient maintypes")

      # Get the patient maintypes
      patient_maintypes_df <-
        get_maintypes_for_diseases(possible_disease_codes_df$Code, safe_query)
      print(paste("patient maintypes = ", patient_maintypes_df))
      s2 <-
        paste("'", patient_maintypes_df$maintype, "'", sep = "")
      c2 <- paste(s2, collapse = ",")

      setProgress(value = 0.4, detail = "Computing trial maintypes")

      maintype_studies_all_sql <-
        paste(
          "select distinct nct_id from trial_maintypes where nci_thesaurus_concept_id in (",
          c2,
          ")"
        )

      maintype_studies_all <- safe_query(
        dbGetQuery,
        maintype_studies_all_sql
      )

      #
      # Logic for the lead disease match is to check that the study matches per api AND matches for lead disease maintype
      #
      df_crit$lead_disease_match <-
        df_crit$clean_nct_id %in% disease_df$nct_id &
          df_crit$clean_nct_id %in% maintype_studies_all$nct_id

      patient_data_env <- new.env(size = 200L)

      print("Instantiating patient data")
      for (row in 1:nrow(sel)) {
        code <- sel[row, "Code"]
        codeVal <- sel[row, "Value"]
        #   #   print(code)
        if (!is.na(suppressWarnings(as.numeric(codeVal)))) {
          eval(parse(text = paste(code, "<-", codeVal)))
          eval(parse(text = paste(code, "<-", codeVal)), envir = patient_data_env)

          print(paste(code, "<-", codeVal))
        } else {
          eval(parse(text = paste(
            code, "<-", "'", trimws(codeVal), "'",
            sep = ""
          )), envir = patient_data_env)
          print(paste(code, "<-", "'", trimws(codeVal), "'", sep = ""))
        }
        #    incProgress(amount = step,
        #                message = 'Computing Matches',
        #                'Evaluating patient data')
      }

      setProgress(value = 0.5, detail = "Creating match matrix")

      # browser()
      print("creating the full match dataframe")
      #  print(input$disease_type)
      df_matches <-
        # data.table(
        data.frame(
          "nct_id" = df_crit$nct_id,
          "brief_title" = df_crit$brief_title,
          "phase" = df_crit$phase,
          "study_source" = df_crit$study_source,
          "num_trues" = NA,
          "disease_codes" = df_crit$diseases,
          "disease_names" = df_crit$disease_names,
          "disease_codes_lead" = df_crit$diseases_lead,
          "disease_names_lead" = df_crit$disease_names_lead,
          "disease_matches" = df_crit$api_disease_match,
          "lead_disease_matches" = df_crit$lead_disease_match,
          "biomarker_exc_names" = df_crit$biomarker_exc_names,
          "biomarker_api_exc_matches" = df_crit$biomarker_api_exc_matches,
          "biomarker_inc_names" = df_crit$biomarker_inc_names,
          "biomarker_api_inc_matches" = df_crit$biomarker_api_inc_matches,
          stringsAsFactors = FALSE
        )



      group1_sql <- "select criteria_type_code, criteria_type_title, criteria_type_sense from criteria_types
where criteria_type_active = 'Y' and criteria_column_index < 2000
order by criteria_column_index "
      df_group1 <- safe_query(dbGetQuery, group1_sql)

      # Add rows for the new Prior Therapy data from the API, for comparison.
      # TODO: replace pt_inc and pt_exc with these when we are ready.
      df_group1[nrow(df_group1) + 1, ] <- c("pt_api_inc", "PT Inclusion (API)", "Inclusion")
      df_group1[nrow(df_group1) + 1, ] <- c("pt_api_exc", "PT Exclusion (API)", "Exclusion")

      group2_sql <- "select criteria_type_code, criteria_type_title, criteria_type_sense from criteria_types
where criteria_type_active = 'Y' and criteria_column_index >= 2000
order by criteria_column_index "
      df_group2 <- safe_query(dbGetQuery, group2_sql)

      # set the debug flag for evals (or not )
      patient_data_env$debug_expressions <- dbinfo$debug_expressions

      #
      # Now get the refined text and descriptions for the dynamic criteria groups -- and for the
      # Static criteria as well
      #

      for (row in 1:nrow(df_group1)) {
        base_string <- df_group1[row, "criteria_type_code"]
        matches_code <- paste(base_string, "_matches", sep = "")

        # TODO(jcallaway): confirm the logic we want about displaying prior therapy
        # results in the UI, especially around if there is no patient PT entered
        # (input$prior_therapy is NULL) or the trial has no PT criteria (trial_codes
        # is empty).
        if ((base_string == "pt_api_inc") || (base_string == "pt_api_exc")) {
          codes_str <- paste(base_string, "_codes", sep = "")
          df_matches$foo <- lapply(
            df_crit[, codes_str],
            function(trial_codes) compute_pt_matches(trial_codes, input$prior_therapy, safe_query)
          )
        } else {
          df_matches[, paste(base_string, "_refined_text", sep = "")] <- df_crit[, paste(base_string, "_refined_text", sep = "")] # human readable
          df_matches[, paste(base_string, "_expression", sep = "")] <- df_crit[, paste(base_string, "_expression", sep = "")]
          df_matches$foo <-
            lapply(
              df_matches[, paste(base_string, "_expression", sep = "")],
              function(x) {
                eval_prior_therapy_app(csv_codes, x, safe_query,
                  eval_env =
                    patient_data_env
                )
              }
            )
        }
        names(df_matches)[names(df_matches) == "foo"] <- matches_code
      }

      df_matches$va_matches <- df_crit$va_match
      df_matches$nih_cc_matches <- df_crit$nih_cc_match
      df_matches$gender <- df_crit$gender
      df_matches$gender_criteria <- df_crit$gender_expression
      df_matches$gender_matches <- NA
      df_matches$min_age_in_years <- df_crit$min_age_in_years
      df_matches$max_age_in_years <- df_crit$max_age_in_years
      df_matches$age_criteria <- df_crit$age_expression
      df_matches$age_matches <- NA

      for (row in 1:nrow(df_group2)) {
        base_string <- df_group2[row, "criteria_type_code"]
        df_matches[, paste(base_string, "_refined_text", sep = "")] <- df_crit[, paste(base_string, "_refined_text", sep = "")]
        df_matches[, paste(base_string, "_expression", sep = "")] <- df_crit[, paste(base_string, "_expression", sep = "")]
        df_matches$foo <-
          lapply(
            df_matches[, paste(base_string, "_expression", sep = "")],
            function(x) {
              eval_prior_therapy_app(csv_codes, x, session_conn,
                eval_env =
                  patient_data_env
              )
            }
          )


        names(df_matches)[names(df_matches) == "foo"] <- paste(base_string, "_matches", sep = "")
      }
      df_matches$clean_nct_id <- df_crit$clean_nct_id
      #    browser()


      # Once these are working -- roll them up in a master loop
      # browser()
      setProgress(value = 0.6, detail = "Creating criteria matches")




      setProgress(value = 0.7, detail = "Creating criteria matches")


      df_matches$age_matches <-
        lapply(
          df_matches$age_criteria,
          function(x) {
            eval_criteria(x, eval_env = patient_data_env)
          }
        )

      df_matches$gender_matches <-
        lapply(
          df_matches$gender_criteria,
          function(x) {
            eval_criteria(x, eval_env = patient_data_env)
          }
        )

      # Magic call to fix up the dataframe after the lapply calls which may create lists all the way down....
      df_temp <- as.data.frame(lapply(df_matches, unlist))
      df_matches <- df_temp

      # df_matches <- as.data.frame(lapply(df_matches, unlist))


      # browser()
      print(Sys.time())
      sessionInfo$df_matches <- df_matches
      print("creating table to display")

      setProgress(value = 0.9, detail = "Creating display")


      sessionInfo$df_matches_to_show <- sessionInfo$df_matches
      counter$countervalue <- counter$countervalue + 1

      observe({
        newColNames <- c(
          "NCT ID",
          "Title",
          "Phase",
          "Study Source",
          "# Matches",
          "Disease Codes",
          "Disease Names",
          "Lead Disease Codes",
          "Lead Disease Names",
          "Disease",
          "Lead Disease",
          "Biomarker Exclusion Names",
          "Biomarker Exclusion",
          "Biomarker Inclusion Names",
          "Biomarker Inclusion"
        )
        initially_hidden_columns <- c(
          "clean_nct_id", "# Matches",
          "Disease Codes", "Lead Disease Codes", "Gender",
          "Gender Expression", "Min Age",
          "Max Age",
          "Age Expression", "Biomarker Exclusion Names", "Biomarker Inclusion Names"
        )
        criteria_columns <- c(
          "Gender",
          "Min Age",
          "Max Age", "Biomarker Exclusion Names", "Biomarker Inclusion Names"
        )

        inclusion_match_column_names <- c(
          "Lead Disease", "Disease", "VA Sites",
          "NIH CC",
          "Gender Match",
          "Age Match",
          "Biomarker Inclusion"
        )
        exclusion_match_column_names <- c("Biomarker Exclusion")

        for (row in 1:nrow(df_group1)) {
          base_string <- df_group1[row, "criteria_type_title"]
          if (base_string != "PT Inclusion (API)" && base_string != "PT Exclusion (API)") {
            newColNames <- append(newColNames, c(base_string, paste(base_string, "Expression"), paste(base_string, "Match")))
            initially_hidden_columns <- append(initially_hidden_columns, c(base_string, paste(base_string, "Expression")))
            criteria_columns <- append(criteria_columns, base_string)
            if (df_group1[row, "criteria_type_sense"] == "Inclusion") {
              inclusion_match_column_names <- append(inclusion_match_column_names, paste(base_string, "Match"))
            } else {
              exclusion_match_column_names <- append(exclusion_match_column_names, paste(base_string, "Match"))
            }
          }
        }

        newColNames <- append(newColNames, c("PT Inclusion (API) Match", "PT Exclusion (API) Match"))
        inclusion_match_column_names <- append(inclusion_match_column_names, "PT Inclusion (API) Match")
        exclusion_match_column_names <- append(exclusion_match_column_names, "PT Exclusion (API) Match")

        newColNames <- append(newColNames, c(
          "VA Sites",
          "NIH CC",
          "Gender",
          "Gender Expression",
          "Gender Match",
          "Min Age",
          "Max Age",
          "Age Expression",
          "Age Match"
        ))
        for (row in 1:nrow(df_group2)) {
          base_string <- df_group2[row, "criteria_type_title"]
          newColNames <- append(newColNames, c(base_string, paste(base_string, "Expression"), paste(base_string, "Match")))
          initially_hidden_columns <- append(initially_hidden_columns, c(base_string, paste(base_string, "Expression")))
          criteria_columns <- append(criteria_columns, base_string)
          if (df_group2[row, "criteria_type_sense"] == "Inclusion") {
            inclusion_match_column_names <- append(inclusion_match_column_names, paste(base_string, "Match"))
          } else {
            exclusion_match_column_names <- append(exclusion_match_column_names, paste(base_string, "Match"))
          }
        }
        newColNames <- append(newColNames, "clean_nct_id")
        colnames(sessionInfo$df_matches_to_show) <- newColNames




        new_match_dt <-
          datatable(
            sessionInfo$df_matches_to_show,
            colnames = newColNames,
            # true_disease,
            # filter='top',
            escape = FALSE,
            class = "cell-border stripe compact wrap hover",
            # class = 'cell-border stripe compact nowrap hover',

            extensions = c("FixedColumns", "Buttons"),
            # extensions = c('FixedColumns'),


            options = list(
              lengthMenu = c(50, 100, 500),
              processing = TRUE,
              dom = '<"top"f<"clear">>t<"bottom"Blip <"clear">>',
              buttons = list(
                list(
                  extend = "columnToggle",
                  text = "Show Criteria",
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
              # paging = TRUE,
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
                  # targets = c(4,  5,7,  11,12,14,15,17,18,19, 20  , 21,23,24,   26,27,30,31,33,34,35 ,37,38,40,41,43,44, 46,47,49)
                ),
                # 17,18,19 are chemo inclusion, ignore for now
                #  list(width = '150px', targets = c(10)),
                list(width = "300px", targets = c(2, 9)),
                list(width = "200px", targets = match(criteria_columns, names(sessionInfo$df_matches_to_show))),
                list(className = "dt-center", targets = c(3, 7:ncol(sessionInfo$df_matches_to_show))),
                # Columns with hover tooltips

                list(
                  className = "text-truncate",
                  targets = match(
                    "Disease Names",
                    names(sessionInfo$df_matches_to_show)
                  ),
                  render = JS(
                    "function(data, type, row, meta) {",
                    "return `<a href=\"#trial-diseases-table-header\">${data}</a>`",
                    "}"
                  )
                ),
                list(
                  targets = match(
                    inclusion_match_column_names,
                    names(sessionInfo$df_matches_to_show)
                  ),
                  render = JS(
                    "function(data, type, row, meta) {  if (data === null) { return \"\" } ",
                    "else if (type == 'display' && data == true ) { return '<img src=\"checkmark-32.png\" />'} ",
                    "else if (type == 'display' && data == false ) {  return  '<img src=\"x-mark-32.png\" />';}",
                    "else  { return \"\" ; }",
                    "}"
                  )
                ),
                list(
                  targets = match(
                    exclusion_match_column_names,
                    names(sessionInfo$df_matches_to_show)
                  ),
                  render = JS(
                    "function(data, type, row, meta) {  if (data === null) { return \"\" } ",
                    "else if (type == 'display' && data == false ) { return '<img src=\"checkmark-32.png\" />'} ",
                    "else if (type == 'display' && data == true ) {  return  '<img src=\"x-mark-32.png\" />';}",
                    "else  { return \"\" ; }",
                    "}"
                  )
                )
              )
            ),
            selection = list(mode = "single", target = "cell")
          ) %>% DT::formatStyle(columns = c(2, 4, 7, 9), fontSize = "75%")


        output$df_matches_data <- DT::renderDT(new_match_dt, server = TRUE)
      })
      # browser()
      sessionInfo$run_count <- sessionInfo$run_count + 1
      click("toggleSidebar")
    })
  }

  #' Observe the Trial Matches output table for cell click.
  #' If the cell is the Disease Names cell, render the Trial's diseases below the matches output table.
  observeEvent(input$df_matches_data_cells_selected, {
    if (!nrow(input$df_matches_data_cells_selected)) {
      return()
    }
    single_row_selection <- input$df_matches_data_cells_selected[1, ]
    names(single_row_selection) <- c("row", "col")
    if (single_row_selection[["col"]] != match("Disease Names", names(sessionInfo$df_matches_to_show))) {
      return()
    }
    selected_trial_row <- sessionInfo$df_matches_to_show[single_row_selection[["row"]], ]
    # Split the "Disease Names" chr vector into a list of disease names.
    trial_disease_list <- strsplit(
      as.character(selected_trial_row$`Disease Names`),
      split = "(?<=\\)),",
      perl = TRUE
    )[[1]]
    # A disease name looks like "Stage IIA Breast Cancer ( C5454 )".
    disease_name_code_regex <- "^(.+?)\\s*\\(\\s*(C\\d+?)\\s*\\)$"
    # Convert each disease name to a data.frame with disease and code columns.
    disease_dfs <- lapply(trial_disease_list, function(disease_chr) {
      match <- stringr::str_match(disease_chr, disease_name_code_regex)[1, 2:3]
      names(match) <- c("disease", "code")
      return(data.frame(as.list(match), stringsAsFactors = FALSE))
    })
    disease_names_df <- rbindlist(disease_dfs)
    disease_names_df$is_match <- FALSE
    # Query to get the path of the search term to the disease code
    path_sql <- "select path from ncit_tc_with_path where parent = $1 and descendant = $2"

    for (search_code in sessionInfo$disease_df$Code) {
      for (row_idx in seq_len(nrow(disease_names_df))) {
        row <- disease_names_df[row_idx, ]
        if (!is.na(row[["is_match"]]) && row[["is_match"]]) {
          # If we already found a match for a previous search code, then ignore this search code
          break
        }
        disease_code <- row[["code"]]
        # Check if there is a path from disease code to search code
        paths <- safe_query(dbGetQuery, path_sql, params = c(disease_code, search_code))
        if (nrow(paths)) {
          print(paste("Path exists:", paths$path[[1]]))
          disease_names_df[row_idx, "is_match"] <- TRUE
          next
        }
        # Otherwise check if there is a path from search code to disease code
        paths <- safe_query(dbGetQuery, path_sql, params = c(search_code, disease_code))
        if (nrow(paths)) {
          print(paste("Path exists:", paths$path[[1]]))
          disease_names_df[row_idx, "is_match"] <- TRUE
          next
        }
      }
    }
    assertthat::assert_that(any(disease_names_df$is_match), msg = "At least one disease should be a match")

    output$df_trial_diseases <- DT::renderDT(disease_names_df %>% arrange(desc(is_match)), options = list(
      columnDefs = list(
        list(
          targets = c(3),
          render = JS(
            "function(dataIsTrue, type, row, meta) {",
            " return dataIsTrue ? '<img src=\"checkmark-32.png\" />' :",
            "'<img src=\"x-mark-32.png\" />' ",
            "}"
          )
        )
      )
    ))

    output$df_trial_diseases_header <- renderUI({
      div(
        h2(HTML(selected_trial_row$`NCT ID`), "TRIAL-level Diseases", id = "trial-diseases-table-header"),
        hr()
      )
    })
  })

  #
  # Search and match button event handler ----
  observeEvent(input$search_and_match, label = "search and match", search_for_trials())
  observeEvent(input$search_and_match_guided_select, label = "search and match", {
    removeModal()
    search_for_trials()
  })
  observeEvent(input$search_and_match_guided_text, label = "search and match", {
    removeModal()
    search_for_trials()
  })
  observeEvent(input$search_and_match_guided_selectize, label = "search and match", {
    removeModal()
    search_for_trials()
  })





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

  # Disease tree typer selected ----
  observeEvent(input$disease_tree_typer, ignoreNULL = TRUE, {
    print("Disease tree typer")
    if (input$disease_tree_typer == "") {
      shinyjs::disable("show_disease_tree_button")
    } else {
      shinyjs::enable("show_disease_tree_button")
    }
  })

  observeEvent(input$show_lung_disease, {
    print("show lung button pressed")
    sessionInfo$disease_tree_c_code_from_button <- "C4878"
  })


  observeEvent(input$show_solid_disease, {
    print("solid button pressed")
    sessionInfo$disease_tree_c_code_from_button <- "C9292"
  })



  observeEvent(input$show_gyn_disease, {
    print("gyn button pressed")
    sessionInfo$disease_tree_c_code_from_button <- "C4913"
  })

  # Show the generic disease tree modal from a button ----


  observeEvent(sessionInfo$disease_tree_c_code_from_button,
    {
      print("Show generic disease tree from button for ")
      print(sessionInfo$disease_tree_c_code_from_button)
      dt_generic_disease_tree <- getDiseaseTreeData(safe_query, sessionInfo$disease_tree_c_code_from_button, use_ctrp_display_name = TRUE)
      output$hidden_root_node <- renderText(dt_generic_disease_tree$child[[1]])
      sessionInfo$disease_tree_root_node <- dt_generic_disease_tree$child[[1]]
      output$generic_disease_tree <- renderCollapsibleTree({
        hh_collapsibleTreeNetwork(
          dt_generic_disease_tree,
          collapsed = TRUE,
          linkLength = 500,
          zoomable = TRUE,
          inputId = "generic_disease_tree_selected_node",
          nodeSize = "nodeSize",
          # nodeSize = 14,
          tooltip = TRUE,
          tooltipHtml = "tooltipHtml",
          aggFun = "identity",
          fontSize = 14 # ,
          # ,
          #  width = '2000px',
          #  height = '1700px'
        )
      })
      click("show_generic_disease_tree_modal")
      sessionInfo$disease_tree_c_code_from_button <- NULL
    },
    ignoreNULL = TRUE
  )


  # Show the generic disease tree modal dialog ----

  observeEvent(input$show_disease_tree_button, {
    print("Show generic disease tree for ")
    print(input$disease_tree_typer)
    dt_generic_disease_tree <- getDiseaseTreeData(safe_query, input$disease_tree_typer, use_ctrp_display_name = TRUE, show_staging = input$show_staging_checkbox)
    print("Show dt generic disease tree")
    print(dt_generic_disease_tree)
    output$hidden_root_node <- renderText(dt_generic_disease_tree$child[[1]])
    sessionInfo$disease_tree_root_node <- dt_generic_disease_tree$child[[1]]
    output$generic_disease_tree <- renderCollapsibleTree({
      hh_collapsibleTreeNetwork(
        dt_generic_disease_tree,
        collapsed = TRUE,
        linkLength = 500,
        zoomable = TRUE,
        inputId = "generic_disease_tree_selected_node",
        nodeSize = "nodeSize",
        # nodeSize = 14,
        tooltip = TRUE,
        tooltipHtml = "tooltipHtml",
        aggFun = "identity",
        fontSize = 14 # ,
        # ,
        #  width = '2000px',
        #  height = '1700px'
      )
    })
    click("show_generic_disease_tree_modal")
  })

  # Handle node click on disease tree ----
  observeEvent(input$generic_disease_tree_selected_node, ignoreNULL = TRUE, {
    print("generic disease tree node selected")
    # browser()
    print(input$generic_disease_tree_selected_node)

    # browser()
    if (length(input$generic_disease_tree_selected_node) > 0) {
      new_disease <- input$generic_disease_tree_selected_node[[length(input$generic_disease_tree_selected_node)]]
      output$generic_disease_tree_disease_selected <- renderText(input$generic_disease_tree_selected_node[[length(input$generic_disease_tree_selected_node)]])
    } else {
      output$generic_disease_tree_disease_selected <- renderText(sessionInfo$disease_tree_root_node)
      new_disease <- sessionInfo$disease_tree_root_node
    }
    see_if_collector_node_sql <- "select count(*) from disease_tree where child = $1 and child <> original_child"
    df_collector_node <- safe_query(dbGetQuery, see_if_collector_node_sql, params = c(new_disease))
    # browser()
    if (df_collector_node$count[[1]] > 0) {
      print("collector node")
      shinyjs::disable("generic_disease_tree_add_disease")
    } else {
      print("regular node ")
      shinyjs::enable("generic_disease_tree_add_disease")
    }
    print("----------")
  })


  observeEvent(input$generic_disease_tree_add_disease, {
    print("add disease from generic disease tree")
    # browser()
    if (length(input$generic_disease_tree_selected_node) > 0) {
      new_disease <- input$generic_disease_tree_selected_node[[length(input$generic_disease_tree_selected_node)]]
    } else {
      new_disease <- sessionInfo$disease_tree_root_node
    }

    print(paste("new disease = ", new_disease))
    # add_disease_sql <- "select distinct nci_thesaurus_concept_id as \"Code\" , 'YES' as \"Value\", preferred_name as \"Diseases\" from  trial_diseases where display_name = $1"
    add_disease_sql <- "
    with poss_diseases as  (
select distinct original_child from disease_tree where child = $1
)
,
ctrp_display_likes as (
select
   case
    when position('  ' in pd.original_child) > 0 then replace(pd.original_child, '  ', '%')
	when right(pd.original_child,1) = ' ' then substr(pd.original_child, 1, length(pd.original_child)-1) || '%'
	else pd.original_child
  end  like_string
  from poss_diseases pd
)

select dtd.nci_thesaurus_concept_id as \"Code\",
   'YES' as \"Value\" ,
    dtd.preferred_name as \"Diseases\" from distinct_trial_diseases dtd
join ctrp_display_likes c on dtd.display_name like c.like_string

    "
    df_new_disease <- safe_query(dbGetQuery, add_disease_sql, params = c(new_disease))
    # browser()
    sessionInfo$disease_df <- rbind(sessionInfo$disease_df, df_new_disease)
    print(sessionInfo$disease_df)
  })

  # crosswalk modal closed ----
  observeEvent(input$crosswalk_bsmodal_close, {
    print("crosswalk modal closed")
    output$crosswalk_name <- renderText("")
    updateTextInput(session, "crosswalk_code", value = "")
  })

  observeEvent(input$biomarker_bsmodal_close, {
    # Clear the biomarker dataframe

    print("biomarker modal closed")
    sessionInfo$biomarker_df <- data.frame(matrix(
      ncol = 3,
      nrow = 0,
      dimnames = list(NULL, c("Code", "Value", "Biomarkers"))
    ))
    print(input$egfr)
    if (input$egfr == "Positive") {
      t <-
        data.frame(
          Code = "C134501",
          Value = "YES",
          Biomarkers = "EGFR Positive"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
      t <-
        data.frame(
          Code = "C98357",
          Value = "YES",
          Biomarkers = "EGFR Gene Mutation"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    } else if (input$egfr == "Negative") {
      t <-
        data.frame(
          Code = "C150501",
          Value = "YES",
          Biomarkers = "EGFR Negative"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    }

    print(input$alk)
    if (input$alk == "Positive") {
      t <-
        data.frame(
          Code = "C128831",
          Value = "YES",
          Biomarkers = "ALK Positive"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
      t <-
        data.frame(
          Code = "C81945",
          Value = "YES",
          Biomarkers = "ALK Gene Mutation"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    } else if (input$alk == "Negative") {
      t <-
        data.frame(
          Code = "C133707",
          Value = "YES",
          Biomarkers = "ALK Negative"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    }



    print(input$ros1)
    if (input$ros1 == "Positive") {
      t <-
        data.frame(
          Code = "C155991",
          Value = "YES",
          Biomarkers = "ROS1 Positive"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
      t <-
        data.frame(
          Code = "C130952",
          Value = "YES",
          Biomarkers = "ROS1 Gene Mutation"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    } else if (input$ros1 == "Negative") {
      t <-
        data.frame(
          Code = "C153498",
          Value = "YES",
          Biomarkers = "ROS1 Negative"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    }

    if (input$her2_neu == "Positive") {
      t <-
        data.frame(
          Code = "C68748",
          Value = "YES",
          Biomarkers = "HER2/Neu Positive"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    } else if (input$ros1 == "Negative") {
      t <-
        data.frame(
          Code = "C68749",
          Value = "YES",
          Biomarkers = "HER2/Neu Negative"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    }

    print(input$nras)
    if (input$nras == "Positive") {
      t <-
        data.frame(
          Code = "C171618",
          Value = "YES",
          Biomarkers = "NRAS Positive"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
      t <-
        data.frame(
          Code = "C41381",
          Value = "YES",
          Biomarkers = "NRAS Gene Mutation"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    } else if (input$nras == "Negative") {
      t <-
        data.frame(
          Code = "C142837",
          Value = "YES",
          Biomarkers = "NRAS Negative"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    }

    print(input$kras)
    if (input$kras == "Positive") {
      t <-
        data.frame(
          Code = "C142134",
          Value = "YES",
          Biomarkers = "KRAS Positive"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
      t <-
        data.frame(
          Code = "C41361",
          Value = "YES",
          Biomarkers = "KRAS Gene Mutation"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    } else if (input$kras == "Negative") {
      t <-
        data.frame(
          Code = "C142879",
          Value = "YES",
          Biomarkers = "KRAS Negative"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    }

    print(input$hras)
    if (input$hras == "Positive") {
      t <-
        data.frame(
          Code = "C171617",
          Value = "YES",
          Biomarkers = "HRAS Positive"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
      t <-
        data.frame(
          Code = "C45934",
          Value = "YES",
          Biomarkers = "HRAS Gene Mutation"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    } else if (input$hras == "Negative") {
      t <-
        data.frame(
          Code = "C160373",
          Value = "YES",
          Biomarkers = "HRAS Gene Mutation Negative"
        )
      sessionInfo$biomarker_df <- rbind(sessionInfo$biomarker_df, t)
    }

    print(input$biomarker_list)
    if (length(input$biomarker_list) > 0) {
      add_disease_sql <- "select code as \"Code\" , 'YES' as \"Value\", pref_name as \"Biomarkers\" from ncit where pref_name = $1"
      for (row in 1:length(input$biomarker_list)) {
        new_disease <- input$biomarker_list[row]
        df_new_disease <-
          safe_query(dbGetQuery, add_disease_sql, params = c(new_disease))
        # browser(0)
        sessionInfo$biomarker_df <-
          rbind(sessionInfo$biomarker_df, df_new_disease)
      }
    }
    print(sessionInfo$biomarker_df)
  })

  observeEvent(input$cancer_add_disease, {
    print("cancer_add_disease")

    # See if we have subtypes, if so use them, otherwise see if we have a maintype/subtype
    # and use that
    if (length(input$subtype_typer) > 0) {
      #
      # There are subtypes selected -- use those and do not use the selected maintype
      #
      add_disease_sql <- "select distinct nci_thesaurus_concept_id as \"Code\" , 'YES' as \"Value\", preferred_name as \"Diseases\" from  trial_diseases where display_name = $1"
      for (row in 1:length(input$subtype_typer)) {
        new_disease <- input$subtype_typer[row]
        df_new_disease <-
          safe_query(dbGetQuery, add_disease_sql, params = c(new_disease))
        # browser()
        sessionInfo$disease_df <-
          rbind(sessionInfo$disease_df, df_new_disease)
      }
    } else if (length(input$maintype_typer) > 0 & input$maintype_typer != "") {
      # No subtype, get the maintype and add that in.
      print(paste("add maintype as disease - ", input$maintype_typer))
      add_disease_sql <- "select distinct nci_thesaurus_concept_id as \"Code\" , 'YES' as \"Value\", preferred_name as \"Diseases\" from  trial_diseases where display_name = $1"
      new_disease <- input$maintype_typer
      df_new_disease <-
        safe_query(dbGetQuery, add_disease_sql, params = c(new_disease))
      sessionInfo$disease_df <-
        rbind(sessionInfo$disease_df, df_new_disease)
    }

    #
    # Now see if we have stage diseases
    #
    # See if we have subtypes, if so use them, otherwise see if we have a maintype/subtype
    # and use that
    if (length(input$stage_typer) > 0) {
      add_disease_sql <- "select distinct nci_thesaurus_concept_id as \"Code\" , 'YES' as \"Value\", preferred_name as \"Diseases\" from  trial_diseases where display_name = $1"
      for (row in 1:length(input$stage_typer)) {
        new_disease <- input$stage_typer[row]
        df_new_disease <-
          safe_query(dbGetQuery, add_disease_sql, params = c(new_disease))
        # browser()
        sessionInfo$disease_df <-
          rbind(sessionInfo$disease_df, df_new_disease)
      }
    }
  })

  ### Add crosswalk codes, if any ----

  observeEvent(input$find_crosswalk_codes, {
    print("add crosswalk codes")
    # closeAlert(session,'crosswalk_modal_alert' )
    print(input$crosswalk_ontology)
    if (input$crosswalk_code != "") {
      # we have a code -
      print(input$crosswalk_code)


      withProgress(message = "Looking up codes", value = 0, {
        # browser()
        # first see is that what is typed is a valid code
        #

        if (input$crosswalk_ontology == "SNOMEDCT") {
          code_lookup_sql <-
            "select str from umls.mrconso where code = $1 and tty = 'PT' and sab = 'SNOMEDCT_US'"
        } else if (input$crosswalk_ontology == "ICD10CM") {
          code_lookup_sql <-
            " select str from umls.mrconso where code =$1 and tty = 'PT' and sab = 'ICD10CM'"
        } else if (input$crosswalk_ontology == "LOINC") {
          code_lookup_sql <-
            "select str from umls.mrconso where code = $1 and sab = 'LNC' and tty = 'LC'"
        }

        df_umls <- safe_query(dbGetQuery,
          code_lookup_sql,
          params = c(input$crosswalk_code)
        )

        # browser()


        if (nrow(df_umls) == 0) {
          createAlert(session,
            "crosswalk_modal_alert",
            title = "Invalid code",
            content = "This is an invalid code"
          )
        } else {
          output$crosswalk_name <- renderText(df_umls$str[[1]])
          ehr_c <-
            paste(input$crosswalk_ontology, input$crosswalk_code, sep = ":")
          new_codes <-
            get_ncit_codes_from_ehr_codes(list(ehr_c), safe_query)


          # browser()
          if (nrow(new_codes) > 0) {
            print(new_codes)
            output$matched_ncit_name <- renderText(
              paste(new_codes$Description[[1]], " (", new_codes$Code[[1]], ")", sep = "")
            )
            # If it is not a disease, stick it in the crosswalk dataframe, otherwise stick
            # it in the disease dataframe
            rowc_df <- safe_query(
              dbGetQuery,
              "select count(*) as num_diseases from trial_diseases where nci_thesaurus_concept_id = $1",
              new_codes$Code[[1]]
            )
            if (rowc_df$num_diseases[[1]] == 0) {
              sessionInfo$crosswalk_df <-
                rbind(sessionInfo$crosswalk_df, new_codes)
              sessionInfo$crosswalk_df <- sessionInfo$crosswalk_df[!duplicated(sessionInfo$crosswalk_df), ]
            } else {
              sessionInfo$disease_df <-
                rbind(sessionInfo$disease_df, new_codes)
              sessionInfo$disease_df <- sessionInfo$disease_df[!duplicated(sessionInfo$disease_df), ]
            }
            #
          } else {
            createAlert(session,
              "crosswalk_modal_alert",
              title = "",
              content = "No equivalent NCI codes found"
            )
          }
        }
      })
    }
  })
  observe({
    show_crosswalk_dt <- datatable(
      sessionInfo$crosswalk_df,
      class = "cell-border stripe compact wrap ",
      rownames = FALSE,
      selection = "single",
      options = list(
        escape = FALSE,
        searching = FALSE,
        paging = FALSE,
        info = FALSE,
        # scrollX = TRUE,
        # scrolly = '200px',
        pageLength = 999,
        scrollY = "100px",
        lengthMenu = list(c(600, -1), c("600", "All")),
        style = "height:100px; overflow-y: scroll; overflow-x:scroll;padding:10px;",
        columnDefs = list(
          list(visible = FALSE, targets = c(0, 1))
          # ,
          # list(
          #   targets = c(1),
          #   render = JS("function(data){return data.replace(/\\n/g, '<br />');}")
          # )
        )
      )
    ) %>% DT::formatStyle(columns = c(0), fontSize = "75%")
    output$crosswalk_codes <- DT::renderDT(show_crosswalk_dt)
  })


  observe({
    print("sessionInfo$disease_df changed")
    # browser()
    # if (nrow(sessionInfo$disease_df) > 0) {
    #     biomarker_df <- get_biomarker_trial_counts_for_diseases(safe_query, sessionInfo$disease_df$Code)
    # }

    show_disease_dt <- datatable(
      sessionInfo$disease_df,
      class = "cell-border stripe compact wrap ",
      rownames = FALSE,
      selection = "single",
      options = list(
        escape = FALSE,
        searching = FALSE,
        paging = FALSE,
        info = FALSE,
        # scrollX = TRUE,
        # scrolly = '200px',
        pageLength = 999,
        scrollY = "100px",
        lengthMenu = list(c(600, -1), c("600", "All")),
        style = "height:100px; overflow-y: scroll; overflow-x:scroll;padding:10px;",
        columnDefs = list(
          list(visible = FALSE, targets = c(0, 1))
          # ,
          # list(
          #   targets = c(1),
          #   render = JS("function(data){return data.replace(/\\n/g, '<br />');}")
          # )
        )
      )
    ) %>% DT::formatStyle(columns = c(0), fontSize = "75%")
    output$diseases <- DT::renderDT(show_disease_dt)
  })


  observe({
    show_biomarker_dt <- datatable(
      sessionInfo$biomarker_df,
      class = "cell-border stripe compact wrap ",
      rownames = FALSE,
      selection = "single",
      options = list(
        escape = FALSE,
        searching = FALSE,
        paging = FALSE,
        info = FALSE,
        # scrollX = TRUE,
        # scrolly = '200px',
        pageLength = 999,
        scrollY = "100px",
        lengthMenu = list(c(600, -1), c("600", "All")),
        style = "height:100px; overflow-y: scroll; overflow-x:scroll;padding:10px;",
        columnDefs = list(
          list(visible = FALSE, targets = c(0, 1))
          # ,
          # list(
          #   targets = c(1),
          #   render = JS("function(data){return data.replace(/\\n/g, '<br />');}")
          # )
        )
      )
    ) %>% DT::formatStyle(columns = c(0), fontSize = "75%")
    output$biomarkers <- DT::renderDT(show_biomarker_dt)
  })

  #
  # Handle the cancer center intput
  #

  observeEvent(input$cancer_center_picker, ignoreNULL = FALSE, {
    print("cancer center -- ")
    print(paste(" --> ", input$cancer_center_picker))
    if (length(input$cancer_center_picker) > 0) {
      withProgress(value = 0.5, message = "Computing cancer center matches", {
        print("we have a cancer center")
        for (row in 1:length(input$cancer_center_picker)) {
          print(paste("row ", row, " is ", input$cancer_center_picker[row]))
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
    print(paste("distance_in_miles=", input$distance_in_miles))
    if (is.na(input$distance_in_miles) |
      input$distance_in_miles == "") {
      print("miles is NA")
      sessionInfo$distance_in_miles <- NA
      sessionInfo$distance_df <- NA
    } else if (!is.na(sessionInfo$latitude) & !is.na(sessionInfo$longitude)) {
      withProgress(value = 0.5, message = "Computing geolocation matches", {
        print("computing distance_df")
        distance_df <-
          get_api_studies_for_location_and_distance(
            sessionInfo$latitude,
            sessionInfo$longitude,
            input$distance_in_miles
          )

        sessionInfo$distance_df <- distance_df
        sessionInfo$distance_in_miles <- input$distance_in_miles
      })
    }
  })


  # This gets called whenever filtering has changed

  get_filterer <- function() {
    print("get_filterer")
    match_types_string <- paste(input$match_types_picker, collapse = " & ")
    phase_string <- paste(input$phases, collapse = " | ")
    study_source_string <- paste(input$study_source, collapse = " | ")

    # filterer <- match_types_string
    print(paste("match_types_string = ", match_types_string))
    print(paste("phase_string = ", phase_string))

    if (match_types_string != "") {
      match_types_string <- paste("(", match_types_string, ")")
    }
    if (phase_string != "") {
      phase_string <- paste("(", phase_string, ")")
    }

    if (study_source_string != "") {
      study_source_string <- paste("(", study_source_string, ")")
    }

    filterer <- ""


    if (match_types_string != "") {
      if (phase_string != "") {
        filterer <- paste(match_types_string, " & ", phase_string)
      } else {
        filterer <- match_types_string
      }
    } else {
      if (phase_string != "") {
        filterer <- phase_string
      }
    }

    sites_search <- paste(input$sites, collapse = " | ")
    if (filterer == "") {
      if (!is_empty(sites_search)) {
        filterer <- paste(" ( ", sites_search, " ) ")
      }
    } else {
      if (!is_empty(sites_search)) {
        p2 <- paste(" ( ", sites_search, " ) ")
        filterer <- paste(filterer, p2, sep = " & ")
      }
    }

    if (filterer == "") {
      if (!is_empty(study_source_string)) {
        filterer <- study_source_string
      }
    } else {
      if (!is_empty(study_source_string)) {
        filterer <- paste(filterer, study_source_string, sep = " & ")
      }
    }

    print(paste("filterer =", filterer))

    if (!is.null(sessionInfo$df_matches_to_show)) {
      print("we have data")

      if (filterer != "") {
        print("there is filtering")
        if (input$disease_type == "lead") {
          filterer <-
            gsub("disease_matches", "lead_disease_matches", filterer)
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
      # browser()
      if (!is.null(nrow(td)) && nrow(td) > 0) {
        print(paste("miles to filter by ", di))
        print(paste("original length - ", nrow(sessionInfo$df_matches_to_show)))

        df_m <- sessionInfo$df_matches_to_show
        df_miles <- sessionInfo$distance_df
        t3 <-
          sqldf("select df_m.* from df_m join df_miles on df_m.clean_nct_id = df_miles.nct_id")
        sessionInfo$df_matches_to_show <- t3
        print(paste("after lrvd filter length - ", nrow(sessionInfo$df_matches_to_show)))
      } else if (!is.na(sessionInfo$distance_in_miles)) {
        df_m <- sessionInfo$df_matches_to_show
        t3 <- sqldf("select df_m.* from df_m where 1=0")
        sessionInfo$df_matches_to_show <- t3
      }

      #
      # Now filter against the cancer center dataframe, if we have data there
      #
      if (!is.null(nrow(sessionInfo$cancer_center_df)) && nrow(sessionInfo$cancer_center_df) > 0) {
        print("filtering against the cancer center df")
        df_m <- sessionInfo$df_matches_to_show
        df_cancer_center <- sessionInfo$cancer_center_df
        t3 <- sqldf("select df_m.* from df_m join df_cancer_center on df_m.clean_nct_id = df_cancer_center.nct_id")
        sessionInfo$df_matches_to_show <- t3
      }


      #
      # Now add in the filter against RVD
      #
      # trvd <- sessionInfo$rvd_df


      trvd <- rvd_df
      # browser()
      if (!is.null(nrow(trvd)) && nrow(trvd) > 0) {
        print(paste("original length - ", nrow(sessionInfo$df_matches_to_show)))

        df_m <- sessionInfo$df_matches_to_show

        t4 <- sqldf("select df_m.* from df_m join trvd on df_m.clean_nct_id = trvd.nct_id")
        sessionInfo$df_matches_to_show <- t4
        print(paste("after lrvd filter length - ", nrow(sessionInfo$df_matches_to_show)))
      }
    } else {
      print("no data, nothing to do")
    }

    return(filterer)
  }


  #
  # Note that counter$countervalue is here because it gets changed during the search and match button click to
  # make this called upon first load of a given search
  #

  observeEvent(
    c(
      input$match_types_picker,
      input$disease_type,
      sessionInfo$distance_in_miles,
      sessionInfo$cancer_center_df,
      input$phases,
      input$sites,
      input$study_source,
      counter$countervalue
    ),
    ignoreNULL = FALSE,
    {
      filterer <- get_filterer()
      print(paste("filterer =", filterer))
    }
  )

  output$downloadData <- downloadHandler(
    filename = function() {
      paste("fctc_boolean_match_csv_", Sys.Date(), ".csv", sep = "")
    },
    content = function(file) {
      write.csv(sessionInfo$df_matches_to_show, file, row.names = FALSE)
    }
  )
}

onStop(function() {
  poolClose(pool_con)
  cat("Closing database connection pool.\n")
})

shinyApp(ui, server)

# # Uncomment the following to expose the R Debugger
# # See this github thread https://github.com/ManuelHentschel/VSCode-R-Debugger/issues/162
# app <- shinyApp(ui, server)
# print(app)
