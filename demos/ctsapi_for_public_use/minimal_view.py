import os

import pandas as pd
import requests
import streamlit as st
from streamlit_extras.floating_button import floating_button
from streamlit_scroll_to_top import scroll_to_here

from common import (
    display_eligibility_unstructured,
    display_sites,
    display_age,
    display_location_summary,
    display_sex,
)

st.set_page_config(layout="wide")

if "scroll_to_header" not in st.session_state:
    st.session_state.scroll_to_header = False


@st.cache_data
def get_trial_minimal(nct_id: str):
    url = "https://clinicaltrialsapi.cancer.gov/api/v2/trials"
    headers = {"X-API-Key": os.environ["CTS_V2_API_KEY"]}
    params = {
        "nct_id": nct_id,
        "include": [
            "nci_id",
            "nct_id",
            "official_title",
            "current_trial_status",
            "eligibility",
            "sites",
        ],
    }
    response = requests.post(url, headers=headers, json=params)
    response.raise_for_status()
    return response.json()["data"][0]


st.header("Results List")

if (
    st.session_state.get("search_results") is None
    or st.session_state["search_results"].empty
):
    st.write("No results to display.")
    st.page_link(page="current_view.py", label="click here to update your search.")
else:
    selected_row = st.dataframe(
        st.session_state["search_results"],
        on_select="rerun",
        selection_mode="single-row",
        column_order=["nct_id", "nci_id", "brief_title", "current_trial_status"],
        hide_index=True,
    )
    st.markdown("> :material/info: Click on a row to view trial details.")
    if selected_row and selected_row["selection"]["rows"]:
        st.html("""
        <div style="margin-bottom: 1em; border: 1px solid #ccc; padding: 1em; border-radius: 8px; width: fit-content;">
            <h3 style="margin-top: 0; width: fit-content;">Legend</h3>
            <span style="background-color: #fff0ee; padding: 0.5em 1em; border-radius: 6px; margin-right: 1em;">
            <b>Removed</b> from current view's full-trial details
            </span>
            <span style="background-color: #edf9f0; padding: 0.5em 1em; border-radius: 6px;">
            <b>Added</b> to the current view's full-trial details
            </span>
        </div>
        """)
        trial_sel: pd.Series = st.session_state["search_results"].iloc[
            selected_row["selection"]["rows"][0]
        ]
        trial_sel_id = trial_sel["nct_id"]
        trial_minimal = get_trial_minimal(trial_sel_id)

        if st.session_state.scroll_to_header:
            scroll_to_here(0, key="header")
            st.session_state.scroll_to_header = False

        st.subheader("Minimal Trial Details")
        st.markdown(
            "> These are the proposed details to display to the public on cancer.gov's full trial details page. It requests a **subset (10%)** of fields from CTS API and displays **100%** of them."
        )
        st.code(
            f"""
requests.post(
    "https://clinicaltrialsapi.cancer.gov/api/v2/trials",
    json={{
        "nct_id": "{trial_sel_id}",
        "include": [
            "nci_id",
            "nct_id",
            "official_title",
            "current_trial_status",
            "eligibility",
            "sites",
        ],
    }},
    headers={{"X-API-Key": "<API_KEY>"}}
)""",
            language="javascript",
        )
        # st.markdown("##### " + trial_minimal["brief_title"])
        st.error("brief_title")

        st.badge(
            "Status: " + trial_minimal["current_trial_status"],
        )
        st.html(f"""<div style="background-color: #edf9f0; padding: 1em; border-radius: 8px;">
        <b>Age:</b> {display_age(trial_minimal, passthru=True)}<br>
        <b>Sex:</b> {display_sex(trial_minimal, passthru=True)}<br>
        <b>Location:</b> {display_location_summary(trial_minimal, passthru=True)}<br>
    </div>""")
        # with st.expander("Description", expanded=True):
        #     st.write(trial_minimal["brief_summary"])
        st.error("brief_summary")
        with st.expander("Eligibility Criteria", expanded=True):
            display_eligibility_unstructured(trial_minimal)
        with st.expander("Locations & Contacts", expanded=True):
            display_sites(trial_minimal)
        with st.expander("Trial Objectives and Outline", expanded=True):
            # st.write(trial_minimal["detail_description"])
            st.error("detail_description")
        with st.expander("Trial Phase and Type", expanded=True):
            # st.write(
            #     "<b>Trial Phase </b>",
            #     "Phase",
            #     trial_minimal["phase"],
            #     unsafe_allow_html=True,
            # )
            st.error("phase")
            # st.write(
            #     "<b>Trial Type </b>",
            #     trial_minimal["primary_purpose"].capitalize(),
            #     unsafe_allow_html=True,
            # )
            st.error("primary_purpose")
        with st.expander("Lead Organization", expanded=True):
            # st.write(
            #     "<b>Lead Organization: </b>",
            #     trial_minimal["lead_org"],
            #     unsafe_allow_html=True,
            # )
            st.error("lead_org")
            # st.write(
            #     "<b>Principal Investigator: </b>",
            #     trial_minimal["principal_investigator"],
            #     unsafe_allow_html=True,
            # )
            st.error("principal_investigator")
        with st.expander("Trial IDs", expanded=True):
            # st.write(
            #     "<b>Primary ID: </b>",
            #     trial_minimal["protocol_id"],
            #     unsafe_allow_html=True,
            # )
            st.error("protocol_id")
            st.write(
                "<b>Secondary IDs: </b>",
                trial_minimal["nci_id"],
                "<br><b>ClinicalTrials.gov ID: </b>",
                f'<a href="https://clinicaltrials.gov/study/{trial_minimal["nct_id"]}" target="_blank">{trial_minimal["nct_id"]}</a>',
                unsafe_allow_html=True,
            )
        floating_button(
            ":material/arrow_upward: Back to Top",
            on_click=lambda: st.session_state.update(scroll_to_header=True),
        )
