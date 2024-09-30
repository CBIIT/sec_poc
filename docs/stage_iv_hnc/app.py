import json
import os
import re
import subprocess
import tempfile
from collections import defaultdict
from pathlib import Path
import concurrent.futures

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
    url = "https://clinicaltrialsapi.cancer.gov/api/v2/diseases?ancestor_ids=C35850&current_trial_status=Active&current_trial_status=Approved&current_trial_status=Enrolling%20by%20Invitation&current_trial_status=In%20Review&current_trial_status=Temporarily%20Closed%20to%20Accrual&current_trial_status=Temporarily%20Closed%20to%20Accrual%20and%20Intervention&type=stage"
    res = requests.get(url, headers={"X-API-KEY": os.getenv("CTS_V2_API_KEY")})
    print(res.status_code, "/api/v2/diseases")
    data = res.json()
    assert data["total"] == len(data["data"])
    print("TOTAL:", data["total"])
    return data["data"]


st.markdown("## Step 1: Get HNC Stages List")
st.markdown(
    """```py
def load_hnc_stages():
    url = "https://clinicaltrialsapi.cancer.gov/api/v2/diseases?ancestor_ids=C35850&current_trial_status=Active&current_trial_status=Approved&current_trial_status=Enrolling%20by%20Invitation&current_trial_status=In%20Review&current_trial_status=Temporarily%20Closed%20to%20Accrual&current_trial_status=Temporarily%20Closed%20to%20Accrual%20and%20Intervention&type=stage"
    res = requests.get(url, headers={"X-API-KEY": os.getenv("CTS_V2_API_KEY")})
    print(res.status_code, "/api/v2/diseases")
    data = res.json()
    assert data["total"] == len(data["data"])
    print("TOTAL:", data["total"])
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
cola, colb = st.columns((6, 6))
with cola:
    st.subheader("Current List")
with colb:
    st.subheader("Static List")
for cat in HNC_CATEGORIES:
    tmp = tempfile.gettempdir()
    df = pd.DataFrame(hnc_stage_categories[cat], columns=["name"])
    df.sort_values(["name"], inplace=True)
    df.to_csv(Path(tmp) / "df1.csv", index=False)

    dfother = pd.read_json(file_dir / "stage_iv_categories" / (cat + ".json"))
    dfother.columns = ["name"]
    dfother.sort_values(["name"], inplace=True)
    dfother.to_csv(Path(tmp) / "df2.csv", index=False)

    outfile = (Path(tmp) / "df.csv.diff").resolve()
    with open(outfile, "w") as fout:
        subprocess.call(
            [
                "diff",
                "-y",
                (Path(tmp) / "df1.csv").resolve(),
                (Path(tmp) / "df2.csv").resolve(),
            ],
            stdout=fout,
        )
    with open((Path(tmp) / "df.csv.diff").resolve()) as f:
        diff = f.read()
        st.markdown(
            f"""```diff
{diff}
```""",
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

col1, col2 = st.columns((6, 6))
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
    st.markdown("##### Relevant Diseases")
    st.dataframe(data, use_container_width=True)

st.markdown("## Verification")


@st.cache_data
def _get_ctsapi_disease_code_trials(code: str):
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


if "stage" in st.session_state:
    codes = hnc_stage_codes[st.session_state.stage]
    jobs = []
    all_trials = set()
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        for code in codes:
            job = executor.submit(_get_ctsapi_disease_code_trials, code)
            jobs.append(job)

        for future in concurrent.futures.as_completed(jobs):
            try:
                data = future.result()
            except Exception as exc:
                print("%r generated an exception: %s" % (code, exc))
            else:
                all_trials.update([t["nci_id"] for t in data])

    if len(all_trials):
        st.write("FOUND:", len(all_trials))
