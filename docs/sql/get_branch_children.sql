with branch_children as (
    select
        distinct parent,
        descendant
    from
        ncit_tc
    where
        parent in ('C43431', 'C12218', 'C1908')
)
select
    distinct parent,
    descendant,
    syn_name,
    pref_name,
    (
        position(
            'ctrp intervention terminology' IN lower(concept_in_subset)
        ) > 0
        or position(
            'ctrp agent terminology' IN lower(concept_in_subset)
        ) > 0
    ) :: text as ctrp_disease
from
    branch_children
    join ncit on ncit.code = descendant
    join ncit_syns on ncit_syns.code = descendant;
