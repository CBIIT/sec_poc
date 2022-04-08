import requests
import sqlite3
import sys
import datetime
import argparse
import os
import psycopg2
import psycopg2.extras

CTS_V2_API_KEY = os.getenv('CTS_V2_API_KEY')
print(CTS_V2_API_KEY)
header_v2_api = {"x-api-key" : CTS_V2_API_KEY, "Content-Type" : "application/json"}

def get_maintypes(con, lead_disease):
    """Get the maintypes for a NCIt code"""

    s = """
    with minlevel as 
 (select min(level) as min_level from ncit_tc_with_path np join maintypes m 
on np.parent = m.nci_thesaurus_concept_id
 join ncit n on np.parent = n.code 
 join ncit nc on np.descendant = nc.code 
 where np.descendant = %s
 )
 select distinct np.parent as mainytype
from ncit_tc_with_path np join maintypes m 
on np.parent = m.nci_thesaurus_concept_id
 join ncit n on np.parent = n.code 
 join ncit nc on np.descendant = nc.code 
 join minlevel ml on np.level=ml.min_level
 where np.descendant = %s

    """

    cur = con.cursor()
    r = cur.execute(s, [lead_disease, lead_disease])
    rc = cur.fetchall()
   # print(lead_disease, rc)
    return rc


def gen_biomarker_info(biomarkers):
    biomarker_inc_codes = []
    biomarker_inc_names = []
    biomarker_exc_codes = []
    biomarker_exc_names = []
    for b in biomarkers:
        if 'inclusion_indicator' in b and b['inclusion_indicator'] is not None and b['inclusion_indicator'] == 'TRIAL':
            if 'eligibility_criterion' in b and b['eligibility_criterion'] is not None:
                if b['eligibility_criterion'] == 'inclusion':
                    biomarker_inc_string = ''
                    if 'name' in b and b['name'] is not None:
                        biomarker_inc_string += b['name']
                    if 'nci_thesaurus_concept_id' in b and b['nci_thesaurus_concept_id'] is not None:
                        biomarker_inc_string += ' (' + b['nci_thesaurus_concept_id'] + ')'
                        biomarker_inc_codes.append( b['nci_thesaurus_concept_id'])
                    biomarker_inc_names.append(biomarker_inc_string)
                elif b['eligibility_criterion'] == 'exclusion':
                    biomarker_exc_string = ''
                    if 'name' in b and b['name'] is not None:
                        biomarker_exc_string += b['name']
                    if 'nci_thesaurus_concept_id' in b and b['nci_thesaurus_concept_id'] is not None:
                        biomarker_exc_string += ' (' + b['nci_thesaurus_concept_id'] + ')'
                        biomarker_exc_codes.append( b['nci_thesaurus_concept_id'])
                    biomarker_exc_names.append(biomarker_exc_string)

    return (biomarker_inc_codes, biomarker_inc_names, biomarker_exc_codes, biomarker_exc_names)

start_time = datetime.datetime.now()

parser = argparse.ArgumentParser(
    description='Update the specified sqlite database with information from the cancer.gov API')
parser.add_argument('--dbname',action='store',type=str, required=False )
parser.add_argument('--host',action='store',type=str, required=False )
parser.add_argument('--user',action='store',type=str, required=False )
parser.add_argument('--password',action='store',type=str, required=False )
parser.add_argument('--port',action='store',type=str, required=False )
args = parser.parse_args()


con = psycopg2.connect(database=args.dbname, user=args.user, host=args.host, port=args.port,
 password=args.password)

cur = con.cursor()
cur.execute('delete from  trial_diseases ')
cur.execute('delete from  trials')
cur.execute('delete from   maintypes')
cur.execute('delete from trial_maintypes')
cur.execute('delete from distinct_trial_diseases')
cur.execute('delete from  trial_sites')
cur.execute('delete from  trial_unstructured_criteria')
con.commit()

# First get the maintypes, then get the study data needed.

r = requests.get('https://clinicaltrialsapi.cancer.gov/api/v2/diseases',
                  params={'type': 'maintype', 'type_not': 'subtype', 'size': 100, 'include' : 'codes'}, headers = header_v2_api
 )

t = r.text
j = r.json()
maintypes = []
for t in j['data']:
    maintypes.append(t['codes'])

cur.executemany('insert into maintypes(nci_thesaurus_concept_id) values (%s)', maintypes)
con.commit()

today_date = datetime.date.today()
two_years_ago = today_date.replace(year = today_date.year - 2)

