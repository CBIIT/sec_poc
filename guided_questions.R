library(shinyBS)

guidedQuestionsUI <- function(id, label = 'Guided Questions') {
    ns <- NS(id)
    bsModal(ns("modalExample"), "Guided Questions", "show_guided_questions", size="large", 
        # fluidPage(id = ns("distTable"),
        selectInput(ns("performance_status"), "How would you describe your symptoms currently?", c(
            "Unspecified" = "C159685",
            "0: Asymptomatic" = "C105722",
            "1: Symptomatic, but fully ambulatory" = "C105723",
            "2: Symptomatic, in bed less than 50% of day" = "C105725",
            "3: Symptomatic, in bed more than 50% of day, but not bed-ridden" = "C105726",
            "4: Bed-ridden" = "C105727"
        ))
        # pickerInput(
        #   inputId = ns("performance_status2"),
        #   label = "How would you describe your symptoms currently?",
        #   choices = c(
        #     "Unspecified" = "C159685",
        #     "0: Asymptomatic" = "C105722",
        #     "1: Symptomatic, but fully ambulatory" = "C105723",
        #     "2: Symptomatic, in bed less than 50% of day" = "C105725",
        #     "3: Symptomatic, in bed more than 50% of day, but not bed-ridden" = "C105726",
        #     "4: Bed-ridden" = "C105727"
        #   ),
        #   selected =  "Unspecified",
        #   multiple = FALSE,
        #   options = list(width = "72px"),
        #   choicesOpt = NULL,
        #   width = 'auto',
        #   inline = FALSE
        # ) 
        # fluidRow(column(2, ':')),
        # )
    )
}

guidedQuestionsServe <- function(id) {
    moduleServer(id, function(input, output, session) {
        performanceStatus <- observe({
            req(input$performance_status)
            print(input$performance_status)
            input$performance_status
        })
        return(performanceStatus)
    })
}

# with biomarker_inc as (
#   select nct_id, trim(unnest(string_to_array(biomarker_inc_codes, ','))) as biomarker_inc_code
#   from trials)
#   select count(bi.biomarker_inc_code) as num_occurences, bi.biomarker_inc_code,
#    coalesce(nullif(n.display_name,''), n.pref_name) as biomarker_name
#    from trial_diseases td  join biomarker_inc bi on bi.nct_id = td.nct_id and lead_disease_indicator = TRUE
#    join ncit n on bi.biomarker_inc_code = n.code
#        where td.nci_thesaurus_concept_id = 'C2991'
#    group by bi.biomarker_inc_code, coalesce(nullif(n.display_name,''), n.pref_name)
#    order by count(bi.biomarker_inc_code) desc;

# link trial_diseses to biomarkers_inc(which is trials) to matching nct_id that have lead_diseaseindicator set to TRUE..named bi
# Than form that join ncit.code to bi.biomarker_inc_code from trials

#  

# EGFR POSITIVE
# C134501 EGFR Positive
# C98357 EGFR Gene Mutation

# EGFR Negative
# C150501 EGFR Negative

# ALK Positive
# C128831 ALK Positive
# C81945 ALK Gene Mutation

# ALK Negative
# C133707 ALK Negative

# select count(*) from trials where diseases IN ('C105722');
# select count(*) from trial_criteria where trial_criteria_expression like '%exists(''C105722'')%' limit 1;
# select count(*) from trial_criteria where criteria_type_id = 8 and trial_criteria_refined_text like any(array['%=< 2%', '%=< 1%', '%=< 0%', '%=< 4%', '%=< 3%']);
# select nct_id from trial_criteria where criteria_type_id = 8 and trial_criteria_refined_text like any(array['%=< 2%', '%=< 1%', '%=< 0%', '%=< 4%', '%=< 3%']);
# TODO: Look into making a graph for biomarks in R

# select biomarker_inc_names from trials where diseases like any(array['%C4878%']) and (max_age_in_years >= 45 and min_age_in_years <= 45) and (gender = 'BOTH' or gender = 'BOTH');

# select * from trials where biomarker_inc_codes like any(array['%C129700%']) limit 1;


# Adding the rest of the and clause to the query Hubert gave me.  This should take all the other guided questions into account 
# with biomarker_inc as (select nct_id, trim(unnest(string_to_array(biomarker_inc_codes, ','))) as biomarker_inc_code from trials HERE) select count(bi.biomarker_inc_code) as num_occurences, bi.biomarker_inc_code, coalesce(nullif(n.display_name,''), n.pref_name) as biomarker_name from trial_diseases td  join biomarker_inc bi on bi.nct_id = td.nct_id and lead_disease_indicator = TRUE join ncit n on bi.biomarker_inc_code = n.code where td.nci_thesaurus_concept_id = 'C9305' group by bi.biomarker_inc_code, coalesce(nullif(n.display_name,''), n.pref_name) order by count(bi.biomarker_inc_code) desc;
# with biomarker_inc as (select nct_id, trim(unnest(string_to_array(biomarker_inc_codes, ','))) as biomarker_inc_code from trials where (max_age_in_years >= 1 and min_age_in_years <= 1) and (gender = 'BOTH' or gender = 'BOTH')) select count(bi.biomarker_inc_code) as num_occurences, bi.biomarker_inc_code, coalesce(nullif(n.display_name,''), n.pref_name) as biomarker_name from trial_diseases td  join biomarker_inc bi on bi.nct_id = td.nct_id and lead_disease_indicator = TRUE join ncit n on bi.biomarker_inc_code = n.code where td.nci_thesaurus_concept_id = 'C9305' group by bi.biomarker_inc_code, coalesce(nullif(n.display_name,''), n.pref_name) order by count(bi.biomarker_inc_code) desc;