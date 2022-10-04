#!/usr/bin/env python

import argparse
from dataclasses import dataclass, field, astuple
from datetime import (date, datetime, timezone)
from typing import (Union, Any)
from psycopg2 import connect
from transformers import TFAutoModelForTokenClassification
from transformers import AutoTokenizer
from transformers import pipeline


## Used to fill bert_candidate_criteria with data from candidate_criteria
# Requires Bert Model to be build and be in place.
#   Look at BERTMODEL_LOCATION for details or to set it...currently set for VM
# Requires a connection to psql
## Joseph Verbeck

# curated_criteria is where i should save formated bert data
# trial_unstructured_criteria is where i should pull data for bert to format

CURRENT_MEDICATION = "'C156818'"
NEOPLASM = "'C3262', 'C6283', 'C88025'"
UNIT_OF_MEASURE_TREE = "'C25709'"
PYSICAL_FEELINGS_QUESTION_TREE = "'C173219'"
PERSONAL_ATTRIBUTE_TREE = "'C19332'"

BERT_MODEL_LOCATION = '/local/models/content/model'
CRITERIA_TYPE_INSERT = '''insert into criteria_types 
    (
        criteria_type_id, criteria_type_code, criteria_type_title, 
        criteria_type_desc, criteria_type_active, criteria_type_sense, criteria_column_index
    ) 
    values (%s, %s, %s, %s, %s, %s, %s);'''

REFINED_BERT_CANDIDATE_CRITERIA = """insert into bert_candidate_criteria 
    (
        nct_id, criteria_type_id, display_order, inclusion_indicator,
        candidate_criteria_text, candidate_criteria_norm_form, candidate_criteria_expression,
        generated_date, marked_done_date
    ) values (%s, %s, %s, %s, %s, %s, %s, %s, %s);"""

CANDIDATE_CRITERIA_SELECT = '''select * from candidate_criteria
    where criteria_type_id=12 OR criteria_type_id=18;'''

## gilbert's disease is being broken into multiple findings...breaks sql insert 
# CANDIDATE_CRITERIA_SELECT = '''select * from candidate_criteria
#     where nct_id='NCT04848337' AND display_order=15
#     limit 1000;'''

# CREATE TABLE bert_candidate_criteria(LIKE candidate_criteria INCLUDING ALL);


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

def get_one(db: connect, query: str) -> Union[Any, None]:
    curr = db.cursor()
    curr.execute(query)
    return curr.fetchone()
        
def save(db: connect, query: str, data: tuple=None ) -> None:
    curr = db.cursor()
    curr.execute(query, data)
    db.commit()

def rollback(db: connect) -> None:
    curr = db.cursor()
    curr.execute("ROLLBACK")
    db.commit()

def get_best_ncit_code_sql_for_span(term) -> str:
        return f"""
            select code from ncit where code not in (
                select descendant from ncit_tc where parent in (
                    {UNIT_OF_MEASURE_TREE}, 
                    {PYSICAL_FEELINGS_QUESTION_TREE},
                    {PERSONAL_ATTRIBUTE_TREE}
                    )
                ) 
            and lower(pref_name) = '{term}'
            and code not in ({NEOPLASM}, {CURRENT_MEDICATION})
            and lower(pref_name) not in ('i', 'ii', 'iii', 'iv', 'v', 'set', 'all', 'at', 'is', 'and', 'or', 'to', 'a', 'be', 'for', 'an', 'as', 'in', 'of', 'x', 'are', 'no', 'any', 'on', 'who', 'have', 't', 'who', 'at')
        """

def get_ncit_code_sql_for_span(term) -> str:
        return f"""
            select distinct code from ncit_syns where code not in (
                select descendant from ncit_tc where parent in (
                    {UNIT_OF_MEASURE_TREE}, 
                    {PYSICAL_FEELINGS_QUESTION_TREE},
                    {PERSONAL_ATTRIBUTE_TREE}
                    )
                )
            and l_syn_name = '{term}'
            and code not in ({NEOPLASM}, {CURRENT_MEDICATION})
            and l_syn_name not in ('i', 'ii', 'iii', 'iv', 'v', 'set', 'all', 'at', 'is', 'and', 'or', 'to', 'a', 'be', 'for', 'an', 'as', 'in', 'of', 'x', 'are', 'no', 'any', 'on', 'who', 'have', 't', 'who', 'at')
        """

def build_expressions(codes: list) -> str:
    expression_list = []
    for code in codes:
        for value in code:
            expression_list.append(f"check_if_any('{value})=='YES'")
    return ' || '.join(expression_list)

class BertTokenizer:


    def __init__(self, nlp, sentence: str) -> None:
        self.nlp = nlp
        self.table = {
            'LABEL_0': 'O',  # We don't care about O labels
            'LABEL_1': 'B-Chemical',
            'LABEL_2': 'B-Disease',
            'LABEL_3': 'I-Disease',
            'LABEL_4': 'I-Chemical',
            'LABEL_5': 'B-Prior',
            'LABEL_6': 'I-Prior'
        }
        self.tokens = nlp(sentence)

    def get_words_and_label(self) -> dict:
        doc_list = {}
        for index, result in enumerate(self.tokens):
            # print(result)
            if all(result['entity'] != label for label in ['LABEL_0', 'LABEL_3', 'LABEL_4', 'LABEL_6']) and (not result['word'].startswith('##')):
                word, label = self._create_word(self.tokens[index:])
                doc_list[word] = label
                # doc_list.append({f"{word}": label})
        return doc_list
        
    def get_word_list(self) -> list:
        doc_list = []
        for index, result in enumerate(self.tokens):
            if all(result['entity'] != label for label in ['LABEL_0', 'LABEL_3', 'LABEL_4', 'LABEL_6']) and (not result['word'].startswith('##')):
                word, _ = self._create_word(self.tokens[index:])
                doc_list.append(word)
        return doc_list

    def _create_word(self, tokens: list) -> tuple:
        first_token = tokens.pop(0)
        word = first_token['word']
        label = self.table[first_token['entity']]
        for token in tokens:
            if token.get('word').startswith('##'):
                word = word + token['word'][2:]
            elif self.table[token.get('entity')].startswith('I-') and self.table[token.get('entity')][2:] == label[2:]:
                word = word + ' ' + token['word']
            # elif self.table[token.get('entity')][2::] == label[2::]:
            #     word = word + token['word']
            elif not token.get('word').startswith('##'):
                return word, label
        return word, label

    def _combine_words(self):
        pass

