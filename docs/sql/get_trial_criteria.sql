with site_counts as (
    select
        count(nct_id) as number_sites,
        nct_id
    from
        trial_sites
    where
        org_status = 'ACTIVE'
    group by
        nct_id
)
select
    '<a href=https://www.cancer.gov/about-cancer/treatment/clinical-trials/search/v?id=' || t.nct_id || '&r=1 target=\"_blank\">' || t.nct_id || '</a>' as nct_id,
    -- clean_nct_id is assumed for any nct_id in the trials table
    t.nct_id as clean_nct_id,
    age_expression,
    disease_names,
    diseases,
    gender,
    gender_expression,
    max_age_in_years,
    min_age_in_years,
    disease_names_lead,
    diseases_lead,
    biomarker_exc_codes,
    biomarker_exc_names,
    biomarker_inc_codes,
    biomarker_inc_names,
    brief_title,
    phase,
    study_source,
    case
        study_source
        when 'National' then 1
        when 'Institutional' then 2
        when 'Externally Peer Reviewed' then 3
        when 'Industrial' then 4
    end study_source_sort_key,
    sc.number_sites
from
    trials t
    join site_counts sc on t.nct_id = sc.nct_id
