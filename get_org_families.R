library(httr)
library(jsonlite)
library(stringr)

#
# R Function to get the list of org families to display
#
get_org_families  <- function() {
  fix_family_name  <- function(family_string) {
    family_strings <- str_split(family_string, "\r")
    ret_string <- ""
    for (row in 1:length(family_strings[[1]])) {
      if (!(
        family_strings[[1]][row] %in% c(
          "Childrens Oncology Group",
          "Alliance for Clinical Trials in Oncology",
          "NCIC Clinical Trials Group",
          "Southwest Oncology Group (SWOG)",
          "ECOG-ACRIN Cancer Research Group",
          "NRG Oncology",
          "VA",
          "VA NAVIGATE",
          "VA HOPE"
          
        )
      )) {
        ret_string <- family_strings[[1]][row]
        
      }
    }
    #print(paste("get_org_families " , family_string, 'returning', ret_string))
    
    #new_string <- gsub("VA HOPE", "", family_string, fixed = TRUE)
    #new_string <- gsub("VA NAVIGATE", "", new_string, fixed = TRUE)
    #new_string <- gsub("VA", "", new_string, fixed = TRUE)
    #new_string <- gsub("\r", "" , new_string, fixed = TRUE)
    return(ret_string)
    
  }
  
  
  start <- 0
  
  CTS_V2_API_KEY <- Sys.getenv('CTS_V2_API_KEY')
  
  if (nchar(CTS_V2_API_KEY) == 0) {
    # Use CTS V1
    d <-
      POST(
        "https://clinicaltrialsapi.cancer.gov/v1/terms",
        body = list(term_type = 'sites.org_family',
                    size = 0),
        encode = "json"
      )
    pdata <- content(d)
    total_to_return <- pdata$total
    print(total_to_return)
    
    url_string <-
      paste(
        "https://clinicaltrialsapi.cancer.gov/v1/terms?term_type=sites.org_family&size=",
        total_to_return,
        sep = ''
      )
    
    data1 <- fromJSON(url_string)
    df1 <- flatten(data1$terms)
    df1$fixed_term <-
      lapply(df1$term, fix_family_name)
    newdf <- df1[c("fixed_term")]
    
    
    z <- subset(newdf, stri_length(newdf$fixed_term) > 0)
  } else {
    # V2
    print("v2")
    d <-
      GET(
        "https://clinicaltrialsapi.cancer.gov/api/v2/trials",
        query = list(
          agg_field = 'sites.org_family',
          current_trial_status = 'Active',
          include = 'none'
        ),
        add_headers(`x-api-key` = CTS_V2_API_KEY, `Content-Type` = 'application/json')
      )
    pdata <- content(d)
    
    dft <- do.call("rbind", pdata$aggregations$sites.org_family)
    df1 <- as.data.frame(dft)
    df1$fixed_term <-
      lapply(df1$key, fix_family_name)
    newdf <- df1[c("fixed_term")]
    
    
    z <- unique(subset(newdf, stri_length(newdf$fixed_term) > 0))
    # browser()
    
  }
  # browser()
  return(z$fixed_term)
}