size = 1
start = 0
include_items = ['nct_id',
                 'eligibility.structured.max_age_in_years',
                 'eligibility.structured.min_age_in_years',
                 'eligibility.structured.gender',
                 'eligibility.unstructured',
                 'diseases',
                 'brief_title',
                 'official_title',
                 'brief_summary',
                 'detail_description',
                 'current_trial_status',
                 'primary_purpose',
                 'phase',
                 'screening',
                 'primary_purpose_code',
                 'study_source',
                 'record_verification_date',
                 'sites',
                 'amendment_date',
                 'biomarkers'
                 ]



#data = {'current_trial_status': 'Active'
  #      'primary_purpose.primary_purpose_code': ['treatment', 'screening'],
      #  'sites.recruitment_status': 'ACTIVE',
    #    'size': size,
    #    'from': 0
    #    ,
    #    'record_verification_date_gte': two_years_ago.isoformat()
 #       }


data = {'current_trial_status': 'Active',
        'primary_purpose': ['TREATMENT', 'SCREENING'],
        'sites.recruitment_status': 'ACTIVE',
        'size' : 1,
        'record_verification_date_gte': two_years_ago.isoformat(),
        'from' : 0
        }
data['include'] = include_items

# NCT02944578
r = requests.post('https://clinicaltrialsapi.cancer.gov/api/v2/trials',
                 headers = header_v2_api, json  = data)



t = r.text
j = r.json()
# print(j)
total = j['total']
size = 50
data['size'] = size

