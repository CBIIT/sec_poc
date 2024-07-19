import spacy
from spacy.matcher import PhraseMatcher
import sqlite3
import datetime
import argparse
from functools import lru_cache
import psycopg2
import psycopg2.extras

import sys
from bz2 import compress, decompress
from pickle import dumps, loads

nlp = spacy.blank("en")
# nlp = spacy.load("en_core_web_sm")
matcher = PhraseMatcher(nlp.vocab, attr="LOWER")

parser = argparse.ArgumentParser(description="Parse NCI codes from the text")

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
start_nlp_init = datetime.datetime.now()
print("Initializing NLP at ", start_nlp_init)
rs = []

# matcher.add("TerminologyList", patterns)

nlp = spacy.blank("en")
NLP_PICKLE_SQL = (
    """select ncit_tokenizer from ncit_version where active_version='Y' limit 1"""
)
rs = cur.execute(NLP_PICKLE_SQL)
pickled = cur.fetchone()[0]
uncompressed_pickle = decompress(pickled)
matcher = loads(uncompressed_pickle)

end_nlp_init = datetime.datetime.now()
print(
    "NLP Init complete at",
    end_nlp_init,
    " elapsed time = ",
    end_nlp_init - start_nlp_init,
)


print("deleting data for trials no longer in active / treatment set")
delete_old_concepts_sql = """
with del_trials as 
(
select distinct c.nct_id from ncit_nlp_concepts c where not exists (select t.nct_id from trials t where t.nct_id = c.nct_id)
)
delete from ncit_nlp_concepts  where nct_id in (select d.nct_id from del_trials d)
"""
cur.execute(delete_old_concepts_sql)
con.commit()


delete_old_trial_dates_sql = """
with del_trials as 
(
select distinct c.nct_id from trial_nlp_dates c where not exists (select t.nct_id from trials t where t.nct_id = c.nct_id)
)
delete from trial_nlp_dates  where nct_id in (select d.nct_id from del_trials d)
"""
cur.execute(delete_old_trial_dates_sql)
con.commit()

delete_old_cand_crit_sql = """
with del_trials as 
(
select distinct c.nct_id from candidate_criteria c where not exists (select t.nct_id from trials t where t.nct_id = c.nct_id)
)
delete from candidate_criteria  where nct_id in (select d.nct_id from del_trials d)
"""
cur.execute(delete_old_trial_dates_sql)
con.commit()


get_trials_sql = """
select  t.nct_id, t.record_verification_date, t.amendment_date, td.tokenized_date
from trials t left outer join trial_nlp_dates td on t.nct_id = td.nct_id 
where (td.tokenized_date is null)
      or td.tokenized_date <= greatest(coalesce( t.record_verification_date,'1980-01-01'), 
                                                            coalesce( t.amendment_date,'1980-01-01'))
"""

get_crit_sql = """
    select nct_id, display_order, description  from trial_unstructured_criteria where nct_id = %s 
order by nct_id, display_order 
/* limit 10000 */  
"""
ins_code_sql = """
    insert into ncit_nlp_concepts(nct_id, display_order, ncit_code, span_text, start_index, end_index) values (%s,%s,%s,%s,%s,%s)
"""


@lru_cache(maxsize=10000)
def get_best_ncit_code_for_span(con, a_span):
    get_best_ncit_code_sql_for_span = """
    select code from ncit where lower(pref_name) = %s and 
    lower(pref_name) not in ('i', 'ii', 'iii', 'iv', 'v', 'set', 'all', 'at', 'is', 'and', 'or', 'to', 'a', 'be', 'for', 'an', 'as', 'in', 'of', 'x', 'are', 'no', 'any', 'on', 'who', 'have', 't', 'who', 'at') 
    """
    cur = con.cursor()
    cur.execute(get_best_ncit_code_sql_for_span, [a_span])
    rs = cur.fetchall()
    return rs


