# %%
import json
import os
import random
import re

import pandas as pd
import requests
import streamlit as st
from common import get_project_file

st.set_page_config(layout="wide")

status_map = {
    "RECRUITING": "ACTIVE",
    "SUSPENDED": "TEMPORARILY_CLOSED_TO_ACCRUAL",
    "ACTIVE_NOT_RECRUITING": "CLOSED_TO_ACCRUAL",
    "ACTIVE": "ACTIVE",
}


@st.cache_data
def get_from_ctgov(study: str, fields: str = "ContactsLocationsModule"):
    url = (
        f"https://clinicaltrials.gov/api/v2/studies/{study}?format=json&fields={fields}"
    )
    response = requests.get(url)
    response.raise_for_status()
    return response.json()


@st.cache_data
def get_from_ctsapi(study: str, **kwargs):
    params = {
        "nct_id": study,
        "include": ["nct_id", "sites"],
        "current_trial_status": [
            "Active",
            "Approved",
            "Enrolling by Invitation",
            "Temporarily Closed to Accrual",
            "Temporarily Closed to Accrual and Intervention",
        ],
        "from": 0,
        "size": 1,
        **kwargs,
    }
    response = requests.post(
        "https://clinicaltrialsapi.cancer.gov/api/v2/trials",
        json=params,
        headers={
            "X-API-Key": os.environ["CTS_V2_API_KEY"],
        },
    )
    response.raise_for_status()
    return response.json()


@st.cache_data
def get_ctsapi_trial_ids():
    data = get_from_ctsapi(
        study=None,
        include=["nct_id", "record_verification_date"],
        size=50,
    )["data"]
    return [(trial["nct_id"], trial["record_verification_date"]) for trial in data]


random.seed(42)
if "trial_ids" not in st.session_state:
    trial_ids = get_ctsapi_trial_ids()
    suggest_trial_ids = []
    for _ in range(10):
        i = random.randint(0, len(trial_ids) - 1)
        suggest_trial_ids.append(trial_ids[i])
        del trial_ids[i]
    st.session_state["trial_ids"] = suggest_trial_ids

nct_id = st.selectbox(
    "Enter NCT ID",
    options=sorted(st.session_state["trial_ids"], key=lambda x: x[1]),
    help="Listing shows randomized trials from CTS API with their last record verification date.",
    width=300,
    index=None,
    accept_new_options=True,
    key="nct_id_selectbox",
)

tab_fields, tab_sites, tab_eligibility = st.tabs(
    ["Fields", "Sites", "Eligibility Criteria"]
)

with tab_fields:
    with open(get_project_file("ctg_study.json")) as fp:
        ctg_fields_json = json.load(fp)

    with open(get_project_file("ctsapi_study.json")) as fp:
        ctsapi_fields_json = json.load(fp)

    suggested_fields = (
        pd.read_excel(get_project_file("field_mapping.xlsx"))[
            ["ctg_field", "ctsapi_field", "notes"]
        ]
        .rename(columns={"notes": "generated notes"})
        .dropna(how="all")
        .reset_index(drop=True)
    )

    def explore_ctgov_fields(obj, prefix=""):
        fields = []
        if obj["type"] == "object":
            for key, value in obj["properties"].items():
                fields.extend(
                    explore_ctgov_fields(
                        value, prefix + key + ("." if value["type"] == "object" else "")
                    )
                )
        elif obj["type"] == "array":
            array_type = obj["items"]
            fields.extend(
                explore_ctgov_fields(
                    array_type, prefix + ("." if array_type["type"] == "object" else "")
                )
            )
        else:
            d = {"field": prefix, "type": obj["type"]}
            if "enum" in obj:
                d["enum"] = obj["enum"]
            fields.append(d)
        return fields

    col1, col2 = tab_fields.columns(2, gap="large")

    with col1:
        col1.markdown("### ClinicalTrials.gov Fields")
        st.dataframe(explore_ctgov_fields(ctg_fields_json), hide_index=False)
    with col2:
        col2.markdown("### CTS API Fields")
        df_ctsapi_fields = pd.DataFrame.from_dict(ctsapi_fields_json, orient="index")
        df_ctsapi_fields["field"] = df_ctsapi_fields.index
        df_ctsapi_fields = df_ctsapi_fields.reset_index(drop=True)
        df_ctsapi_fields = df_ctsapi_fields[["field", "type", "enum"]]
        st.dataframe(df_ctsapi_fields, hide_index=False)
    tab_fields.markdown("#### Predicted Pairings")
    tab_fields.dataframe(suggested_fields)

