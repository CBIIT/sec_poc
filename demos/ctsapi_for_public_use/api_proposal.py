import os

import requests
import streamlit as st

st.set_page_config(layout="wide")

st.header("API Proposal")


@st.cache_data
def query_ctsapi_hacker(**kwargs):
    body = {
        "include": [
            "nct_id",
        ],
        "from": 0,
        "size": 1,
        **kwargs,
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


st.markdown("## 1. Searchable fields should not [cannot] be private")
st.markdown(
    'If fields are private and searchable, there\'s an inherent problem with that. One could ask a probing question: "Does X=Y data exist in the system?" If the query for X=Y returns results, regardless of the structure of that data, the answer is known, at least in part. Take for example the hacker\'s query below. Let\'s say that any trial with `current_trial_status="Approved"` is now considered private information. If a hacker uses that query, any results that come back are positive hits for their probing question, regardless of the data that is returned. This could lead to potential exposure of private information.',
)

st.markdown("""### Hacker's query
```javascript
body = {
    "include": [
        "nct_id" // <- The structure of the data returned is not essential for leaking private information
                 //    as long as there is at least one identifying field
    ],
    "current_trial_status": "Approved", // <- This is our new "private" key=value pair
    "from": 0,
    "size": 1,
}
requests.post(
    "https://clinicaltrialsapi.cancer.gov/api/v2/trials",
    json=body,
    headers={"X-API-Key": "<API_KEY>"},
)
```
""")
btn1 = st.button(
    "Hacker Search for Approved Trials",
)
if "approved_trials_search" not in st.session_state:
    st.session_state["approved_trials_search"] = False
if btn1 or st.session_state["approved_trials_search"]:
    trials, total = query_ctsapi_hacker(current_trial_status="Approved")
    st.session_state["approved_trials_search"] = True
    st.write("Total Trials Found:", total)
    st.write("Example Response:")
    if trials:
        st.json(trials[-1])
        st.warning(
            f'Even though the `current_trial_status` field is not included in the response, it was used to probe for private data. The results here tell us that there are {total} trials with `current_trial_status="Approved"`.',
            icon=":material/warning:",
            width=750,
        )

st.markdown("""### Taking it a step further
Let's use a hypothetical example where a participating site's person of contact is repeatedly pestered by spam calls, and so, the API maintainers have decided to make the `sites.contact_email` field private but searchable. A hacker could then construct a query body like this:""")
email = st.text_input("Email address", width=500)
st.markdown(f"""
```javascript
body = {{
    "include": [
        "nct_id"
    ],
    "sites.contact_email": "{email}",
    "from": 0,
    "size": 1,
}}
```
            """)

btn2 = st.button("Hacker Search for Email", disabled=not email)
if "email_search" not in st.session_state:
    st.session_state["email_search"] = False
if btn2 or st.session_state["email_search"]:
    trials, total = query_ctsapi_hacker(**{"sites.contact_email": email})
    st.session_state["email_search"] = True
    st.write("Total Trials Found:", total)
    st.write("Example Response:")
    if trials:
        st.json(trials[-1])
        st.warning(
            f'Even though the `sites.contact_email` field is not included in the response, it was used to probe for private data. The results here tell us that there are {total} trials with `sites.contact_email="{email}"`. So if the hacker was looking for a specific email address, they now know that it exists in the system.',
            icon=":material/warning:",
            width=750,
        )

st.markdown("## 2. Private fields should be removed altogether")
st.markdown("""
This is the approach used by the CTS API for trial/site statuses = "In Review." The private data is deleted directly from the database, so there will never be results returned for queries that include private fields. This is the most secure way to handle private data because it ensures that no information can be leaked/inferred through the API.

If private data is to be made searchable, it should be done through an authorization layer using a provider like Auth0 or Okta. This way, the data is only exposed through the API for authorized users. It would require replicating the database and retaining the private data in this new database for authorized queries only.
            """)
