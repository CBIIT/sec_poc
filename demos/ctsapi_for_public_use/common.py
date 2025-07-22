import streamlit as st
from haversine import Unit, haversine


def display_eligibility_unstructured(trial):
    unstructured = (
        trial["eligibility"]["unstructured"]
        if "unstructured" in trial["eligibility"]
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
                "<ul style='margin-left: 1em;'>" + "".join(inclusion_list) + "</ul>"
            )

            st.markdown("###### Exclusion Criteria")
            exclusion_list = [
                f"<li>{criterion['description']}</li>"
                for criterion in unstructured
                if not criterion["inclusion_indicator"]
            ]
            st.html(
                "<ul style='margin-left: 1em;'>" + "".join(exclusion_list) + "</ul>"
            )


def display_sites(trial):
    us_sites_by_state = {}
    for site in trial["sites"]:
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


def display_age(trial, passthru=False):
    age_requirement = ""
    if "structured" in trial["eligibility"]:
        structured = trial["eligibility"]["structured"]
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
    if passthru:
        return age_requirement.lower()
    st.write(
        "<b>Age:</b>",
        age_requirement.lower(),
        unsafe_allow_html=True,
    )


def display_sex(trial, passthru=False):
    sex = ""
    if "structured" in trial["eligibility"]:
        structured = trial["eligibility"]["structured"]
        if structured["sex"] == "ALL" or structured["sex"] == "BOTH":
            sex = "Male or Female"
        else:
            sex = structured["sex"].capitalize()
    if passthru:
        return sex
    st.write("<b>Sex: </b>", sex, unsafe_allow_html=True)


def _is_in_radius(query_coords, site_coords, radius):
    haversine_distance_mi = haversine(
        query_coords,
        site_coords,
        unit=Unit.MILES,
    )
    if haversine_distance_mi <= float(radius):
        return True
    return False


def display_location_summary(trial, passthru=False):
    site_count = 0
    nearby_sites = 0
    for site in trial["sites"]:
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
            and st.session_state["search_trials_body"].get("sites.org_coordinates_lat")
            and _is_in_radius(
                (
                    st.session_state["search_trials_body"]["sites.org_coordinates_lat"],
                    st.session_state["search_trials_body"]["sites.org_coordinates_lon"],
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
    if passthru:
        return location
    st.write(
        f"<b>Location:</b> {location}",
        unsafe_allow_html=True,
    )
