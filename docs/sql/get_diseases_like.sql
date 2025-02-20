with poss_diseases as (
    select
        distinct original_child
    from
        disease_tree
    where
        child = :disease
),
ctrp_display_likes as (
    select
        case
            when position('  ' in pd.original_child) > 0 then replace(pd.original_child, '  ', '%')
            when right(pd.original_child, 1) = ' ' then substr(
                pd.original_child,
                1,
                length(pd.original_child) -1
            ) || '%'
            else pd.original_child
        end like_string
    from
        poss_diseases pd
)
select
    dtd.nci_thesaurus_concept_id as "Code",
    'YES' as "Value",
    dtd.preferred_name as "Diseases"
from
    distinct_trial_diseases dtd
    join ctrp_display_likes c on dtd.display_name like c.like_string;
