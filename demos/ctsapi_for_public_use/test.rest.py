# %%
import os

import requests


def get_all_trials(from_=0, results=[]):
    response = requests.post(
        "https://clinicaltrialsapi.cancer.gov/api/v2/trials",
        headers={"x-api-key": os.getenv("CTS_V2_API_KEY")},
        json={
            "include": [
                # "lead_org",
                # "current_trial_status",
                # "current_trial_status_date",
                # "ccr_id",
                # "nct_id",
                # "protocol_id",
                "study_source",
                # "nci_funded",
                # "ctep_id",
            ],
            # "lead_org._raw": "National Cancer Institute",
            # "lead_org._raw": "NCI - Center for Cancer Research",
            # "nci_funded_not": "Direct",
            # "study_source_not": "Institutional",
            # "missing_not": ["ctep_id"],
            # "nci_funded": "Direct",
            # "study_source": "National",
            # "outer_or_lead_org._fulltext": "NCI",
            "current_trial_status": [
                "Active",
                "Approved",
                "Enrolling by Invitation",
                "In Review",
                "Temporarily Closed to Accrual",
                "Temporarily Closed to Accrual and Intervention",
            ],
            "from": from_,
            "size": (size := 50),
        },
    )
    response.raise_for_status()
    response_json = response.json()
    data, total = response_json["data"], response_json["total"]

    results.extend(data)

    if len(results) < total:
        print(f"Fetched {len(results)} trials so far, total: {total}")
        return get_all_trials(from_=from_ + size, results=results)

    return results


all_trials = get_all_trials()
# lead_orgs = set([trial["lead_org"] for trial in all_trials])
# lead_orgs
study_source = set([trial["study_source"] for trial in all_trials])
study_source
