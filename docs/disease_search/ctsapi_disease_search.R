library(httr)
library(data.table)
library(dplyr)
library(jsonlite)
getwd()
CTS_V2_API_KEY <- Sys.getenv("CTS_V2_API_KEY")

PAGE_SIZE <- 50
INCLUDE_FIELDS <- c(
  "nct_id",
  "diseases",
  "current_trial_status",
  "primary_purpose",
  "sites.recruitment_status"
)

poc_disease_search <- function(
    ncit_code,
    from = 0,
    size = PAGE_SIZE) {
  response <- httr::POST(
    "https://clinicaltrialsapi.cancer.gov/api/v2/trials",
    # Copied from get_api_studies_for_disease.R
    body = list(
      current_trial_status = "Active",
      primary_purpose = c("TREATMENT", "SCREENING"),
      # maintype = c("C4872"),
      # stage = ncit_code,
      diseases.nci_thesaurus_concept_id = ncit_code,
      sites.recruitment_status = "ACTIVE",
      include = INCLUDE_FIELDS,
      from = from,
      size = size
    ),
    encode = "json",
    httr::add_headers(`x-api-key` = CTS_V2_API_KEY, `Content-Type` = "application/json"),
    httr::timeout(5)
  )
  data <- httr::content(response)
  assertthat::assert_that(response$status_code == 200, msg = paste("Response status is", response$status_code))
  return(data)
}

paginate_cts_api <- function(paged_data, total_expected, FUN, ...) {
  print(paste("    Expecting:", total_expected))
  while (length(paged_data) < total_expected) {
    data <- FUN(from = length(paged_data), ...)
    paged_data <- append(paged_data, data$data)
    print(paste("          Got:", length(data$data)))
    print(paste("        Total:", length(paged_data)))
  }
  return(paged_data)
}

search_term <- "Stage IA Breast Cancer"
breast_carcinoma <- c("C4872")
# ncit_code <- c("C4872") # Breast Carcinoma
# ncit_code <- c("C153238") # Metastatic Breast Carcinoma
# ncit_code <- c("C3641") # Stage 0 Breast Cancer AJCC v6 and v7
ncit_code <- c("C85835", "C139557", "C139536") # Stage IA BC (w/ AJCC versions)
trials_p1 <- poc_disease_search(ncit_code)

all_trials <- paginate_cts_api(trials_p1$data, trials_p1$total, poc_disease_search, ncit_code = ncit_code)

count <- 0
disease_count <- 0
list_of_trial_disease_list <- Map(function(t) {
  count <<- count + 1
  diseases <- Map(function(d) {
    disease_count <<- disease_count + 1
    return(
      list(
        nct_id = t$nct_id,
        disease = d$name,
        inclusion_indicator = d$inclusion_indicator,
        code = d$nci_thesaurus_concept_id,
        type = toString(d$type),
        parents = toString(d$parents)
      )
    )
  }, t$diseases)
  return(diseases)
}, all_trials)
list_of_trial_disease_dt <- lapply(list_of_trial_disease_list, rbindlist)
count
disease_count

#' Make sure that the search term appears in each trial
noop <- lapply(list_of_trial_disease_dt, function(trial_disease_dt) {
  assertthat::assert_that(search_term %in% trial_disease_dt$disease)
})

#' Apply the following if checking leaf-node searches (e.g. Stage search with no children terms)
noop <- lapply(list_of_trial_disease_dt, function(trial_disease_dt) {
  search_term_idxs <- which(trial_disease_dt$disease == search_term)
  terms <- trial_disease_dt[search_term_idxs]
  assertthat::assert_that(length(terms) >= 1,
    msg = "Expecting at least one instance of search_term"
  )
  assertthat::assert_that(unique(terms$inclusion_indicator) == "TRIAL",
    msg = "Expecting that leaf-node terms should all be found at TRIAL level"
  )
})

diseases_df <- rbindlist(list_of_trial_disease_dt)

visited <- c()
paths <- list()

construct_paths_to_root <- function(trial_disease_dt, starting_terms) {
  terms <- trial_disease_dt[trial_disease_dt$code %in% starting_terms, ]

  apply(terms, 1, function(term) {
    if (!term["code"] %in% visited) {
      visited <<- c(visited, term["code"])
      paths <<- append(paths, list(code = term["code"], disease = term["disease"]))
    }
  })

  # For each term's parents
  lapply(terms$parents, function(p_chr) {
    assertthat::assert_that(length(p_chr) == 1, msg = "Parents character vector should have length of 1")
    p_list <- strsplit(p_chr, split = ",\\s*")
    # Apply the same path construction to each parent
    lapply(p_list[[1]], function(p_chr) {
      if (!p_chr %in% visited) {
        construct_paths_to_root(trial_disease_dt, starting_terms = p_chr)
      }
    })
  })
}

noop <- lapply(list_of_trial_disease_dt, function(dt) construct_paths_to_root(dt, ncit_code))
# path_of_codes
