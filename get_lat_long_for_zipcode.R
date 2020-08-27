library(httr)

get_lat_long_for_zipcode  <- function(zipcode) {
  #https://public.opendatasoft.com/api/records/1.0/search/?dataset=us-zip-code-latitude-and-longitude&q=80302&facet=state&facet=timezone&facet=dst
  
  d <-
    GET(
      "https://public.opendatasoft.com/api/records/1.0/search",
      query = list(dataset = "us-zip-code-latitude-and-longitude", q = zipcode)
    )
  
  pdata <- content(d)
  print(pdata$nhits)
  if (pdata$nhits == 1) {
    return(c(
      pdata$records[[1]]$fields$latitude,
      pdata$records[[1]]$fields$longitude,
      pdata$records[[1]]$fields$city,
      pdata$records[[1]]$fields$state
    ))
  } else {
    return(pdata$nhits)
  }
}
