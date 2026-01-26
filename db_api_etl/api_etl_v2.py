import requests
import datetime
import argparse
import os
import psycopg2
import psycopg2.extras

CTS_V2_API_KEY = os.getenv('CTS_V2_API_KEY')
header_v2_api = {"x-api-key" : CTS_V2_API_KEY, "Content-Type" : "application/json"}

def get_maintypes(con, lead_disease):
    """Get the maintypes for a NCIt code"""

    s = """
    with minlevel as (
        select
            min(level) as min_level
        from
            ncit_tc_with_path np
            join maintypes m on np.parent = m.nci_thesaurus_concept_id
            join ncit n on np.parent = n.code
            join ncit nc on np.descendant = nc.code
        where
            np.descendant = %s
    )
    select
        distinct np.parent as mainytype
    from
        ncit_tc_with_path np
        join maintypes m on np.parent = m.nci_thesaurus_concept_id
        join ncit n on np.parent = n.code
        join ncit nc on np.descendant = nc.code
        join minlevel ml on np.level = ml.min_level
    where
        np.descendant = %s"""

    cur = con.cursor()
    cur.execute(s, [lead_disease, lead_disease])
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


def insert_prior_therapies(db_conn, db_cur, nct_id,
                           prior_therapies):
    """
    Populates the trial_prior_therapies table for a single trial.
    """
    if prior_therapies:
        args_to_insert: list[tuple] = [(nct_id,
                          prior_therapy["nci_thesaurus_concept_id"],
                          prior_therapy["eligibility_criterion"],
                          prior_therapy["inclusion_indicator"],
                          prior_therapy["name"])
                          for prior_therapy in prior_therapies]
        sql = """insert into trial_prior_therapies(nct_id, nci_thesaurus_concept_id, eligibility_criterion, inclusion_indicator, name)
                    values(%s, %s, %s, %s, %s)"""
        psycopg2.extras.execute_batch(sql, args_to_insert, con=cur)
        db_conn.commit()


start_time = datetime.datetime.now()

parser = argparse.ArgumentParser(
    description='Update the specified sqlite database with information from the cancer.gov API')
parser.add_argument('--dbname', action='store', type=str, required=False, default='sec')
parser.add_argument('--host', action='store', type=str, required=False, default='localhost')
parser.add_argument('--user', action='store', type=str, required=False, default='sec')
parser.add_argument('--password', action='store', type=str, required=False, default='sec')
parser.add_argument('--port', action='store', type=str, required=False, default='5433')
args = parser.parse_args()


con = psycopg2.connect(database=args.dbname, user=args.user, host=args.host, port=args.port,
 password=args.password)

cur = con.cursor()
cur.execute("delete from maintypes")

# First get the maintypes, then get the study data needed.

try:
    r = requests.get('https://clinicaltrialsapi.cancer.gov/api/v2/diseases',
                    params={'type': 'maintype', 'type_not': 'subtype', 'size': 100, 'include' : 'codes'}, headers = header_v2_api
    )
    r.raise_for_status()
except Exception as err:
    con.rollback()
    raise err
else:
    con.commit()

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


include_items = [
    'active_sites_count',
    'age_expression',
    'amendment_date',
    'biomarkers',
    'brief_summary',
    'brief_title',
    'ccr_id',
    'classification_code',
    'completion_date',
    'completion_date_type_code',
    'ctep_id',
    'current_trial_status',
    'current_trial_status_date',
    'dcp_id',
    'detail_description',
    'disease_names_lead',
    'diseases',
    'eligibility.structured.max_age_in_years',
    'eligibility.structured.min_age_in_years',
    'eligibility.structured.sex',
    'eligibility.unstructured',
    'gender',
    'gender_expression',
    'interventional_model',
    'lead_org',
    'lead_org_cancer_center',
    'max_age_in_years',
    'min_age_in_years',
    'minimum_target_accrual_number',
    'nci_funded',
    'nct_id',
    'number_of_arms',
    'official_title',
    'phase',
    'primary_purpose',
    'principal_investigator',
    'protocol_id',
    'record_verification_date',
    'sampling_method_code',
    'sites',
    'start_date',
    'start_date_type_code',
    'study_model_code',
    'study_model_other_text',
    'study_population_description',
    'study_protocol_type',
    'study_source',
    'study_subtype_code']

