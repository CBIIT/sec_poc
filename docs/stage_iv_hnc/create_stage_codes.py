import json

import psycopg2 as pg
from psycopg2.extras import execute_values

conn = pg.connect(dbname="sec", user="secapp", host="r_363-postgres-1")
cur = conn.cursor()

with open("stage_codes.json") as f:
    codes = json.load(f)

cur.execute("create table if not exists stage_codes (code varchar(30))")
cur.execute("truncate stage_codes")

execute_values(cur, "insert into stage_codes values %s", [(code,) for code in codes])
conn.commit()
