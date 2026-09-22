#!/usr/bin/env python
import argparse
import os
import pickle
from bz2 import compress
from datetime import datetime, timezone
from pathlib import Path
from pickle import dumps
import traceback

import psycopg2
import spacy
from spacy import blank
from spacy.matcher import PhraseMatcher

# Ensure the sec_etl root (where etl_processor.py lives) is on sys.path whether
# run via the sec_etl-level symlink, directly, or through etl.qmd.
import os as _os
import sys as _sys
_THIS_DIR = _os.path.dirname(_os.path.abspath(__file__))
for _root in (_THIS_DIR, _os.path.dirname(_THIS_DIR), _os.path.dirname(_os.path.dirname(_THIS_DIR)), _os.getcwd()):
    if _os.path.isfile(_os.path.join(_root, 'etl_processor.py')):
        if _root not in _sys.path:
            _sys.path.insert(0, _root)
        break

from etl_processor import EtlProcessor, etl_printer, force_requested


class NlpTokenizerProcessor(EtlProcessor):
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
    ACTIVE_VERSION_COUNT_SQL = """
    select count(*) from ncit_version where active_version = 'Y' and ncit_tokenizer is not null
    """

    def __init__(self, args=None, name=None, python_file=None):
        python_file = python_file or __file__
        super().__init__(
            name=name or Path(python_file).stem,
            args=args,
            python_file=python_file,
        )

    @etl_printer
    def build_parser(self) -> argparse.ArgumentParser:
        parser = argparse.ArgumentParser(
            description='Update the specified sqlite database with information from the cancer.gov API'
        )
        parser.add_argument('--force', '-f', action='store_true', required=False,
                            default=force_requested(__file__))
        parser.add_argument('--dbname', action='store', type=str, required=False, default=os.environ.get('DB_NAME', 'sec'))
        parser.add_argument('--host', action='store', type=str, required=False, default=os.environ.get('DB_HOST', 'localhost'))
        parser.add_argument('--user', action='store', type=str, required=False, default=os.environ.get('DB_USER', 'sec'))
        parser.add_argument('--password', action='store', type=str, required=False, default=os.environ.get('DB_PASS', 'sec'))
        parser.add_argument('--port', action='store', type=str, required=False, default=os.environ.get('DB_PORT', '5433'))
        return parser

    @etl_printer
    def is_tokenizer_current(self, cur):
        cur.execute(self.ACTIVE_VERSION_COUNT_SQL)
        return cur.fetchone()[0]

    @etl_printer
    def build_matcher(self, cur, nlp):
        cur.execute(self.NCIT_CODE_AND_SYNONYMS_SQL)
        records = cur.fetchall()
        cur.execute(self.NCIT_SYNONYMS_SQL)
        records.extend(cur.fetchall())

        code_synonym_set = set()
        for record in records:
            code = record[0]
            synonyms = record[1].split('|')
            new_tuple = (zip([code] * len(synonyms), synonyms))  # list(zip([code] * len(synonyms), synonyms))
            code_synonym_set.add(new_tuple)
        patterns = []
        for code_synonym in code_synonym_set:  # patterns = [nlp.make_doc(v[1]) for v in code_synonym_set]
            v = next(code_synonym)
            patterns.append(nlp.make_doc(v[1]))
        matcher = PhraseMatcher(nlp.vocab, attr='LOWER')
        matcher.add('TerminologyList', patterns)
        return matcher

    @etl_printer
    def save_matcher(self, con, cur, matcher):
        compressed_pickled_string = compress(dumps(matcher))
        timestamp = datetime.now(timezone.utc)
        cur.execute(self.NCI_VERSION_UPDATE_SQL, (timestamp, compressed_pickled_string, 'Y'))
        con.commit()
        cur.execute(self.REMOVE_OLD_VERSIONS_OF_NCIT)
        con.commit()

    @etl_printer
    def process(self):
        start_time = datetime.now()
        con = None
        try:
            self.pr(spacy.__version__)
            self.pr(pickle.format_version)
            con = psycopg2.connect(
                database=self.args.dbname,
                user=self.args.user,
                host=self.args.host,
                port=self.args.port,
                password=self.args.password,
            )
            cur = con.cursor()

            active_version_count = self.is_tokenizer_current(cur)
            self.pr('is tokenizer up to date', active_version_count)
            self.pr(f'force run = {self.args.force}')
            should_run = (active_version_count == 0 or self.args.force)
            self.pr('should run?', should_run)
            if should_run:
                self.pr('updating NLP ')
                nlp = blank('en')
                matcher = self.build_matcher(cur, nlp)
                self.save_matcher(con, cur, matcher)
        except Exception as exc:
            self.fail('NLP Tokenizer FAILED: ', exc, traceback.format_exc())
        finally:
            if con is not None:
                con.close()
            super().post_process()

        end_time = datetime.now()
        print('NLP Tokenizer Completed in ', end_time - start_time)
        return self.succeeded


if __name__ == '__main__':
    bootstrap_processor = NlpTokenizerProcessor(args=None, python_file=__file__)
    parser = bootstrap_processor.build_parser()
    parsed_args = parser.parse_args()
    # Module-level `success` is what etl.qmd reads back out of the module
    # namespace (runpy.run_path) to decide whether this step passed.
    success = NlpTokenizerProcessor(args=parsed_args, python_file=__file__).process()
