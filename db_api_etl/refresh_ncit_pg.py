#!/usr/bin/env python
# coding: utf-8

# # Generate the transitive closure table for the NCI Thesaurus
# 
# This notebook shows how to generate the transitive closure table for the NCI (National Cancer Institute) Thesaurus. 
# It uses a combination of sqlite and pandas to minimize the amount of code needed to create the transitive closure table.  
# 
# Download the latest flat format thesaurus file from here: https://cbiit.cancer.gov/evs-download/thesaurus-downloads
# Unzip the file into a directory, and set the full path to the name of the Thesaurus.txt fle.
# 
# The NCI Thesaurus (NCIt) is a multi-axial hierarchy.  If a node has more than one parent, then the parents column will contain the C codes for the parents in a pipe delimited string.
# 
# Hubert Hickman

import sqlite3
import pandas
import zipfile
import pprint
import sys
import wget
import datetime
import argparse
import tempfile
from pathlib import Path
import requests
import psycopg2
import psycopg2.extras
import csv
import io

start_time = datetime.datetime.now()
pp = pprint.PrettyPrinter(indent=4)

parser = argparse.ArgumentParser(description='Download the NCIT Thesaurus Zip file and create transitive closure tables in a sqlite database.')

parser.add_argument('--dbname', action='store', type=str, required=False)
parser.add_argument('--host', action='store', type=str, required=False)
parser.add_argument('--user', action='store', type=str, required=False)
parser.add_argument('--password', action='store', type=str, required=False)
parser.add_argument('--port', action='store', type=str, required=False)

# You are here

args = parser.parse_args()

#con = sqlite3.connect(args.dbfilename)

con = psycopg2.connect(database=args.dbname, user=args.user, host=args.host, port=args.port,
 password=args.password)

cur = con.cursor()

url_fstring = "https://evs.nci.nih.gov/ftp1/NCI_Thesaurus/archive/%s_Release/Thesaurus_%s.FLAT.zip"
r = requests.get('https://api-evsrest.nci.nih.gov/api/v1/concept/ncit',
                 params={'include': 'minimal', 'list': 'C2991'}, timeout=(.4, 7.0))
evs_results = r.json()
print(evs_results)
if len(evs_results) != 1 or 'version' not in evs_results[0]:
    print("NO VERSION NUMBER in returned info from EVS", evs_results)
    sys.exit(0)

current_evs_version = evs_results[0]['version']
print("Current EVS NCIT version :", current_evs_version)
#
# E.g. https://evs.nci.nih.gov/ftp1/NCI_Thesaurus/archive/22.01e_Release/Thesaurus_22.01e.FLAT.zip
# Note that the NCIT Download page MAY have a different version that what EVS is using.  We
# want to stay in sync with EVS
#

check_version_sql = " select version_id from ncit_version where active_version = 'Y'"
cur = con.cursor()
cur.execute(check_version_sql)
rs = cur.fetchone()

if rs is not None and rs[0] == current_evs_version:
    print("POC NCIt is same as EVS NCIt, exiting")
    con.commit()
    con.close()
    sys.exit(0)
elif rs is None:
    print("No current NCIt version noted in the POC db")
else:
    print("EVS NCIt version :", current_evs_version, " POC DB NCIt version:", rs[0])

print("Preparing to process NCIT version", current_evs_version)
url_string = url_fstring % (current_evs_version, current_evs_version)

tfilename = Path(url_string).name
tfile = tempfile.NamedTemporaryFile(suffix=tfilename)
thesaurus_zip = wget.download(url=url_string, out=tfile.name)
arch = zipfile.ZipFile(thesaurus_zip, mode='r')

print("Extracting thesaurus file contents")
thesaurus_file = arch.open('Thesaurus.txt', mode='r')

cur.execute("drop index if exists ncit_code_index")
cur.execute("drop index if exists lower_pref_name_idx")
# Names in the dataframe will become columns in the sqlite database

# In[37]:
cur.execute("truncate table ncit")
con.commit()
thesaurus_rows = []
reader = csv.reader(io.TextIOWrapper(thesaurus_file, encoding='utf-8'), delimiter='\t')
for a_row in reader:
    t = a_row
    t.append(a_row[3].split('|')[0])
    thesaurus_rows.append(t)

con.commit()

ncit_ins_sql = """
    insert into ncit(code, url, parents, synonyms, definition, display_name, concept_status, 
         semantic_type, pref_name) values(%s,%s,%s,%s,%s,%s,%s,%s,%s)
    """

psycopg2.extras.execute_batch(cur, ncit_ins_sql, thesaurus_rows, page_size=1000)


con.commit()


print("creating thesaurus file indexes")
cur.execute("create index ncit_code_index on ncit(code)")
cur.execute("create index lower_pref_name_idx on ncit(lower(pref_name))")
con.commit()

# In[43]:


print("getting all concepts that have parents")
cur = con.cursor()
cur.execute("select code, parents from ncit where (parents is not null and parents <> '')")

# Get all of the concepts that have parents into a result set

# In[44]:


concept_parents = cur.fetchall()

# In[45]:


#print(len(concept_parents))

# In[46]:


con.commit()

# Create a table that will hold the concept, the parent, the path from parent to the concept, and the level (need this to properly recurse along the relationship).

# In[47]:


cur.execute('truncate table parents')

# Put the direct concept &rarr; parent relationships in the table as level 1 items.

# In[48]:

cur.execute("drop index if exists par_concept_idx")

cur.execute("drop index if exists par_par_idx")

