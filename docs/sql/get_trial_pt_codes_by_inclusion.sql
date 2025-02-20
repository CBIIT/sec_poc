select
    nct_id,
    string_agg(nci_thesaurus_concept_id, ',') as pt_api_inc_codes
from
    trial_prior_therapies
where
    eligibility_criterion = 'inclusion'
    and inclusion_indicator = 'TRIAL'
group by
    nct_id;

select
    nct_id,
    string_agg(nci_thesaurus_concept_id, ',') as pt_api_exc_codes
from
    trial_prior_therapies
where
    eligibility_criterion = 'exclusion'
    and inclusion_indicator = 'TRIAL'
group by
    nct_id;
