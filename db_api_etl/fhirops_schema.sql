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
-- Name: fhirops; Type: SCHEMA; Schema: -; Owner: secapp
--

CREATE SCHEMA fhirops;


ALTER SCHEMA fhirops OWNER TO secapp;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: fhirops; Owner: secapp
--

CREATE TABLE fhirops.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE fhirops.ar_internal_metadata OWNER TO secapp;

--
-- Name: authentications; Type: TABLE; Schema: fhirops; Owner: secapp
--

CREATE TABLE fhirops.authentications (
    id bigint NOT NULL,
    access_token character varying,
    token_type character varying,
    expires_at timestamp without time zone,
    scope character varying,
    id_token character varying,
    state character varying,
    patient character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    oauth_callback_id bigint
);


ALTER TABLE fhirops.authentications OWNER TO secapp;

--
-- Name: authentications_id_seq; Type: SEQUENCE; Schema: fhirops; Owner: secapp
--

CREATE SEQUENCE fhirops.authentications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fhirops.authentications_id_seq OWNER TO secapp;

--
-- Name: authentications_id_seq; Type: SEQUENCE OWNED BY; Schema: fhirops; Owner: secapp
--

ALTER SEQUENCE fhirops.authentications_id_seq OWNED BY fhirops.authentications.id;


--
-- Name: foobar; Type: TABLE; Schema: fhirops; Owner: secapp
--

CREATE TABLE fhirops.foobar (
    v1 integer
);


ALTER TABLE fhirops.foobar OWNER TO secapp;

--
-- Name: jobs; Type: TABLE; Schema: fhirops; Owner: secapp
--

