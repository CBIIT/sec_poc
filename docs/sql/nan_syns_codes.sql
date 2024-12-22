with bad_syns_codes as (
    select
        distinct code
    from
        ncit_syns
    where
        l_syn_name ilike 'none'
        or l_syn_name ilike 'na'
        or l_syn_name ilike 'nan'
)
select
    parent,
    descendant
from
    ncit_tc tc
    join bad_syns_codes bc on tc.descendant = bc.code
    and tc.parent in ('C43431', 'C12218', 'C1908') -- prior_therapy set
;
