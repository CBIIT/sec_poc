drop table if exists trials;

create table trials
(
    nct_id                        varchar(100) not null
        primary key,
    brief_title                   text,
    official_title                text,
    brief_summary                 text,
    detail_description            text,
    max_age_in_years              integer,
    min_age_in_years              integer,
    age_expression                varchar(200),
    gender                        varchar(10),
    gender_expression             varchar(200),
    diseases                      text,
    disease_names                 text,
    diseases_lead                 text,
    disease_names_lead            text,
    phase                         text,
    primary_purpose_code          text,
    study_source                  text,
    record_verification_date      date,
    amendment_date                date,
    biomarker_exc_codes           text,
    biomarker_exc_names           text,
    biomarker_inc_codes           text,
    biomarker_inc_names           text,
    active_sites_count            integer,
    ccr_id                        text,
    classification_code           text,
    completion_date               text,
    completion_date_type_code     text,
    ctep_id                       text,
    current_trial_status          text,
    current_trial_status_date     text,
    dcp_id                        text,
    interventional_model          text,
    lead_org                      text,
    lead_org_cancer_center        text,
    minimum_target_accrual_number integer,
    nci_funded                    text,
    number_of_arms                integer,
    primary_purpose               text,
    principal_investigator        text,
    protocol_id                   text,
    sampling_method_code          text,
    start_date                    text,
    start_date_type_code          text,
    study_model_code              text,
    study_model_other_text        text,
    study_population_description  text,
    study_protocol_type           text,
    study_subtype_code            text
);


drop index if exists trials_nct_idx;

create index trials_nct_idx on trials(nct_id);

drop table if exists trial_diseases;

