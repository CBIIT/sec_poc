#
# Test for check_if_any.R.
# TODO(callaway): use sqlite or something else more lightweight than an
# actual postgres connection to a local DB.
#

library(pool)

source('check_if_any.R')


# On error print stack traces.
options(error = quote({
  dump.frames(to.file=T, dumpto='last.dump')
  load('last.dump.rda')
  print(last.dump)
  q()
}))


pool_con <- dbPool(
  drv = RPostgres::Postgres(),
  dbname = 'sec',
  host = 'localhost', 
  user = 'secapp',
  password = 'test',
  port = 5432, 
  idleTimeout = 300,
  minSize = 0,
  maxSize = 1,
  validationInterval = 60000000000
)


# TODO(callaway): re-use this function, copied from app.R.
generate_safe_query <- function(pool) {
  function(db_function, ...) {
    db_function(pool, ...)
  }
}


test_success <- function(safe_query, test_function) {
  ncit_code = 'C254'
  participant_codes <- "'C730','C75150','C81444'"
  result <- test_function(participant_codes, safe_query, ncit_code)
  if (result != 'YES') {
  	stop(sprintf('Expecting YES for code %s and participant_codes %s', ncit_code, participant_codes))
  }
}


test_failure <- function(safe_query, test_function) {
  codes <- list(
  	'C999999999',  # Code does not exist in local DB
  	'C9999')       # Code exists, but does not match
  participant_codes <- "'C730','C75150','C81444'"
  for (code in codes) {
	result <- test_function(participant_codes, safe_query, code)
	if (result != 'NO') {
      stop(sprintf('Expecting NO for code %s and participant_codes %s', code, participant_codes))
	}
  }
}


main <- function() {
  safe_query <<- generate_safe_query(pool_con)
  test_success(safe_query, check_if_any)
  test_failure(safe_query, check_if_any)
  test_success(safe_query, check_if_any_in_descendants_or_parents)
  test_failure(safe_query, check_if_any_in_descendants_or_parents)
  print('All tests passed.')
}


if(!interactive()) {
  main()
}
