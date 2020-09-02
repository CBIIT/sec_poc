#
# R Function to get the ncit code for a given intervention_name
#
get_ncit_code_for_intervention  <- function(intervention_string) {
  start <- 0
  
  d <-
    POST(
      "https://clinicaltrialsapi.cancer.gov/v1/interventions?",
      body = list(
        name = intervention_string
      ),
      encode = "json"
    )
  pdata <- content(d)
  
  for (i in pdata$terms) {
    # print(paste(i$name, i$codes[1]))
    if(i$name == intervention_string) {
      return(i$codes[[1]])
    }
  }
  
  
  
  return("")
}