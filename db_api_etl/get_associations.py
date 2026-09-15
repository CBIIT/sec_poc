import argparse
import datetime
import os
from pathlib import Path
import traceback

import psycopg2
import psycopg2.extras
import requests

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

from etl_processor import EtlProcessor, etl_printer


header_api = {"Content-Type": "application/json"}


class AssociationsProcessor(EtlProcessor):
    DROP_SQL = "drop table if exists associations"
    TABLE_SQL = """
    create table associations (
    association     text,
    code text,
    code_name text,
    related_code text,
    related_name text
    )
    """
    # NOTE: carried over from the original script -- these were defined but
    # never executed (and INDEX_SQL3/INDEX_SQL4 share the name
    # `association_rel_code`, so applying both would fail). Left unexecuted to
    # preserve the original behavior.
    INDEX_SQL1 = "create index association_type_code on associations(association, code)"
    INDEX_SQL2 = "create index association_code on associations(code)"
    INDEX_SQL3 = "create index association_rel_code on associations(association,related_code)"
    INDEX_SQL4 = "create index association_rel_code on associations(related_code)"
    INSERT_SQL = "insert into associations(association, code, code_name, related_code, related_name) values (%s,%s,%s,%s,%s)"

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
        parser.add_argument('--dbname', action='store', type=str, required=False, default=os.environ.get('DB_NAME', 'sec'))
        parser.add_argument('--host', action='store', type=str, required=False, default=os.environ.get('DB_HOST', 'localhost'))
        parser.add_argument('--user', action='store', type=str, required=False, default=os.environ.get('DB_USER', 'sec'))
        parser.add_argument('--password', action='store', type=str, required=False, default=os.environ.get('DB_PASS', 'sec'))
        parser.add_argument('--port', action='store', type=str, required=False, default=os.environ.get('DB_PORT', '5433'))
        return parser

    @staticmethod
    def request_associations(starting_from=0):
        r = requests.get(
            f"https://api-evsrest.nci.nih.gov/api/v1/concept/ncit/associations/Has_Target?fromRecord={starting_from}&pageSize=6000",
            timeout=(0.4, 7.0),
            headers=header_api,
        )
        return r.json()

    @staticmethod
    def collect_associations(data, collector):
        for r in data['associationEntries']:
            collector.append(
                [r['association'], r['code'], r['name'], r['relatedCode'], r['relatedName']]
            )

    @etl_printer
    def reset_table(self, con, cur):
        cur.execute(self.DROP_SQL)
        cur.execute(self.TABLE_SQL)
        con.commit()

    @etl_printer
    def fetch_all_associations(self):
        data = self.request_associations(starting_from=0)
        associations = []  # Collect results here
        self.collect_associations(data, associations)
        local_size = len(associations)
        evs_size = data['total']
        while local_size < evs_size:
            data = self.request_associations(starting_from=local_size)
            self.collect_associations(data, associations)
            new_local_size = len(associations)
            assert new_local_size > local_size, \
                'Local associations array is not growing after fetching from EVS API. Exiting.'
            local_size = new_local_size

        assert len(associations) > 0, \
            'No associations found. Something must be wrong with connection to EVS API.'
        return associations

    @etl_printer
    def insert_associations(self, con, cur, associations):
        print(f'inserting {len(associations)} associations')
        # NOTE: the original called execute_batch with the arguments out of
        # order (sql/cur swapped), which raised at runtime. Corrected to the
        # documented (cur, sql, argslist) signature.
        psycopg2.extras.execute_batch(cur, self.INSERT_SQL, associations, page_size=1000)
        con.commit()
        # `associations` is dropped and recreated above, so it starts with no
        # grants and the read-only role must be re-granted every run. Both calls
        # are best-effort: on a fresh local DB the role may not exist yet, and
        # the ETL must not fail over a missing GRANT (it previously did).
        self.ensure_role(con)
        self.grant_select(con, 'associations')

    @etl_printer
    def process(self):
        start_time = datetime.datetime.now()
        con = None
        try:
            con = psycopg2.connect(
                database=self.args.dbname,
                user=self.args.user,
                host=self.args.host,
                port=self.args.port,
                password=self.args.password,
            )
            cur = con.cursor()
            self.reset_table(con, cur)
            associations = self.fetch_all_associations()
            self.insert_associations(con, cur, associations)
        except Exception as exc:
            self.fail('GET ASSOCIATIONS ETL FAILED: ', exc, traceback.format_exc())
        finally:
            if con is not None:
                con.close()
            super().post_process()

        print('Associations ETL completed in ', datetime.datetime.now() - start_time)
        return self.succeeded


if __name__ == '__main__':
    bootstrap_processor = AssociationsProcessor(args=None, python_file=__file__)
    parser = bootstrap_processor.build_parser()
    parsed_args = parser.parse_args()
    # Module-level `success` is what etl.qmd reads back out of the module
    # namespace (runpy.run_path) to decide whether this step passed.
    success = AssociationsProcessor(args=parsed_args, python_file=__file__).process()
