import os
from typing import Literal

import pandas as pd
import requests
import streamlit as st
from data.trial_types_phases import trial_phases_map, trial_types_map
from data.us_states import us_states, us_states_abbreviations
from streamlit_extras.floating_button import floating_button
from streamlit_scroll_to_top import scroll_to_here

st.set_page_config(layout="wide")

col1, col2 = st.columns([1, 2])


@st.cache_data
def get_disease_maintypes():
    url = "https://clinicaltrialsapi.cancer.gov/api/v2/diseases"
    params = {
        "current_trial_status": [
            "Active",
            "Approved",
            "Enrolling by Invitation",
            "In Review",
            "Temporarily Closed to Accrual",
            "Temporarily Closed to Accrual and Intervention",
        ],
        "type": "maintype",
    }
    disease_maintypes_res = requests.get(
        url, params=params, headers={"X-API-Key": os.environ["CTS_V2_API_KEY"]}
    )
    disease_maintypes_res.raise_for_status()
    disease_maintypes = disease_maintypes_res.json()["data"]
    return [(disease["name"], disease["codes"]) for disease in disease_maintypes]


@st.cache_data
def get_disease_decendents(
    maintype_ids: list[str], derivative_type: Literal["subtype", "stage", "finding"]
):
    """Helper function to get disease subtypes for a given maintype."""
    url = "https://clinicaltrialsapi.cancer.gov/api/v2/diseases"
    params = {
        "current_trial_status": [
            "Active",
            "Approved",
            "Enrolling by Invitation",
            "In Review",
            "Temporarily Closed to Accrual",
            "Temporarily Closed to Accrual and Intervention",
        ],
        "type": derivative_type,
    }
    if len(maintype_ids) > 1:
        st.badge(
            "Warning: Multiple maintype IDs provided, using all for subtype search, and 1 for finding search.",
            color="orange",
            icon=":material/warning:",
        )
    if derivative_type == "finding":
        params["maintype"] = maintype_ids[0]  # Only one maintype for findings
    else:
        params["ancestor_ids"] = maintype_ids
    disease_subtypes_res = requests.get(
        url, params=params, headers={"X-API-Key": os.environ["CTS_V2_API_KEY"]}
    )
    disease_subtypes_res.raise_for_status()
    disease_subtypes = disease_subtypes_res.json()["data"]
    return [(disease["name"], disease["codes"]) for disease in disease_subtypes]


@st.cache_data
def get_coordinates(zip_code: str):
    """
    Placeholder function to get latitude and longitude from a zip code.
    Replace this with a real geocoding API if needed.
    """
    coords_res = requests.get(
        f"https://www.cancer.gov/cts_api/zip_code_lookup/{zip_code}"
    )
    coords_res.raise_for_status()
    coords = coords_res.json()
    return coords["lat"], coords["lon"]


def _get_interventions(name: str, category: list[str] = None):
    url = "https://clinicaltrialsapi.cancer.gov/api/v2/interventions"
    params = {
        "category": category,
        "current_trial_status": [
            "Active",
            "Approved",
            "Enrolling by Invitation",
            "In Review",
            "Temporarily Closed to Accrual",
            "Temporarily Closed to Accrual and Intervention",
        ],
        "name": name,
        "order": "desc",
        "size": 10,
        "sort": "count",
    }
    interventions_res = requests.get(
        url, params=params, headers={"X-API-Key": os.environ["CTS_V2_API_KEY"]}
    )
    interventions_res.raise_for_status()
    interventions = interventions_res.json()["data"]
    return [
        (intervention["name"], intervention["codes"]) for intervention in interventions
    ]


@st.cache_data
def get_agents(name: str):
    return _get_interventions(name, category=["Agent", "Agent Category"])


@st.cache_data
def get_other_treatments(name: str):
    return _get_interventions(name, category=["Other"])


@st.cache_data
def get_countries():
    url = "https://clinicaltrialsapi.cancer.gov/api/v2/trials"
    params = {
        "current_trial_status": [
            "Active",
            "Approved",
            "Enrolling by Invitation",
            "In Review",
            "Temporarily Closed to Accrual",
            "Temporarily Closed to Accrual and Intervention",
        ],
        "agg_field": "sites.org_country",
        "include": None,
    }
    countries_res = requests.get(
        url, params=params, headers={"X-API-Key": os.environ["CTS_V2_API_KEY"]}
    )
    countries_res.raise_for_status()
    countries = countries_res.json()["aggregations"]["sites.org_country"]
    return [country["key"] for country in countries]


@st.cache_data
def get_organizations(name: str):
    url = "https://clinicaltrialsapi.cancer.gov/api/v2/organizations"
    params = {
        "current_trial_status": [
            "Active",
            "Approved",
            "Enrolling by Invitation",
            "In Review",
            "Temporarily Closed to Accrual",
            "Temporarily Closed to Accrual and Intervention",
        ],
        "name": name,
        "size": 10,
    }
    organizations_res = requests.get(
        url, params=params, headers={"X-API-Key": os.environ["CTS_V2_API_KEY"]}
    )
    organizations_res.raise_for_status()
    organizations = organizations_res.json()["data"]
    return [organization["name"] for organization in organizations]


@st.cache_data
def get_principal_investigator(name: str):
    url = "https://clinicaltrialsapi.cancer.gov/api/v2/trials"
    params = {
        "current_trial_status": [
            "Active",
            "Approved",
            "Enrolling by Invitation",
            "In Review",
            "Temporarily Closed to Accrual",
            "Temporarily Closed to Accrual and Intervention",
        ],
        "agg_field": "principal_investigator",
        "agg_name": name,
    }
    principal_investigator_res = requests.get(
        url, params=params, headers={"X-API-Key": os.environ["CTS_V2_API_KEY"]}
    )
    principal_investigator_res.raise_for_status()
    principal_investigator = principal_investigator_res.json()["aggregations"][
        "principal_investigator"
    ]
    return [investigator["key"] for investigator in principal_investigator]


@st.cache_data
def get_lead_organizations(name: str):
    url = "https://clinicaltrialsapi.cancer.gov/api/v2/trials"
    params = {
        "current_trial_status": [
            "Active",
            "Approved",
            "Enrolling by Invitation",
            "In Review",
            "Temporarily Closed to Accrual",
            "Temporarily Closed to Accrual and Intervention",
        ],
        "agg_field": "lead_org",
        "agg_field_order": "asc",
        "agg_field_sort": "agg_field",
        "agg_name": name,
        "from": 0,
        "include": None,
        "size": 10,
    }
    lead_org_res = requests.get(
        url, params=params, headers={"X-API-Key": os.environ["CTS_V2_API_KEY"]}
    )
    lead_org_res.raise_for_status()
    lead_orgs = lead_org_res.json()["aggregations"]["lead_org"]
    return [org["key"] for org in lead_orgs]


@st.cache_data
def get_diseases_by_type(codes: list[str]):
    url = "https://clinicaltrialsapi.cancer.gov/api/v2/diseases"
    params = {
        "current_trial_status": [
            "Active",
            "Approved",
            "Enrolling by Invitation",
            "In Review",
            "Temporarily Closed to Accrual",
            "Temporarily Closed to Accrual and Intervention",
        ],
        "type": ["maintype", "subtype", "stage", "finding"],
        "code": codes,
        "size": 100,
    }
    diseases_res = requests.get(
        url, params=params, headers={"X-API-Key": os.environ["CTS_V2_API_KEY"]}
    )
    diseases_res.raise_for_status()
    diseases = diseases_res.json()["data"]
    diseases_by_type = {"maintype": [], "subtype": [], "stage": [], "finding": []}
    for disease in diseases:
        disease_type = disease["type"]
        if "maintype" in disease_type:
            diseases_by_type["maintype"].extend(disease["codes"])
        elif "subtype" in disease_type:
            diseases_by_type["subtype"].extend(disease["codes"])
        elif "stage" in disease_type:
            diseases_by_type["stage"].extend(disease["codes"])
        elif "finding" in disease_type:
            diseases_by_type["finding"].extend(disease["codes"])
    return diseases_by_type


@st.cache_data
def search_trials(
    age: int = None,
    cancer_findings: list[str] = None,
    cancer_stages: list[str] = None,
    cancer_subtypes: list[str] = None,
    cancer_type: list[str] = None,
    city: str = None,
    country: str = None,
    drugs: list[str] = None,
    healthy_volunteers: bool = None,
    institution: str = None,
    investigator: str = None,
    keyword: str = None,
    lead_org: str = None,
    nih_campus: bool = False,
    other_treatments: list[str] = None,
    radius: int = None,
    state: str = None,
    trial_ids: str = None,
    trial_phases: list[str] = None,
    trial_types: list[str] = None,
    va_only: bool = None,
    zip_code: str = None,
    from_: int = 0,
    size: int = 10,
):
    body = {
        "current_trial_status": [
            "Active",
            "Approved",
            "Enrolling by Invitation",
            "In Review",
            "Temporarily Closed to Accrual",
            "Temporarily Closed to Accrual and Intervention",
        ],
        "from": from_,
        "size": size,
    }
    if drugs:
        body["arms.interventions.nci_thesaurus_concept_id"] = drugs
    if other_treatments:
        if drugs:
            body["arms.interventions.nci_thesaurus_concept_id"] += other_treatments
        else:
            body["arms.interventions.nci_thesaurus_concept_id"] = other_treatments
    if healthy_volunteers:
        body["eligibility.structured.accepts_healthy_volunteers"] = True
    if age:
        body["eligibility.structured.max_age_in_years_gte"] = age
        body["eligibility.structured.min_age_in_years_lte"] = age
    if keyword:
        body["keyword"] = keyword
    if lead_org:
        body["lead_org._fulltext"] = lead_org
    if cancer_type:
        diseases_by_type = get_diseases_by_type(cancer_type)
        body["maintype"] = diseases_by_type["maintype"]
        if cancer_subtypes:
            body["subtype"] = diseases_by_type["subtype"]
        if cancer_stages:
            body["stage"] = diseases_by_type["stage"]
        if cancer_findings:
            body["finding"] = diseases_by_type["finding"]
    if investigator:
        body["principal_investigator._fulltext"] = investigator
    if zip_code:
        coords = get_coordinates(zip_code)
        body["sites.org_coordinates_lat"] = coords[0]
        body["sites.org_coordinates_lon"] = coords[1]
        body["sites.org_radius_miles"] = f"{radius}mi"
    elif country:
        body["sites.org_country"] = country
        if state:
            body["sites.org_state_or_province"] = [us_states_abbreviations[state]]
        if city:
            body["sites.org_city"] = city
    elif institution:
        body["sites.org_name._fulltext"] = institution
    elif nih_campus:
        body["sites.org_postal_code"] = "20892"
    if zip_code or country or institution or nih_campus:
        body["sites.recruitment_status"] = [
            "active",
            "approved",
            "enrolling_by_invitation",
            "in_review",
            "temporarily_closed_to_accrual",
        ]
    if va_only:
        body["sites.org_va"] = True
    if trial_ids:
        body["trial_ids"] = [tid.strip() for tid in trial_ids.split(",") if tid.strip()]
    if trial_phases:
        phases = []
        for phase in trial_phases:
            phases.extend(trial_phases_map[phase])
        body["phase"] = phases
    if trial_types:
        body["primary_purpose"] = [
            trial_types_map[trial_type] for trial_type in trial_types
        ]
    print("Debugging search trials", body)
    trials_res = requests.post(
        "https://clinicaltrialsapi.cancer.gov/api/v2/trials",
        json=body,
        headers={"X-API-Key": os.environ["CTS_V2_API_KEY"]},
    )
    trials_res.raise_for_status()
    res_json = trials_res.json()
    trials, total = res_json["data"], res_json["total"]
    if not trials:
        st.warning("No trials found with the specified criteria.")
        return pd.DataFrame(), 0
    return pd.DataFrame(trials), total


