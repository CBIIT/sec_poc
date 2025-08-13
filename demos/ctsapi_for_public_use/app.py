import streamlit as st

pg = st.navigation(
    [
        st.Page("current_view.py"),
        st.Page("minimal_view.py"),
        st.Page("field_exploration.py"),
        st.Page("api_proposal.py"),
        st.Page("compare_sites.py", title="compare CTG and CTS API"),
    ]
)
pg.run()
