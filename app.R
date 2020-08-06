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

ui <- fluidPage(
  useShinyjs(),
  tags$head(tags$style(
    HTML("hr {border-top: 1px solid #000000;}")
  )),
  
  titlePanel(title = div(img(src = "SEC-logo.png"), style = "text-align: center;")),
  sidebarLayout(
    div(
      id = "Sidebar",
      
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
        selectizeInput("disease_typer",label = "Diseases", NULL, multiple = TRUE),
        selectizeInput("misc_typer",label = "Misc", NULL, multiple = TRUE),
        
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
  session_conn = DBI::dbConnect(RSQLite::SQLite(), dbinfo$db_file_location)
  
  df_disease_choices <- 
    dbGetQuery(session_conn, "select  preferred_name 
               from trial_diseases ds where ds.disease_type like '%maintype%' or ds.disease_type like  '%subtype%'
			   group by preferred_name
			   order by count(preferred_name) desc")
  
  df_misc_choices <-
    dbGetQuery(session_conn, "select pref_name from ncit where concept_status <> 'Obsolete_Concept' or concept_status is null order by parents, pref_name
")
    
  DBI::dbDisconnect(session_conn)
  
  updateSelectizeInput(session,  'disease_typer', choices = df_disease_choices$preferred_name , server = TRUE)
  updateSelectizeInput(session,  'misc_typer', choices = df_misc_choices$pref_name , server = TRUE)
  
  
  observeEvent(input$toggleSidebar, {
    shinyjs::toggle(id = "Sidebar")
  })
}

shinyApp(ui, server)