library(httr)

get_lat_long_for_zipcode  <- function(zipcode) {
  #https://public.opendatasoft.com/api/records/1.0/search/?dataset=us-zip-code-latitude-and-longitude&q=80302&facet=state&facet=timezone&facet=dst
  
  # https://public.opendatasoft.com/api/records/1.0/search/?dataset=georef-united-states-of-america-zc-point&q=71016&
  
  
  d <-
    GET(
      "https://public.opendatasoft.com/api/records/1.0/search",
      query = list(dataset = "georef-united-states-of-america-zc-point", q = zipcode)
    )
  
  pdata <- content(d)
  print(pdata$nhits)
  if (pdata$nhits == 1) {
    return(c(
      pdata$records[[1]]$fields$geo_point_2d[[1]],
      pdata$records[[1]]$fields$geo_point_2d[[2]],
      pdata$records[[1]]$fields$usps_city,
      pdata$records[[1]]$fields$stusps_code
    ))
  } else {
    return(pdata$nhits)
  }
}