con.commit()
for concept, parents in concept_parents:
    parentl = parents.split('|')
    for p in parentl:
        cur.execute("insert into parents(concept, parent, level, path )values(%s,%s,1,%s)",
                    (concept, p, p + '|' + concept))
con.commit()

# In[49]:


#print(con.execute("select * from parents where parent= 'C3824'").fetchall())

# In[50]:


cur.execute("create index par_concept_idx on parents(concept)")
cur.execute("create index par_par_idx on parents(parent)")

# This is the key part - execute the recursive SQL to generate the set of all paths through the NCIt.  We'll prune this to just concepts and descendants a few steps below.

# In[63]:

print("computing transitive closure")
cur.execute("drop table if exists ncit_tc_with_path")
cur.execute('create table ncit_tc_with_path as with recursive ncit_tc_rows(parent, descendant, level, path ) as ' +
            '(select parent, concept as descendant, level, path from parents union all ' +
            "select p.parent , n.descendant as descendant, n.level+1 as level ,  p.parent || '|' || n.path  as path " +
            'from ncit_tc_rows n join parents p on n.parent = p.concept  ' +
            ') select * from ncit_tc_rows')

cur.execute('create index ncit_tc_path_parent on ncit_tc_with_path(parent)')
cur.execute('CREATE INDEX ncit_tc_path_descendant on ncit_tc_with_path(descendant)')
con.commit()

# Create the transitive closure table.  This fits the mathematical definition of transitive closure.

# In[52]:


cur.execute('drop table if exists ncit_tc')
cur.execute("create table ncit_tc as select distinct parent, descendant from ncit_tc_with_path ")
cur.execute('create index ncit_tc_parent on ncit_tc (parent) ')

# In[53]:

cur.execute('select count(*) from ncit_tc')
total_num_rows_in_tc = cur.fetchone()[0]
print("There are ", total_num_rows_in_tc, "rows in the transitive closure table")

# In[54]:


#pp.pprint(con.execute("select count(*) from ncit_tc where parent = 'C7057'").fetchall())

# In[55]:


#pp.pprint(con.execute("select code from ncit where parents is null").fetchall())

# In[56]:


#pp.pprint(con.execute("select * from ncit_tc limit 10").fetchall())

# We need to add in the reflexive relations (i.e. xRx for any concept x).  This is a convenience to simplify the subsumption operations using the database table.

# In[57]:


cur.execute(
    '''with codes as 
    (
    select distinct parent as code from ncit_tc
    union
    select distinct descendant as code from ncit_tc
    ) 
    insert into ncit_tc (parent, descendant) 
    select c.code as parent, c.code as descendant from codes c
    ''')

# In[64]:


cur.execute(
    '''with codes as 
    (
    select distinct parent as code from ncit_tc
    union
    select distinct descendant as code from ncit_tc
    ) 
    insert into ncit_tc_with_path (parent, descendant, level, path) 
    select c.code, c.code, 0  , c.code  from codes c
    ''')

# In[59]:



# In[61]:


cur.execute("select count(*) from ncit_tc_with_path ")
num_paths = cur.fetchone()[0]
print("There are ", num_paths , " distinct paths in the NCIt.")

# In[62]:


cur.execute("drop index if exists tc_parent_index")
cur.execute("create index tc_parent_index on ncit_tc(parent)")

# At this point, several options are available.
# * Use this table in operations.
# * Export the table in CSV to use in other situations
# * Reinstantiate the table as a pandas dataframe to use directly in Python/pandas

# In[65]:


con.commit()

# Now update the synonyms
sql = '''select code, synonyms from ncit 
where (concept_status is null or (concept_status not like '%Obsolete%' and concept_status not like '%Retired%') ) 
'''

insert_sql = '''
insert into ncit_syns(code, syn_name, l_syn_name) values(%s,%s,%s)
'''
cur = con.cursor()
cur.execute('drop table if exists ncit_syns')
con.commit()
cur.execute(
    """
create table ncit_syns
(
code varchar(100),
syn_name text,
l_syn_name text)""")
con.commit()
cur.execute(sql)
r = cur.fetchall()
#bar = progressbar.ProgressBar(maxval=len(r),
#
#                       widgets=[progressbar.Bar('=', '[', ']'), ' ', progressbar.Percentage()])
#bar.start()

biglist = []
i=0
for rec in r:

    c = rec[0]
    synonyms = rec[1].split('|')
    newlist = list(zip([c] * len(synonyms), synonyms, [s.lower() for s in synonyms]))

    i += 1
 #   bar.update(i)
    biglist.extend(newlist)
    #print(rs)

print("inserting synonmyms in database")
cur.execute("BEGIN TRANSACTION")
cur.executemany(insert_sql, biglist )
con.commit()
print("done inserting synonyms in database")
cur.execute('create index ncit_syns_code_idx on ncit_syns(code)')
cur.execute('create index ncit_syns_syn_name on ncit_syns(syn_name)')
cur.execute('create index ncit_lsyns_syn_name on ncit_syns(l_syn_name)')

# First make sure other versions are not marked as active

cur.execute('update ncit_version set active_version = NULL')
cur.execute("""insert into ncit_version(version_id, downloaded_url, transitive_closure_generation_date, active_version)
           values(%s,%s,%s,%s)
   """, [current_evs_version, url_string, datetime.datetime.now(), 'Y'])
con.commit()

end_time = datetime.datetime.now()
print("Process complete in ", end_time - start_time)

con.close()