@lru_cache(maxsize=10000)
def get_all_ncit_codes_for_span(con, a_span):
    get_ncit_code_sql_for_span = """
    select distinct code from ncit_syns where l_syn_name = %s and
     l_syn_name not in ('i', 'ii', 'iii', 'iv', 'v', 'set', 'all' , 'at', 'is', 'and', 'or', 'to', 'a', 'be', 'for', 'an', 'as', 'in', 'of', 'x', 'are', 'no', 'any', 'on', 'who', 'have', 't', 'who', 'at') 
    """
    cur = con.cursor()
    cur.execute(get_ncit_code_sql_for_span, [a_span])
    rs = cur.fetchall()
    return rs


cur.execute(get_trials_sql)
trial_list_for_processing = cur.fetchall()
con.commit()

print("there are ", len(trial_list_for_processing), " trials to tokenize ")

i = 0

print(
    f"{'Count' : <8}{'  NCT ID': <15}{'RVD' : ^30}{'Amendment Date' : ^30}{'Prior Tokenized Date' : ^30}"
)


for t in trial_list_for_processing:
    print(
        f"{i+1: <8}{t[0]: <15}{str(t[1]) if t[1] is not None else '': <30}{str(t[2]) if t[2] is not None else '': <30}{str(t[3]) if t[3] is not None else '' : <30}"
    )
    cur.execute(get_crit_sql, [t[0]])
    con.commit()
    crits = cur.fetchall()

    cur.execute("delete from ncit_nlp_concepts where nct_id = %s ", [t[0]])
    for crit in crits:
        doc = nlp(crit[2])
        matches = matcher(doc)
        spans = []
        for match_id, start, end in matches:
            span = doc[start:end]
            spans.append(doc[start:end])
        #  print(span.text)

        # ncit_set = set()
        filtered_spans = spacy.util.filter_spans(spans)
        # print(filtered_spans)
        for f in filtered_spans:
            lower_f = f.text.lower()
            # print(lower_f)
            try:
                float(lower_f)
                is_a_float = True
            except:
                is_a_float = False

            if not is_a_float:
                # cur.execute(get_best_ncit_code_sql_for_span, [f.lower_])
                # bcodes = cur.fetchall()
                bcodes = get_best_ncit_code_for_span(con, lower_f)
                if len(bcodes) > 0:
                    for one_code in bcodes:
                        cur.execute(
                            ins_code_sql,
                            [
                                crit[0],
                                crit[1],
                                one_code[0],
                                lower_f,
                                f.start_char,
                                f.end_char,
                            ],
                        )
                else:
                    # cur.execute(get_ncit_code_sql_for_span, [f.lower_])
                    # rcodes = cur.fetchall()
                    rcodes = get_all_ncit_codes_for_span(con, lower_f)
                    for one_code in rcodes:
                        cur.execute(
                            ins_code_sql,
                            [
                                crit[0],
                                crit[1],
                                one_code[0],
                                lower_f,
                                f.start_char,
                                f.end_char,
                            ],
                        )
        # con.commit()
    cur.execute("select count(*) from trial_nlp_dates where nct_id = %s", [t[0]])
    hm = cur.fetchone()[0]
    if hm == 1:
        cur.execute(
            "update trial_nlp_dates set tokenized_date = %s  where nct_id = %s",
            [datetime.datetime.now(), t[0]],
        )
    else:
        cur.execute(
            "insert into trial_nlp_dates(nct_id, tokenized_date) values(%s,%s)",
            [t[0], datetime.datetime.now()],
        )
    con.commit()
    i += 1
#   bar.update(i)

# Now refresh the nlp_data_tab and reindex

cur.execute("drop table if exists nlp_data_tab")
con.commit()
cur.execute("""create table nlp_data_tab as select nct_id, ncit_code, display_order, pref_name, span_text, start_index, end_index, inclusion_indicator, description
from nlp_data_view""")
con.commit()
cur.execute("create index nlp_dt_ncit_code on nlp_data_tab(ncit_code)")
con.commit()
cur.execute("create index nlp_dt_nct_id on nlp_data_tab(nct_id)")
con.commit()

con.close()

run_done = datetime.datetime.now()
print("run complete - at ", run_done, "elapsed time ", run_done - start_nlp_init)
