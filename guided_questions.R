library(shinyBS)

guidedQuestionsUI <- function(id, label = 'Guided Questions') {
    ns <- NS(id)
    bsModal(ns("modalExample"), "Guided Questions", "show_guided_questions", size="large", 
        # fluidPage(id = ns("distTable"),
        selectInput(ns("performance_status"), "How would you describe your symptoms currently?", c(
            "Unspecified" = "C159685",
            "0: Asymptomatic" = "C105722",
            "1: Symptomatic, but fully ambulatory" = "C105723",
            "2: Symptomatic, in bed less than 50% of day" = "C105725",
            "3: Symptomatic, in bed more than 50% of day, but not bed-ridden" = "C105726",
            "4: Bed-ridden" = "C105727"
        ))
        # pickerInput(
        #   inputId = ns("performance_status2"),
        #   label = "How would you describe your symptoms currently?",
        #   choices = c(
        #     "Unspecified" = "C159685",
        #     "0: Asymptomatic" = "C105722",
        #     "1: Symptomatic, but fully ambulatory" = "C105723",
        #     "2: Symptomatic, in bed less than 50% of day" = "C105725",
        #     "3: Symptomatic, in bed more than 50% of day, but not bed-ridden" = "C105726",
        #     "4: Bed-ridden" = "C105727"
        #   ),
        #   selected =  "Unspecified",
        #   multiple = FALSE,
        #   options = list(width = "72px"),
        #   choicesOpt = NULL,
        #   width = 'auto',
        #   inline = FALSE
        # ) 
        # fluidRow(column(2, ':')),
        # )
    )
}

guidedQuestionsServe <- function(id) {
    moduleServer(id, function(input, output, session) {
        performanceStatus <- observe({
            req(input$performance_status)
            print(input$performance_status)
            input$performance_status
        })
        return(performanceStatus)
    })
}