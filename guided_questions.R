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



calculate_mean <- function(data) {
    total = 0
    for(d in data){ # Where d is the freq values for all values in collection
        total = total + d
    }
    return(total / length(data) )
}

calculate_devation_sum <- function(data) {
    total = 0
    mean = calculate_mean(data)
    for(d in data){
        total = total + (d - mean) ^ 2
    }
    return(total)
}

calculate_variance_of_devation <- function(data){
    devationSum = calculate_devation_sum(data)
    return(devationSum / length(data))
}

calculate_standard_devation <- function(data){
    return(sqrt(calculate_variance_of_devation(data)))
}

calculate_frequency <- function(data){
    freq = list()
    for(item in data){
        for(value in item){
            valueChar = as.character(value)
            if(is.null(freq[[valueChar]])){
                freq[valueChar] <- 1
            }else{
                freq[valueChar] = freq[[valueChar]] + 1
            }
        }
    }
    # print(freq)
    return(calculate_standard_devation(unname(unlist(freq))))
}

normalize_performance_status <- function(data){
    normalized_list = c()
    for(performance_status in data){
        for(value in performance_status){
            if(!is.na(value)){
                if(str_detect(value, "<") == TRUE){
                    normalized_list = append(normalized_list, as.numeric(str_extract(value, "\\d+")))
                }else{
                    normalized_list = append(normalized_list, NA)
                }
            }else{
                normalized_list = append(normalized_list, NA)
            }
        }
    }
    return(normalized_list)
}

normalize_ccode_string <- function(data){
    normalized_list = list()
    for(value in data){
        for(fuckyouR in value){
            if(!is.null(fuckyouR) && fuckyouR != "" && !is.na(fuckyouR)){
                newString = gsub("'", '', fuckyouR)
                newString = gsub(" ", '', fuckyouR)
                newValues = strsplit(newString, ",")
                normalized_list = append(normalized_list, list(newValues))
            }else{
                normalized_list = append(normalized_list, NA)
            }
        }
    }
    if(length(normalized_list) == 0) return(NA)
    return(normalized_list)
}

calculate_ccode_frequency <- function(data){
    freq = list()
    for(value in data){
        if(!is.null(value)){
            newString = gsub("'", '', value)
            newValues = strsplit(newString, ",")
            for(trueValue in newValues){
                for(item in trueValue){
                    if(is.null(freq[[item]])){
                        freq[item] <- 1
                    }else{
                        freq[item] = freq[[item]] + 1
                    }
                }
            }
        }
    }
    return(calculate_standard_devation(unname(unlist(freq))))
}


# find lowest value return name of dataframe
# colnames(df1)[apply(df1, 1, which.min)]

