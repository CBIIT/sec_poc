import datetime
import argparse
import os
import os.path
import pandas as pd
import psycopg2
import psycopg2.extras
from sqlalchemy import create_engine

parser = argparse.ArgumentParser(description='Extract a copy of the criteria files and criteria types files.')

parser.add_argument('--dbname', action='store', type=str, required=True)
parser.add_argument('--host', action='store', type=str, required=True)
parser.add_argument('--user', action='store', type=str, required=True)
parser.add_argument('--password', action='store', type=str, required=True)
parser.add_argument('--port', action='store', type=str, required=True)
parser.add_argument('--filedir', action='store', type=str, required=True)



args = parser.parse_args()


# construct an engine connection string
engine_string = "postgresql+psycopg2://{user}:{password}@{host}:{port}/{database}".format(
    user = args.user,
    password = args.password,
    host = args.host,
    port = args.port,
    database = args.dbname,
)

# create sqlalchemy engine
engine = create_engine(engine_string)

# read a table from database into pandas dataframe, replace "tablename" with your table name
df_crit_types = pd.read_sql_table('criteria_types',engine)
df_trial_criteria = pd.read_sql_table('trial_criteria', engine)
s = datetime.datetime.now().isoformat().replace('-','_').replace(':','_')

file_name_crit_types = os.path.join(args.filedir, "criteria_types_"+ s+ ".csv")
file_name_trial_crits = os.path.join(args.filedir, "trial_criteria_" + s +".csv")
print(file_name_crit_types, file_name_trial_crits)
df_crit_types.to_csv(file_name_crit_types, sep='|', encoding='utf-8')
df_trial_criteria.to_csv(file_name_trial_crits, sep='|', encoding='utf-8')

