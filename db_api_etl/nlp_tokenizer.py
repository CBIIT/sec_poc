#!/usr/bin/env python

import argparse
from datetime import (datetime, timezone)
from typing import (Union, Any)
from psycopg2 import connect
from bz2 import compress
from pickle import dumps
import pickle
import spacy
from spacy import blank
from spacy.matcher import PhraseMatcher
import sys


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
NCI_VERSION_UPDATE_SQL = '''UPDATE ncit_version SET ncit_tokenizer_generation_date=(%s), 
    ncit_tokenizer=(%s)
    WHERE active_version=(%s)'''

REMOVE_OLD_VERSIONS_OF_NCIT = """
update ncit_version set ncit_tokenizer = NULL where (active_version <> 'Y' or active_version is null) 
"""

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

def get_one(db: connect, query: str) -> Union[Any, None]:
        curr = db.cursor()
        curr.execute(query)
        return curr.fetchone()
        
def save(db: connect, query: str, data: tuple=None ) -> None:
        curr = db.cursor()
        curr.execute(query, data)
        db.commit()

def get_nlp() -> blank:
    return blank("en")
    
def get_db_config(args):
    return {
        k : args.get(k, d) for (k, d) in
        [('dbname', 'sec'), ('host', 'localhost'), ('port', '5432'), ('user', 'secapp'), ('password', 'sec')]
    }
if __name__ == '__main__':
    print(spacy.__version__)
    print(pickle.format_version)
    start_time = datetime.now()
    parser = argparse.ArgumentParser(
        description='Update the specified sqlite database with information from the cancer.gov API')
    parser.add_argument('--force', '-f', action='store_true', required=False, default=False)
    parser.add_argument('--dbname',action='store',type=str, required=False , default='sec')
    parser.add_argument('--host',action='store',type=str, required=False ,default='localhost')
    parser.add_argument('--user',action='store',type=str, required=False, default='sec' )
    parser.add_argument('--password',action='store',type=str, required=False, default='sec')
    parser.add_argument('--port',action='store',type=str, required=False, default='5433' )

    args = parser.parse_args()
    db = get_db(**get_db_config(vars(args)))
    
    active_version_count = get_one(db, """
    select count(*) from ncit_version where active_version = 'Y' and ncit_tokenizer is not null
    """)[0]
    print("is tokenizer up to date",active_version_count )
    print(f'force run = {args.force}')
    should_run = (active_version_count ==0 or args.force)
    print("should run?",should_run)
    if should_run:
        print("updating NLP ")
        nlp = get_nlp()
     
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
        save(db, NCI_VERSION_UPDATE_SQL, (timestamp, compressed_pickled_string, 'Y',))
        
        save(db, REMOVE_OLD_VERSIONS_OF_NCIT )
        
    db.close()
    end_time = datetime.now()
    print("NLP Tokenizer Completed in ", end_time - start_time)
