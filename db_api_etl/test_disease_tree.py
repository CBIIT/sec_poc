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
print("Processing disease tree data")
cur.execute('drop table if exists disease_tree_temp')
con.commit()

sql = """
    create temporary table disease_tree_temp as (
  with recursive parent_descendant(top_code, parent, descendant, level, path_string)
  as (
  select tc.parent as top_code, tc.parent , tc.descendant , 1 as level, n1.pref_name || ' | ' || n2.pref_name as path_string  
  from ncit_tc_with_path tc join ncit n1 on tc.parent = n1.code join ncit n2 on tc.descendant = n2.code 
  where tc.parent 
   in (
         select nci_thesaurus_concept_id
         from distinct_trial_diseases ds where ds.disease_type = 'maintype' or ds.disease_type like  '%maintype-subtype%'
         and nci_thesaurus_concept_id not in ('C2991', 'C2916') union select 'C4913' as nci_thesaurus_concept_id 
   )
   and tc.level = 1 
  union ALL
  select pd.top_code, pd.descendant as parent ,
  tc1.descendant as descendant, 
  pd.level + 1 as level,
  pd.path_string || ' | ' ||  n1.pref_name as path_string
  from parent_descendant pd join
  ncit_tc_with_path tc1 on pd.descendant = tc1.parent and tc1.level = 1
  join ncit n1 on n1.code = tc1.descendant
  )
  -- select * from parent_descendant  where level < 3 order by top_code, level
  ,
  data_for_tree as
  (
  select distinct pd.top_code, n1.pref_name  as parent,
  n2.pref_name  as child,
  pd.level
  --,
  --pd.path_string
  from parent_descendant pd
  join ncit n1 on pd.parent = n1.code 
  join ncit n2 on pd.descendant = n2.code 
  where exists (select dd.nci_thesaurus_concept_id from distinct_trial_diseases dd where dd.nci_thesaurus_concept_id = n2.code )
  -- and (n1.pref_name not like '%AJCC%' and n2.pref_name not like '%AJCC%')
  )
  ,
  all_nodes as (
  select top_code, parent, child, level 
  --, path_string 
  from data_for_tree
  union
  select n.code as top_code, NULL as parent , pref_name  as child, 0 as level 
  --, pref_name as path_string
  from ncit n where n.code in (
        select nci_thesaurus_concept_id
        from distinct_trial_diseases ds where ds.disease_type = 'maintype' or ds.disease_type like  '%maintype-subtype%'
        and nci_thesaurus_concept_id not in ('C2991', 'C2916') union select 'C4913' as nci_thesaurus_concept_id 
  )
  )
  ,
  ctrp_names as (
  select distinct preferred_name, display_name from trial_diseases 
  ),
    all_nodes_ctrp as (   
                        select an.top_code,  replace(replace(replace(ctrp1.display_name, 'AJCC v7', ''), 'AJCC v8', '') , 'AJCC v6', '') as parent , 
                       replace(replace(replace(ctrp2.display_name, 'AJCC v7', ''), 'AJCC v8', ''), 'AJCC v6', '') as child,  
                       level as level,  
                       1 as collapsed, 10 as \"nodeSize\" --, path_string
                       from all_nodes an left outer join ctrp_names ctrp1 on an.parent=ctrp1.preferred_name
                       join ctrp_names ctrp2 on an.child = ctrp2.preferred_name where  ( ctrp1.display_name != ctrp2.display_name or  level = 0) 
                      )
                      select distinct top_code, parent, child, level as levels, collapsed, \"nodeSize\"  from all_nodes_ctrp 
                      where level < 999 
                      )
"""
cur.execute(sql)
sql = """
        insert into disease_tree (code, parent, child, levels, collapsed, \"nodeSize\")
        select top_code as code, replace(parent, '  ', ' '), replace(child, '  ', ' '), levels, collapsed, 
        \"nodeSize\" from disease_tree_temp
        order by code, levels, parent, child;
"""
cur.execute(sql)
con.commit()    

con.close()

