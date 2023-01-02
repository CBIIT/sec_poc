import argparse
from psycopg2 import connect
from typing import (Union, Any)
from datetime import (datetime)

def get_db(host: str, port: str, user: str, password: str, dbname: str) -> connect:
     return connect(
            host=host,
            port=port,
            database=dbname,
            user=user,
            password=password
        )

def get_all(db: connect, query: str) -> Union[Any, None]:
    curr = db.cursor()
    curr.execute(query)
    return curr.fetchall()

def save(db: connect, query: str, data: tuple=None ) -> None:
    curr = db.cursor()
    curr.execute(query, data)
    db.commit()

def get_biomarkers_from_trials() -> str:
        return "SELECT biomarker_inc_codes, biomarker_exc_codes, nct_id FROM trials;"

# python biomarker_fill.py --dbname sec --user secapp
# For display names hit NCIT table psql;
# For parent/children hit PARENTS table psql;
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
    
    db = get_db(**vars(args))
    biomarkers = get_all(db, get_biomarkers_from_trials())
    uniq_biomarker_map = {}
    for biomarker in biomarkers:
        if biomarker[0]:
            inc_biomarkers = biomarker[0].split(', ')
            for inc_biomarker in inc_biomarkers:
                if uniq_biomarker_map.get(inc_biomarker):
                    uniq_biomarker_map[inc_biomarker]['count'] += 1
                    uniq_biomarker_map[inc_biomarker]['nct_ids'].append(biomarker[2])
                else:
                    uniq_biomarker_map[inc_biomarker] = {'inclusion': True, 'count': 1, 'nct_ids': [biomarker[2]]}
        if biomarker[1]:
            exc_biomarkers = biomarker[1].split(', ')
            for exc_biomarker in exc_biomarkers:
                if uniq_biomarker_map.get(exc_biomarker):
                    uniq_biomarker_map[exc_biomarker]['count'] += 1
                    uniq_biomarker_map[exc_biomarker]['nct_ids'].append(biomarker[2])
                else:
                    uniq_biomarker_map[exc_biomarker] = {'exclusion': True, 'count': 1, 'nct_ids': [biomarker[2]]}
    print(uniq_biomarker_map)
        