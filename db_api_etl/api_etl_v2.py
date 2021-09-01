import requests
import sqlite3
import sys
import datetime
import argparse
import os

CTS_V2_API_KEY = os.getenv('CTS_V2_API_KEY')
header_v2_api = {"x-api-key" : CTS_V2_API_KEY, "Content-Type" : "application/json"}

def get_maintypes(con, lead_disease):
    """Get the maintypes for a NCIt code"""

    s = """
    with minlevel as 
 (select min(level) as min_level from ncit_tc_with_path np join maintypes m 
on np.parent = m.nci_thesaurus_concept_id
 join ncit n on np.parent = n.code 
 join ncit nc on np.descendant = nc.code 
 where np.descendant = ?
 )
 select distinct np.parent as mainytype
from ncit_tc_with_path np join maintypes m 
on np.parent = m.nci_thesaurus_concept_id
 join ncit n on np.parent = n.code 
 join ncit nc on np.descendant = nc.code 
 join minlevel ml on np.level=ml.min_level
 where np.descendant = ?

    """

    cur = con.cursor()
    r = cur.execute(s, [lead_disease, lead_disease])
    rc = r.fetchall()
   # print(lead_disease, rc)
    return rc


start_time = datetime.datetime.now()

parser = argparse.ArgumentParser(
    description='Update the specified sqlite database with information from the cancer.gov API')
parser.add_argument('--dbfilename', action='store', type=str, required=True)
args = parser.parse_args()

database_file = args.dbfilename

con = sqlite3.connect(database_file)
cur = con.cursor()
cur.execute('delete from trial_diseases')
cur.execute('delete from trials')
cur.execute('delete from maintypes')
cur.execute('delete from trial_maintypes')
cur.execute('delete from distinct_trial_diseases')
cur.execute('delete from trial_sites')
cur.execute('delete from trial_unstructured_criteria')
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

cur.executemany('insert into maintypes(nci_thesaurus_concept_id) values (?)', maintypes)
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
                 'amendment_date'
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
        for s in trial['sites']:
            cur.execute('insert into trial_sites(nct_id, org_name, org_family, org_status, org_to_family_relationship) values (?,?,?,?,?)',
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
        cur.execute(
            'insert into trials(nct_id, brief_title, official_title, ' +
            'brief_summary, detail_description, max_age_in_years, min_age_in_years, gender,' +
            'age_expression, gender_expression, phase , primary_purpose_code, study_source, record_verification_date, amendment_date)' +
            ' values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
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
             None if 'amendment_date' not in trial else trial['amendment_date']
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
            if 'type' not in d:
                print("NO TYPE:", d)
                print(trial)

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
            'update trials set diseases = ? , diseases_lead = ?, ' +
            ' disease_names = ?, disease_names_lead = ? where nct_id = ?',
            [','.join(dlist_all), ','.join(dlist_lead), ','.join(dname_list_all), ','.join(dname_list_lead),
             trial['nct_id']])

        cur.executemany(
            'insert into trial_diseases(nct_id, nci_thesaurus_concept_id, lead_disease_indicator, preferred_name, disease_type, inclusion_indicator, display_name) ' +
            ' values(?,?,?,?,?,?,?)',
            dlist)

        for maintype in maintype_set:
            cur.execute('insert into trial_maintypes(nct_id, nci_thesaurus_concept_id) values (?,?)',
                        [trial['nct_id'], maintype])
        con.commit()

        # end of disease processing

        # unstructured criteria
        if 'unstructured' in trial['eligibility'] and trial['eligibility']['unstructured'] is not None:
            uns = trial['eligibility']['unstructured']
            for crit in uns:
               # print(crit)
                cur.execute('insert into trial_unstructured_criteria(nct_id, inclusion_indicator, display_order, description) values (?,?,?,?)',
                            [ trial['nct_id'], crit['inclusion_indicator'], crit['display_order'], crit['description']]
                            )
        con.commit()

    # r = requests.post('https://clinicaltrialsapi.cancer.gov/v1/clinical-trials',
    #                  data=data)

    c = cur.execute('select count(*) from trials').fetchone()[0]
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

con.close()

end_time = datetime.datetime.now()
print("API ETL all ops completed in ", end_time - start_time)
