library(testthat)
setwd("/opt/R/sec_poc/")
source("tests/testthat/helper.R")
source("get_api_studies_for_disease_v2.R", local = TRUE)

trials_queue <- Queue$new()
trials_queue$enqueue(
  list(
    total = 1,
    data = list(
      list(
        nct_id = "NCT1",
        diseases = list(
          list(
            name = "d1",
            nci_thesaurus_concept_id = "C1234",
            parents = list()
          )
        )
      )
    )
  )
)

poc_disease_search <- function(body_args = NULL) {
  print("mocking disease search")
  return(trials_queue$dequeue())
}


test_that("get api studies works as expected", {
  studies <- get_api_studies_for_disease_v2("C1234")
  expect_equal(studies$nct_ids, list("NCT1"))
})
