# Get the biomarker list from EVS


library(httr)


get_biomarkers_from_evs  <- function() {
 # https://api-evsrest.nci.nih.gov/api/v1/concept/ncit/C142799/inverseAssociations
  
  d <-
    GET(
      "https://api-evsrest.nci.nih.gov/api/v1/concept/ncit/C142800/inverseAssociations"
     )
    
  
  pdata <- content(d)
  
  #print(pdata)
  dft <- rbindlist(pdata)
  return(dft)
}