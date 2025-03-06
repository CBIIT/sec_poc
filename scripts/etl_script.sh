python db_api_etl/refresh_ncit_pg.py --dbname sec --host oel8-postgres-1 --user secapp --port 5432 --password 1234
python db_api_etl/nlp_tokenizer.py --dbname sec --host oel8-postgres-1 --user secapp --port 5432
python db_api_etl/api_etl_v2.py --dbname sec --host oel8-postgres-1 --user secapp --port 5432
