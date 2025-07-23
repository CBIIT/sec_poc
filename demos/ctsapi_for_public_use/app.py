import streamlit as st

pg = st.navigation(
    [
        st.Page("current_view.py"),
        st.Page("minimal_view.py"),
        st.Page("field_exploration.py"),
    ]
)
pg.run()
