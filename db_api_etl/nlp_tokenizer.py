#!/usr/bin/env python

import argparse
from datetime import (datetime, timezone)
from typing import (Union, Any)
from psycopg2 import connect
from bz2 import compress
from pickle import dumps
from spacy import blank
from spacy.matcher import PhraseMatcher


NCIT_CODE_AND_SYNONYMS_SQL = '''
        select code, synonyms from ncit
        where (
            concept_status is null or (
                concept_status not like '%Obsolete%' and concept_status not like '%Retired%'
                )
            ) 
        /* and (lower(synonyms) like '%chemotherapy%' or lower(synonyms) like '%ecog%' or lower(synonyms) like '%white blood cell%') */
        '''
NCIT_SYNONYMS_SQL = '''select code, l_syn_name from ncit_syns'''
# NCI_VERSION_INSERT_SQL = '''insert into test_nlp_version (ncit_tokenizer_generation_date, ncit_tokenizer) values (%s,%s)'''
NCI_VERSION_INSERT_SQL = '''UPDATE test_ncit_version SET ncit_tokenizer_generation_date=(%s), 
    ncit_tokenizer=(%s)
    WHERE active_version=(%s)'''


def get_db(host: str, port: str, user: str, password: str, dbname: str) -> connect:
     return connect(
            host=host,
            port=port,
            database=dbname,
            user=user,
            password=password
        )

def get(db: connect, query: str) -> Union[Any, None]:
        curr = db.cursor()
        curr.execute(query)
        return curr.fetchall()

def save(db: connect, query: str, data: tuple) -> None:
        curr = db.cursor()
        curr.execute(query, data)
        db.commit()

def get_nlp() -> blank:
    return blank("en")
    

if __name__ == '__main__':
    start_time = datetime.now()
    parser = argparse.ArgumentParser(
        description='Update the specified sqlite database with information from the cancer.gov API')
    parser.add_argument('--dbname',action='store',type=str, required=False )
    parser.add_argument('--host',action='store',type=str, required=False )
    parser.add_argument('--user',action='store',type=str, required=False )
    parser.add_argument('--password',action='store',type=str, required=False )
    parser.add_argument('--port',action='store',type=str, required=False )
    args = parser.parse_args()
    nlp = get_nlp()
    db = get_db(**vars(args))
    records = get(db, NCIT_CODE_AND_SYNONYMS_SQL)
    records.extend(get(db, NCIT_SYNONYMS_SQL))
    code_synonym_set = set()
    for record in records:
        code = record[0]
        synonyms = record[1].split('|')
        new_tuple = (zip([code] * len(synonyms), synonyms)) # list(zip([code] * len(synonyms), synonyms)) 
        code_synonym_set.add(new_tuple)
    patterns = []
    for code_synonym in code_synonym_set: # patterns = [nlp.make_doc(v[1]) for v in code_synonym_set]
        v = next(code_synonym)
        patterns.append(nlp.make_doc(v[1]))
    matcher = PhraseMatcher(nlp.vocab, attr='LOWER')
    matcher.add("TerminologyList", patterns)
    compressed_pickled_string = compress(dumps(matcher))
    timestamp = datetime.now(timezone.utc)
    save(db, NCI_VERSION_INSERT_SQL, (timestamp, compressed_pickled_string, 'Y',))
    db.close()
    end_time = datetime.now()
    print("NLP Tokenizer Completed in ", end_time - start_time)