getGuidedQuestionDataFrames <-  function(safe_query){
    trialValues <- safe_query(
        dbGetQuery,
        'select t.min_age_in_years, t.max_age_in_years, t.gender, t.diseases, t.biomarker_inc_codes, t.biomarker_exc_codes, t.phase, t.nct_id, tc.trial_criteria_refined_text from trials t left outer join trial_criteria tc on tc.nct_id = t.nct_id and tc.criteria_type_id = 8;'
    )
    freq_min_age = calculate_frequency(trialValues[1])
    freq_max_age = calculate_frequency(trialValues[2])
    freq_gender = calculate_frequency(trialValues[3])
    freq_phase = calculate_frequency(trialValues[7])
    freq_perf = calculate_frequency(trialValues[9])
    freq_disease = calculate_ccode_frequency(trialValues[4])
    freq_biomarkers = calculate_frequency(trialValues[5])
    freq_age = ((freq_max_age + freq_min_age) / 2)
    newString = "with biomarker_inc as (
                select nct_id, trim(unnest(string_to_array(biomarker_inc_codes, ','))) as biomarker_inc_code
                from trials)
                select bi.biomarker_inc_code,
                coalesce(nullif(n.display_name,''), n.pref_name) as biomarker_name
                from trial_diseases td  join biomarker_inc bi on bi.nct_id = td.nct_id and lead_disease_indicator = TRUE
                join ncit n on bi.biomarker_inc_code = n.code
                group by bi.biomarker_inc_code, coalesce(nullif(n.display_name,''), n.pref_name)
                order by count(bi.biomarker_inc_code) desc;"
    biomarkers_inc <- safe_query(
        dbGetQuery,
        newString
    )
    df_biomarker_list_jv <- setNames(c(biomarkers_inc[["biomarker_inc_code"]]), as.vector(biomarkers_inc[["biomarker_name"]]))
    df_disease_list <- safe_query(
        dbGetQuery,
        "select distinct nci_thesaurus_concept_id, preferred_name from trial_diseases;"
    )
    df_disease_list <- setNames(
        as.vector(df_disease_list[["nci_thesaurus_concept_id"]]),as.vector(df_disease_list[["preferred_name"]])
    )
    df1 <- list(
        age=list(
            freq=freq_age,
            modalType='nextTextModal',
            modalParams=list(
                "age_guided",
                'How old are you??',
                "guided_question1"
            ),
            isSelectizeInput=FALSE,
            calc=function(df, x){ 
                if(x != ""){ 
                    df <- df %>% filter(MinAge <= as.numeric(x) | is.na(MinAge) )
                    df <- df %>% filter(MaxAge >= as.numeric(x) | is.na(MaxAge) )
                    return(df)
                }
            }
        ),
        gender=list(
            freq=freq_gender,
            modalType='nextModal',
            modalParams=list(
                'gender_guided',
                'What is your gender??',
                c("Female"="FEMALE", "Male"="MALE", "Rather not specify"="BOTH"),
                'guided_question2'
            ),
            isSelectizeInput=FALSE,
            calc=function(df, x){ df %>% filter(str_detect(Gender, paste(x, collapse="|")) | is.na(Gender)) }
        ),
        performanceStatus=list(
            freq=freq_perf,
            modalType='nextModal',
            modalParams=list(
                "performance_guided",
                'How would you describe your symptoms currently??',
                c(
                    "Unspecified" = "C159685",
                    "0: Asymptomatic" = "C105722",
                    "1: Symptomatic, but fully ambulatory" = "C105723",
                    "2: Symptomatic, in bed less than 50% of day" = "C105725",
                    "3: Symptomatic, in bed more than 50% of day, but not bed-ridden" = "C105726",
                    "4: Bed-ridden" = "C105727"
                ),
                "guided_question3"
            ),
            isSelectizeInput=FALSE,
            calc=function(df, x){
                y <- 0
                switch(x,
                    C159685 = {y <- 5},
                    C105722 = {y <- 0},
                    C105723 = {y <- 1},
                    C105725 = {y <- 2},
                    C105726 = {y <- 3},
                    C105727 = {y <- 4}
                )
                df %>% filter(PrefStat <= y | is.na(PrefStat))
            }
        ),
        diseases=list(
            freq=freq_disease,
            modalType='nextSelectizeModal',
            modalParams=list(
                "disease_search_guided",
                "Do you have any of these diseases??",
                "guided_question4"
            ),
            isSelectizeInput=TRUE,
            calc=function(df, x){
                df %>% filter(str_detect(Diseases, paste(x, collapse="|")) | is.na(Diseases) ) 
            },
            selectionData=df_disease_list
        ),
        biomarkers=list(
            freq=freq_biomarkers,
            modalType='nextSelectizeModal',
            modalParams=list(
                'update_guided_question1',
                'Do you have any of these biomarkers??',
                'guided_question5'
            ),
            isSelectizeInput=TRUE,
            calc=function(df, x){ 
                print(x)
                df %>% filter(str_detect(BiomarkersInc, paste(x, collapse="|")) | is.na(BiomarkersInc) ) 
            },
            selectionData=df_biomarker_list_jv
        )
    )
    # order by lowest freq_standard
    df1 = df1[order(sapply(df1, '[[', 1))]
    for(i in 1:5){
        if(length(df1[[i]][[3]]) > 3){
            df1[[i]][[3]][[4]] = str_c("guided_question", i)
        }else {
            df1[[i]][[3]][[3]] = str_c("guided_question", i)
        }
    }
    norm_bioExc = normalize_ccode_string(trialValues[6])
    print(length(trialValues[[6]]))
    print(length(norm_bioExc))
    df2 = data.frame(
        Id=trialValues[[8]],
        MinAge=trialValues[[1]],
        MaxAge=trialValues[[2]],
        Gender=trialValues[[3]],
        Diseases=trialValues[[4]],
        BiomarkersInc=trialValues[[5]],
        BiomarkersExc=trialValues[[6]],
        Phase=trialValues[[7]],
        PrefStat=normalize_performance_status(trialValues[9])
    )
    print(typeof(df2$BiomarkersInc[[2]]))
    return(list(df1, df2))
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

