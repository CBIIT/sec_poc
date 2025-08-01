import streamlit as st
import requests
import pandas as pd
import os

st.set_page_config(layout="wide")


@st.cache_data
def get_trial_doc():
    url = "https://clinicaltrialsapi.cancer.gov/api/v2/docs/trial.json"
    response = requests.get(url)
    response.raise_for_status()
    return response.json()


trial_doc = get_trial_doc()


def flatten_dict(d, parent_key="", sep="."):
    items = []
    for k, v in d.items():
        new_key = f"{parent_key}{sep}{k}" if parent_key else k
        if isinstance(v, dict) and isinstance(v.get("properties"), dict):
            items.extend(flatten_dict(v["properties"], new_key, sep=sep))
        else:
            if "fields" in v:
                del v["fields"]
            items.append({"field": new_key, **v})
    return items


cwd = os.getcwd()
if "demos" in cwd and "ctsapi_for_public_use" in cwd:
    path = "."
else:
    path = os.path.join("demos", "ctsapi_for_public_use")
cancergov_used_fields_df = pd.read_csv(os.path.join(path, "fields_used.csv"))
suggested_fields_df = pd.read_csv(os.path.join(path, "fields_suggested.csv"))
field_sources_df = pd.read_csv(os.path.join(path, "field_sources.csv"))
field_sources_df = field_sources_df.set_index("Field", drop=True)
field_sources_df = field_sources_df.dropna(how="all")


# Create a hierarchical (MultiIndex) columns DataFrame
def make_multiindex_columns(df):
    new_cols = []
    for col in df.columns:
        if "." in col:
            group, sub = col.split(".", 1)
            new_cols.append((group, sub))
        else:
            new_cols.append((col, ""))
    df.columns = pd.MultiIndex.from_tuples(new_cols)
    return df


field_sources_df = make_multiindex_columns(field_sources_df)
field_sources_df.sort_index(axis=1, inplace=True)

flat_data = flatten_dict(trial_doc)
df = pd.DataFrame(flat_data)
df = df.merge(cancergov_used_fields_df, on="field", how="left", right_index=False)
df = df.merge(suggested_fields_df, on="field", how="left", right_index=False)
df = df.set_index(pd.RangeIndex(start=1, stop=len(df) + 1), drop=True)
df["nci_internal_source"] = ""

st.subheader("CTS API v2 Trial Fields (from /docs trial.json)")
field_filter_a = st.text_input(
    "Search for a field",
    key="field_search_a",
    placeholder="Type to search for a field...",
    width=500,
)
filtered_fields = df[
    df["field"].str.contains(field_filter_a, case=False, na=False, regex=False)
]
edited = st.data_editor(
    filtered_fields,
    use_container_width=True,
    disabled=(
        "field",
        "type",
        "where_used",
        "currently_used_by_cancer.gov",
    ),
)
st.html(f"<sub>showing {len(filtered_fields)} of {len(df)} fields</sub>")

st.markdown(
    f"> ~{round(df['currently_used_by_cancer.gov'].sum() / len(df) * 100)}%* of the fields requested by cancer.gov are used on the site."
)
st.markdown(
    "<sub>*The fields used by cancer.gov (or not) may not be exact. This information was collected from minified code on the website and is a best-guess based on what is visible to the user.</sub>",
    unsafe_allow_html=True,
)

if edited is not None:
    currently_used_fields = set(edited[edited["currently_used_by_cancer.gov"]]["field"])
    suggested_fields = set(edited[edited["suggested_fields"]]["field"])
    diff_current = currently_used_fields - suggested_fields
    diff_suggested = suggested_fields - currently_used_fields
    comparison_table = pd.DataFrame()
    if diff_current:
        comparison_table["Used but not suggested"] = list(diff_current) + [None] * (
            len(diff_suggested) - len(diff_current)
        )
    if diff_suggested:
        comparison_table["Suggested but not used"] = list(diff_suggested) + [None] * (
            len(diff_current) - len(diff_suggested)
        )

    st.subheader("Suggested Differences from Current Use on Cancer.gov")
    st.dataframe(comparison_table, hide_index=True)

st.subheader("Field Sources (from glossary)")
field_filter_b = st.text_input(
    "Search for a field",
    key="field_search_b",
    placeholder="Type to search for a field...",
    width=500,
)

filtered_field_sources = field_sources_df[
    field_sources_df.index.to_series().str.contains(
        field_filter_b, case=False, na=False, regex=False
    )
]
st.dataframe(filtered_field_sources)
st.html(
    f"<sub>showing {len(filtered_field_sources)} of {len(field_sources_df)} fields</sub>"
)

with st.expander("Field Definitions and Debugging Information", expanded=False):
    st.markdown("##### Field Glossary")

    glossary_html = """
    <dl>
        <dt>NCI</dt>
        <dd>
            National Cancer Institute
            <dl>
                <dt>CCCT</dt>
                <dd>
                    Coordinating Center for Clinical Trials (CCCT)
                    <dl>
                        <dt>CTRP</dt>
                        <dd>Clinical Trials Reporting Program (CTRP)</dd>
                        <dt>CTRO</dt>
                        <dd>Clinical Trials Reporting Office (CTRO)</dd>
                    </dl>
                </dd>
                <dt>CCR</dt>
                <dd>Center for Cancer Research (CCR)</dd>
                <dt>CTSU</dt>
                <dd>Clinical Trials Support Unit (CTSU)</dd>
                <dt>DCTD</dt>
                <dd>
                    Division of Cancer Treatment and Diagnosis (DCTD)
                    <dl>
                        <dt>CTEP</dt>
                        <dd>Cancer Therapy Evaluation Program (CTEP)</dd>
                    </dl>
                </dd>
                <dt>DCP</dt>
                <dd>
                    Division of Cancer Prevention (DCP)
                    <dl>
                        <dt>PIO</dt>
                        <dd>Protocol Information Office (PIO)</dd>
                    </dl>
                </dd>
                <dt>EVS</dt>
                <dd>Enterprise Vocabulary Services (EVS)</dd>
                <dt>NCI Designated Cancer Centers</dt>
                <dd>There are 73 NCI-Designated Cancer Centers, located in 37 states and the District of Columbia, that are funded by NCI to deliver cutting-edge cancer treatments to patients. <a href="https://www.cancer.gov/research/infrastructure/cancer-centers" target="_blank">source</a></dd>
            </dl>
        </dd>
        <dt>"The Lead Organization"</dt>
        <dd></dd>
    </dl>
    """

    st.html(glossary_html)

    # These were confirmed by Mike to be intentionally left out of the field glossary
    excludes = set(
        [
            "_current_trial_status_sort_order",
            "_primary_purpose_sort_order",
            "_phase_sort_order",
            "_current_trial_status_sort_order",
            "_study_protocol_type_sort_order",
            "active_sites_count",
            "classification_code",
        ]
    )
    api_fields = set(df["field"]) - excludes
    glossary_fields = set(field_sources_df.index)
    st.markdown("##### Fields documented in API schema but not in field glossary")
    st.json(sorted(api_fields.difference(glossary_fields)))
    st.markdown("##### Fields listed in field glossary but not in API schema")
    st.json(sorted(glossary_fields.difference(api_fields)))
