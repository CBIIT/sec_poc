library(httr)

get_umls_crosswalk  <- function(umls_ontology, ontology_code, tgt) {
  print(paste("tgt", tgt))
  if(is.na(tgt)) {
    print( 'tgt is NA')
    return()
  }
  
  # 
  # get the service ticket 
  #
  st_service <- "http://umlsks.nlm.nih.gov"
  
  d <-
    POST(
      tgt,
      body = list(
        service = "http://umlsks.nlm.nih.gov"
      ),
      encode = "form",
      add_headers(c("Content-type" = "application/x-www-form-urlencoded", "Accept" = "text/plain"))
    )
  st <- content(d)
  print(st)
  
  # Now do the UMLS crosswalk call
  
  crosswalk_uri <- 'crosswalk/current/source/'
  umls_service <- 'https://uts-ws.nlm.nih.gov/rest/'
  crosswalk_body <- list('ticket' =  st, 'targetSource'=  'NCI')
  crosswalk_url <- paste(umls_service, crosswalk_uri,umls_ontology,'/',ontology_code , sep="" )
  print(crosswalk_url)
  d <-
    GET(
      crosswalk_url,
      query = list('ticket' =  st, 'targetSource' = 'NCI')
    )
  if (d$status_code == 200) {
    #
    # Then we have some codes sent back to us from the crosswalk
    #
    ret_list <- list()
    crosswalk_ret <- content(d)
    crosswalk_results <- crosswalk_ret$result
    for(i in 1:length(crosswalk_results)) {
      print(crosswalk_results[[i]]$ui)
      if (crosswalk_results[[i]]$ui != 'TCGA') {
        ret_list <- append(ret_list, crosswalk_results[[i]]$ui)
      }
    }
    return(ret_list)
  }
  
  return(NULL)
  
  
}
