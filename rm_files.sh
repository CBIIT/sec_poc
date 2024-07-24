#!/bin/bash

# Define your sets of file names
set_a=($(ls db_api_etl))
set_b=(api_etl_instrumented.py api_etl.py api_etl_v2_instrumented.py api_etl_v2.py criteria_types.csv crit_types_06_23_2021.sql nci_api_db.sql nlp_pg nlp_tokenizer.py refresh_ncit_pg.py refresh_ncit.py test_disease_tree.py trial_criteria_06_23_2021.sql)

# Iterate over set A
for file_a in "${set_a[@]}"; do
  # Check if the file is in set B
  found=false
  for file_b in "${set_b[@]}"; do
    if [ "$file_a" == "$file_b" ]; then
      found=true
      break
    fi
  done

  # If the file is not found in set B, remove it
  if [ "$found" == false ]; then
    echo "Removing $file_a"
    rm "db_api_etl/$file_a"
  fi
done