print("there are ", total, 'trials')
run = True
while run:
    print(start)
    r = requests.post('https://clinicaltrialsapi.cancer.gov/api/v2/trials',
                      headers=header_v2_api, json=data)
    print('status code returned = ', r.status_code)
    t = r.text
    j = r.json()
    # print(j)
    print('received ', len(j['data']), ' records')



    for trial in j['data']:
        print('NCT ID :', trial['nct_id'])
        for s in trial['sites']:
            cur.execute('insert into trial_sites(nct_id, org_name, org_family, org_status, org_to_family_relationship) values (%s,%s,%s,%s,%s)',
                        [trial['nct_id'], s['org_name'], s['org_family'], s['recruitment_status'],None])

        # print(trial['nct_id'])
        if trial['eligibility']['structured']['gender'] == 'BOTH':
            gender_expression = 'TRUE'
        elif trial['eligibility']['structured']['gender'] == 'MALE':
            # gender_expression = "C46109 == 'YES'"
            gender_expression = "exists('C46109')"
        elif trial['eligibility']['structured']['gender'] == 'FEMALE':
            gender_expression = "exists('C46110')"
        else:
            gender_expression = 'TRUE'

        max_age_in_years = 999 if 'max_age_in_years' not in trial['eligibility']['structured'] else trial['eligibility']['structured']['max_age_in_years']
        min_age_in_years = 0 if 'min_age_in_years' not in trial['eligibility']['structured'] else trial['eligibility']['structured']['min_age_in_years']
        biomarker_info = [[], [], [], []] if ('biomarkers' not in trial or trial['biomarkers'] is None )  else gen_biomarker_info(trial['biomarkers'])
        print(biomarker_info)  # (biomarker_inc_codes, biomarker_inc_names, biomarker_exc_codes, biomarker_exc_names)

        cur.execute(
            """insert into trials(nct_id, brief_title, official_title, 
            brief_summary, detail_description, max_age_in_years, min_age_in_years, gender,
            age_expression, gender_expression, phase , primary_purpose_code, study_source, record_verification_date, amendment_date,
            biomarker_inc_codes, biomarker_inc_names, biomarker_exc_codes, biomarker_exc_names) 
            values (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
            [trial['nct_id'], trial['brief_title'],
             trial['official_title'], trial['brief_summary'], trial['detail_description']
                ,max_age_in_years
                , min_age_in_years
                , trial['eligibility']['structured']['gender'],
             None if max_age_in_years is None or min_age_in_years is None else "C25150 >= " + str(min_age_in_years) + " & C25150 <= " +
             str(max_age_in_years),
             gender_expression,
             trial['phase'],
             trial['primary_purpose'],
             trial['study_source'],
             None if 'record_verification_date' not in trial else trial['record_verification_date'],
             None if 'amendment_date' not in trial else trial['amendment_date'],
             None if len(biomarker_info[0]) == 0 else ', '.join(biomarker_info[0]),
             None if len(biomarker_info[1]) == 0 else ', '.join(biomarker_info[1]),
             None if len(biomarker_info[2]) == 0 else ', '.join(biomarker_info[2]),
             None if len(biomarker_info[3]) == 0 else ', '.join(biomarker_info[3])
             ])
        con.commit()

        # disease processing

        dlist = []
        dlist_all = []
        dlist_lead = []
        dname_list_all = []
        dname_list_lead = []
        maintype_set = set()
        for d in trial['diseases']:
            if 'type' not in d or 'name' not in d or d['name'] is None:
                print("Inconsistent disease data : ", d)
            else:
                dlist.append(
                    [trial['nct_id'], d['nci_thesaurus_concept_id'], d['is_lead_disease'], None, # Note have to put the preferred name back here.
                     None if 'type' not in d or len(d['type']) == 0 else '-'.join(sorted(d['type']))
                        ,
                     d['inclusion_indicator'], None if 'name' not in d else d['name']  # Note this the CTRP display name
                     ]
                )

                if d['inclusion_indicator'] == 'TRIAL':
                    dlist_all.append("'" + d['nci_thesaurus_concept_id'] + "'")
                    dname_list_all.append(d['name'] + ' ( ' + d['nci_thesaurus_concept_id'] + ' )')  #Changing to name (ctrp_display_name)

                if d['inclusion_indicator'] == 'TRIAL' and d['is_lead_disease'] == True:
                    dlist_lead.append("'" + d['nci_thesaurus_concept_id'] + "'")
                    dname_list_lead.append(d['name'] + ' ( ' + d['nci_thesaurus_concept_id'] + ' )')
                    # also add in the maintypes
                    maintypes = get_maintypes(con, d['nci_thesaurus_concept_id'])
                    if maintypes is not None:
                        for m in maintypes:
                            maintype_set.add(m[0])

        cur.execute(
            'update trials set diseases = %s , diseases_lead = %s, ' +
            ' disease_names = %s, disease_names_lead = %s where nct_id = %s',
            [','.join(dlist_all), ','.join(dlist_lead), ','.join(dname_list_all), ','.join(dname_list_lead),
             trial['nct_id']])

        psycopg2.extras.execute_batch(cur,
        'insert into trial_diseases(nct_id, nci_thesaurus_concept_id, lead_disease_indicator, preferred_name, disease_type, inclusion_indicator, display_name) ' +
        ' values(%s,%s,%s,%s,%s,%s,%s)',
        dlist, page_size = 1000)

        for maintype in maintype_set:
            cur.execute('insert into trial_maintypes(nct_id, nci_thesaurus_concept_id) values (%s,%s)',
                        [trial['nct_id'], maintype])
        con.commit()

        # end of disease processing

        # unstructured criteria
        if 'unstructured' in trial['eligibility'] and trial['eligibility']['unstructured'] is not None:
            uns = trial['eligibility']['unstructured']
            for crit in uns:
               # print(crit)
                cur.execute('insert into trial_unstructured_criteria(nct_id, inclusion_indicator, display_order, description) values (%s,%s,%s,%s)',
                            [ trial['nct_id'], crit['inclusion_indicator'], crit['display_order'], crit['description']]
                            )
        con.commit()
        #print(str(trial['biomarkers']))

    # r = requests.post('https://clinicaltrialsapi.cancer.gov/v1/clinical-trials',
    #                  data=data)

    r = cur.execute('select count(*) from trials')
    c = cur.fetchone()[0]
    if len(j['data']) < 50:
        run = False

    print("record count = ", c)
    start = start + len(j['data'])
    data['from'] = start



end_time = datetime.datetime.now()
print("API ETL mainline ops completed in ", end_time - start_time)

cur.execute("drop table if exists temp_trial_diseases")
con.commit()
cur.execute("""
create table temp_trial_diseases as 
select td.idx, td.nct_id, td.nci_thesaurus_concept_id, td.lead_disease_indicator, n.pref_name as preferred_name, td.disease_type, td.inclusion_indicator, td.display_name
from trial_diseases td join ncit n on td.nci_thesaurus_concept_id = n.code
""")
cur.execute("delete from trial_diseases")

cur.execute("""
insert into trial_diseases 
select  td.idx, td.nct_id, td.nci_thesaurus_concept_id, td.lead_disease_indicator, td.preferred_name, td.disease_type, td.inclusion_indicator, td.display_name
from temp_trial_diseases td
""")
con.commit()

cur.execute(
    "insert into distinct_trial_diseases  select DISTINCT nci_thesaurus_concept_id, preferred_name,disease_type, display_name  from trial_diseases where disease_type is not null")
con.commit()



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

end_time = datetime.datetime.now()
print("API ETL all ops completed in ", end_time - start_time)