CREATE TABLE fhirops.jobs (
    id character varying NOT NULL,
    search_session_id character varying,
    username character varying,
    percent_done double precision,
    total_steps integer,
    current_step integer,
    current_step_name character varying,
    job_type character varying,
    status integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE fhirops.jobs OWNER TO secapp;

--
-- Name: ncit_tc_all; Type: TABLE; Schema: fhirops; Owner: secapp
--

CREATE TABLE fhirops.ncit_tc_all (
    parent text,
    descendant text
);


ALTER TABLE fhirops.ncit_tc_all OWNER TO secapp;

--
-- Name: ncit_tc_with_path_all; Type: TABLE; Schema: fhirops; Owner: secapp
--

CREATE TABLE fhirops.ncit_tc_with_path_all (
    parent text,
    descendant text,
    level integer,
    path text
);


ALTER TABLE fhirops.ncit_tc_with_path_all OWNER TO secapp;

--
-- Name: oauth_callbacks; Type: TABLE; Schema: fhirops; Owner: secapp
--

CREATE TABLE fhirops.oauth_callbacks (
    id bigint NOT NULL,
    verified_state boolean,
    code character varying,
    state character varying,
    oauth_url character varying,
    response_body_raw character varying,
    response_code integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE fhirops.oauth_callbacks OWNER TO secapp;

--
-- Name: oauth_callbacks_id_seq; Type: SEQUENCE; Schema: fhirops; Owner: secapp
--

CREATE SEQUENCE fhirops.oauth_callbacks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fhirops.oauth_callbacks_id_seq OWNER TO secapp;

--
-- Name: oauth_callbacks_id_seq; Type: SEQUENCE OWNED BY; Schema: fhirops; Owner: secapp
--

ALTER SEQUENCE fhirops.oauth_callbacks_id_seq OWNED BY fhirops.oauth_callbacks.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: fhirops; Owner: secapp
--

CREATE TABLE fhirops.schema_migrations (
    version character varying NOT NULL
);


ALTER TABLE fhirops.schema_migrations OWNER TO secapp;

--
-- Name: search_session; Type: TABLE; Schema: fhirops; Owner: secapp
--

CREATE TABLE fhirops.search_session (
    session_uuid character varying NOT NULL,
    submit_date character varying,
    nodename character varying DEFAULT 'VA Lighthouse'::character varying,
    username character varying
);


ALTER TABLE fhirops.search_session OWNER TO secapp;

--
-- Name: search_session_data; Type: TABLE; Schema: fhirops; Owner: secapp
--

CREATE TABLE fhirops.search_session_data (
    id bigint NOT NULL,
    search_session_id character varying,
    session_uuid character varying,
    concept_cd character varying,
    original_concept_cd character varying,
    valtype_cd character varying,
    tval_char character varying,
    nval_num double precision,
    units_cd character varying,
    comment character varying
);


ALTER TABLE fhirops.search_session_data OWNER TO secapp;

--
-- Name: search_session_data_id_seq; Type: SEQUENCE; Schema: fhirops; Owner: secapp
--

CREATE SEQUENCE fhirops.search_session_data_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fhirops.search_session_data_id_seq OWNER TO secapp;

--
-- Name: search_session_data_id_seq; Type: SEQUENCE OWNED BY; Schema: fhirops; Owner: secapp
--

ALTER SEQUENCE fhirops.search_session_data_id_seq OWNED BY fhirops.search_session_data.id;


--
-- Name: authentications id; Type: DEFAULT; Schema: fhirops; Owner: secapp
--

ALTER TABLE ONLY fhirops.authentications ALTER COLUMN id SET DEFAULT nextval('fhirops.authentications_id_seq'::regclass);


--
-- Name: oauth_callbacks id; Type: DEFAULT; Schema: fhirops; Owner: secapp
--

ALTER TABLE ONLY fhirops.oauth_callbacks ALTER COLUMN id SET DEFAULT nextval('fhirops.oauth_callbacks_id_seq'::regclass);


--
-- Name: search_session_data id; Type: DEFAULT; Schema: fhirops; Owner: secapp
--

ALTER TABLE ONLY fhirops.search_session_data ALTER COLUMN id SET DEFAULT nextval('fhirops.search_session_data_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: fhirops; Owner: secapp
--

ALTER TABLE ONLY fhirops.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: authentications authentications_pkey; Type: CONSTRAINT; Schema: fhirops; Owner: secapp
--

ALTER TABLE ONLY fhirops.authentications
    ADD CONSTRAINT authentications_pkey PRIMARY KEY (id);


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: fhirops; Owner: secapp
--

ALTER TABLE ONLY fhirops.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- Name: oauth_callbacks oauth_callbacks_pkey; Type: CONSTRAINT; Schema: fhirops; Owner: secapp
--

ALTER TABLE ONLY fhirops.oauth_callbacks
    ADD CONSTRAINT oauth_callbacks_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: fhirops; Owner: secapp
--

ALTER TABLE ONLY fhirops.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: search_session_data search_session_data_pkey; Type: CONSTRAINT; Schema: fhirops; Owner: secapp
--

ALTER TABLE ONLY fhirops.search_session_data
    ADD CONSTRAINT search_session_data_pkey PRIMARY KEY (id);


--
-- Name: search_session search_session_pkey; Type: CONSTRAINT; Schema: fhirops; Owner: secapp
--

ALTER TABLE ONLY fhirops.search_session
    ADD CONSTRAINT search_session_pkey PRIMARY KEY (session_uuid);


--
-- Name: fhirops_tc_all_descendant; Type: INDEX; Schema: fhirops; Owner: secapp
--

CREATE INDEX fhirops_tc_all_descendant ON fhirops.ncit_tc_all USING btree (descendant);


--
-- Name: fhirops_tc_all_parent; Type: INDEX; Schema: fhirops; Owner: secapp
--

CREATE INDEX fhirops_tc_all_parent ON fhirops.ncit_tc_all USING btree (parent);


--
-- Name: index_authentications_on_oauth_callback_id; Type: INDEX; Schema: fhirops; Owner: secapp
--

CREATE INDEX index_authentications_on_oauth_callback_id ON fhirops.authentications USING btree (oauth_callback_id);


--
-- Name: index_jobs_on_search_session_id; Type: INDEX; Schema: fhirops; Owner: secapp
--

CREATE INDEX index_jobs_on_search_session_id ON fhirops.jobs USING btree (search_session_id);


--
-- Name: index_search_session_data_on_search_session_id; Type: INDEX; Schema: fhirops; Owner: secapp
--

CREATE INDEX index_search_session_data_on_search_session_id ON fhirops.search_session_data USING btree (search_session_id);


--
-- Name: ncit_tc_path_all_descendant; Type: INDEX; Schema: fhirops; Owner: secapp
--

CREATE INDEX ncit_tc_path_all_descendant ON fhirops.ncit_tc_with_path_all USING btree (descendant);


--
-- Name: ncit_tc_path_all_parent; Type: INDEX; Schema: fhirops; Owner: secapp
--

CREATE INDEX ncit_tc_path_all_parent ON fhirops.ncit_tc_with_path_all USING btree (parent);


--
-- Name: authentications fk_rails_41fdce0738; Type: FK CONSTRAINT; Schema: fhirops; Owner: secapp
--

ALTER TABLE ONLY fhirops.authentications
    ADD CONSTRAINT fk_rails_41fdce0738 FOREIGN KEY (oauth_callback_id) REFERENCES fhirops.oauth_callbacks(id);


--
-- PostgreSQL database dump complete
--

