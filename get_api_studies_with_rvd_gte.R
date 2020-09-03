#
# R Function to get the list of studies from the API 
# for a given lat,long, and distance 
#
get_api_studies_with_rvd_gte  <- function(a_date) {
  start <- 0
  
  d <-
    POST(
      "https://clinicaltrialsapi.cancer.gov/v1/clinical-trials",
      body = list(
        current_trial_status = 'active',
        primary_purpose.primary_purpose_code = c('treatment','screening'),
        record_verification_date_gte = a_date,
        include = list('nct_id'),
        size = 50,
        from = start
      ),
      encode = "json"
    )
  pdata <- content(d)
  total_to_return <- pdata$total
  
  df <- rbindlist(pdata$trials)
  num_returned <- nrow(df)
  start <- num_returned
  while(start < total_to_return) {
    d <-
      POST(
        "https://clinicaltrialsapi.cancer.gov/v1/clinical-trials",
        body = list(
          current_trial_status = 'active',
          primary_purpose.primary_purpose_code = c('treatment', 'screening'),
          record_verification_date_gte = a_date,
          include = list('nct_id'),
          size = 50,
          from = start
        ),
        encode = "json"
      )
    pdata <- content(d)
    dfi <- rbindlist(pdata$trials) # Turns the list into a dataframe
    start <- start + nrow(dfi)
    df <- rbind(df, dfi)
    
  }
  # print(df)
  return(df)
}