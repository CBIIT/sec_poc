create table disease_tree_temp as (
    with recursive parent_descendant(top_code, parent, descendant, level, path_string) as (
        select
            tc.parent as top_code,
            tc.parent,
            tc.descendant,
            1 as level,
            n1.pref_name || ' | ' || n2.pref_name as path_string
        from
            ncit_tc_with_path tc
            join ncit n1 on tc.parent = n1.code
            join ncit n2 on tc.descendant = n2.code
        where
            tc.parent in (
                select
                    nci_thesaurus_concept_id
                from
                    distinct_trial_diseases ds
                where
                    (
                        ds.disease_type = 'maintype'
                        or ds.disease_type like '%maintype-subtype%'
                    )
                    and nci_thesaurus_concept_id not in ('C2991', 'C2916')
                union
                select
                    'C4913' as nci_thesaurus_concept_id
            )
            and tc.level = 1
        union
        ALL
        select
            pd.top_code,
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
            distinct pd.top_code,
            n1.pref_name as parent,
            n2.pref_name as child,
            pd.level,
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
            top_code,
            parent,
            child,
            level
        from
            data_for_tree
        union
        select
            n.code as top_code,
            NULL as parent,
            pref_name as child,
            0 as level
        from
            ncit n
        where
            n.code in (
                select
                    nci_thesaurus_concept_id
                from
                    distinct_trial_diseases ds
                where
                    ds.disease_type = 'maintype'
                    or ds.disease_type like '%maintype-subtype%'
                    and nci_thesaurus_concept_id not in ('C2991', 'C2916')
                union
                select
                    'C4913' as nci_thesaurus_concept_id
            )
    ),
    trial_disease_counts as (
        select
            display_name,
            replace(
                replace(
                    replace(display_name, 'AJCC v7', ''),
                    'AJCC v8',
                    ''
                ),
                'AJCC v6',
                ''
            ) as rev_name,
            count(display_name) as num_trials
        from
            trial_diseases
        group by
            display_name
    ),
    ctrp_display_name_trial_counts as (
        select
            rev_name,
            sum(num_trials) as num_trials
        from
            trial_disease_counts
        group by
            rev_name
    ),
    ctrp_names as (
        select
            distinct preferred_name,
            display_name
        from
            trial_diseases
    ),
    all_nodes_ctrp as (
        select
            an.top_code,
            replace(
                replace(
                    replace(ctrp1.display_name, 'AJCC v7', ''),
                    'AJCC v8',
                    ''
                ),
                'AJCC v6',
                ''
            ) as parent,
            replace(
                replace(
                    replace(ctrp2.display_name, 'AJCC v7', ''),
                    'AJCC v8',
                    ''
                ),
                'AJCC v6',
                ''
            ) as child,
            level as level,
            1 as collapsed,
            10 as "nodeSize",
            CASE
                when cc.num_trials = 1 THEN coalesce(cast(cc.num_trials as varchar), ' ') || ' trial'
                when cc.num_trials > 1 THEN coalesce(cast(cc.num_trials as varchar), ' ') || ' trials'
                else ' '
            END as "tooltipHtml"
        from
            all_nodes an
            left outer join ctrp_names ctrp1 on an.parent = ctrp1.preferred_name
            join ctrp_names ctrp2 on an.child = ctrp2.preferred_name
            left outer join ctrp_display_name_trial_counts cc on cc.rev_name = ctrp2.display_name
        where
            (
                ctrp1.display_name != ctrp2.display_name
                or level = 0
            )
    )
    select
        distinct top_code,
        parent,
        child,
        level as levels,
        collapsed,
        "nodeSize",
        "tooltipHtml"
    from
        all_nodes_ctrp
    where
        level < 999
)
