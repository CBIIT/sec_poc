#!/usr/bin/env python
from os.path import join as pjoin, basename, dirname, exists
from os import makedirs
from io import StringIO
from datetime import datetime as dt
import argparse
from datetime import (datetime, timezone)
from typing import (Union, Any)
from psycopg2 import connect
from bz2 import compress
from pickle import dumps
import pickle
import sys

OUTPUT_DIR = 'etl_output'
makedirs(OUTPUT_DIR, exist_ok=True)
BASE_NAME = basename(__file__)
FILE_NAME = basename(__file__).removesuffix('.py')
OUPUT_PATH = pjoin(OUTPUT_DIR, f'{FILE_NAME}.txt')
open(OUPUT_PATH, 'w').write(f'{BASE_NAME} started at {dt.now()}\n')
BUFFER = StringIO()
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
    print(f'host={host}, port={port}, user={user}, dbname={dbname}', flush=True)
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

def get_nlp():
    return blank("en")
    
def get_db_config(args):
    return {
        k : args.get(k, d) for (k, d) in
        [('dbname', 'sec'), ('host', 'localhost'), ('port', '5432'), ('user', 'secapp'), ('password', 'sec')]
    }
def pr(*args, **kwargs):
    kwargs.update({'flush': True, 'file':BUFFER})
    print(*args, **kwargs)

def output_buffer_to_file():
    with open(OUPUT_PATH, 'at') as f:
        f.write(BUFFER.getvalue())

if __name__ == '__main__':
    try:
        import spacy
        from spacy import blank
        from spacy.matcher import PhraseMatcher
        pr(spacy.__version__)
        pr(pickle.format_version)
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
        pr("is tokenizer up to date",active_version_count )
        pr(f'force run = {args.force}')
        should_run = (active_version_count ==0 or args.force)
        pr("should run?",should_run)
        if should_run:
            pr("updating NLP ")
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
        pr("NLP Tokenizer Completed in ", end_time - start_time)
        open(OUPUT_PATH, 'at').write(f'{BASE_NAME} completed successfully at {dt.now()} in {end_time - start_time}\n')
    except Exception as e:
        pr(f'Error in nlp_tokenizer.py: {str(e)}', file=sys.stderr, flush=True)
        open(OUPUT_PATH, 'at').write(f'{BASE_NAME} has errors {str(e)} {dt.now()}\n')
    finally:
        output_buffer_to_file()