create table trial_diseases (
  idx serial primary key,
  nct_id varchar(100),
  nci_thesaurus_concept_id varchar(100),
  lead_disease_indicator boolean,
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

create table distinct_trial_diseases(
  nci_thesaurus_concept_id text,
  preferred_name text,
  disease_type text,
  display_name text
);

create index dtd_index on distinct_trial_diseases(nci_thesaurus_concept_id);

drop table if exists maintypes;

create table maintypes(nci_thesaurus_concept_id varchar(100));

create index maintype_idx on maintypes(nci_thesaurus_concept_id);

drop table if exists trial_maintypes;

create table trial_maintypes(
  nct_id varchar(100),
  nci_thesaurus_concept_id text,
  constraint trial_maintypes_pk primary key (nct_id, nci_thesaurus_concept_id)
);

drop table if exists trial_sites;

create table trial_sites(
  nct_id varchar(100),
  org_name text,
  org_family text,
  org_status text,
  org_to_family_relationship text
);

create index trial_sites_nct_idx on trial_sites(nct_id);

create index trial_sites_nct_name_idx on trial_sites(nct_id, org_name);

create index trial_sites_nct_fam_idx on trial_sites(nct_id, org_family);

drop table if exists trial_unstructured_criteria;

create table trial_unstructured_criteria (
  nct_id varchar(100),
  display_order int,
  inclusion_indicator text,
  description text
);

create index tuc_nct_index on trial_unstructured_criteria(nct_id);

create sequence trial_diseases_sequence start with 250;

-- Leave room for imported criteria
drop table if exists criteria_types;

create table criteria_types(
  criteria_type_id INTEGER PRIMARY KEY,
  criteria_type_code text not null,
  criteria_type_title text not null,
  criteria_type_desc text not null,
  criteria_type_active varchar(1) check (
    criteria_type_active = 'Y'
    or criteria_type_active = 'N'
  ),
  criteria_type_sense text check (
    criteria_type_sense = 'Inclusion'
    or criteria_type_sense = 'Exclusion'
  ),
  criteria_column_index int
);

drop table if exists trial_criteria;

create table trial_criteria (
  nct_id varchar(100),
  criteria_type_id integer,
  trial_criteria_orig_text text,
  trial_criteria_refined_text text not null,
  trial_criteria_expression text not null,
  update_date timestamp,
  update_by text,
  primary key(nct_id, criteria_type_id),
  foreign key(criteria_type_id) references criteria_types(criteria_type_id)
);

drop table if exists trial_unstructured_criteria;

create table trial_unstructured_criteria (
  nct_id varchar(100),
  display_order int,
  inclusion_indicator boolean,
  description text
);

create index tuc_nct_index on trial_unstructured_criteria(nct_id);

drop table if exists ncit_version;

create table ncit_version (
  version_id varchar(32),
  downloaded_url text,
  transitive_closure_generation_date timestamp,
  active_version char(1) check (
    active_version = 'Y'
    or active_version is NULL
  ),
  ncit_tokenizer_generation_date timestamp,
  ncit_tokenizer bytea
);

drop table if exists ncit;

create table ncit(
  code varchar(25) primary key,
  url text,
  parents text,
  synonyms text,
  definition text,
  display_name text,
  concept_status text,
  semantic_type text,
  pref_name text,
  concept_in_subset text
);

drop table if exists disease_tree;

create table disease_tree (
  code text,
  parent text,
  child text,
  levels int,
  collapsed int,
  "nodeSize" int,
  "tooltipHtml" text,
  original_child text
);

create index disease_tree_index_1 on disease_tree(code);

create index disease_tree_index_2 on disease_tree(code, levels, parent, child);

drop table if exists disease_tree_nostage;

create table disease_tree_nostage(
  code text,
  parent text,
  child text,
  levels int,
  collapsed int,
  "nodeSize" int,
  "tooltipHtml" text,
  original_child text
);

create index disease_tree_index_1_ns on disease_tree_nostage(code);

create index disease_tree_index_2_ns on disease_tree_nostage(code, levels, parent, child);

drop table if exists curated_crosswalk;

CREATE TABLE curated_crosswalk (
  id serial primary key,
  code_system TEXT,
  disease_code TEXT,
  preferred_name TEXT,
  evs_c_code TEXT,
  evs_preferred_name TEXT
);

create index crosswalk_ind1 on curated_crosswalk(code_system, disease_code);

create index crosswalk_ind2 on curated_crosswalk(evs_c_code);

drop table if exists parents;

CREATE TABLE parents (
  concept TEXT,
  parent TEXT,
  path TEXT,
  level int
);

drop table if exists trial_prior_therapies;

CREATE TABLE trial_prior_therapies(
  idx SERIAL PRIMARY KEY,
  nct_id VARCHAR(100),
  nci_thesaurus_concept_id VARCHAR(25),
  eligibility_criterion TEXT,
  inclusion_indicator TEXT,
  name TEXT,
  CONSTRAINT trial_prior_therapies_trial_fk FOREIGN KEY (nct_id) REFERENCES trials(nct_id) --  TODO (callaway: uncomment this foreign key constraint if/when we can be sure that
  --  all thesaurus entries will exist in our DB.  Currently, it's possible for abstractors
  --  to have access to NCIT concept codes that have not been released by EVS.
  --  CONSTRAINT trial_prior_therapies_ncit_fk FOREIGN KEY (nci_thesaurus_concept_id) REFERENCES ncit(code)
);

CREATE INDEX trial_prior_therapies_nct_id_idx ON trial_prior_therapies(nct_id);

CREATE INDEX trial_prior_therapies_nci_thesaurus_concept_id_idx ON trial_prior_therapies(nci_thesaurus_concept_id);

create view ncit_version_view as
select
  version_id,
  downloaded_url,
  transitive_closure_generation_date,
  ncit_tokenizer_generation_date,
  active_version
from
  ncit_version;

create table bad_ncit_syns (code varchar(100), syn_name text);

insert into
  bad_ncit_syns(code, syn_name)
values
  ('C116664', 'ECoG');

insert into
  bad_ncit_syns(code, syn_name)
values
  ('C161964', 'ECOG');

insert into
  criteria_types(
    criteria_type_id,
    criteria_type_code,
    criteria_type_title,
    criteria_type_desc,
    criteria_type_active,
    criteria_type_sense,
    criteria_column_index
  )
values
(1,'biomarker_exc','Biomarker Exclusion','Biomarker Exclusion','N','Exclusion',20),
(2,'biomarker_inc','Biomarker Inclusion','Biomarker Inclusion','N','Inclusion',30),
(3,'immunotherapy_exc','Immunotherapy Exclusion','Immunotherapy Exclusion','N','Exclusion',10),
(4,'chemotherapy_exc','Chemotherapy Exclusion','Chemotherapy Exclusion','N','Exclusion',40),
(5,'hiv_exc','HIV Exclusion','HIV Exclusion','Y','Exclusion',50),
(6,'plt','PLT','Platelets','Y','Inclusion',2010),
(7,'wbc','WBC','White Blood Count','Y','Inclusion',2020),
(8,'perf','Performance Status','Performance Status','Y','Inclusion',2030),
(11,'bmets','Brain Mets','brain mets','Y','Exclusion',60),
(12,'pt_inc','PT Inclusion','Prior therapy inclusion criteria (includes chemotherapy & immunotherapy)','Y','Inclusion',70),
(17,'surg','Prior Surgery','Prior therapy: surgery exclusion','N','Exclusion',50),
(18,'pt_exc','PT Exclusion','chemotherapy, immunotherapy','Y','Exclusion',80),
(19,'diseases_inc','Diseases Inclusion (NLP)','NLP derived diseases facts and expressions.','N','Inclusion',3),
(254,'BMI','BMI','BMI inclusion','N','Inclusion',1910),
(256,'hcv','Hepatitis C infection','Understood to be active Hepatitis C infection (C3098)','N','Exclusion',1930),
(255,'hbv','Hepatitis B infection','Understood as active HBV infection (C3097)','N','Exclusion',1920),
(257,'so_transplant','Solid Organ Transplant','Solid organ transplant (C15289)','N','Exclusion',1940),
(253,'swallow','Able to swallow','Trials where participants are ineligible due to inability to swallow (and not having NG or G tube)','N','Exclusion',1900),
(258,'seizures','Seizures','Coding for uncontrolled seizures, but using NCIt code for just "seizure" (C2962) -- search&match interface needs to specify that search criteria of seizure=yes means UNCONTROLLED seizures only','N','Exclusion',1950);
