import json
import os
import re
from collections import defaultdict
from pathlib import Path
import concurrent.futures
from urllib.parse import urlencode

import pandas as pd
import requests
import streamlit as st

file_dir = Path(__file__).parent

layout = "wide"
st.set_page_config(page_title="Powered by Streamlit", layout=layout)
st.title("Stage IV Head and Neck Cancer")
USE_CONT_WIDTH = False if layout == "wide" else True

HNC_MAINTYPE = "C35850"

HNC_STAGEIV_TEMPLATE = {
    "Stage IV Head and Neck Carcinoma": re.compile(r"\biv\b", flags=re.I),
    "Stage IVA Head and Neck Carcinoma": re.compile(r"\biva\b", flags=re.I),
    "Stage IVB Head and Neck Carcinoma": re.compile(r"\bivb\b", flags=re.I),
    "Stage IVC Head and Neck Carcinoma": re.compile(r"\bivc\b", flags=re.I),
}
HNC_CATEGORIES = list(HNC_STAGEIV_TEMPLATE.keys())


@st.cache_data
def get_hnc_stages():
    current_trial_status = urlencode(
        {
            "current_trial_status": [
                "Active",
                "Approved",
                "Enrolling by Invitation",
                "In Review",
                "Temporarily Closed to Accrual",
                "Temporarily Closed to Accrual and Intervention",
            ]
        },
        doseq=True,
    )
    url = f"https://clinicaltrialsapi.cancer.gov/api/v2/diseases?ancestor_ids=C35850&{current_trial_status}&type=stage"
    res = requests.get(url, headers={"X-API-KEY": os.getenv("CTS_V2_API_KEY")})
    print(res.status_code, "/api/v2/diseases")
    data = res.json()
    assert data["total"] == len(data["data"])
    print("TOTAL:", data["total"])
    return data["data"]


@st.cache_data
def get_hnc_stage_trials(stages: list[str]):
    body = {
        "current_trial_status": [
            "Active",
            "Approved",
            "Enrolling by Invitation",
            "In Review",
            "Temporarily Closed to Accrual",
            "Temporarily Closed to Accrual and Intervention",
        ],
        "include": ["nci_id", "brief_title", "primary_purpose", "diseases"],
        "maintype": [HNC_MAINTYPE],
        "stage": stages,
        "from": 0,
        "size": 50,
    }
    url = "https://clinicaltrialsapi.cancer.gov/api/v2/trials"
    res = requests.post(
        url, headers={"X-API-KEY": os.getenv("CTS_V2_API_KEY")}, json=body
    )
    print(res.status_code, "/api/v2/trials")
    data = res.json()
    trials = data["data"]
    total = data["total"]
    n = 1
    while len(trials) < total:
        start = len(trials)
        body["from"] = start
        res = requests.post(
            url, headers={"X-API-KEY": os.getenv("CTS_V2_API_KEY")}, json=body
        )
        print(res.status_code, "/api/v2/trials")
        data = res.json()
        trials_continued = data["data"]
        trials += trials_continued
        print("page", (n := n + 1), f"({len(trials)} of {total})")
    return trials


@st.cache_data
def get_hnc_disease_code_trials(code: str):
    body = {
        "current_trial_status": [
            "Active",
            "Approved",
            "Enrolling by Invitation",
            "In Review",
            "Temporarily Closed to Accrual",
            "Temporarily Closed to Accrual and Intervention",
        ],
        "include": ["nci_id"],
        "diseases.nci_thesaurus_concept_id": code,
        "from": 0,
        "size": 50,
    }
    url = "https://clinicaltrialsapi.cancer.gov/api/v2/trials"
    res = requests.post(
        url, headers={"X-API-KEY": os.getenv("CTS_V2_API_KEY")}, json=body
    )
    print(res.status_code, "/api/v2/trials")
    data = res.json()
    trials = data["data"]
    total = data["total"]
    n = 1
    while len(trials) < total:
        start = len(trials)
        body["from"] = start
        res = requests.post(
            url, headers={"X-API-KEY": os.getenv("CTS_V2_API_KEY")}, json=body
        )
        print(res.status_code, "/api/v2/trials")
        data = res.json()
        trials_continued = data["data"]
        trials += trials_continued
        print("page", (n := n + 1), f"({len(trials)} of {total})")
    return trials


