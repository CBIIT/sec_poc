getDiseaseTreeData <- function(con,ncit_code) {

  s <- "
  with recursive parent_descendant(parent, descendant, level)
  as (
  select tc.parent , tc.descendant , 1 as level from ncit_tc_with_path tc
  where tc.parent = ? and tc.level = 1
  union ALL
  select pd.descendant as parent ,
  tc1.descendant as descendant,
  pd.level + 1 as level
  from parent_descendant pd join
  ncit_tc_with_path tc1 on
  pd.descendant = tc1.parent and tc1.level = 1
  )
  ,
  
  data_for_tree as
  (
  select distinct n1.pref_name  as parent,
  n2.pref_name  as child,
  pd.level
  from parent_descendant pd
  join ncit n1 on pd.parent = n1.code 
  join ncit n2 on pd.descendant = n2.code 
  where exists (select dd.nci_thesaurus_concept_id from distinct_trial_diseases dd where dd.nci_thesaurus_concept_id = n1.code or dd.nci_thesaurus_concept_id = n2.code)
   
  )
  ,
  all_nodes as (
  select parent, child, level from data_for_tree
  union
  select NULL as parent , pref_name  as child, 0 as level
  from ncit n where n.code = ?
  )

  select parent, child, level as levels , cast(1 as integer) as collapsed, 10 as nodeSize  from all_nodes where level < 999 
  order by levels"
  
# s <- "
#   with recursive parent_descendant(parent, descendant, level)
# as (
# select tc.parent , tc.descendant , 1 as level from ncit_tc_with_path tc
# where tc.parent = ? and tc.level = 1
# union ALL
# select pd.descendant as parent ,
# tc1.descendant as descendant,
# pd.level + 1 as level
# from parent_descendant pd join
# ncit_tc_with_path tc1 on
# pd.descendant = tc1.parent and tc1.level = 1
# )
# ,
# data_for_tree as
# (
#   select distinct n1.pref_name as parent,
#   n2.pref_name as child,
#   pd.level
#   from parent_descendant pd
#   join ncit n1 on pd.parent = n1.code 
#   join ncit n2 on pd.descendant = n2.code 
#   
#   
# )
# ,
# all_nodes as (
# select parent, child, level from data_for_tree
# union
# select NULL as parent , pref_name as child, 0 as level
# from ncit n where n.code = ?
# )
# select parent, child, level as levels, 10 as nodeSize from all_nodes where level < 999
# "
df_tree_data <-
  dbGetQuery(con,
             s,
             params = c(ncit_code,ncit_code))

return(df_tree_data)
}