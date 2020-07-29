library(shiny)
library(shinyjs)
library(shinyWidgets)

ui <- fluidPage(
  useShinyjs(),
  tags$head(
    tags$style(HTML("hr {border-top: 1px solid #000000;}"))
  ),
  
  titlePanel(title = div(img(src = "SEC-logo.png"), style = "text-align: center;")),
  sidebarLayout(
    
    div(id = "Sidebar",
        
        sidebarPanel(
          tags$style(".well {background-color:#F0F8FF;}"),
          fluidRow(column(8,align = 'left', h4("Search Criteria")),
                   column(4, alight = 'right',style = "display:inline-block; margin-top: 10px; ", actionLink('clear_all', label = 'Clear All'))
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
            inputId = "gender", label = "Gender", 
            choices = c("Male", "Female", "Unspecified"),selected = "Unspecified",
            justified = FALSE, status = "primary"
            # checkIcon = list(yes = icon("ok", lib = "glyphicon"), no = icon("remove", lib = "glyphicon"))
          ),
          actionButton("search_and_match", "SEARCH AND MATCH")
        )),
    
    
    mainPanel(actionButton("toggleSidebar", "Toggle sidebar"))
  )
  
)

server <- function(input, output, session) {
  observeEvent(input$toggleSidebar, {
    shinyjs::toggle(id = "Sidebar")
  })
}

shinyApp(ui, server)