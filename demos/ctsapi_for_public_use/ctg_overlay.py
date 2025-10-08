import ast
import os
import requests
import streamlit as st

from common import remove_tree_terms

st.subheader("Overlay CTS API data on ClinicalTrials.gov")


@st.cache_data
def get_trial(query: str):
    trials_res = requests.post(
        "https://clinicaltrialsapi.cancer.gov/api/v2/trials",
        json=ast.literal_eval(query),
        headers={"X-API-Key": os.environ["CTS_V2_API_KEY"]},
    )
    trials_res.raise_for_status()
    return trials_res.json()["data"][0]


st.markdown("### Trial Finder")
query = st.text_area(
    "Enter a search term to find trials",
    value="""{
    "include": [
        "current_trial_status",
        "brief_title",
        "nct_id",
        "lead_org",
        "record_verification_date",
        "brief_summary",
        "detail_description",
        "official_title",
        "diseases.inclusion_indicator",
        "diseases.name",
        "diseases.nci_thesaurus_concept_id",
        "keywords",
        "arms",
        "other_ids",
        "central_contact",
        "sites.org_postal_code",
        "sites.recruitment_status",
        "sites.org_state_or_province",
        "sites.org_coordinates",
        "sites.org_coordinates",
        "sites.org_name",
        "sites.org_country",
        "sites.contact_phone",
        "sites.contact_name",
        "sites.contact_email",
        "sites.org_city",
        "eligibility.unstructured.description",
        "primary_purpose",
        "masking.allocation_code",
        "interventional_model",
        "masking.masking"
        "principal_investigator"
        "amendment_date",
        "current_trial_status_date",
        "start_date",
        "start_date_type_code",
        "completion_date",
        "completion_date_type_code"
    ],
    "from": 0,
    "size": 1,
}
""",
    key="search_term",
    help="Type a search term to find trials related to that condition or topic.",
    height=1000,
)

if st.button("Search Trials"):
    st.markdown("### Results")
    response = get_trial(query)
    response = remove_tree_terms(response)
    st.json(response)
