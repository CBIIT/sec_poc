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
      bsTooltip("toggleSidebar", 'Hide/show the search criteria', placement = "bottom", trigger = "hover",
                options = NULL),
      
      
      fluidRow(

        
        
          checkboxGroupInput(
            "match_types_to_show_col2",
            label = " ",
            inline = TRUE,
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
            # ,
            # selected = c(
            #   " (perf_matches == TRUE | is.na(perf_matches) ) ",
            #   " ( immunotherapy_matches == FALSE | is.na(immunotherapy_matches) ) ",
            #   " ( biomarker_exc_matches == FALSE | is.na(biomarker_exc_matches) )   ",
            #   " ( biomarker_inc_matches == TRUE | is.na(biomarker_inc_matches) )   ",
            #   " ( chemotherapy_exc_matches == FALSE | is.na(chemotherapy_exc_matches) )   ",
            #   " ( hiv_exc_matches == FALSE | is.na(hiv_exc_matches) ) "
            # )
            
            #selected = c("disease_matches == TRUE","gender_matches == TRUE" ,"age_matches == TRUE")
          
      )
      )
        ,
      fluidRow(
        
          
          radioButtons(
            "disease_type",
            "Disease types to match:",
            c("Trial" = "trial",
              "Lead" = "lead"),
            inline = TRUE
          )
          ,
          checkboxGroupInput(
            "phases",
            label = "Phases:",
            inline = TRUE,
            choices = c(
              "I" = "  ( phase == 'O' |  phase == 'I' | phase == 'I_II')  ",
              "II" = " ( phase == 'II'| phase == 'I_II' | phase == 'II_III' ) ",
              "III" = " (  phase == 'III' | phase == 'II_III' ) ",
              "IV" = " phase == 'IV' "
            )
          )
          ,
          checkboxGroupInput(
            "sites",
            label = "Study Sites",
            inline = TRUE,
            choices = c("VA" = "  ( va_matches == TRUE )  ",
                        "NIH CC" = " ( nih_cc_matches == TRUE ) ")
          ),
          numericInput(
            "distance_in_miles",
            "Distance (miles):",
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
  



server <- function(input, output, session) {
  observeEvent(input$toggleSidebar, {
    shinyjs::toggle(id = "Sidebar")
  })
}

shinyApp(ui, server)