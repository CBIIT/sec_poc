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

start_time = datetime.datetime.now()
pp = pprint.PrettyPrinter(indent=4)

parser = argparse.ArgumentParser(description='Download the NCIT Thesaurus Zip file and create transitive closure tables in a sqlite database.')

parser.add_argument('--dbfilename', action='store', type=str, required=True)
parser.add_argument('--thesaurus_url', action='store', type=str, required=True)

args = parser.parse_args()

# Set these to whatever you need them to be.
print("downloading thesaurus file from ", args.thesaurus_url)
#thesaurus_url = 'http://evs.nci.nih.gov/ftp1/NCI_Thesaurus/Thesaurus_19.08d.FLAT.zip'

thesaurus_zip = wget.download(args.thesaurus_url)


arch = zipfile.ZipFile(thesaurus_zip, mode='r')

print("extracting thesaurus file")
thesaurus_file = arch.open('Thesaurus.txt', mode='r')



con = sqlite3.connect(args.dbfilename)

cur = con.cursor()
cur.execute("select count(*) from ncit_version where version_id = ? and active_version = 'Y' ", [args.thesaurus_url])
ver_rs = cur.fetchone()[0]

#
# Check to see if we need to process this version.  If we do, we will write a record to ncit_version after we are all done
# with the transitive closure generation.
#

if ver_rs == 1:
    # No need to process this version.
    print("Version", args.thesaurus_url, "is the current version - nothing to do and exiting.")
    sys.exit()

print(ver_rs)


# Names in the dataframe will become columns in the sqlite database

# In[37]:


ncit_df = pandas.read_csv(thesaurus_file, delimiter='\t', header=None,
                          names=('code', 'url', 'parents', 'synonyms',
                                 'definition', 'display_name', 'concept_status', 'semantic_type', 'pref_name'))

# Add in the preferred name field - the first choice in the list of synonyms.  Note that this column is not in the NCI Thesaurus and can be computed in pandas or in sqlite.

# In[38]:


ncit_df['pref_name'] = ncit_df.apply(lambda row: row['synonyms'].split('|')[0], axis=1)

# In[39]:


# print(ncit_df)


# In[40]:

# Write the dataframe out to the sqlite table
print("Writing thesaurus file to database")
ncit_df.to_sql('ncit', con=con, if_exists='replace')

#con.execute("delete from ncit where concept_status in ('Obsolete_Concept', 'Retired_Concept')")

# In[42]:

print("creating thesaurus file indexes")
con.execute("drop index if exists ncit_code_index")
con.execute("create index ncit_code_index on ncit(code)")
con.execute("drop index if exists lower_pref_name_idx")
con.execute("create index lower_pref_name_idx on ncit(lower(pref_name))")
con.commit()

# In[43]:


print("getting all concepts that have parents")
cur = con.cursor()
cur.execute("select code, parents from ncit where parents is not null")

# Get all of the concepts that have parents into a result set

# In[44]:


concept_parents = cur.fetchall()

# In[45]:


#print(len(concept_parents))

# In[46]:


con.commit()

# Create a table that will hold the concept, the parent, the path from parent to the concept, and the level (need this to properly recurse along the relationship).

# In[47]:


con.execute('drop table if exists parents')
con.execute("""
create table parents (
concept text,
parent text,
path text,
level int)
""")

# Put the direct concept &rarr; parent relationships in the table as level 1 items.

# In[48]:


for concept, parents in concept_parents:
    parentl = parents.split('|')
    for p in parentl:
        con.execute("insert into parents(concept, parent, level, path )values(?,?,1,?)",
                    (concept, p, p + '|' + concept))
con.commit()

# In[49]:


#print(con.execute("select * from parents where parent= 'C3824'").fetchall())

# In[50]:


con.execute("drop index if exists par_concept_idx")
con.execute("create index par_concept_idx on parents(concept)")
con.execute("drop index if exists par_par_idx")
con.execute("create index par_par_idx on parents(parent)")

# This is the key part - execute the recursive SQL to generate the set of all paths through the NCIt.  We'll prune this to just concepts and descendants a few steps below.

# In[63]:

print("computing transitive closure")
con.execute("drop table if exists ncit_tc_with_path")
con.execute('create table ncit_tc_with_path as with recursive ncit_tc_rows(parent, descendant, level, path ) as ' +
            '(select parent, concept as descendant, level, path from parents union all ' +
            "select p.parent , n.descendant as descendant, n.level+1 as level ,  p.parent || '|' || n.path  as path " +
            'from ncit_tc_rows n join parents p on n.parent = p.concept  ' +
            ') select * from ncit_tc_rows')

con.execute('create index ncit_tc_path_parent on ncit_tc_with_path(parent)')
con.execute('CREATE INDEX ncit_tc_path_descendant on ncit_tc_with_path(descendant)')
con.commit()

# Create the transitive closure table.  This fits the mathematical definition of transitive closure.

# In[52]:


con.execute('drop table if exists ncit_tc')
con.execute("create table ncit_tc as select distinct parent, descendant from ncit_tc_with_path ")
con.execute('create index ncit_tc_parent on ncit_tc (parent) ')

# In[53]:

total_num_rows_in_tc = con.execute('select count(*) from ncit_tc').fetchone()[0]
print("There are ", total_num_rows_in_tc, "rows in the transitive closure table")

# In[54]:


#pp.pprint(con.execute("select count(*) from ncit_tc where parent = 'C7057'").fetchall())

# In[55]:


#pp.pprint(con.execute("select code from ncit where parents is null").fetchall())

# In[56]:


#pp.pprint(con.execute("select * from ncit_tc limit 10").fetchall())

# We need to add in the reflexive relations (i.e. xRx for any concept x).  This is a convenience to simplify the subsumption operations using the database table.

# In[57]:


con.execute(
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


con.execute(
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


reflexive_concepts = con.execute("select count(*) from ncit_tc where parent=descendant").fetchone()[0]

# In[60]:


print('There are ', reflexive_concepts, ' reflexive relationships added to the transitive closure.')

# In[61]:


num_paths = con.execute("select count(*) from ncit_tc_with_path ").fetchone()[0]
print("There are ", num_paths , " distinct paths in the NCIt.")

# In[62]:


con.execute("drop index if exists tc_parent_index")
con.execute("create index tc_parent_index on ncit_tc(parent)")

# At this point, several options are available.
# * Use this table in operations.
# * Export the table in CSV to use in other situations
# * Reinstantiate the table as a pandas dataframe to use directly in Python/pandas

# In[65]:


con.commit()

# update the
# Now update the version table to note when we generated the TC

u1_sql = """ update ncit_version set active_version = 'N' """
cur.execute(u1_sql)
con.commit()

i1_sql = """
insert into ncit_version(version_id, tc_gen_date, active_version) values (?,?,?)
"""
cur.execute(i1_sql, [args.thesaurus_url, datetime.datetime.now(), 'Y'])
con.commit()

end_time = datetime.datetime.now()

print("Process complete in ", end_time - start_time)
# In[ ]:
