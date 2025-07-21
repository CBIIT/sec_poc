import math
import os
from typing import Literal

import pandas as pd
import requests
import streamlit as st
from data.trial_types_phases import trial_phases_map, trial_types_map
from data.us_states import us_states, us_states_abbreviations
from haversine import Unit, haversine
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
        st.warning("Multiple maintype IDs provided, using all.")
    if derivative_type == "finding":
        params["maintype"] = maintype_ids
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
    if coords_res.status_code != 200:
        st.error(
            f"Error fetching coordinates for zip code {zip_code}. Please check the zip code and try again."
        )
    coords_res.raise_for_status()
    coords = coords_res.json()
    return coords["lat"], coords["long"]


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
    names = [intervention["name"] for intervention in interventions]
    codes = [intervention["codes"] for intervention in interventions]
    return {"names": names, "codes": codes}


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
        "include": [
            "nci_id",
            "nct_id",
            "brief_title",
            "sites.org_name",
            "sites.org_postal_code",
            "eligibility.structured",
            "current_trial_status",
            "sites.org_va",
            "sites.org_country",
            "sites.org_state_or_province",
            "sites.org_city",
            "sites.org_coordinates",
            "sites.recruitment_status",
            "diseases",
        ],
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
        codes = cancer_type
        if cancer_subtypes:
            codes.extend(cancer_subtypes)
        if cancer_stages:
            codes.extend(cancer_stages)
        if cancer_findings:
            codes.extend(cancer_findings)
        diseases_by_type = get_diseases_by_type(codes)
        body["maintype"] = diseases_by_type["maintype"]
        if diseases_by_type["subtype"]:
            body["subtype"] = diseases_by_type["subtype"]
        if diseases_by_type["stage"]:
            body["stage"] = diseases_by_type["stage"]
        if diseases_by_type["finding"]:
            body["finding"] = diseases_by_type["finding"]
    if investigator:
        body["principal_investigator._fulltext"] = investigator
    if zip_code:
        coords = get_coordinates(zip_code)
        body["sites.org_coordinates_lat"] = coords[0]
        body["sites.org_coordinates_lon"] = coords[1]
        body["sites.org_coordinates_dist"] = f"{radius}mi"
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
        return pd.DataFrame(), 0, body
    return pd.DataFrame(trials), total, body


@st.cache_data
def get_trial(id_: str):
    """Get full trial details by NCT ID."""
    url = f"https://clinicaltrialsapi.cancer.gov/api/v2/trials/{id_}"
    trial_res = requests.get(url, headers={"X-API-Key": os.environ["CTS_V2_API_KEY"]})
    trial_res.raise_for_status()
    return trial_res.json()


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
    cancer_type_ids_sel = [el for el in cancer_type_options if el[0] == cancer_type_sel]
    if cancer_type_ids_sel:
        cancer_type_ids_sel = cancer_type_ids_sel[0][1]
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
    st.markdown("##### Trial Type")
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
    st.markdown("##### Drug/Treatment")
    # 6. Drug/Treatment (refactored)
    drug_search_text = st.text_input(
        "Drug/Drug Family Search",
    )
    drug_options = {"names": [], "codes": []}
    if drug_search_text:
        drug_options = get_agents(drug_search_text)
    drugs_names_sel = st.multiselect(
        "Select Drug(s)/Drug Family(ies)",
        options=drug_options["names"],
    )
    drugs_codes_sel = []
    if drugs_names_sel:
        # Get the codes for the selected drugs
        for i, drug_name in enumerate(drug_options["names"]):
            if drug_name in drugs_names_sel:
                drugs_codes_sel.extend(drug_options["codes"][i])
    # 6b. Other Treatments (refactored)
    other_treatment_search_text = st.text_input(
        "Other Treatment Search",
    )
    other_treatments_options = {"names": [], "codes": []}
    if other_treatment_search_text:
        other_treatments_options = get_other_treatments(other_treatment_search_text)
    other_treatments_names_sel = st.multiselect(
        "Select Other Treatment(s)",
        options=other_treatments_options["names"],
    )
    other_treatments_codes_sel = []
    if other_treatments_names_sel:
        # Get the codes for the selected other treatments
        for i, other_treatment_name in enumerate(other_treatments_options["names"]):
            if other_treatment_name in other_treatments_names_sel:
                other_treatments_codes_sel.extend(other_treatments_options["codes"][i])

    # 7. Trial Phase
    st.markdown("##### Trial Phase")
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
        st.session_state["page_selector"] = 1
    submit = st.button("Search Trials")

    def update_trial_state():
        st.session_state["search_results_from"] = (
            (st.session_state["page_selector"] - 1)
            * st.session_state["search_results_size"]
            if "page_selector" in st.session_state
            else 0
        )
        trials, total, body = search_trials(
            age=age,
            cancer_findings=cancer_finding_ids_sel,
            cancer_stages=cancer_stage_ids_sel,
            cancer_subtypes=cancer_subtype_ids_sel,
            cancer_type=cancer_type_ids_sel,
            city=city,
            country=country,
            drugs=drugs_codes_sel,
            healthy_volunteers=healthy_volunteers,
            institution=institution,
            investigator=investigator,
            keyword=keyword,
            lead_org=lead_org,
            nih_campus=nih_campus,
            other_treatments=other_treatments_codes_sel,
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
        st.session_state["search_trials_body"] = body

    if submit:
        update_trial_state()

    if st.session_state.get("search_trials_body") is not None:
        st.markdown("###### Request Body")
        st.json(st.session_state["search_trials_body"])

    if st.session_state["search_results"] is not None:
        selected_row = st.dataframe(
            st.session_state["search_results"],
            on_select="rerun",
            selection_mode="single-row",
            column_order=["nct_id", "nci_id", "brief_title", "current_trial_status"],
            hide_index=True,
        )
        st.write("Total Trials Found:", st.session_state["search_results_total"])
        last_page = max(
            1,
            math.ceil(
                st.session_state["search_results_total"]
                / st.session_state["search_results_size"]
            ),
        )
        cur_page = (
            st.session_state["search_results_from"] // 10 + 1
            if st.session_state["search_results_total"]
            else 1
        )
        selected_page = st.number_input(
            f"Page {cur_page} of {last_page}",
            min_value=1,
            max_value=last_page,
            value=cur_page,
            step=1,
            key="page_selector",
            on_change=update_trial_state,
            width=260,
        )

        if selected_row and selected_row["selection"]["rows"]:
            trial_sel: pd.Series = st.session_state["search_results"].iloc[
                selected_row["selection"]["rows"][0]
            ]

            st.subheader("Results List")
            st.markdown(
                "> This is how the results are listed in cancer.gov. *It includes PARTIAL fields*. See the `include` field in the above request."
            )
            st.write(f"<b>{trial_sel['brief_title']}</b>", unsafe_allow_html=True)
            st.write(
                "<b>Status:</b>",
                trial_sel["current_trial_status"],
                unsafe_allow_html=True,
            )
            age_requirement = ""
            if "structured" in trial_sel["eligibility"]:
                structured = trial_sel["eligibility"]["structured"]
                if (
                    structured.get("min_age_in_years") >= 0
                    and structured.get("max_age_in_years") < 999
                ):
                    age_requirement = f"{int(structured['min_age_in_years'])} to {int(structured['max_age_in_years'])} years"
                elif (
                    structured.get("min_age_in_years") >= 0
                    and structured.get("max_age_in_years") >= 999
                ):
                    age_requirement = f"{structured['min_age']} and over"
            st.write(
                "<b>Age:</b>",
                age_requirement.lower(),
                unsafe_allow_html=True,
            )
            sex = ""
            if "structured" in trial_sel["eligibility"]:
                structured = trial_sel["eligibility"]["structured"]
                if structured["sex"] == "ALL" or structured["sex"] == "BOTH":
                    sex = "Male or Female"
                else:
                    sex = structured["sex"].capitalize()
            st.write("<b>Sex: </b>", sex, unsafe_allow_html=True)

            def is_in_radius(query_coords, site_coords, radius):
                haversine_distance_mi = haversine(
                    query_coords,
                    site_coords,
                    unit=Unit.MILES,
                )
                if haversine_distance_mi <= float(radius):
                    return True
                return False

            site_count = 0
            nearby_sites = 0
            for site in trial_sel["sites"]:
                if site["org_country"] != "United States":
                    continue
                if site["recruitment_status"].lower() in [
                    "active",
                    "approved",
                    "enrolling_by_invitation",
                    "in_review",
                    "temporarily_closed_to_accrual",
                ]:
                    site_count += 1
                if (
                    site
                    and site["org_coordinates"]
                    and st.session_state["search_trials_body"].get(
                        "sites.org_coordinates_lat"
                    )
                    and is_in_radius(
                        (
                            st.session_state["search_trials_body"][
                                "sites.org_coordinates_lat"
                            ],
                            st.session_state["search_trials_body"][
                                "sites.org_coordinates_lon"
                            ],
                        ),
                        (
                            site["org_coordinates"]["lat"],
                            site["org_coordinates"]["lon"],
                        ),
                        st.session_state["search_trials_body"][
                            "sites.org_coordinates_dist"
                        ].replace("mi", ""),
                    )
                ):
                    nearby_sites += 1

            location = f"{site_count} sites in the United States that are not closed, completed, or withdrawn"
            if nearby_sites > 0:
                location += f", including {nearby_sites} near you"

            st.write(
                f"<b>Location:</b> {location}",
                unsafe_allow_html=True,
            )

            if st.session_state.scroll_to_header:
                scroll_to_here(0, key="header")
                st.session_state.scroll_to_header = False
            st.divider()
            st.subheader("Full Trial Details")
            st.markdown(
                "> This is how the full trial details are displayed in cancer.gov after a user clicks on a trial's title. *It includes ALL fields.*"
            )
            full_trial = get_trial(trial_sel["nct_id"])
            st.markdown("##### " + full_trial["brief_title"])
            st.badge(
                "Status: " + full_trial["current_trial_status"],
            )
            with st.expander("Description", expanded=True):
                st.write(full_trial["brief_summary"])
            with st.expander("Eligibility Criteria", expanded=True):
                unstructured = (
                    full_trial["eligibility"]["unstructured"]
                    if "unstructured" in full_trial["eligibility"]
                    else []
                )
                if unstructured:
                    if len(unstructured) == 1:
                        st.write(unstructured[0]["description"])
                    else:
                        st.markdown("###### Inclusion Criteria")
                        inclusion_list = [
                            f"<li>{criterion['description']}</li>"
                            for criterion in unstructured
                            if criterion["inclusion_indicator"]
                        ]
                        st.html(
                            "<ul style='margin-left: 1em;'>"
                            + "".join(inclusion_list)
                            + "</ul>"
                        )

                        st.markdown("###### Exclusion Criteria")
                        exclusion_list = [
                            f"<li>{criterion['description']}</li>"
                            for criterion in unstructured
                            if not criterion["inclusion_indicator"]
                        ]
                        st.html(
                            "<ul style='margin-left: 1em;'>"
                            + "".join(exclusion_list)
                            + "</ul>"
                        )
            with st.expander("Locations & Contacts", expanded=True):
                us_sites_by_state = {}
                for site in full_trial["sites"]:
                    if site["org_country"] != "United States":
                        continue
                    if site["recruitment_status"].lower() not in [
                        "active",
                        "approved",
                        "enrolling_by_invitation",
                        "in_review",
                        "temporarily_closed_to_accrual",
                    ]:
                        continue
                    state = site["org_state_or_province"]
                    if state not in us_sites_by_state:
                        us_sites_by_state[state] = []
                    us_sites_by_state[state].append(site)
                st.html("<h2 style='margin: 0;'>United States</h4>")
                for state in sorted(us_sites_by_state.keys()):
                    st.html(f"<h3 style='margin: 0; margin-left: 1em;'>{state}</h5>")
                    by_city = {}
                    for site in us_sites_by_state[state]:
                        city = site["org_city"]
                        if city not in by_city:
                            by_city[city] = []
                        by_city[city].append(site)
                    for city in sorted(by_city.keys()):
                        st.html(f"<h4 style='margin: 0; margin-left: 2em;'>{city}</h4>")
                        for site in by_city[city]:
                            st.html(f"""
                                <div style='margin-left: 3em;'>
                                    <strong>{site["org_name"]}</strong><br>
                                    Status: {site["recruitment_status"].replace("_", " ").capitalize()}<br>
                                    Contact: {site["contact_name"]}<br>
                                    Phone: {site["contact_phone"]}<br>
                                    Email: {site["contact_email"]}<br>
                                </div>
                            """)
            with st.expander("Trial Objectives and Outline", expanded=True):
                st.write(full_trial["detail_description"])
            with st.expander("Trial Phase and Type", expanded=True):
                st.write(
                    "<b>Trial Phase </b>",
                    "Phase",
                    full_trial["phase"],
                    unsafe_allow_html=True,
                )
                st.write(
                    "<b>Trial Type </b>",
                    full_trial["primary_purpose"].capitalize(),
                    unsafe_allow_html=True,
                )
            with st.expander("Lead Organization", expanded=True):
                st.write(
                    "<b>Lead Organization: </b>",
                    full_trial["lead_org"],
                    unsafe_allow_html=True,
                )
                st.write(
                    "<b>Principal Investigator: </b>",
                    full_trial["principal_investigator"],
                    unsafe_allow_html=True,
                )
            with st.expander("Trial IDs", expanded=True):
                st.write(
                    "<b>Primary ID: </b>",
                    full_trial["protocol_id"],
                    unsafe_allow_html=True,
                )
                st.write(
                    "<b>Secondary IDs: </b>",
                    full_trial["nci_id"],
                    "<br><b>ClinicalTrials.gov ID: </b>",
                    f'<a href="https://clinicaltrials.gov/study/{full_trial["nct_id"]}" target="_blank">{full_trial["nct_id"]}</a>',
                    unsafe_allow_html=True,
                )
        floating_button(
            ":material/arrow_upward: Back to Top",
            on_click=lambda: st.session_state.update(scroll_to_header=True),
        )
