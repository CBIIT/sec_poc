with recursive parent_descendant(parent, descendant, level, path_string) as (
    select
        tc.parent,
        tc.descendant,
        1 as level,
        n1.pref_name || ' | ' || n2.pref_name as path_string
    from
        ncit_tc_with_path tc
        join ncit n1 on tc.parent = n1.code
        join ncit n2 on tc.descendant = n2.code
    where
        tc.parent = :code
        and tc.level = 1
    union
    ALL
    select
        pd.descendant as parent,
        tc1.descendant as descendant,
        pd.level + 1 as level,
        pd.path_string || ' | ' || n1.pref_name as path_string
    from
        parent_descendant pd
        join ncit_tc_with_path tc1 on pd.descendant = tc1.parent
        and tc1.level = 1
        join ncit n1 on n1.code = tc1.descendant
),
data_for_tree as (
    select
        distinct n1.pref_name as parent,
        n2.pref_name as child,
        pd.level
    from
        parent_descendant pd
        join ncit n1 on pd.parent = n1.code
        join ncit n2 on pd.descendant = n2.code
    where
        exists (
            select
                dd.nci_thesaurus_concept_id
            from
                distinct_trial_diseases dd
            where
                dd.nci_thesaurus_concept_id = n2.code
        )
),
all_nodes as (
    select
        parent,
        child,
        level
    from
        data_for_tree
    union
    select
        NULL as parent,
        pref_name as child,
        0 as level
    from
        ncit n
    where
        n.code = :code
)
select
    parent,
    child,
    level as levels,
    1 as collapsed,
    10 as "nodeSize"
from
    all_nodes
where
    level < 999
order by
    level;
