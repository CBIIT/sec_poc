#!/bin/bash
start_time=$(date +%s)

function run_py_script() {
  python3 "$1" --user "$DB_USER" --host "$DB_HOST" --port "$DB_PORT" --dbname "$DB_NAME" --password "$DB_PASS"
}
function check_trials_count() {
  PGPASSWORD="$DB_PASS" psql --username="$DB_USER" --host="$DB_HOST" --port="$DB_PORT" --no-password sec -t -c "select count(*) from trials"
}

# Check the NCIT version and refresh if needed
run_py_script /app/refresh_ncit_pg.py
sleep 3

# Now update the tokenizer if needed 
run_py_script /app/nlp_tokenizer.py

# Now run ETL for stage
run_py_script /app/api_etl_v2.py

# Get associations
run_py_script /app/get_associations.py

if [[ $(check_trials_count) -ge '3945' ]]; then
  echo "Trial count after ETL > 3945, Good to run NLP"
  run_py_script /app/nlp_pg/sec_poc_tokenizer.py
  sleep 1
  run_py_script /app/nlp_pg/sec_poc_classifier.py
  sleep 1
  run_py_script /app/nlp_pg/sec_poc_expression_generator.py
fi

end_time=$(date +%s)
elapsed=$((end_time - start_time))
echo "Elapsed time: $elapsed seconds"