st.markdown("## Step 1: Get HNC Stages")
st.markdown(
    """```py
def get_hnc_stages():
    current_trial_status = urlencode(
        {
            "current_trial_status": [
                "Active",
                "Approved",
                "Enrolling by Invitation",
                "In Review",
                "Temporarily Closed to Accrual",
                "Temporarily Closed to Accrual and Intervention",
            ]
        },
        doseq=True,
    )
    url = f"https://clinicaltrialsapi.cancer.gov/api/v2/diseases?ancestor_ids=C35850&{current_trial_status}&type=stage"
    res = requests.get(url, headers={"X-API-KEY": os.getenv("CTS_V2_API_KEY")})
    data = res.json()
    assert data["total"] == len(data["data"])
    return data["data"]

hnc_stages = get_hnc_stages()
```""",
)
data_load_state = st.text("Loading stage data...")
hnc_stages = get_hnc_stages()
data_load_state.text("")
st.dataframe(
    pd.DataFrame(hnc_stages)[["name", "codes"]],
    column_config={"parent_ids": None},
    hide_index=False,
    use_container_width=USE_CONT_WIDTH,
)

st.markdown("## Step 2: Split them into Predefined Categories")
st.markdown(
    """```python
# continuing from step 1...

HNC_STAGEIV_TEMPLATE = {
    "Stage IV Head and Neck Carcinoma": re.compile(r"\\biv\\b", flags=re.I),
    "Stage IVA Head and Neck Carcinoma": re.compile(r"\\biva\\b", flags=re.I),
    "Stage IVB Head and Neck Carcinoma": re.compile(r"\\bivb\\b", flags=re.I),
    "Stage IVC Head and Neck Carcinoma": re.compile(r"\\bivc\\b", flags=re.I),
}
HNC_CATEGORIES = list(HNC_STAGEIV_TEMPLATE.keys())

hnc_stage_categories = defaultdict(list)
hnc_stage_codes = defaultdict(list)
for stage in hnc_stages:
    for key, pattern in HNC_STAGEIV_TEMPLATE.items():
        if pattern.search(stage["name"]):
            hnc_stage_categories[key].append(stage["name"])
            for code in stage["codes"]:
                hnc_stage_codes[key].append(code)
```"""
)
hnc_stage_categories = defaultdict(list)
hnc_stage_codes = defaultdict(list)
for stage in hnc_stages:
    for key, pattern in HNC_STAGEIV_TEMPLATE.items():
        if pattern.search(stage["name"]):
            hnc_stage_categories[key].append(stage["name"])
            for code in stage["codes"]:
                hnc_stage_codes[key].append(code)

st.markdown("### Step 2a. Diff the current list with the static list from Cancer.gov")
st.html(
    '<p style="max-width: 50vw;">Symmetric Difference between Computed and Static Categories. '
    'The Static Categories were found from Cancer.gov\'s trial search page within the "Stage" dropdown.</p>'
)
total = 0
for cat in HNC_CATEGORIES:
    total += len(hnc_stage_categories[cat])
    st.write(cat)
    computed_categories = set(hnc_stage_categories[cat])
    with open(file_dir / "stage_iv_categories" / (cat + ".json")) as fp:
        static_categories = set(json.load(fp))
    st.write(computed_categories.symmetric_difference(static_categories))
print("TOTAL # Terms under Stage IV", total)

st.markdown("## Step 3: Select stage value to filter trials by")


def find_trials():
    stage = st.session_state.stage
    stage_codes = hnc_stage_codes[stage]
    with open(file_dir / "stage_codes.json", "w") as f:
        json.dump(stage_codes, f)
    fetch_state = st.text("Finding trials...")
    trials = get_hnc_stage_trials(stage_codes)
    fetch_state.text("")
    return trials


def verify_trials_have_stage(trials):
    for trial in trials:
        trial_has_exp_disease = False
        for disease in trial["diseases"]:
            if (
                disease["nci_thesaurus_concept_id"]
                in hnc_stage_codes[st.session_state.stage]
            ):
                trial_has_exp_disease = True
                break
        assert (
            trial_has_exp_disease
        ), f"Trial {trial['nci_id']} is missing {st.session_state.stage}"
    print(f"verified {st.session_state.stage}")


if "trial_ids" not in st.session_state:
    st.session_state.trial_ids = []
    st.session_state.trial_ids_set = set()
    st.session_state.trials = []
    st.session_state.trial_ids_set_other = set()