with tab_sites:
    if nct_id:
        jdata = get_from_ctgov(nct_id[0])
        df_ctgov = pd.json_normalize(
            jdata,
            record_path=["protocolSection", "contactsLocationsModule", "locations"],
        ).sort_values(by=["facility"], ignore_index=True)
        df_ctgov["contacts"] = df_ctgov["contacts"].astype(str)
        df_ctgov = df_ctgov[
            [
                "facility",
                "status",
            ]
        ]

        jdata = get_from_ctsapi(nct_id[0])
        df_ctsapi = pd.json_normalize(
            jdata,
            record_path=["data", "sites"],
        ).sort_values(by=["org_name"], ignore_index=True)
        org_name_misspellings = df_ctsapi["org_name"].apply(
            lambda x: bool(re.search(r"\s{2,}", x))
        )
        df_ctsapi["org_name"] = df_ctsapi["org_name"].apply(
            lambda x: re.sub(r"\s{2,}", " ", x)
        )
        df_ctsapi = df_ctsapi[
            [
                "org_name",
                "recruitment_status",
            ]
        ]

        col1, col2 = tab_sites.columns(2, gap="large")
        with col1:
            col1.subheader("ClinicalTrials.gov Sites")
            col1.dataframe(df_ctgov)

        with col2:
            col2.subheader("CTS API Sites")
            col2.dataframe(df_ctsapi)

        df_compare = pd.merge(
            left=df_ctgov,
            right=df_ctsapi,
            how="right",
            left_on="facility",
            right_on="org_name",
            suffixes=("_ctgov", "_ctsapi"),
        )
        df_compare = df_compare[["org_name", "recruitment_status", "status"]]
        df_compare["status"] = df_compare["status"].apply(status_map.get)
        df_compare = df_compare[
            df_compare["status"] != df_compare["recruitment_status"]
        ]
        df_compare = df_compare.rename(
            columns={
                "org_name": "CTS API Site Name",
                "status": "ClinicalTrials.gov Status",
                "recruitment_status": "CTS API Status",
            }
        )
        df_compare = df_compare.sort_values(by=["CTS API Site Name"], ignore_index=True)

        st.markdown("#### Mismatched Sites")
        st.dataframe(df_compare)
        st.markdown(
            f"> Joined on CTS API data. Corrected {org_name_misspellings.sum()} CTS API `org_name's` with multiple spaces."
        )
    else:
        st.markdown(
            "Please select an NCT ID from the dropdown to compare sites between ClinicalTrials.gov and CTS API."
        )

with tab_eligibility:
    if nct_id:
        ctsapi_eligibility = get_from_ctsapi(nct_id[0], include=["eligibility"])
        ctgov_eligibility = get_from_ctgov(nct_id[0], fields="EligibilityModule")
        ctsapi_lines = []
        ctgov_lines = []
        ctgov_map = {}
        ctsapi_map = {}

        for row in ctsapi_eligibility["data"][0]["eligibility"]["unstructured"]:
            for line in row["description"].split("\n"):
                if line.strip():
                    key = re.sub(r"[^\w]", "", line).strip().lower()
                    ctsapi_map[key] = line
                    ctsapi_lines.append(key)
        for line in ctgov_eligibility["protocolSection"]["eligibilityModule"][
            "eligibilityCriteria"
        ].split("\n"):
            if line.strip():
                key = re.sub(r"[^\w]", "", line).strip().lower()
                ctgov_map[key] = line
                ctgov_lines.append(key)

        df_compare_elig = pd.merge(
            left=pd.DataFrame(ctgov_lines, columns=["ctgov_eligibility"]),
            right=pd.DataFrame(ctsapi_lines, columns=["ctsapi_eligibility"]),
            how="right",
            left_on="ctgov_eligibility",
            right_on="ctsapi_eligibility",
        )
        df_compare_elig = df_compare_elig[
            df_compare_elig["ctgov_eligibility"]
            != df_compare_elig["ctsapi_eligibility"]
        ].reset_index(drop=True)

        df_ctgov_lines = pd.DataFrame(ctgov_lines, columns=["ctgov_eligibility"])
        df_ctgov_lines["ctgov_eligibility"] = df_ctgov_lines["ctgov_eligibility"].apply(
            lambda x: ctgov_map.get(x, x)
        )

        st.markdown("### ClinicalTrials.gov Eligibility Criteria")
        st.dataframe(df_ctgov_lines)

        df_compare_elig["ctsapi_eligibility"] = df_compare_elig[
            "ctsapi_eligibility"
        ].apply(lambda x: ctsapi_map.get(x, x))
        st.markdown("#### Mismatched Eligibility Criteria")
        st.dataframe(
            df_compare_elig, column_order=["ctsapi_eligibility", "ctgov_eligibility"]
        )
        st.markdown(
            "> Joined on CTS API data by splitting newlines, removing punctuation, and lowercasing the text."
        )
    else:
        st.markdown(
            "Please select an NCT ID from the dropdown to compare sites between ClinicalTrials.gov and CTS API."
        )