@dataclass
class BertCandidateCriteria:
    nct_id: str
    criteria_type_id: str
    display_order: int
    inclusion_indicator: int
    candidate_criteria_text: str
    candidate_criteria_norm_form: str
    candidate_criteria_expression: str
    generated_date: str
    marked_done_date: field(default=None)

    def __iter__(self):
        return iter(astuple(self))


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

    ############## Pull from trial_unstructured_criteria ##########

    unstructered_trials_data = get_all(db, CANDIDATE_CRITERIA_SELECT)
    
    # tokenizer = AutoTokenizer.from_pretrained("distilbert-base-uncased")
    tokenizer = AutoTokenizer.from_pretrained('/local/models/distilbert-base-uncased', local_files_only=True)
    model = TFAutoModelForTokenClassification.from_pretrained(BERT_MODEL_LOCATION)
    bert_pipeline = pipeline("ner", model=model, tokenizer=tokenizer)

    modified_data = []
    for trial in unstructered_trials_data:
        try:
            bert = BertTokenizer(bert_pipeline, trial[4].split(")---")[1])
            bert_findings = bert.get_words_and_label()
            print(bert_findings)
            candidate_criteria_norm_form = []
            found_c_codes = []
            if bert_findings:
                for term, tag in bert_findings.items():
                    print(term)
                    ccode = get_all(db, get_best_ncit_code_sql_for_span(term))
                    if len(ccode) < 0:
                        ccodes = get_all(db, get_ncit_code_sql_for_span(term))
                    if ccode:
                        found_c_codes.append(list(ccode[0]))
                        candidate_criteria_norm_form.append(f"{list(ccode[0])} - {term} ({tag})")
                    else:
                        candidate_criteria_norm_form.append(f"{[]} - {term} ({tag})")
            # print(build_expressions(found_c_codes))
            # print(candidate_criteria_norm_form)

            save(
                db, 
                REFINED_BERT_CANDIDATE_CRITERIA,
                tuple(BertCandidateCriteria(
                    nct_id=trial[0],
                    criteria_type_id=trial[1],
                    display_order=trial[2],
                    inclusion_indicator=trial[3],
                    candidate_criteria_text=trial[4],
                    candidate_criteria_norm_form=candidate_criteria_norm_form,
                    candidate_criteria_expression=build_expressions(found_c_codes),
                    generated_date=datetime.now(),
                    marked_done_date=None
                ))
                # (
                #     trial[0], # nct_id
                #     trial[1], # criteria_type_id
                #     trial[2], # display_order
                #     trial[3], # inclusion_indicator
                #     trial[4], # candidate_criteria_text
                #     candidate_criteria_norm_form, # candidate_criteria_norm_form
                #     build_expressions(found_c_codes), # candidate_criteria_expression
                #     datetime.now(), # generated_date
                #     None, # marked_done_date
                # )
            )
        except Exception as err:
            print(err)
            rollback(db)



    ########################### END ###############################

    ############## Pull from trial_criteria #######################
    # save(db, CRITERIA_TYPE_INSERT, ('20', 'bert_pt_exc', 'Bert PT Exclusion', 'chemotherapy', 'N', 'Exclusion', '3010',))
    # pt_inclusions = get_all(db, 'select (trial_criteria_orig_text) from trial_criteria where criteria_type_id=12;')
    # pt_exclusions = get_all(db, 'select (trial_criteria_orig_text) from trial_criteria where criteria_type_id=18;')
    # tokenizer = AutoTokenizer.from_pretrained("distilbert-base-uncased")
    # model = TFAutoModelForTokenClassification.from_pretrained(BERT_MODEL_LOCATION)
    # bert_pipeline = pipeline("ner", model=model, tokenizer=tokenizer)

    # for pt_inclusion in pt_inclusions:
    #     print(pt_inclusion[0])
    #     bert = BertTokenizer(bert_pipeline, pt_inclusion[0])
    #     bert_findings = bert.get_words_and_label()
    #     if bert_findings:
    #         for key_term, term_type in bert_findings.items():
    #             print(f"{key_term} - ({term_type}) ({code})")
    # pt_inclusions = None

    # for pt_exclusion in pt_exclusions:
    #     print(pt_exclusion[0])
    #     bert = BertTokenizer(bert_pipeline, pt_exclusion[0])
    #     print(bert.get_words_and_label())
    # pt_exclusions = None
    
    ############## END ##########################################


    db.close()
    end_time = datetime.now()
    print("BERT Tokenizer Completed in ", end_time - start_time)


#     criteria_type_id | criteria_type_code |   criteria_type_title    |                            criteria_type_desc                            | criteria_type_active | criteria_type_sense | criteria_column_index 
# ------------------+--------------------+--------------------------+--------------------------------------------------------------------------+----------------------+---------------------+-----------------------
#                 1 | biomarker_exc      | Biomarker Exclusion      | Biomarker Exclusion                                                      | N                    | Exclusion           |                    20