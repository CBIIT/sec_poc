from dataclasses import dataclass
from nltk import word_tokenize
from datetime import datetime
from psycopg2 import connect
import csv
import re


## Generates the BERT corpus data set using identified prior therapy codes against sentences that should contain prior therapy key words 
# 
# Requires the pt_codes.cvs with header pref_name, code
# Example pt_codes.cvs data set would be 2-Nitropropane, C44313
#
# Requires a corpus of sentences to match above pt_codes.cvs 
# 
## Joseph Verbeck

# used_words = set()

## replace lambda
# Given [0, 0, 0, 0] and [5,6] starting at index 1 replace it with [5,6]
# Expected results [0,5,6,0]
# def replace(original_list, replace_list, start_index) -> original_list_with_replacements
replace=lambda a,b,s:a[:s]+b+a[s+len(b):]

@dataclass
class TokenizedLine:
    sentence: str
    tokens: list
    lookup_tokens: list
    tags: list

def build_tags(lenth_of: int):
    if lenth_of >= 2:
        return [5] + ([6] * (lenth_of - 1))
    return [5]

def findWholeWord(w): #SLOOOOOWWWW!!!!! Don't use this unless really required.
    return re.compile(r'\b({0})\b'.format(re.escape(w)), flags=re.IGNORECASE).search

def is_multiple_words(tag_word):
    if len(tag_word.split(" ")) >= 2:
        return True
    return False

def mark_tags(tokens, tag_word, tags, replace_tags):
    if is_multiple_words(tag_word):
        first_word = tag_word.split(" ")[0]
    else:
        first_word = tag_word
    # print(f"word {first_word}, index: {tokens}")
    try:
        index = tokens.index(first_word)
        if tags[index] == 0:
            return replace(tags, replace_tags, index)
        return tags
    except Exception as e:
        return tags



def get_transformed_pt_codes():
    pt_codes = {}
    with open('pt_codes.csv', 'r') as pt_codes_file:
        reader = csv.reader(pt_codes_file)
        for row in reader:
            if pt_codes.get(row[0][:2].lower()):
                pt_codes.get(row[0][:2].lower())[row[0]] = build_tags(len(word_tokenize(row[0])))
            else:
                pt_codes[row[0][:2].lower()] = {row[0]: build_tags(len(word_tokenize(row[0])))}
            # pt_codes[row[0][:2]] = {row[0]: build_tags(len(word_tokenize(row[0])))}
            # pt_codes[row[0][:2]] = build_tags(len(word_tokenize(row[0])))
    # print(pt_codes)

    return pt_codes

def get_tokenized_trial_sentences():
    tokenized_lines = []
    with open('sentence_corpus.txt') as file:
        for line in file:
            tokenized_words = word_tokenize(line.lower())
            lookup_tokens = [word[:2].lower() for word in tokenized_words if len(word) >= 2]
            tl = TokenizedLine(line.rstrip(), tokenized_words, lookup_tokens, [0] * len(tokenized_words))
            tokenized_lines.append(tl)
    print(len(tokenized_lines))
    return [tokenized_lines[0]]

if __name__ == '__main__':
    start_time = datetime.now()
    pt_codes = get_transformed_pt_codes()
    # print(pt_codes)
    tokenized_sentences = get_tokenized_trial_sentences()
    for tokenized_sentence in tokenized_sentences:
        for lookup_token in tokenized_sentence.lookup_tokens:
            for key, value in pt_codes.get(lookup_token, {}).items():
                if key.lower() in tokenized_sentence.sentence.lower():
                    tokenized_sentence.tags = mark_tags(tokenized_sentence.tokens, key.lower(), tokenized_sentence.tags, value)
    pt_codes = None # Clear pt_codes from memory
    with open('pt_transformed_data.csv', 'w') as out_csv:
        writer = csv.writer(out_csv)
        for tokenized_sentence in tokenized_sentences:
            #Malformed csv but this is how panda worked the first time so how the other scripts reads.
            #will fix when i have time -jv
            writer.writerow([str(tokenized_sentence.tokens), str(tokenized_sentence.tags)])
    print(f"Took: {datetime.now() - start_time}")