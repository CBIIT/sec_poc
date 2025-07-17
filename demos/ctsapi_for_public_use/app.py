import streamlit as st

pg = st.navigation([st.Page("full_view.py"), st.Page("pared_view.py")])
pg.run()