with col1:
    st.title("NCI-Supported Clinical Trials Advanced Search")
    st.header("Find NCI-Supported Clinical Trials")
    # 1. Primary Cancer Type/Condition
    cancer_type_sel = st.selectbox(
        "Primary Cancer Type/Condition",
        options=pd.DataFrame(
            cancer_type_options := get_disease_maintypes(),
            columns=["name", "codes"],
        ),
        index=None,
    )
    cancer_type_ids_sel = [
        el[1] for el in cancer_type_options if el[0] == cancer_type_sel
    ]
    cancer_subtype_ids_sel = []
    cancer_stage_ids_sel = []
    cancer_finding_ids_sel = []

    if cancer_type_sel:
        # Get the maintype ID for the selected cancer type
        # Get subtypes and findings for the selected maintype
        cancer_subtype_options = get_disease_decendents(
            cancer_type_ids_sel, derivative_type="subtype"
        )
        cancer_subtypes_sel = st.multiselect(
            "Select Cancer Subtype(s)",
            options=pd.DataFrame(cancer_subtype_options, columns=["name", "codes"]),
        )
        cancer_subtype_ids_sel = [
            el[1] for el in cancer_subtype_options if el[0] in cancer_subtypes_sel
        ]

        cancer_stage_options = get_disease_decendents(
            cancer_type_ids_sel, derivative_type="stage"
        )
        cancer_stages_sel = st.multiselect(
            "Select Cancer Stage(s)",
            options=pd.DataFrame(cancer_stage_options, columns=["name", "codes"]),
        )
        cancer_stage_ids_sel = [
            el[1] for el in cancer_stage_options if el[0] in cancer_stages_sel
        ]

        cancer_finding_options = get_disease_decendents(
            cancer_type_ids_sel, derivative_type="finding"
        )
        cancer_findings_sel = st.multiselect(
            "Select Cancer Finding(s)",
            options=pd.DataFrame(cancer_finding_options, columns=["name", "codes"]),
        )
        cancer_finding_ids_sel = [
            el[1] for el in cancer_finding_options if el[0] in cancer_findings_sel
        ]

    # 2. Age
    age = st.number_input(
        "Age of Participant", value=None, min_value=0, max_value=120, step=1
    )

    # 3. Keywords/Phrases
    keyword = st.text_input(
        "Keywords/Phrases",
    )

    va_only = st.checkbox("Limit results to Veterans Affairs facilities")
    location_type = st.radio(
        "Search by",
        [
            "All Locations",
            "Zip Code",
            "Country/State/City",
        ]
        + (
            [
                "Hospitals/Institutions",
                "At NIH (only show trials at the NIH Clinical Center in Bethesda, MD)",
            ]
            if not va_only
            else []
        ),
    )

    # 4. Location fields (reactive)
    zip_code = country = state = city = institution = radius = nih_campus = None
    if location_type == "Zip Code":
        zip_code = st.text_input("Zip Code")
        radius = st.selectbox(
            "Radius (miles)", options=[20, 50, 100, 200, 500], index=2
        )
    elif location_type == "Country/State/City":
        country = st.selectbox(
            "Country",
            options=get_countries(),
        )
        if country == "United States":
            state = st.selectbox(
                "State",
                options=us_states,
            )
        city = st.text_input("City")
    elif location_type == "Hospitals/Institutions":
        institution_search_text = st.text_input(
            "Institution Search",
        )
        institution_options = []
        if institution_search_text:
            institution_options = get_organizations(institution_search_text)
        institution = st.selectbox(
            "Select Institution",
            options=institution_options,
        )
    elif location_type.startswith("At NIH"):
        nih_campus = True

    # 5. Trial Type
    st.subheader("Trial Type")
    trial_types = st.multiselect(
        "Select trial type(s)",
        [
            "Treatment",
            "Prevention",
            "Supportive Care",
            "Health Services Research",
            "Diagnostic",
            "Screening",
            "Basic Science",
            "Other",
        ],
        default=None,
    )
    healthy_volunteers = st.checkbox(
        "Limit results to trials accepting healthy volunteers"
    )

    # 6. Drug/Treatment
    st.subheader("Drug/Treatment")
    # 6. Drug/Treatment (refactored)
    drug_search_text = st.text_input(
        "Drug/Drug Family Search",
    )
    drugs_options = []
    if drug_search_text:
        drugs_options = [name for name, _ in get_agents(drug_search_text)]
    drugs = st.multiselect(
        "Select Drug(s)/Drug Family(ies)",
        options=drugs_options,
    )
    # 6b. Other Treatments (refactored)
    other_treatment_search_text = st.text_input(
        "Other Treatment Search",
    )
    other_treatments_options = []
    if other_treatment_search_text:
        other_treatments_options = [
            name for name, _ in get_other_treatments(other_treatment_search_text)
        ]
    other_treatments = st.multiselect(
        "Select Other Treatment(s)",
        options=other_treatments_options,
    )

    # 7. Trial Phase
    st.subheader("Trial Phase")
    trial_phases = st.multiselect(
        "Select trial phase(s)",
        ["Phase I", "Phase II", "Phase III", "Phase IV"],
        default=None,
    )

    # 8. Trial ID
    trial_ids = st.text_input("Trial ID(s)", help="Separate multiple IDs with commas.")

    # 9. Trial Investigators
    investigator_search_text = st.text_input("Trial Investigators")
    investigators_options = []
    if investigator_search_text:
        investigators_options = get_principal_investigator(investigator_search_text)
    investigator = st.selectbox(
        "Select Investigator",
        options=investigators_options,
    )

    # 10. Lead Organization
    lead_org_search_text = st.text_input("Lead Organization")
    lead_org_options = []
    if lead_org_search_text:
        lead_org_options = get_lead_organizations(lead_org_search_text)
    lead_org = st.selectbox(
        "Select Lead Organization",
        options=lead_org_options,
    )


