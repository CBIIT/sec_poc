library(httr)


get_lat_long_for_zipcode  <- function(zipcode) {
  dbinfo <- config::get()
  print(zipcode)
  #https://public.opendatasoft.com/api/records/1.0/search/?dataset=us-zip-code-latitude-and-longitude&q=80302&facet=state&facet=timezone&facet=dst
  
  # https://public.opendatasoft.com/api/records/1.0/search/?dataset=georef-united-states-of-america-zc-point&q=71016&
  
  
  d <-
    GET(
      "https://dev.virtualearth.net/REST/v1/Locations",
      query = list(CountryRegion = 'US', 
                   q = toString(zipcode),
                   maxResults =1 ,
                   key =  dbinfo$bing_maps_api_key,
                   postalCode = zipcode)
    )
  
  pdata <- content(d)
  #print(pdata)
  if (pdata$resourceSets[[1]]$estimatedTotal == 1) {
    return(c(
      pdata$resourceSets[[1]]$resources[[1]]$geocodePoints[[1]]$coordinates[[1]],
      pdata$resourceSets[[1]]$resources[[1]]$geocodePoints[[1]]$coordinates[[2]],
      #pdata$records[[1]]$fields$usps_city,
      pdata$resourceSets[[1]]$resources[[1]]$address$locality,
      #pdata$records[[1]]$fields$stusps_code
      pdata$resourceSets[[1]]$resources[[1]]$address$adminDistrict
    ))
  } else {
    return(pdata$resourceSets[[1]]$estimatedTotals)
  }
}