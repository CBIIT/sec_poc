#
# R Function to get the list of studies from the API for a passed in list of biomarkers and inclusion/exclusion for eligibility criterion
#
get_api_studies_for_biomarkers  <- function(ncit_code, eligibility_criterion ) {
  start <- 0
  CTS_V2_API_KEY <- Sys.getenv('CTS_V2_API_KEY')
  if (nchar(CTS_V2_API_KEY) >  0) {
      # V2
      d <-
        POST(
          'https://clinicaltrialsapi.cancer.gov/api/v2/trials',
          body = list(
            current_trial_status = 'Active',
            primary_purpose = c('TREATMENT', 'SCREENING'),
            biomarkers.nci_thesaurus_concept_id = ncit_code,
            biomarkers.eligibility_criterion = eligibility_criterion, 
            sites.recruitment_status = 'ACTIVE',
            include = list('nct_id'),
            size = 50,
            from = 0
          ),
          encode = "json",
          add_headers(`x-api-key` = CTS_V2_API_KEY, `Content-Type` = 'application/json')
        )
      pdata <- content(d)
      total_to_return <- pdata$total
      
      df <- rbindlist(pdata$data)
      num_returned <- nrow(df)
      start <- num_returned
      while (start < total_to_return) {
        d <-
          POST(
            'https://clinicaltrialsapi.cancer.gov/api/v2/trials',
            body = list(
              current_trial_status = 'Active',
              primary_purpose = c('TREATMENT', 'SCREENING'),
              biomarkers.nci_thesaurus_concept_id =  ncit_code,
              biomarkers.eligibility_criterion = eligibility_criterion, 
              sites.recruitment_status = 'ACTIVE',
              include = list('nct_id'),
              size = 50,
              from = start
            ),
            encode = "json",
            add_headers(`x-api-key` = CTS_V2_API_KEY, `Content-Type` = 'application/json')
          )
        pdata <- content(d)
        dfi <- rbindlist(pdata$data) # Turns the list into a dataframe
        start <- start + nrow(dfi)
        df <- rbind(df, dfi)
        
      }
      return(df)
    }
}
