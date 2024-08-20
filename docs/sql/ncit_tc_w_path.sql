-- If A is a parent of B
-- And B is a parent of C
-- Then the ncit_tc_with_path table will contain the following:
-- | parent | descendant | level | path   |
-- | ------ | ---------- | ----- | ----   |
-- | A      | B          | 1     | A|B    |
-- | B      | C          | 1     | B|C    |
-- | A      | C          | 2     | A|B|C  |
create table ncit_tc_with_path as with recursive ncit_tc_rows(parent, descendant, level, path) as (
    select
        parent,
        concept as descendant,
        level,
        path
    from
        parents
    union
    all
    select
        p.parent,
        n.descendant as descendant,
        n.level + 1 as level,
        p.parent || '|' || n.path as path -- Prepend new parents to the existing path
    from
        ncit_tc_rows n
        join parents p on n.parent = p.concept -- Find all parents of concept = n.parent (find parents of parents)
)
select
    *
from
    ncit_tc_rows
