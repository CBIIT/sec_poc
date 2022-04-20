#
# R Function to get the list of studies from the API 
# for a given lat,long, and distance 
#
get_api_studies_for_location_and_distance  <- function(lat, long, num_miles) {
  start <- 0

  CTS_V2_API_KEY <- Sys.getenv('CTS_V2_API_KEY')
  
  if (nchar(CTS_V2_API_KEY) == 0) {
    # V1
    
  d <-
    POST(
      "https://clinicaltrialsapi.cancer.gov/v1/clinical-trials",
      body = list(
        current_trial_status = 'active',
        primary_purpose.primary_purpose_code = c('treatment','screening'),
        sites.org_coordinates_lat = lat,
        sites.org_coordinates_lon = long,
        sites.org_coordinates_dist = paste(num_miles,'mi', sep=''),
        sites.recruitment_status = c('active','approved','enrolling_by_invitation','temporarily_closed_to_accrual'), 
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
          sites.org_coordinates_lat = lat,
          sites.org_coordinates_lon = long,
          sites.org_coordinates_dist = paste(num_miles,'mi',sep=''),
          sites.recruitment_status = c('active','approved','enrolling_by_invitation','temporarily_closed_to_accrual'), 
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
  } else {
    #V2
    print("V2 Studies for location and distance")
    d <-
      POST(
        'https://clinicaltrialsapi.cancer.gov/api/v2/trials',
        body = list(
          current_trial_status = 'Active',
          primary_purpose = c('TREATMENT', 'SCREENING'),
          sites.org_coordinates_lat = lat,
          sites.org_coordinates_lon = long,
          sites.org_coordinates_dist = paste(num_miles,'mi',sep=''),
          sites.recruitment_status = c('active','approved','enrolling_by_invitation','temporarily_closed_to_accrual'), 
          include = list('nct_id'),
          size = 50,
          from = 0
        ),
        encode = "json",
        add_headers(`x-api-key` = CTS_V2_API_KEY, `Content-Type` = 'application/json'),
        timeout(4)
      )
    print(paste("location and distance studies return code = ",d$status_code))
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
            sites.org_coordinates_lat = lat,
            sites.org_coordinates_lon = long,
            sites.org_coordinates_dist = paste(num_miles,'mi',sep=''),
            sites.recruitment_status = c('active','approved','enrolling_by_invitation','temporarily_closed_to_accrual'),      
            include = list('nct_id'),
            size = 50,
            from = start
          ),
          encode = "json",
          add_headers(`x-api-key` = CTS_V2_API_KEY, `Content-Type` = 'application/json'),
          timeout(4)
        )
      pdata <- content(d)
      dfi <- rbindlist(pdata$data) # Turns the list into a dataframe
      start <- start + nrow(dfi)
      df <- rbind(df, dfi)
      
    }
    return(df)
  }
  
}