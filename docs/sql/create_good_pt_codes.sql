create
or replace view good_pt_codes as (
    -- Select all descendants from higher-level intervention terms (e.g., "Intervention or Procedure" (C25218))
    with descendants as (
        select
            descendant
        from
            ncit_tc
        where
            parent in ('C25218', 'C1908', 'C62634', 'C163758')
    ),
    -- Exclude certain codes. Why?
    descendants_to_remove as (
        select
            descendant
        from
            ncit_tc
        where
            parent in (
                'C25294',
                -- this one may be related to POC-80
                'C102116',
                'C173045',
                'C65141',
                'C91102',
                'C20993'
            )
        UNION
        select
            'C305' as descendant -- bilirubin
        union
        select
            'C399' as descendant -- creatinine
        union
        select
            'C37932' as descendant -- contraception  
        union
        select
            'C92949' as descendant -- pregnancy test
        UNION
        select
            'C1505' as descendant -- dietary supplment
        UNION
        select
            'C71961' as descendant -- grapefruit juice
        UNION
        select
            'C71974' as descendant -- grapefruit
        UNION
        select
            'C16124' as descendant -- prior therapy
    ),
    good_codes as (
        select
            d.descendant
        from
            descendants d
        except
        select
            d2.descendant
        from
            descendants_to_remove d2
    )
    select
        n.code,
        trim(n.pref_name) as pref_name,
        trim(n.synonyms) as synonyms,
        trim(n.semantic_type) as semantic_type
    from
        ncit n
        join good_codes gc on n.code = gc.descendant
)
