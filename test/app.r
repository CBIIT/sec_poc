library(shiny)
library(DT)

source("../get_api_studies_for_disease_v2.R")
options(
  shiny.launch.browser = FALSE
)

shinyApp(
  # Client-side
  ui = fluidPage(
    tags$head(
      tags$style(HTML("
      .center-content {
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
        row-gap: 8px;
      }
      [id^='search_terms_'] {
        width: auto !important;
        position: sticky;
        top: 1px;
        z-index: 1;
        background-color: wheat;
      }
      .trial-table {
      }
    "))
    ),
    tabsetPanel(
      id = "tabset",
      tabPanel(
        "Stage II BC",
        div(
          class = "center-content",
          h1("Search Terms"),
          DTOutput("search_terms_a"),
          uiOutput("total_trials_1_a"),
          uiOutput("tables_ui_a"),
          uiOutput("total_trials_2_a")
        )
      ),
      tabPanel(
        "Stage IIA BC",
        div(
          class = "center-content",
          h1("Search Terms"),
          DTOutput("search_terms_b"),
          uiOutput("total_trials_1_b"),
          uiOutput("tables_ui_b"),
          uiOutput("total_trials_2_b")
        )
      ),
      tabPanel(
        "Stage II BC - TRIAL Only",
        div(
          class = "center-content",
          h1("Search Terms"),
          DTOutput("search_terms_c"),
          uiOutput("total_trials_1_c"),
          uiOutput("tables_ui_c"),
          uiOutput("total_trials_2_c")
        )
      )
    )
  ),
  # Server-side
  server = function(input, output, session) {
    sessionData <- reactiveValues(
      all_p_a = NULL,
      all_p_b = NULL,
      all_p_c = NULL
    )

    observeEvent(input$tabset, {
      search_terms <- NULL
      suffix <- NULL
      if (input$tabset == "Stage II BC") {
        search_terms <- data.frame(matrix(c(
          "Stage II Breast Cancer AJCC v6 and v7", "C7768",
          "Prognostic Stage II Breast Cancer AJCC v8", "C139569",
          "Anatomic Stage II Breast Cancer AJCC v8", "C139538"
        ), ncol = 2, byrow = TRUE))
        suffix <- "a"
      } else if (input$tabset == "Stage IIA BC") {
        search_terms <- data.frame(matrix(c(
          "Anatomic Stage IIA Breast Cancer AJCC v8", "C139539",
          "Stage IIA Breast Cancer AJCC v6 and v7", "C5454",
          "Prognostic Stage IIA Breast Cancer AJCC v8", "C139571"
        ), ncol = 2, byrow = TRUE))
        suffix <- "b"
      } else {
        search_terms <- data.frame(matrix(c(
          "Stage II Breast Cancer AJCC v6 and v7", "C7768",
          "Prognostic Stage II Breast Cancer AJCC v8", "C139569",
          "Anatomic Stage II Breast Cancer AJCC v8", "C139538"
        ), ncol = 2, byrow = TRUE))
        suffix <- "c"
      }
      print(search_terms)
      print(suffix)

      names(search_terms) <- c("disease", "code")
      search_codes <- search_terms$code

      output[[paste0("search_terms_", suffix)]] <- renderDT(
        search_terms,
        options = list(dom = "t")
      )

      if (is.null(sessionData[[paste0("all_p_", suffix)]])) {
        print("Fetching results from API...")

        args_other <- list()
        if (suffix == "c") {
          args_other$diseases.inclusion_indicator <- "TRIAL"
        }
        p1 <- poc_disease_search(body_args = c(list(
          diseases.nci_thesaurus_concept_id = search_codes
        ), args_other))
        all_p <- paginate_cts_api(p1$data, p1$total, FUN = poc_disease_search, body_args = c(list(
          diseases.nci_thesaurus_concept_id = search_codes
        ), args_other))
        sessionData[[paste0("all_p_", suffix)]] <- all_p

        print("Pages len:")
        print(length(all_p))
        output[[paste0("total_trials_1_", suffix)]] <- renderUI({
          p(paste("Total # trials:", length(all_p)))
        })
        output[[paste0("total_trials_2_", suffix)]] <- renderUI({
          p(paste("Total # trials:", length(all_p)))
        })

        l_trial_ids <- lapply(all_p, function(trial) trial$nct_id)
        l_diseases <- lapply(all_p, function(trial) {
          disease_df <- data.frame()
          for (disease in trial$diseases) {
            if (disease$inclusion_indicator == "TRIAL") {
              disease_df <- rbind(disease_df, list(
                inc_indicator = "TRIAL",
                disease = disease$name, code = disease$nci_thesaurus_concept_id
              ), stringsAsFactors = FALSE)
            }
          }
          return(disease_df)
        })
        print("Diseases DF len:")
        print(length(l_diseases))

        output[[paste0("tables_ui_", suffix)]] <- renderUI({
          tables_ui <- lapply(seq_along(l_diseases), function(i) {
            div(
              class = "trial-table",
              h2(paste(paste0("(", i, ")"), "Trial", l_trial_ids[[i]])),
              DTOutput(paste0("table_", suffix, "_", i))
            )
          })
          do.call(tagList, tables_ui)
        })

        lapply(seq_along(l_diseases), function(i) {
          output[[paste0("table_", suffix, "_", i)]] <- renderDT({
            datatable(l_diseases[[i]], options = list(dom = "tp")) %>% formatStyle(
              "code",
              target = "row",
              backgroundColor = styleEqual(search_codes, lapply(seq_along(search_codes), function(i) "yellow"))
            )
          })
        })
      }
    })
  }
)
