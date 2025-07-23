import streamlit as st
import requests
import pandas as pd
from collections import defaultdict

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


cancergov_used_fields_df = pd.read_csv("fields_used.csv")
suggested_fields_df = pd.read_csv("fields_suggested.csv")
field_sources_df = pd.read_csv("field_sources.csv")
field_sources_df = field_sources_df.set_index(
    pd.RangeIndex(start=1, stop=len(field_sources_df) + 1), drop=True
)
# Drop rows where all specified columns are NaN
field_sources_df = field_sources_df.dropna(
    how="all",
    subset=[
        "Protocol Trials",
        "Imported Trials",
        "All",
        "Protocol Trials.Cancer Centers",
        "Protocol Trials.CTEP and DCP",
        "Protocol Trials.DCP",
        "Protocol Trials.CTEP Rostered; NCORP Studies",
        "Protocol Trials.CTEP Non-rostered",
        "Imported Trials.Cancer Centers",
        "Imported Trials.CCR",
        "Protocol Trials.CTEP and/or DCP",
    ],
)


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
df["nci_internal_source"] = False

st.header("CTS API v2 Trial Fields")
field_filter_a = st.text_input(
    "Search for a field",
    key="field_search_a",
    placeholder="Type to search for a field...",
    width=500,
)
edited = st.data_editor(
    df[df["field"].str.contains(field_filter_a, case=False, na=False, regex=False)],
    use_container_width=True,
    disabled=(
        "field",
        "type",
        "where_used",
        "currently_used_by_cancer.gov",
    ),
)

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
    intersection = currently_used_fields & suggested_fields
    union = currently_used_fields | suggested_fields
    similarity_msg = f"{round(len(intersection) / len(union) * 100)}% of fields currently used by cancer.gov are also suggested for use"
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

st.subheader("Field Sources")
field_filter_b = st.text_input(
    "Search for a field",
    key="field_search_b",
    placeholder="Type to search for a field...",
    width=500,
)
st.dataframe(
    field_sources_df[
        field_sources_df[" Field"].str.contains(
            field_filter_b, case=False, na=False, regex=False
        )
    ]
)

st.markdown("##### Fields documented in API schema but not in field glossary")
st.json(sorted(set(df["field"]).difference(set(field_sources_df[" Field"]))))
st.markdown("##### Fields listed in field glossary but not in API schema")
st.json(sorted(set(field_sources_df[" Field"]).difference(set(df["field"]))))
