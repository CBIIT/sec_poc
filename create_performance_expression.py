import sys

def create_ecog_zubrod_expression(score_main=None, score_dict=None, score = None, relational=None):

    needed_codes_pycode = """
["( exists('" + score_dict[e] + "') && " + score_dict[e] + " == 'YES')" for e in
                    score_dict if e """ + relational + " score]"

    needed_codes = eval(needed_codes_pycode, locals())
    ret_expression = " || ".join(needed_codes) + " || ( exists('" + score_main + "') &&  " + \
                     score_main + relational + str(score) + ")"

    return ret_expression

def create_performance_expression(ecog=None, ecog_relational=None):
    if ecog_relational is None:
        ecog_relational = '<='
    ecog_scores = {0: 'C105722', 1: 'C105723', 2: 'C105725', 3: 'C105726', 4: 'C105727', 5: 'C105728'}
    zubrod_scores = {0: 'C19998', 1: 'C19999', 2: 'C17846', 3: 'C17847', 4: 'C17848', 5: 'C20000'}
    karnofsky_scores = {100: 'C105707', 90: 'C105709', 80: 'C105710', 70: 'C105711', 60: 'C105712',
                        50: 'C105713', 40: 'C105714', 30: 'C105715', 20: 'C105716', 10: 'C105718',
                        0: 'C105720'}
    ecog_main = 'C105721'  # the parent, which could have an integer
    zubrod_main = 'C25400'
    karnofsky_main = 'C28013'

    #
    #conversion scale comes from :
    # https: // oncologypro.esmo.org / Oncology - in -Practice / Practice - Tools / Performance - Scales
    #
    convert_to_karnofsky = { 0: [100], 1: [80,90], 2: [60, 70], 3: [40, 50], 4: [10,20,30], 5: [0]}

    def create_karnofksy(ecog=None, ecog_relational=None):
        if ecog_relational is None:
            ecog_relational = '<='

       # print(convert_to_karnofsky)
        #mapped =  [convert_to_karnofsky[e] for e in convert_to_karnofsky if e <= ecog]
        if ecog_relational in ['<=', '=<']:
            mapped = [convert_to_karnofsky[e] for e in convert_to_karnofsky if e <= ecog]
        elif ecog_relational in ['>=', '=>']:
            mapped = [convert_to_karnofsky[e] for e in convert_to_karnofsky if e >= ecog]
        elif ecog_relational == '<':
            mapped = [convert_to_karnofsky[e] for e in convert_to_karnofsky if e < ecog]
        elif ecog_relational == '=':
            mapped = [convert_to_karnofsky[e] for e in convert_to_karnofsky if e == ecog]

        #print(ecog_relational,ecog, "mapped = ", mapped)
        mapped_flat =  sorted([item for sublist in mapped for item in sublist])
        #print("mapped flat", mapped_flat)

        needed_codes = ["( exists('" + karnofsky_scores[e] + "') && (" + karnofsky_scores[e] + " == 'YES'))" for e in
                        mapped_flat ]
       # print(needed_codes)
        if ecog_relational in ['<=', '=<']:
            quan_karnofsky = '( C28013 >=  ' + str( min(convert_to_karnofsky[ecog])) + ')'
        elif ecog_relational == '<':
            quan_karnofsky =  '( C28013 >  ' + str( max(convert_to_karnofsky[ecog])) + ')'
        elif ecog_relational == '=':
            quan_karnofsky = '( C28013 ==  ' + str(max(convert_to_karnofsky[ecog])) + ')'
      #  print(quan_karnofsky)

        karnofsky_expression = " || ".join(needed_codes) + " || (exists('C28013') && " + quan_karnofsky + ")"
        return karnofsky_expression


    karnofsky_expressions = create_karnofksy(ecog, ecog_relational)
    if ecog_relational in ('<=', '=<'):
        ecog_expression = create_ecog_zubrod_expression(ecog_main, ecog_scores, ecog, relational='<=')
        zubrod_expression = create_ecog_zubrod_expression(zubrod_main, zubrod_scores, ecog, relational='<=')
        #needed_ecog_codes = ["( exists('" + ecog_scores[e] + "') && " + ecog_scores[e] + " == 'YES')" for e in
        #                     ecog_scores if e <= ecog]
        #ecog_expression = " || ".join(needed_ecog_codes) + " || (( exists('C105721') &&  C105721 <= " + str(ecog) + ")"

    elif ecog_relational == '<':
        ecog_expression = create_ecog_zubrod_expression(ecog_main, ecog_scores, ecog, relational='<')
        zubrod_expression = create_ecog_zubrod_expression(zubrod_main, zubrod_scores, ecog, relational='<')

    elif ecog_relational in ('>=', '=>'):
        ecog_expression = create_ecog_zubrod_expression(ecog_main, ecog_scores, ecog, relational='>=')
        zubrod_expression = create_ecog_zubrod_expression(zubrod_main, zubrod_scores, ecog, relational='>=')

    elif ecog_relational == '>':
        ecog_expression = create_ecog_zubrod_expression(ecog_main, ecog_scores, ecog, relational='>')
        zubrod_expression = create_ecog_zubrod_expression(zubrod_main, zubrod_scores, ecog, relational='>')

    elif ecog_relational == '=':
        ecog_expression = create_ecog_zubrod_expression(ecog_main, ecog_scores, ecog, relational='==')
        zubrod_expression = create_ecog_zubrod_expression(zubrod_main, zubrod_scores, ecog, relational='==')
    ret_val = ' (' + ecog_expression + ') || ('+zubrod_expression+') || (' + karnofsky_expressions + ')'
    
    # Now add in an expression to return NA if the patient has no performance expression
    
    ret_val = "if (check_if_any('C20641') == 'NO') { NA } else { " + ret_val + " }"
  #  print(ret_val)
    return ret_val


def parse_performance_string(s):
    #  print(s)
    sys.stdout.flush()
    sv = s.replace('Performance Status', '').strip().split(' ')
    if len(sv) == 2:
        pe = create_performance_expression(int(sv[1]), sv[0])
    else:
        pe = 'FALSE'
        # TODO: Check evaluation when there is no performance status for the patient (none at all)
        #pe = None
    return (pe)


def parse_dataframe(df):
    df['perf_criteria'] = df['perf_description'].apply(lambda x: parse_performance_string(x))
    return (df)


if __name__ == "__main__":
    import pandas as pd

    print("in main")
    r = {'perf_description': ['Performance Status =< 2', 'Performance Status =< 1', 'Performance Status < 3']}
    d = pd.DataFrame(r, columns=['perf_description'])

    parse_dataframe(d)
    print(d)