data = {'current_trial_status': 'Active',
        'primary_purpose': ['TREATMENT', 'SCREENING'],
        'sites.recruitment_status': 'ACTIVE',
        'size' : 1,
        'record_verification_date_gte': two_years_ago.isoformat(),
        'from' : 0
        }
data['include'] = include_items

cur.execute("delete from trial_diseases")
cur.execute("delete from trial_prior_therapies")
cur.execute("delete from trials")
cur.execute("delete from trial_maintypes")
cur.execute("delete from distinct_trial_diseases")
cur.execute("delete from trial_sites")
cur.execute("delete from trial_unstructured_criteria")

# NCT02944578
try:
    r = requests.post('https://clinicaltrialsapi.cancer.gov/api/v2/trials',
                    headers = header_v2_api, json  = data)
except Exception as err:
    con.rollback()
    raise err
else:
    con.commit()

t = r.text
j = r.json()
# print(j)
total = j['total']
size = 50
data['size'] = size

print("there are ", total, 'trials')
run = True
session = requests.Session()
while run:
    print('START:', start)
    r = session.post('https://clinicaltrialsapi.cancer.gov/api/v2/trials',
                      headers=header_v2_api, json=data, timeout=(5.0, 20.0) )
    print('status code returned = ', r.status_code)
    t = r.text
    j = r.json()
    # print(j)
    print('received ', len(j['data']), ' records')

    for trial in j["data"]:
        print("NCT ID :", trial["nct_id"])
        for s in trial["sites"]:
            cur.execute(
                """insert into
                trial_sites(
                    nct_id,
                    org_name,
                    org_family,
                    org_status,
                    org_to_family_relationship
                )
                values (%s,%s,%s,%s,%s)""",
            [trial['nct_id'], s['org_name'], s['org_family'], s['recruitment_status'],None])

        # print(trial['nct_id'])
        if trial['eligibility']['structured']['sex'] == 'ALL':
            gender_expression = 'TRUE'
        elif trial['eligibility']['structured']['sex'] == 'MALE':
            # gender_expression = "C46109 == 'YES'"
            gender_expression = "exists('C46109')"
        elif trial['eligibility']['structured']['sex'] == 'FEMALE':
            gender_expression = "exists('C46110')"
        else:
            gender_expression = 'TRUE'

        max_age_in_years = 999 if 'max_age_in_years' not in trial['eligibility']['structured'] else trial['eligibility']['structured']['max_age_in_years']
        min_age_in_years = 0 if 'min_age_in_years' not in trial['eligibility']['structured'] else trial['eligibility']['structured']['min_age_in_years']

        biomarker_info = [[], [], [], []] if ('biomarkers' not in trial or trial['biomarkers'] is None )  else gen_biomarker_info(trial['biomarkers'])
        print(biomarker_info)  # (biomarker_inc_codes, biomarker_inc_names, biomarker_exc_codes, biomarker_exc_names)
        current_trial_status = trial.get('current_trial_status', '')
        current_trial_status = current_trial_status.lower() if current_trial_status is not None else ''