# Original query given to me by Hubert
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

# Working example 
# with biomarker_inc as (
#   select nct_id, trim(unnest(string_to_array(biomarker_inc_codes, ','))) as biomarker_inc_code, gender, min_age_in_years, max_age_in_years
#   from trials)
#   select bi.biomarker_inc_code,
#    coalesce(nullif(n.display_name,''), n.pref_name) as biomarker_name
#    from trial_diseases td  join biomarker_inc bi on bi.nct_id = td.nct_id and lead_disease_indicator = TRUE
#    join ncit n on bi.biomarker_inc_code = n.code
#        where td.nci_thesaurus_concept_id in ('C7808') and (bi.max_age_in_years >= 45 and bi.min_age_in_years <= 45) and (bi.gender = 'MALE' or bi.gender = 'BOTH')
#    group by bi.biomarker_inc_code, coalesce(nullif(n.display_name,''), n.pref_name);


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

# select count(*) from trials join trial_criteria on trials.nct_id = trial_criteria.nct_id where (trial_criteria.trial_criteria_refined_text = 'Performance Status =< 2'
# select count(*) from trials join trial_criteria on trials.nct_id = trial_criteria.nct_id where (trial_criteria.trial_criteria_refined_text in ('Performance Status =< 2', 'Performance Status =< 1', 'Performance Status =< 0'));



# Adding the rest of the and clause to the query Hubert gave me.  This should take all the other guided questions into account 
# with biomarker_inc as (select nct_id, trim(unnest(string_to_array(biomarker_inc_codes, ','))) as biomarker_inc_code from trials HERE) select count(bi.biomarker_inc_code) as num_occurences, bi.biomarker_inc_code, coalesce(nullif(n.display_name,''), n.pref_name) as biomarker_name from trial_diseases td  join biomarker_inc bi on bi.nct_id = td.nct_id and lead_disease_indicator = TRUE join ncit n on bi.biomarker_inc_code = n.code where td.nci_thesaurus_concept_id = 'C9305' group by bi.biomarker_inc_code, coalesce(nullif(n.display_name,''), n.pref_name) order by count(bi.biomarker_inc_code) desc;
# with biomarker_inc as (select nct_id, trim(unnest(string_to_array(biomarker_inc_codes, ','))) as biomarker_inc_code from trials where (max_age_in_years >= 1 and min_age_in_years <= 1) and (gender = 'BOTH' or gender = 'BOTH')) select count(bi.biomarker_inc_code) as num_occurences, bi.biomarker_inc_code, coalesce(nullif(n.display_name,''), n.pref_name) as biomarker_name from trial_diseases td  join biomarker_inc bi on bi.nct_id = td.nct_id and lead_disease_indicator = TRUE join ncit n on bi.biomarker_inc_code = n.code where td.nci_thesaurus_concept_id = 'C9305' group by bi.biomarker_inc_code, coalesce(nullif(n.display_name,''), n.pref_name) order by count(bi.biomarker_inc_code) desc;