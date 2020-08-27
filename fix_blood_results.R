fix_blood_results  <- function(s) {
  n <- gsub(',', '',
            gsub('/uL', '',
                 gsub(
                   'and',
                   '&',
                   gsub(
                     '=<',
                     '<=',
                     gsub(
                       'White blood cell count (WBC)',
                       'C51948',
                       gsub('Platelet count', 'C51951', s, fixed = TRUE),
                       fixed = TRUE
                     ),
                     fixed = TRUE
                   ), fixed = TRUE
                 ),
                 fixed = TRUE),
            fixed = TRUE)
  
  return(n)
}