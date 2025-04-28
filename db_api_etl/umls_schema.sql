--
-- PostgreSQL database dump
--

-- Dumped from database version 16.4
-- Dumped by pg_dump version 16.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: umls; Type: SCHEMA; Schema: -; Owner: secapp
--

CREATE SCHEMA umls;


ALTER SCHEMA umls OWNER TO secapp;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: comp_parents; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.comp_parents (
    parent text,
    concept text,
    level integer,
    path text
);


ALTER TABLE umls.comp_parents OWNER TO secapp;

--
-- Name: curated_crosswalk; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.curated_crosswalk (
    index bigint,
    identifier bigint,
    code_system text,
    disease_code text,
    preferred_name text,
    evs_nci_code text,
    corrected_preferred_name_for_icd9 text,
    date_last_created text,
    date_last_updated text,
    site_code text,
    site_name text,
    disease_code_site_code text,
    evs_preferred_name text,
    comments text
);


ALTER TABLE umls.curated_crosswalk OWNER TO secapp;

--
-- Name: mrcols; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.mrcols (
    col text,
    des text,
    ref double precision,
    min bigint,
    av double precision,
    max bigint,
    fil text,
    dty text
);


ALTER TABLE umls.mrcols OWNER TO secapp;

--
-- Name: mrconso; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.mrconso (
    cui character(8),
    lat character(3),
    ts character(1),
    lui character varying(10),
    stt character varying(3),
    sui character varying(10),
    ispref character(1),
    aui character varying(9),
    saui character varying(100),
    scui character varying(100),
    sdui character varying(100),
    sab character varying(40),
    tty character varying(20),
    code character varying(100),
    str character varying(3000),
    srl integer,
    suppress character(1),
    cvf character varying(50)
);


ALTER TABLE umls.mrconso OWNER TO secapp;

--
-- Name: mrdef; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.mrdef (
    cui character(8),
    aui character varying(9),
    atui character varying(11),
    satui character varying(50),
    sab character varying(40),
    def character varying(16000),
    suppress character(1),
    cvf character varying(50)
);


ALTER TABLE umls.mrdef OWNER TO secapp;

--
-- Name: mrdoc; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.mrdoc (
    dockey text,
    value text,
    type text,
    expl text
);


ALTER TABLE umls.mrdoc OWNER TO secapp;

--
-- Name: mrfiles; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.mrfiles (
    fil text,
    des text,
    fmt text,
    cls bigint,
    rws bigint,
    bts bigint
);


ALTER TABLE umls.mrfiles OWNER TO secapp;

--
-- Name: mrhier; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.mrhier (
    cui character(8),
    aui character varying(9),
    cxn integer,
    paui character varying(9),
    sab character varying(40),
    rela character varying(100),
    ptr character varying(1000),
    hcd character varying(100),
    cvf character varying(50)
);


ALTER TABLE umls.mrhier OWNER TO secapp;

--
-- Name: mrrel; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.mrrel (
    cui1 character(8),
    aui1 character varying(9),
    stype1 character varying(50),
    rel character varying(4),
    cui2 character(8),
    aui2 character varying(9),
    stype2 character varying(50),
    rela character varying(100),
    rui character varying(10),
    srui character varying(50),
    sab character varying(40),
    sl character varying(40),
    rg character varying(10),
    dir character varying(1),
    suppress character(1),
    cvf character varying(50)
);


ALTER TABLE umls.mrrel OWNER TO secapp;

--
-- Name: ncit; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.ncit (
    index bigint,
    code text,
    url text,
    parents text,
    synonyms text,
    definition text,
    display_name text,
    concept_status text,
    semantic_type text,
    pref_name text
);


ALTER TABLE umls.ncit OWNER TO secapp;

--
-- Name: ncit_tc_all; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.ncit_tc_all (
    parent text,
    descendant text
);


ALTER TABLE umls.ncit_tc_all OWNER TO secapp;

--
-- Name: ncit_tc_with_path_all; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.ncit_tc_with_path_all (
    parent text,
    descendant text,
    level integer,
    path text
);


ALTER TABLE umls.ncit_tc_with_path_all OWNER TO secapp;

