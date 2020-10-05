drop table if exists trials;
create table trials (
nct_id varchar(100) primary key,
brief_title text,
official_title text,
brief_summary text,
detail_description text,
max_age_in_years int,
min_age_in_years int,
age_expression varchar(200),
gender varchar(10),
gender_expression varchar(200),
diseases  text,
disease_names text,
diseases_lead text,
disease_names_lead text,
phase text,
primary_purpose_code text,
study_source text
record_verification_date date
);
drop table if exists trial_diseases;

create table trial_diseases
(
idx integer primary key,
nct_id varchar(100),
nci_thesaurus_concept_id varchar(100),
lead_disease_indicator varchar(4),
preferred_name text,
disease_type text,
inclusion_indicator text,
display_name text,
--constraint trial_diseases_pk primary key (nct_id, nci_thesaurus_concept_id)
constraint trial_diseases_trial_fk foreign key (nct_id) references trials(nct_id)
);
create index trial_diseases_nct_id_idx on trial_diseases(nct_id);
create index trial_diseases_concept_idx on trial_diseases(nci_thesaurus_concept_id);
create index trial_diseases_concept_lead on trial_diseases(nci_thesaurus_concept_id, lead_disease_indicator);
create index trial_diseases_lead_disease on trial_diseases(lead_disease_indicator);
create index trial_diseases_inc_ind on trial_diseases(inclusion_indicator);


drop table if exists distinct_trial_diseases;
create table distinct_trial_diseases(nci_thesaurus_concept_id text, preferred_name, disease_type, display_name);
create index dtd_index on distinct_trial_diseases(nci_thesaurus_concept_id);


drop table if exists maintypes;
create table maintypes(
nci_thesaurus_concept_id varchar(100)
);
create index maintype_idx on maintypes(nci_thesaurus_concept_id);

drop table if exists trial_maintypes;
create table trial_maintypes(
nct_id varchar(100),
nci_thesaurus_concept_id text,
constraint trial_maintypes_pk primary key (nct_id, nci_thesaurus_concept_id)
);
