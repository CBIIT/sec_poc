import argparse
import datetime

import psycopg2
import psycopg2.extras
import requests

drop_sql = "drop table if exists associations"
table_sql = """
create table associations (
association     text,
code text,
code_name text,
related_code text,
related_name text
)
"""
index_sql1 = "create index association_type_code on associations(association, code)"
index_sql2 = "create index association_code on associations(code)"
index_sql3 = (
    "create index association_rel_code on associations(association,related_code)"
)
index_sql4 = "create index association_rel_code on associations(related_code)"

insert_sql = "insert into associations(association, code, code_name, related_code, related_name) values (%s,%s,%s,%s,%s)"

start_time = datetime.datetime.now()

parser = argparse.ArgumentParser(
    description="Update the specified sqlite database with information from the cancer.gov API"
)
parser.add_argument("--dbname", action="store", type=str, required=False)
parser.add_argument("--host", action="store", type=str, required=False)
parser.add_argument("--user", action="store", type=str, required=False)
parser.add_argument("--password", action="store", type=str, required=False)
parser.add_argument("--port", action="store", type=str, required=False)
args = parser.parse_args()


con = psycopg2.connect(
    database=args.dbname,
    user=args.user,
    host=args.host,
    port=args.port,
    password=args.password,
)

cur = con.cursor()

header_api = {"Content-Type": "application/json"}
#
# curl -X 'GET' \
#  'https://api-evsrest.nci.nih.gov/api/v1/concept/ncit/associations/Has_Target?fromRecord=0&pageSize=1000' \
#  -H 'accept: application/json'

cur.execute(drop_sql)
cur.execute(table_sql)
con.commit()

num_concepts_per_evs_call = 6000


def request_associations(starting_from=0):
    r = requests.get(
        f"https://api-evsrest.nci.nih.gov/api/v1/concept/ncit/associations/Has_Target?fromRecord={starting_from}&pageSize=6000",
        timeout=(0.4, 7.0),
        headers=header_api,
    )
    return r.json()


def collect_associations(data, collector):
    for r in data["associationEntries"]:
        collector.append(
            [r["association"], r["code"], r["name"], r["relatedCode"], r["relatedName"]]
        )


data = request_associations(starting_from=0)
associations = []  # Collect results here
collect_associations(data, associations)
local_size = len(associations)
evs_size = data["total"]
while local_size < evs_size:
    data = request_associations(starting_from=local_size)
    collect_associations(data, associations)
    new_local_size = len(associations)
    assert (
        new_local_size > local_size
    ), "Local associations array is not growing after fetching from EVS API. Exiting."
    local_size = new_local_size


assert (
    len(associations) > 0
), "No associations found. Something must be wrong with connection to EVS API."

print(f"inserting {local_size} associations")
psycopg2.extras.execute_batch(cur, insert_sql, associations, page_size=1000)

con.commit()
cur.execute("grant select on associations to sec_read")
con.commit()
