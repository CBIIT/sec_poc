select
    criteria_type_code,
    criteria_type_title,
    criteria_type_sense
from
    criteria_types
where
    criteria_type_active = 'Y'
    and criteria_column_index < 2000
order by
    criteria_column_index;