col1, col2 = st.columns((6, 6))
with col1:
    st.selectbox("Stage", ["", *HNC_CATEGORIES], key="stage")

    if st.button("Find Trials", type="primary"):
        trials = find_trials()
        trial_ids = [trial["nci_id"] for trial in trials]
        st.session_state.trials = trials
        st.session_state.trial_ids = pd.DataFrame(
            trials, columns=["nci_id", "brief_title"]
        )
        verify_trials_have_stage(trials)

        st.session_state.trial_ids_set = set(trial_ids)
        st.session_state.trial_ids_set_other = set()
        codes = hnc_stage_codes[st.session_state.stage]
        jobs = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            for code in codes:
                job = executor.submit(get_hnc_disease_code_trials, code)
                jobs.append(job)

            for future in concurrent.futures.as_completed(jobs):
                try:
                    data = future.result()
                except Exception as exc:
                    print("%r generated an exception: %s" % (code, exc))
                else:
                    st.session_state.trial_ids_set_other.update(
                        [t["nci_id"] for t in data]
                    )

    trial_ids = st.session_state.trial_ids
    st.html(
        f"<div style='text-align:left;'><i>Showing {len(trial_ids)} of {len(trial_ids)} trials</i></div>"
    )
    event = st.dataframe(
        st.session_state.trial_ids,
        hide_index=False,
        use_container_width=True,
        on_select="rerun",
        selection_mode="single-row",
    )
with col2:
    st.html("<div>&nbsp;</div>")
    st.html("<div>&nbsp;</div>")
    st.html("<div>&nbsp;</div>")
    row_selections = event.selection["rows"]
    trial = (
        st.session_state.trials[row_selections[0]]
        if row_selections
        else {"diseases": [], "brief_title": ""}
    )
    st.write(trial["brief_title"])
    data = []
    for disease in trial["diseases"]:
        if (
            disease["nci_thesaurus_concept_id"]
            in hnc_stage_codes[st.session_state.stage]
            or disease["nci_thesaurus_concept_id"] == HNC_MAINTYPE
        ):
            data.append(
                {
                    "inclusion_indicator": disease["inclusion_indicator"],
                    "name": disease["name"],
                    "code": disease["nci_thesaurus_concept_id"],
                }
            )
    st.markdown("##### Relevant Diseases")
    st.dataframe(data, use_container_width=True)
st.markdown(
    """
The "Find Trials" button executes the function below:

```python
def get_hnc_stage_trials(stages: list[str]):
    body = {{ 
        "current_trial_status": [
            "Active",
            "Approved",
            "Enrolling by Invitation",
            "In Review",
            "Temporarily Closed to Accrual",
            "Temporarily Closed to Accrual and Intervention",
        ],
        "include": ["nci_id", "brief_title", "primary_purpose", "diseases"],
        "maintype": {},
        "stage": {},
        "from": 0,
        "size": 50,
    }}
    url = "https://clinicaltrialsapi.cancer.gov/api/v2/trials"
    res = requests.post(
        url, headers={{"X-API-KEY": os.getenv("CTS_V2_API_KEY")}}, json=body
    )
    res_json = res.json()
    trials = res_json["data"]
    total = res_json["total"]
    while len(trials) < total:
        start = len(trials)
        body["from"] = start
        res = requests.post(
            url, headers={{"X-API-KEY": os.getenv("CTS_V2_API_KEY")}}, json=body
        )
        res_json = res.json()
        trials += res_json["data"]
    return trials
```""".format(
        [HNC_MAINTYPE],
        hnc_stage_codes[st.session_state.stage] if st.session_state.stage else "stages",
    )
)
st.markdown("## Verification")
st.html(
    '<p style="max-width: 50vw;">The verification step uses the same code as step 3 above, except for the following difference in body arguments</p>'
)
st.markdown("""
```python
body = {
    "current_trial_status": [
        "Active",
        "Approved",
        "Enrolling by Invitation",
        "In Review",
        "Temporarily Closed to Accrual",
        "Temporarily Closed to Accrual and Intervention",
    ],
    "include": ["nci_id"],
    "diseases.nci_thesaurus_concept_id": code, # <- passing each code one at a time rather than maintype & stage list
    "from": 0,
    "size": 50,
}
```""")
st.html(
    "<p style='max-width: 50vw;'>Since only one code gets passed at a time, the verification needs to make one call per code in the list of stage codes. "
    "The results should be that the same NCI IDs are discovered with both methods with 0 difference.</p>"
)
if len(st.session_state.trial_ids_set_other):
    st.markdown("**Result:**")
    st.write(
        st.session_state.trial_ids_set.symmetric_difference(
            st.session_state.trial_ids_set_other
        )
    )
