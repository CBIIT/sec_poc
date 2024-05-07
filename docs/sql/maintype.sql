-- Finds the shortest path from the starting code to its nearest maintype ancestor
with minlevel as (
    select
        min(level) as min_level
    from
        ncit_tc_with_path np --
        join maintypes m on np.parent = m.nci_thesaurus_concept_id
        join ncit n on np.parent = n.code
        join ncit nc on np.descendant = nc.code
    where
        np.descendant = :starting_code
)
select
    distinct np.parent as maintype
from
    ncit_tc_with_path np
    join maintypes m on np.parent = m.nci_thesaurus_concept_id
    join ncit n on np.parent = n.code
    join ncit nc on np.descendant = nc.code
    join minlevel ml on np.level = ml.min_level
where
    np.descendant = :starting_code;