#

        active_sites_count = trial['active_sites_count']
        age_expression = age_expression = None if max_age_in_years is None or min_age_in_years is None else "C25150 >= " + str(
            min_age_in_years) + " & C25150 <= " + str(max_age_in_years)
        amendment_date = trial['amendment_date']
        biomarker_inc_codes = None if len(biomarker_info[0]) == 0 else ", ".join(biomarker_info[0])
        biomarker_inc_names = None if len(biomarker_info[1]) == 0 else ", ".join(biomarker_info[1])
        biomarker_exc_codes = None if len(biomarker_info[2]) == 0 else ", ".join(biomarker_info[2])
        biomarker_exc_names = None if len(biomarker_info[3]) == 0 else ", ".join(biomarker_info[3])
        biomarkers = trial['biomarkers']
        brief_summary = trial['brief_summary']
        brief_title = trial['brief_title']
        ccr_id = trial['ccr_id']
        classification_code = trial['classification_code']
        completion_date = trial['completion_date']
        completion_date_type_code = trial['completion_date_type_code']
        ctep_id = trial['ctep_id']
        #current_trial_status = trial['current_trial_status']
        current_trial_status_date = trial['current_trial_status_date']
        dcp_id = trial['dcp_id']
        detail_description = trial['detail_description']
        diseases = trial['diseases']
        # eligibility.structured.max_age_in_years = trial['max_age_in_years']
        # eligibility.structured.min_age_in_years = trial['min_age_in_years']
        # eligibility.structured.sex = trial['sex']
        # eligibility.unstructured = trial['unstructured']
        gender = trial['eligibility']['structured']['sex']
        #gender_expression = gender_expression']
        interventional_model = trial['interventional_model']
        lead_org = trial['lead_org']
        lead_org_cancer_center = trial['lead_org_cancer_center']
        # max_age_in_years = trial['max_age_in_years']
        # min_age_in_years = trial['min_age_in_years']
        minimum_target_accrual_number = trial['minimum_target_accrual_number']
        nci_funded = trial['nci_funded']
        nct_id = trial['nct_id']
        number_of_arms = trial['number_of_arms']
        official_title = trial['official_title']
        phase = trial['phase']
        primary_purpose = trial['primary_purpose']
        primary_purpose_code = trial['primary_purpose']
        principal_investigator = trial['principal_investigator']
        #prior_therapy = trial['prior_therapy']
        protocol_id = trial['protocol_id']
        record_verification_date = trial['record_verification_date']
        sampling_method_code = trial['sampling_method_code']
        sites = trial['sites']
        start_date = trial['start_date']
        start_date_type_code = trial['start_date_type_code']
        study_model_code = trial['study_model_code']
        study_model_other_text = trial['study_model_other_text']
        study_population_description = trial['study_population_description']
        study_protocol_type = trial['study_protocol_type']
        study_source = trial['study_source']
        study_subtype_code = trial['study_subtype_code']

        values = {
                'active_sites_count': active_sites_count,
                'age_expression': age_expression,
                'amendment_date': amendment_date,
                'biomarker_exc_codes': biomarker_exc_codes,
                'biomarker_exc_names': biomarker_exc_names,
                'biomarker_inc_codes': biomarker_inc_codes,
                'biomarker_inc_names': biomarker_inc_names,
                'brief_summary': brief_summary,
                'brief_title': brief_title,
                'ccr_id': ccr_id,
                'classification_code': classification_code,
                'completion_date': completion_date,
                'completion_date_type_code': completion_date_type_code,
                'ctep_id': ctep_id,
                'current_trial_status': current_trial_status,
                'current_trial_status_date': current_trial_status_date,
                'dcp_id': dcp_id,
                'detail_description': detail_description,
                'max_age_in_years': max_age_in_years,
                'min_age_in_years': min_age_in_years,
                'gender': gender,
                'gender_expression': gender_expression,
                'interventional_model': interventional_model,
                'lead_org': lead_org,
                'lead_org_cancer_center': lead_org_cancer_center,
                'max_age_in_years': max_age_in_years,
                'min_age_in_years': min_age_in_years,
                'minimum_target_accrual_number': minimum_target_accrual_number,
                'nci_funded': nci_funded,
                'nct_id': nct_id,
                'number_of_arms': number_of_arms,
                'official_title': official_title,
                'phase': phase,
                'primary_purpose': primary_purpose,
                'primary_purpose_code': primary_purpose_code,
                'principal_investigator': principal_investigator,
                'protocol_id': protocol_id,
                'record_verification_date': record_verification_date,
                'sampling_method_code': sampling_method_code,
                'start_date': start_date,
                'start_date_type_code': start_date_type_code,
                'study_model_code': study_model_code,
                'study_model_other_text': study_model_other_text,
                'study_population_description': study_population_description,
                'study_protocol_type': study_protocol_type,
                'study_source': study_source,
                'study_subtype_code': study_subtype_code
        }
        params = list(values.values())
        sstring = ['%s' for _ in params]
        sql = f"""insert into trials({",".join(values.keys())}) values({','.join(sstring)})"""

        cur.execute(sql, params)
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
                    [
                        trial["nct_id"],
                        d["nci_thesaurus_concept_id"],
                        d["is_lead_disease"],
                        None,  # Note have to put the preferred name back here.
                        None if "type" not in d or len(d["type"]) == 0 else "-".join(sorted(d["type"])),
                        d["inclusion_indicator"],
                        None if "name" not in d else d["name"],  # NOTE: this the CTRP display name
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

        psycopg2.extras.execute_batch("""insert into trial_diseases(nct_id,
                                                                    nci_thesaurus_concept_id,
                                                                    lead_disease_indicator,
                                                                    preferred_name,
                                                                    disease_type,
                                                                    inclusion_indicator,
                                                                    display_name)
                                         values (%s, %s, %s, %s, %s, %s, %s)
                                      """, dlist, con=cur, page_size=1000)

        for maintype in maintype_set:
            cur.execute('insert into trial_maintypes(nct_id, nci_thesaurus_concept_id) values (%s,%s)',
                        [trial['nct_id'], maintype])
        con.commit()

        # end of disease processing

        if 'prior_therapy' in trial:
            insert_prior_therapies(con, cur, trial['nct_id'], trial['prior_therapy'])

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
update trial_diseases td
set preferred_name = n.pref_name
from ncit n
where n.code = td.nci_thesaurus_concept_id
""")

cur.execute("""
insert into
    distinct_trial_diseases
select
    DISTINCT nci_thesaurus_concept_id,
    preferred_name,
    disease_type,
    display_name
from
    trial_diseases
where
    disease_type is not null
""")
con.commit()

print("Processing disease tree data")
cur.execute("drop table if exists disease_tree_temp")
con.commit()

create_func_sql = """
CREATE OR REPLACE FUNCTION replace_ajcc(disease_name TEXT) RETURNS TEXT AS $$
DECLARE
    ajccv6 TEXT;
    ajccv7 TEXT;
    ajccv8 TEXT;
BEGIN
    SELECT replace(disease_name, 'AJCC v6', '') INTO ajccv6;
    SELECT replace(ajccv6, 'AJCC v7', '') INTO ajccv7;
    SELECT replace(ajccv7, 'AJCC v8', '') INTO ajccv8;
    RETURN ajccv8;
END;
$$ LANGUAGE plpgsql IMMUTABLE RETURNS NULL ON NULL INPUT PARALLEL SAFE;
"""
cur.execute(create_func_sql)
con.commit()

sql = """
create table disease_tree_temp as (
    with recursive parent_descendant(top_code, parent, descendant, level) as (
        select
            tc.parent as top_code,
            tc.parent,
            tc.descendant,
            1 as level
        from
            ncit_tc_with_path tc
        where
            tc.parent in (
                select
                    nci_thesaurus_concept_id
                from
                    distinct_trial_diseases ds
                where
                    (
                        ds.disease_type = 'maintype'
                        or ds.disease_type like '%maintype-subtype%'
                    )
                    and nci_thesaurus_concept_id not in ('C2991', 'C2916')
                union
                select
                    'C4913' as nci_thesaurus_concept_id
            )
            and tc.level = 1
        union
        ALL
        select
            pd.top_code,
            pd.descendant as parent,
            tc1.descendant as descendant,
            pd.level + 1 as level
        from
            parent_descendant pd
            join ncit_tc_with_path tc1 on pd.descendant = tc1.parent
            and tc1.level = 1
        where
            exists (
                select
                    dd.nci_thesaurus_concept_id
                from
                    distinct_trial_diseases dd
                where
                    dd.nci_thesaurus_concept_id = tc1.descendant
            )
    ),
    all_nodes as (
        select
            top_code,
            n1.pref_name as parent,
            n2.pref_name as child,
            level
        from
            parent_descendant pd
            join ncit n1 on pd.parent = n1.code
            join ncit n2 on pd.descendant = n2.code
        union
        select
            n.code as top_code,
            NULL as parent,
            pref_name as child,
            0 as level
        from
            ncit n
        where
            n.code in (
                select
                    nci_thesaurus_concept_id
                from
                    distinct_trial_diseases ds
                where
                    ds.disease_type = 'maintype'
                    or ds.disease_type like '%maintype-subtype%'
                    and nci_thesaurus_concept_id not in ('C2991', 'C2916')
                union
                select
                    'C4913' as nci_thesaurus_concept_id
            )
    ),
    disease_aggs as (
        select
            replace_ajcc(display_name) as rev_name,
            count(*) as num_trials
        from
            trial_diseases
        group by
            replace_ajcc(display_name)
    )
    select
        distinct an.top_code,
        replace_ajcc(dds1.display_name) as parent,
        replace_ajcc(dds2.display_name) as child,
        level as levels,
        1 as collapsed,
        10 as "nodeSize",
        CASE
            when disease_aggs.num_trials = 1 THEN coalesce(cast(disease_aggs.num_trials as varchar), ' ') || ' trial'
            when disease_aggs.num_trials > 1 THEN coalesce(cast(disease_aggs.num_trials as varchar), ' ') || ' trials'
            else ' '
        END as "tooltipHtml"
    from
        all_nodes an
        left join distinct_trial_diseases dds1 on an.parent = dds1.preferred_name
        join distinct_trial_diseases dds2 on an.child = dds2.preferred_name
        left join disease_aggs on disease_aggs.rev_name = dds2.display_name
        -- NOTE: cases where the rev_name is different from display_name are handled
        -- in the python code
    where
        (
            dds1.display_name != dds2.display_name
            -- there are cases of duplicate parent-child names especially when dealing with Adult/Child cancers
            or level = 0
        )
        and level < 999
)
"""
cur.execute(sql)
con.commit()

# Note now take care of the blank tool tips because of AJCC substitutions.

sql_for_synthetic_node = """
select distinct
    top_code,
    parent,
    child,
    levels,
    collapsed,
    "nodeSize",
    "tooltipHtml"
from
    disease_tree_temp
where
    "tooltipHtml" = ' '
"""

cur.execute(sql_for_synthetic_node)
syn_nodes  = cur.fetchall()
print(syn_nodes)
for syn_node in syn_nodes:
    print("Processing syn node", syn_node)
    syn_node_name = syn_node[2]
    # Now see where the AJCC substitution happened
    if '  ' in syn_node_name:
        print("2 spaces")
        syn_node_name_like = syn_node_name.replace('  ', '%')
    elif syn_node_name[-1] == ' ':
        print('space at end')
        syn_node_name_like = syn_node_name[:-1] + '%'
    else:
        print("UNKNOWN reason for syn node blank html tool tip ")
        syn_node_name_like = None
    print("syn_node_name_like", syn_node_name_like)
    syn_node_trial_count_sql = """
    with ncit_codes_for_syn_node as (
        select
            DISTINCT nci_thesaurus_concept_id
        from
            distinct_trial_diseases
        where
            display_name like %s
    )
    select
        count(distinct nct_id)
    from
        trial_diseases td
        join ncit_codes_for_syn_node sn on td.nci_thesaurus_concept_id = sn.nci_thesaurus_concept_id"""
    if syn_node_name_like is not None:
        cur.execute(syn_node_trial_count_sql, [syn_node_name_like])
        t= cur.fetchone()
        syn_node_count = t[0]
        print("node count = ", syn_node_count )
        if syn_node_count == 1:
            new_tooltip = "1 trial"
        else:
            new_tooltip = str(syn_node_count)+ " trials"
        print(new_tooltip)
        usql = """
        update
            disease_tree_temp
        set
            "tooltipHtml" = %s
        where
            top_code = %s
            and parent = %s
            and child = %s
            and levels = %s
            and collapsed = %s
            and "nodeSize" = %s"""
        cur.execute(usql, [new_tooltip, syn_node[0], syn_node[1], syn_node[2], syn_node[3], syn_node[4], syn_node[5]])
        con.commit()

cur.execute("delete from disease_tree")

sql = """
insert into
    disease_tree (
        code,
        parent,
        child,
        levels,
        collapsed,
        "nodeSize",
        "tooltipHtml",
        original_child
    )
select
    top_code as code,
    trim(replace(parent, '  ', ' ')),
    trim(replace(child, '  ', ' ')),
    levels,
    collapsed,
    "nodeSize",
    "tooltipHtml",
    child
from
    disease_tree_temp
order by
    code,
    levels,
    parent,
    child
"""
cur.execute(sql)
con.commit()

cur.execute("drop table disease_tree_temp")
con.commit()

# Now process for nostaging
print("Processing disease tree data (no stage data version) ")
cur.execute("drop table if exists disease_tree_temp_nostage")
con.commit()

sql = """
create table disease_tree_temp_nostage as (
    with recursive parent_descendant(top_code, parent, descendant, level) as (
        select
            tc.parent as top_code,
            tc.parent,
            tc.descendant,
            1 as level
        from
            ncit_tc_with_path tc
            join distinct_trial_diseases dtd on tc.descendant = dtd.nci_thesaurus_concept_id
            and dtd.disease_type not in ('stage', 'grade-stage')
        where
            tc.parent in (
                select
                    nci_thesaurus_concept_id
                from
                    distinct_trial_diseases ds
                where
                    (
                        ds.disease_type = 'maintype'
                        or ds.disease_type like '%maintype-subtype%'
                    )
                    and nci_thesaurus_concept_id not in ('C2991', 'C2916')
                union
                select
                    'C4913' as nci_thesaurus_concept_id
            )
            and tc.level = 1
        union
        ALL
        select
            pd.top_code,
            pd.descendant as parent,
            tc1.descendant as descendant,
            pd.level + 1 as level
        from
            parent_descendant pd
            join ncit_tc_with_path tc1 on pd.descendant = tc1.parent
            and tc1.level = 1
            join distinct_trial_diseases dtd1 on dtd1.nci_thesaurus_concept_id = tc1.descendant
            and dtd1.disease_type not in ('stage', 'grade-stage')
    ),
    all_nodes as (
        select
            top_code,
            n1.pref_name as parent,
            n2.pref_name as child,
            level
        from
            parent_descendant pd
            join ncit n1 on pd.parent = n1.code
            join ncit n2 on pd.descendant = n2.code
        union
        select
            n.code as top_code,
            NULL as parent,
            pref_name as child,
            0 as level
        from
            ncit n
        where
            n.code in (
                select
                    nci_thesaurus_concept_id
                from
                    distinct_trial_diseases ds
                where
                    ds.disease_type = 'maintype'
                    or ds.disease_type like '%maintype-subtype%'
                    and nci_thesaurus_concept_id not in ('C2991', 'C2916')
                union
                select
                    'C4913' as nci_thesaurus_concept_id
            )
    ),
    disease_aggs as (
        select
            replace_ajcc(display_name) as rev_name,
            count(*) as num_trials
        from
            trial_diseases
        where
            disease_type not in ('stage', 'grade-stage')
        group by
            replace_ajcc(display_name)
    )
    select
        distinct an.top_code,
        replace_ajcc(dds1.display_name) as parent,
        replace_ajcc(dds2.display_name) as child,
        level as levels,
        1 as collapsed,
        10 as "nodeSize",
        CASE
            when disease_aggs.num_trials = 1 THEN coalesce(cast(disease_aggs.num_trials as varchar), ' ') || ' trial'
            when disease_aggs.num_trials > 1 THEN coalesce(cast(disease_aggs.num_trials as varchar), ' ') || ' trials'
            else ' '
        END as "tooltipHtml"
    from
        all_nodes an
        left join distinct_trial_diseases dds1 on an.parent = dds1.preferred_name
        join distinct_trial_diseases dds2 on an.child = dds2.preferred_name
        left join disease_aggs on disease_aggs.rev_name = dds2.display_name
    where
        (
            dds1.display_name != dds2.display_name
            or level = 0
        )
        and level < 999
)"""
cur.execute(sql)
con.commit()

# Note now take care of the blank tool tips

sql_for_synthetic_node = """
select
    distinct top_code,
    parent,
    child,
    levels,
    collapsed,
    "nodeSize",
    "tooltipHtml"
from
    disease_tree_temp_nostage
where
    "tooltipHtml" = ' '
"""

cur.execute(sql_for_synthetic_node)
syn_nodes  = cur.fetchall()
print(syn_nodes)
for syn_node in syn_nodes:
    print("Processing syn node", syn_node)
    syn_node_name = syn_node[2]
    # Now see where the AJCC substitution happened
    if '  ' in syn_node_name:
        print("2 spaces")
        syn_node_name_like = syn_node_name.replace('  ', '%')
    elif syn_node_name[-1] == ' ':
        print('space at end')
        syn_node_name_like = syn_node_name[:-1] + '%'
    else:
        print("UNKNOWN reason for syn node blank html tool tip ")
        syn_node_name_like = None
    print("syn_node_name_like", syn_node_name_like)
    syn_node_trial_count_sql = """
    with ncit_codes_for_syn_node as (
        select
            DISTINCT nci_thesaurus_concept_id
        from
            distinct_trial_diseases
        where
            display_name like %s
    )
    select
        count(distinct nct_id)
    from
        trial_diseases td
        join ncit_codes_for_syn_node sn on td.nci_thesaurus_concept_id = sn.nci_thesaurus_concept_id"""
    if syn_node_name_like is not None:
        cur.execute(syn_node_trial_count_sql, [syn_node_name_like])
        t= cur.fetchone()
        syn_node_count = t[0]
        print("node count = ", syn_node_count )
        if syn_node_count == 1:
            new_tooltip = "1 trial"
        else:
            new_tooltip = str(syn_node_count)+ " trials"
        print(new_tooltip)
        usql = """
        update
            disease_tree_temp_nostage
        set
            "tooltipHtml" = %s
        where
            top_code = %s
            and parent = %s
            and child = %s
            and levels = %s
            and collapsed = %s
            and "nodeSize" = %s"""
        cur.execute(usql, [new_tooltip, syn_node[0], syn_node[1], syn_node[2], syn_node[3], syn_node[4], syn_node[5]])
        con.commit()

cur.execute("delete from disease_tree_nostage")

sql = """
insert into
    disease_tree_nostage (
        code,
        parent,
        child,
        levels,
        collapsed,
        "nodeSize",
        "tooltipHtml",
        original_child
    )
select
    top_code as code,
    trim(replace(parent, '  ', ' ')),
    trim(replace(child, '  ', ' ')),
    levels,
    collapsed,
    "nodeSize",
    "tooltipHtml",
    child
from
    disease_tree_temp_nostage
order by
    code,
    levels,
    parent,
    child"""
cur.execute(sql)
con.commit()

cur.execute("drop table disease_tree_temp_nostage")
con.commit()

print("Processing mul CTRP display name node tree data")

#
# Now fix the nodes for which one CTRP display name yields > 1 C code
# Because some display names have more than one C code, the disease aggregations, above, may have
# counted the same trial more than once (i.e., the same trial may have multiple instances of the same display name under different C codes).
# We only want to count DISTINCT trials.
#
print("Correcting node counts for nodes with more than one C code for a display_name")
get_mul_counts_sql = """
with multiple_display_names as (
    select
        display_name
    from
        distinct_trial_diseases
    group by
        display_name
    having
        count(display_name) > 1
)
select
    count(distinct td.nct_id) as num_trials,
    mdn.display_name
from
    trial_diseases td
    join multiple_display_names mdn on td.display_name = mdn.display_name
group by
    mdn.display_name
"""
update_tree_sql = """
update disease_tree set "tooltipHtml" = %s where child = %s
"""
update_tree_nostage_sql = """
update disease_tree_nostage set "tooltipHtml" = %s where child = %s
"""

cur.execute(get_mul_counts_sql)
mul_nodes  = cur.fetchall()
print(mul_nodes)
for a_node in mul_nodes:
    print("processing node ", a_node)
    if a_node[0] == 1:
        new_tooltip = "1 trial"
    else:
        new_tooltip = str(a_node[0])+ " trials"
    print(new_tooltip)
    cur.execute(update_tree_sql, [new_tooltip, a_node[1]])
    cur.execute(update_tree_nostage_sql, [new_tooltip, a_node[1]])
    con.commit()

con.close()
end_time = datetime.datetime.now()
print("API ETL all ops completed in ", end_time - start_time)

def get_safe(adict, key, default_if_none):
    v = adict.get(key, default_if_none)
    v = v if v is not None else default_if_none
    return v