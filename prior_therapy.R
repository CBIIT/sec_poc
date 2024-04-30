
#yesNoMaybeEnum <- function() {list(YES = 'YES', NO = 'NO', MAYBE = 'MAYBE')}

# If there are trial-level thesaursus codes (trial_pt_codes), returns TRUE if any
# of the patient_pt_codes are descendants of, or ancestors of,  any of the
# trial_pt_codes.  If none of the trial codes match in this way, returns FALSE.
# If either trial_pt_codes or patient_pt_codes are empty, returns NA.
#
# This is appropriate for matching on trial prior therapy criteria, since we want
# to match if any of the patient prior therapies are the same as, more
# specific, or less specific than the trial criteria.
compute_pt_matches <- function(trial_pt_codes, patient_pt_codes, safe_query) {
  if ((is.null(trial_pt_codes) || is.na(trial_pt_codes))
      || (is.null(patient_pt_codes) || length(patient_pt_codes) == 0)) {
    return(NA)
    
  } else {
    quoted_patient_codes <- toString(shQuote(patient_pt_codes))
    trial_code_v <- unlist(strsplit(trial_pt_codes, ','))
    for (i in 1:length(trial_code_v)) {
      sql = sprintf('select count(*) as num_descendants from ncit_tc where parent = $1 and descendant in (%s)', quoted_patient_codes)
      result_set <- safe_query(dbGetQuery, sql, params = trial_code_v[i])
      if (result_set$num_descendants[[1]] > 0) {
        return(TRUE)
      } else {
        
        # Check ancestors, including indirect ancestors, for a match.
        sql = sprintf('select count(*) as num_ancestors from ncit_tc where descendant = $1 and parent in (%s)', quoted_patient_codes)
        result_set <- safe_query(dbGetQuery, sql, params = trial_code_v[i])
        if (result_set$num_ancestors[[1]] > 0) {
          return(TRUE)
        }
      }
    }
    return(FALSE)
  }
}