--
-- Name: ncit_tc_with_path_comp; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.ncit_tc_with_path_comp (
    parent text,
    descendant text,
    level integer,
    path text
);


ALTER TABLE umls.ncit_tc_with_path_comp OWNER TO secapp;

--
-- Name: ncit_tc_with_path_icd10cm; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.ncit_tc_with_path_icd10cm (
    parent text,
    descendant text,
    level integer,
    path text
);


ALTER TABLE umls.ncit_tc_with_path_icd10cm OWNER TO secapp;

--
-- Name: ncit_tc_with_path_loinc; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.ncit_tc_with_path_loinc (
    parent text,
    descendant text,
    level integer,
    path text
);


ALTER TABLE umls.ncit_tc_with_path_loinc OWNER TO secapp;

--
-- Name: ncit_tc_with_path_ncit; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.ncit_tc_with_path_ncit (
    parent text,
    descendant text,
    level integer,
    path text
);


ALTER TABLE umls.ncit_tc_with_path_ncit OWNER TO secapp;

--
-- Name: ncit_tc_with_path_snomedct; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.ncit_tc_with_path_snomedct (
    parent text,
    descendant text,
    level integer,
    path text
);


ALTER TABLE umls.ncit_tc_with_path_snomedct OWNER TO secapp;

--
-- Name: ncit_version_composite; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.ncit_version_composite (
    version_id character varying(32),
    downloaded_url text,
    active_version character varying(1),
    composite_ontology_generation_date text
);


ALTER TABLE umls.ncit_version_composite OWNER TO secapp;

--
-- Name: parents; Type: TABLE; Schema: umls; Owner: secapp
--

CREATE TABLE umls.parents (
    concept text,
    parent text,
    path text,
    level integer
);


ALTER TABLE umls.parents OWNER TO secapp;

--
-- Name: cc_code_system_idx; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX cc_code_system_idx ON umls.curated_crosswalk USING btree (code_system);


--
-- Name: conso_aui; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX conso_aui ON umls.mrconso USING btree (aui);


--
-- Name: hier_aui; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX hier_aui ON umls.mrhier USING btree (aui);


--
-- Name: hier_paui; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX hier_paui ON umls.mrhier USING btree (paui);


--
-- Name: hier_sab; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX hier_sab ON umls.mrhier USING btree (sab);


--
-- Name: ix_curated_crosswalk_index; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX ix_curated_crosswalk_index ON umls.curated_crosswalk USING btree (index);


--
-- Name: ix_ncit_index; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX ix_ncit_index ON umls.ncit USING btree (index);


--
-- Name: lower_pref_name_idx; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX lower_pref_name_idx ON umls.ncit USING btree (lower(pref_name));


--
-- Name: mrconso_cui; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX mrconso_cui ON umls.mrconso USING btree (cui);


--
-- Name: ncit_code_index; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX ncit_code_index ON umls.ncit USING btree (code);


--
-- Name: ncit_tc_parent_all; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX ncit_tc_parent_all ON umls.ncit_tc_all USING btree (parent);


--
-- Name: ncit_tc_path_descendant; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX ncit_tc_path_descendant ON umls.ncit_tc_with_path_all USING btree (descendant);


--
-- Name: ncit_tc_path_parent; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX ncit_tc_path_parent ON umls.ncit_tc_with_path_all USING btree (parent);


--
-- Name: par_concept_idx; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX par_concept_idx ON umls.parents USING btree (concept);


--
-- Name: par_par_idx; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX par_par_idx ON umls.parents USING btree (parent);


--
-- Name: rel_cui1; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX rel_cui1 ON umls.mrrel USING btree (cui1);


--
-- Name: rel_cui2; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX rel_cui2 ON umls.mrrel USING btree (cui2);


--
-- Name: tc_desc_all_index; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX tc_desc_all_index ON umls.ncit_tc_all USING btree (descendant);


--
-- Name: tc_parent_all_index; Type: INDEX; Schema: umls; Owner: secapp
--

CREATE INDEX tc_parent_all_index ON umls.ncit_tc_all USING btree (parent);


--
-- PostgreSQL database dump complete
--

