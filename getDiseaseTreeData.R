getDiseaseTreeData <- function(safe_query,ncit_code, search_string = NA, use_ctrp_display_name = FALSE) {
  
  s <- "
 with recursive parent_descendant(parent, descendant, level, path_string)
  as (
  select tc.parent , tc.descendant , 1 as level, n1.pref_name || ' | ' || n2.pref_name as path_string  
  from ncit_tc_with_path tc join ncit n1 on tc.parent = n1.code join ncit n2 on tc.descendant = n2.code 
  where tc.parent = ? and tc.level = 1 
  union ALL
  select pd.descendant as parent ,
  tc1.descendant as descendant, 
  pd.level + 1 as level,
  pd.path_string || ' | ' ||  n1.pref_name as path_string
  from parent_descendant pd join
  ncit_tc_with_path tc1 on pd.descendant = tc1.parent and tc1.level = 1
  join ncit n1 on n1.code = tc1.descendant

  )
 -- select * from parent_descendant 
  
  
  ,
  data_for_tree as
  (
  select distinct n1.pref_name  as parent,
  n2.pref_name  as child,
  pd.level
  --,
  --pd.path_string
  from parent_descendant pd
  join ncit n1 on pd.parent = n1.code 
  join ncit n2 on pd.descendant = n2.code 
       where exists (select dd.nci_thesaurus_concept_id from distinct_trial_diseases dd where dd.nci_thesaurus_concept_id = n2.code )


  )
  ,
  all_nodes as (
  select parent, child, level 
  --, path_string 
  from data_for_tree
  union
  select NULL as parent , pref_name  as child, 0 as level 
  --, pref_name as path_string
  from ncit n where n.code = ?
  )
  select parent, child, level as levels,  1 as collapsed , 10 as \"nodeSize\" --, path_string
  
  
  from all_nodes where level < 999
  order by level"
  
  
  s_ctrp <- "
    select parent, child, levels, collapsed, \"nodeSize\" ,  \"tooltipHtml\" from disease_tree where code = $1
    order by levels, parent, child
  "
  
 
  if (use_ctrp_display_name == TRUE) {
    q_string <- s_ctrp
  } else {
    q_string <- s
  }
  
  df_tree_data <-
    safe_query(dbGetQuery,
               q_string,
               params = c(ncit_code))
  
  
 # browser()
  if(is.na(search_string) | search_string == "") {
    return(df_tree_data)
  } 
  
  # We have a search string and need to see if it occurs in any of the child nodes
  # if it is not found, put up an alert and then return the original data frame.
  
  hits <- grep(tolower(search_string), tolower(df_tree_data$child))
  rows_to_mark <- vector()
  
  
  markCollapsed <- function(row, rows_to_mark) {
    print(paste('STARTING markCollapsed', row))
    if(row > 1){
     
    
    # First mark the 
    rows_to_mark <- append(rows_to_mark, row)
    df_tree_data$collapsed[row] <<- 0
    #
    # Now get the parents that have the same name and recurse
    #
    name_to_find <- df_tree_data$parent[row]
    print(name_to_find)
    new_hits <- which(df_tree_data$child == name_to_find)
   # new_hits <- grep(tolower(name_to_find), tolower(df_tree_data$child))
    print(new_hits)
   # browser()
    
    for(i in 1:length(new_hits)) {
      df_tree_data$collapsed[new_hits[i]] <- 0
      if(new_hits[i] > 1) {
       # rows_to_mark <- append(rows_to_mark, new_hits[i])
        markCollapsed(new_hits[i], rows_to_mark)
      }
    }
   # browser()  
    print(paste('ENDING markCollapsed', row))
    }
  }
  
  if(length(hits) > 0 ) {
  for (i in 1:length(hits)) {
    markCollapsed(hits[i], rows_to_mark)
    
  }
}
  return(df_tree_data)
  
}