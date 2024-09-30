import json
import os
import re
from collections import defaultdict
from urllib.parse import urlencode
from pathlib import Path

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
def load_hnc_stages():
    querystr = urlencode(
        {
            "ancestor_ids": [HNC_MAINTYPE],
            "current_trial_status": [
                "Active",
                "Approved",
                "Enrolling by Invitation",
                "In Review",
                "Temporarily Closed to Accural",
                "Temporarily Closed to Accrual and Intervention",
            ],
            "include": ["parent_ids", "name", "codes", "count"],
            "type": "stage",
        },
        doseq=True,
    )
    url = f"https://clinicaltrialsapi.cancer.gov/api/v2/diseases?{querystr}"
    print(url)
    res = requests.get(url, headers={"X-API-KEY": os.getenv("CTS_V2_API_KEY")})
    print(res.status_code)
    data = res.json()
    assert data["total"] == len(data["data"])
    return data["data"]


st.markdown("## Step 1: Get HNC Stages List")
st.markdown(
    """```py
HNC_MAINTYPE = "C35850" # Code for "Head and Neck Carcinoma"

def load_hnc_stages():
    querystr = urlencode(
        {
            "ancestor_ids": [HNC_MAINTYPE],
            "current_trial_status": [
                "Active",
                "Approved",
                "Enrolling by Invitation",
                "In Review",
                "Temporarily Closed to Accural",
                "Temporarily Closed to Accrual and Intervention",
            ],
            "include": ["parent_ids", "name", "codes", "count"],
            "type": "stage",
        },
        doseq=True,
    )
    url = f"https://clinicaltrialsapi.cancer.gov/api/v2/diseases?{querystr}"
    res = requests.get(url, headers={"X-API-KEY": os.getenv("CTS_V2_API_KEY")})
    data = res.json()
    return data["data"]

hnc_stages = load_hnc_stages()
```""",
)
data_load_state = st.text("Loading stage data...")
hnc_stages = load_hnc_stages()
data_load_state.text("")
st.dataframe(
    hnc_stages,
    column_config={"parent_ids": None},
    hide_index=False,
    use_container_width=USE_CONT_WIDTH,
)

st.markdown("## Step 2: Split them into Predefined Categories")
st.markdown(
    """```py
HNC_STAGEIV_TEMPLATE = {
    "Stage IV Head and Neck Carcinoma": re.compile(r"\\biv\\b", flags=re.I),
    "Stage IVA Head and Neck Carcinoma": re.compile(r"\\biva\\b", flags=re.I),
    "Stage IVB Head and Neck Carcinoma": re.compile(r"\\bivb\\b", flags=re.I),
    "Stage IVC Head and Neck Carcinoma": re.compile(r"\\bivc\\b", flags=re.I),
}
HNC_CATEGORIES = list(HNC_STAGEIV_TEMPLATE.keys())

hnc_stage_categories = []
for stage in hnc_stages:
    for key, pattern in HNC_STAGEIV_TEMPLATE.items():
        if pattern.search(stage["name"]):
            hnc_stage_categories.append(
                {
                    "parent": key,
                    "name": stage["name"],
                    "codes": stage["codes"],
                }
            )
```"""
)
hnc_stage_categories = []
hnc_stage_codes = defaultdict(list)
for stage in hnc_stages:
    for key, pattern in HNC_STAGEIV_TEMPLATE.items():
        if pattern.search(stage["name"]):
            hnc_stage_categories.append(
                {
                    "parent": key,
                    "name": stage["name"],
                    "codes": stage["codes"],
                }
            )
            for code in stage["codes"]:
                hnc_stage_codes[key].append(code)

df = (
    pd.DataFrame(hnc_stage_categories)
    .groupby(["parent"])["name"]
    .apply(lambda x: "<br>".join(x))
    .reset_index()
)
df.columns = ["New Head and Neck Concept", "Associated Terms"]
st.markdown(
    df.to_html(escape=False, index=False),
    unsafe_allow_html=True,
)

st.markdown("## Step 3: Select stage value to filter trials by")
cont = st.container()
cont.selectbox("Stage", HNC_CATEGORIES, key="stage")


@st.cache_data
def _get_ctsapi_hnc_stage_trials(stages: list[str]):
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
    print(url)
    res = requests.post(
        url, headers={"X-API-KEY": os.getenv("CTS_V2_API_KEY")}, json=body
    )
    print(res.status_code)
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
        print(res.status_code)
        data = res.json()
        trials_continued = data["data"]
        trials += trials_continued
        print("page", (n := n + 1), f"({len(trials)} of {total})")
    return trials


def find_trials():
    stage = st.session_state.stage
    stage_codes = hnc_stage_codes[stage]
    with open(file_dir / "stage_codes.json", "w") as f:
        json.dump(stage_codes, f)
    fetch_state = st.text("Finding trials...")
    trials = _get_ctsapi_hnc_stage_trials(stage_codes)
    fetch_state.text("")
    return trials


if "trial_ids" not in st.session_state:
    st.session_state.trial_ids = []
    st.session_state.trials = []


if cont.button("Find Trials", type="primary"):
    trials = find_trials()
    trial_ids = [trial["nci_id"] for trial in trials]
    st.session_state.trials = trials
    st.session_state.trial_ids = pd.DataFrame(trials, columns=["nci_id", "brief_title"])
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

col1, col2 = st.columns((4, 8))
with col1:
    trial_ids = st.session_state.trial_ids
    st.html(
        f"<div style='text-align:left;'><i>Showing {len(trial_ids)} of {len(trial_ids)} trials</i></div>"
    )
    event = st.dataframe(
        st.session_state.trial_ids,
        hide_index=False,
        use_container_width=False,
        on_select="rerun",
        selection_mode="single-row",
    )
with col2:
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
    st.markdown("##### Diseases")
    st.dataframe(data, use_container_width=True)
