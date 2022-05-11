
#
import psycopg2
import argparse
import pandas
import sys
from sqlalchemy import create_engine, inspect


print(sys.argv)

parser = argparse.ArgumentParser(description='Import the disease codes into the crosswalk table')

parser.add_argument('--dbname', action='store', type=str, required=False)
parser.add_argument('--host', action='store', type=str, required=False)
parser.add_argument('--user', action='store', type=str, required=False)
parser.add_argument('--password', action='store', type=str, required=False)
parser.add_argument('--port', action='store', type=str, required=False)

args = parser.parse_args()
print(args.dbname)

DATABASE_URI = "postgresql://{}:{}@{}:{}/{}".format(args.user, args.password, args.host, args.port, args.dbname)
engine = create_engine(DATABASE_URI)

insp = inspect(engine)
print(insp.get_table_names() )

 
con = psycopg2.connect(database=args.dbname, user=args.user, host=args.host, port=args.port,
 password=args.password)

cur = con.cursor()


def import_table(excel_file_name, sheetname, con):
    df = pandas.read_excel(excel_file_name, sheet_name=sheetname)
    df.columns = [c.replace(' ', '_').replace('(', '_').replace(')', '').replace('/', '_').replace('>','_').replace('=','_').lower() for c in df.columns]
    
    table_name = sheetname.lower().replace('-', '_').replace(' ', '_')
    print('Table name is ' + table_name)
    
    df.to_sql(table_name, con=con, if_exists='replace')


import_table('20211124_disease_codes.xlsx', 'ICD10', engine)
import_table('20211124_disease_codes.xlsx', 'ICD9', engine)

cur.execute("delete from curated_crosswalk")
cur.execute(""" 
insert into curated_crosswalk(code_system, disease_code, preferred_name, evs_c_code, evs_preferred_name) 
select code_system, disease_code, preferred_name, evs_c_code, evs_preferred_name from icd10 
union
select code_system, disease_code, preferred_name, evs_c_code, evs_preferred_name from icd9 

""")
cur.execute("drop table if exists icd10")
cur.execute("drop table if exists icd9")
con.commit()

con.close()