with col2:
    st.header("Search Results")
    st.write(
        "This section will display the search results based on the criteria selected in the left column."
    )

    if "scroll_to_header" not in st.session_state:
        st.session_state.scroll_to_header = False

    if "search_results" not in st.session_state:
        st.session_state["search_results"] = None
        st.session_state["search_results_total"] = 0
        st.session_state["search_results_size"] = 10
        st.session_state["search_results_from"] = 0
        st.session_state["page_selector"] = 0
    submit = st.button("Search Trials")

    def update_trial_state():
        st.session_state["search_results_from"] = (
            st.session_state["page_selector"]
            if "page_selector" in st.session_state
            else 0
        ) * st.session_state["search_results_size"]
        trials, total = search_trials(
            age=age,
            cancer_findings=cancer_finding_ids_sel,
            cancer_stages=cancer_stage_ids_sel,
            cancer_subtypes=cancer_subtype_ids_sel,
            cancer_type=cancer_type_ids_sel,
            city=city,
            country=country,
            drugs=drugs,
            healthy_volunteers=healthy_volunteers,
            institution=institution,
            investigator=investigator,
            keyword=keyword,
            lead_org=lead_org,
            nih_campus=nih_campus,
            other_treatments=other_treatments,
            radius=radius,
            state=state,
            trial_ids=trial_ids,
            trial_phases=trial_phases,
            trial_types=trial_types,
            va_only=va_only,
            zip_code=zip_code,
            from_=st.session_state["search_results_from"],
            size=st.session_state["search_results_size"],
        )
        st.session_state["search_results"] = trials
        st.session_state["search_results_total"] = total

    if submit:
        update_trial_state()

    if st.session_state["search_results"] is not None:
        selected_row = st.dataframe(
            st.session_state["search_results"],
            on_select="rerun",
            selection_mode="single-row",
            column_order=["nct_id", "nci_id", "brief_title", "current_trial_status"],
            hide_index=True,
        )
        st.write("Total Trials Found:", st.session_state["search_results_total"])
        selected_page = st.selectbox(
            "Select a page",
            options=range(
                0,
                (
                    st.session_state["search_results_total"]
                    // st.session_state["search_results_size"]
                )
                + 1,
            ),
            index=st.session_state["search_results_from"]
            // st.session_state["search_results_size"],
            key="page_selector",
            on_change=update_trial_state,
            width=120,
        )

        if selected_row and selected_row["selection"]["rows"]:
            trial_sel: pd.Series = st.session_state["search_results"].iloc[
                selected_row["selection"]["rows"][0]
            ]
            st.subheader("Fields to Display")
            if st.session_state.scroll_to_header:
                scroll_to_here(0, key="header")
                st.session_state.scroll_to_header = False
            fields_sel = st.dataframe(
                row_fields := sorted(trial_sel.keys()),
                selection_mode="multi-row",
                on_select="rerun",
            )
            if fields_sel and fields_sel["selection"]["rows"]:
                for field in fields_sel["selection"]["rows"]:
                    st.write(
                        f"<b>{row_fields[field].upper()}:</b>",
                        trial_sel[row_fields[field]],
                        unsafe_allow_html=True,
                        width=120,
                    )
                floating_button(
                    ":material/arrow_upward: Back to Top",
                    on_click=lambda: st.session_state.update(scroll_to_header=True),
                )
