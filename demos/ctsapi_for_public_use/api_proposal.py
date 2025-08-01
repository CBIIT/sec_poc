import os
import requests
import streamlit as st

st.set_page_config(layout="wide")

st.header("API Proposal")

study_source = st.selectbox(
    "Study Source",
    options=["Externally Peer Reviewed", "Industrial", "Institutional", "National"],
    width=260,
)
st.markdown("""
> Select a study source which we will treat as a "private" field for search.
""")


@st.cache_data
def query_ctsapi(study_source: str):
    body = {
        "include": [
            "brief_title",
            "current_trial_status",
            "nci_id",
            "nct_id",
            "study_source",
        ],
        "current_trial_status": [
            "Active",
            "Approved",
            "Enrolling by Invitation",
            "In Review",
            "Temporarily Closed to Accrual",
            "Temporarily Closed to Accrual and Intervention",
        ],
        "from": 0,
        "size": 50,
        "study_source": study_source,
    }
    trials_res = requests.post(
        "https://clinicaltrialsapi.cancer.gov/api/v2/trials",
        json=body,
        headers={"X-API-Key": os.environ["CTS_V2_API_KEY"]},
    )
    trials_res.raise_for_status()
    res_json = trials_res.json()
    trials, total = res_json["data"], res_json["total"]
    return trials, total


st.markdown(f"""#### Using query
```javascript
body = {{
    "include": [
        "brief_title",
        "current_trial_status",
        "nci_id",
        "nct_id",
        // study_source is actually included, but we can pretend that it's not.
        // This implementation would need to be handled by the CTS API team.
    ],
    "current_trial_status": [
        "Active",
        "Approved",
        "Enrolling by Invitation",
        "In Review",
        "Temporarily Closed to Accrual",
        "Temporarily Closed to Accrual and Intervention",
    ],
    "from": 0,
    "size": 50,
    "study_source": "{study_source}",
}}
requests.post(
    "https://clinicaltrialsapi.cancer.gov/api/v2/trials",
    json=body,
    headers={{"X-API-Key": "<API_KEY>"}},
)
```
""")

if st.button("Search", disabled=not study_source):
    trials, total = query_ctsapi(study_source)
    st.write(f"Total Trials Found: {total}")
    st.write("Example Response:")
    for trial in trials:
        assert trial["study_source"] == study_source, "Study source mismatch"
    del trial["study_source"]  # Remove study_source for display
    trial["matched_on"] = {"study_source": study_source}
    st.json(trial)
    st.markdown("""
> Note: The `study_source` field is not included in the response because it is treated as a private field for searching only.
""")
