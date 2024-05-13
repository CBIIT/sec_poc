library(httr)
library(data.table)
library(dplyr)
library(jsonlite)
library(openxlsx)
library(assertthat)
print(getwd())


CTS_V2_API_KEY <- Sys.getenv("CTS_V2_API_KEY")

PAGE_SIZE <- 50
INCLUDE_FIELDS <- c(
  "nct_id",
  "diseases"
)

#' Search CTS API
#' @param body_args named list. Use it to tweak the query to CTS API. See below for examples
#' @examples
#' > body_args <- list(
#'    maintype = c("C4872"),
#'    stage = ncit_code
#'    diseases.inclusion_indicator = "TRIAL"
#'   )
#' # Or this also works
#' > body_args <- list(
#'   diseases.nci_thesaurus_concept_id = ncit_code,
#'   diseases.inclusion_indicator = "TRIAL"
#' )
poc_disease_search <- function(
    from = 0,
    size = PAGE_SIZE,
    body_args = list()) {

  body <- c(
    list(
      current_trial_status = "Active",
      primary_purpose = c("TREATMENT", "SCREENING"),
      sites.recruitment_status = "ACTIVE",
      include = INCLUDE_FIELDS,
      from = from,
      size = size
    ),
    body_args
  )

  response <- httr::POST(
    "https://clinicaltrialsapi.cancer.gov/api/v2/trials",
    # Copied from get_api_studies_for_disease.R
    body = body,
    encode = "json",
    httr::add_headers(`x-api-key` = CTS_V2_API_KEY, `Content-Type` = "application/json"),
    httr::timeout(5)
  )

  data <- httr::content(response)
  if (response$status_code != 200) {
    print(response)
  }

  return(data)
}

paginate_cts_api <- function(paged_data, total_expected, FUN, ...) {
  while (length(paged_data) < total_expected) {
    data <- FUN(from = length(paged_data), ...)
    paged_data <- append(paged_data, data$data)
  }
  return(paged_data)
}

flatten_trial_diseases_to_dt <- function(trial) {
  rows <- list()
  for (disease in trial$diseases) {
    new_row <- list(
      nct_id = trial$nct_id,
      disease = disease$name,
      # inclusion_indicator = disease$inclusion_indicator,
      code = disease$nci_thesaurus_concept_id,
      # type = toString(disease$type),
      parents = toString(disease$parents)
    )
    rows[[length(rows) + 1]] <- new_row
  }
  return(rbindlist(rows))
}

#' Given a data table consisting of code, disease, and parent codes
#' visit all the parent codes starting from `starting_terms`.
#' @param starting_terms vector of character. Codes to begin visiting parents from.
construct_paths_to_root <- function(trial_disease_dt, starting_terms, visited) {
  terms <- trial_disease_dt[trial_disease_dt$code %in% starting_terms, ]

  apply(terms, 1, function(term) {
    if (!term[["code"]] %in% names(visited)) {
      assign(term[["code"]], term[["disease"]], visited)
    }
  })

  # For each term's parents
  lapply(terms$parents, function(p_chr) {
    assert_that(length(p_chr) == 1, msg = "Parents character vector should have length of 1")
    p_list <- strsplit(p_chr, split = ",\\s*")
    # Apply the same path construction to each parent
    lapply(p_list[[1]], function(p_chr) {
      if (!p_chr %in% names(visited)) {
        construct_paths_to_root(trial_disease_dt, p_chr, visited)
      }
    })
  })
}

get_api_studies_for_disease_v2 <- function(ncit_code) {
  body_args <- list(
    diseases.nci_thesaurus_concept_id = ncit_code
  )
  # Get page 1 of the ncit_code (disease) trials
  disease_trials_p1 <- poc_disease_search(
    body_args = body_args
  )
  # Get the rest of the pages of ncit_code (disease) trials
  disease_trials <- paginate_cts_api(
    disease_trials_p1$data,
    disease_trials_p1$total,
    poc_disease_search,
    body_args = body_args
  )
  print(paste("Fetched", length(disease_trials), "disease search-term trials."))

  # Save the retrieved trials into a list of data.table
  all_trials_as_dts <- list()
  for (trial in disease_trials) {
    dt <- flatten_trial_diseases_to_dt(trial)
    all_trials_as_dts[[length(all_trials_as_dts) + 1]] <- dt
  }

  # Gather all parent terms for each trial starting from the original search terms.
  parent_terms_env <- new.env()
  starting_terms <- ncit_code
  for (dt in all_trials_as_dts) {
    if (all(starting_terms %in% names(parent_terms_env))) {
      print("Breaking early b/c all search terms have been visited")
      break
    }
    # Each data.table represents a separate trial returned from the original search.
    # The data table consists of a trial's diseases, at least one of which is a positive
    # match for the original search codes.
    terms_in_trial <- starting_terms[starting_terms %in% dt$code]
    assert_that(length(terms_in_trial) >= 1)
    terms_not_visited_yet <- terms_in_trial[!terms_in_trial %in% names(parent_terms_env)]
    if (length(terms_not_visited_yet)) {
      print(paste("Visiting", terms_not_visited_yet))
      construct_paths_to_root(dt, starting_terms, parent_terms_env)
    }
  }
  parent_terms <- as.list(parent_terms_env)
  parent_ncit_codes <- names(parent_terms)

  # Fetch all TRIAL-level parent-code trials
  parent_codes_trials <- lapply(parent_ncit_codes, function(parent_ncit_code) {
    body_args <- list(
      diseases.nci_thesaurus_concept_id = parent_ncit_code,
      diseases.inclusion_indicator = "TRIAL"
    )
    p1 <- poc_disease_search(body_args = body_args)
    all_pages <- paginate_cts_api(p1$data, p1$total, poc_disease_search, body_args = body_args)
    return(all_pages)
  })
  count_of_parent_trials <- Reduce(function(count, list_of_trials) {
    return(count + length(list_of_trials))
  }, parent_codes_trials, 0)
  print(paste("Fetched", count_of_parent_trials, "parent trials."))

  for (list_of_trials in parent_codes_trials) {
    for (trial in list_of_trials) {
      dt <- flatten_trial_diseases_to_dt(trial)
      all_trials_as_dts[[length(all_trials_as_dts) + 1]] <- dt
    }
  }

  unique_nct_ids <- unique(lapply(all_trials_as_dts, function(dt) dt$nct_id[[1]]))
  print(paste("Fetched", length(unique_nct_ids), "combined trials."))
  return(list(nct_ids = unique_nct_ids))
}


# get_api_studies_for_disease_v2(
#   c("C7768", "C139538", "C139569")
# )
