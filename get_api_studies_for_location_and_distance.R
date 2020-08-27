#
# R Function to get the list of studies from the API 
# for a given lat,long, and distance 
#
get_api_studies_for_location_and_distance  <- function(lat, long, num_miles) {
  start <- 0
  
  d <-
    POST(
      "https://clinicaltrialsapi.cancer.gov/v1/clinical-trials",
      body = list(
        current_trial_status = 'active',
        primary_purpose.primary_purpose_code = c('treatment','screening'),
        sites.org_coordinates_lat = lat,
        sites.org_coordinates_lon = long,
        sites.org_coordinates_dist = paste(num_miles,'mi', sep=''),
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