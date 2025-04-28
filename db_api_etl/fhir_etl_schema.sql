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
-- Name: fhir_etl; Type: SCHEMA; Schema: -; Owner: secapp
--

CREATE SCHEMA fhir_etl;


ALTER SCHEMA fhir_etl OWNER TO secapp;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: condition; Type: TABLE; Schema: fhir_etl; Owner: secapp
--

CREATE TABLE fhir_etl.condition (
    id integer NOT NULL,
    patient_id integer NOT NULL,
    name text NOT NULL,
    condition_date timestamp without time zone,
    code character varying(256),
    code_scheme character varying(256),
    clinical_status text,
    cancer_related boolean
);


ALTER TABLE fhir_etl.condition OWNER TO secapp;

--
-- Name: condition_id_seq; Type: SEQUENCE; Schema: fhir_etl; Owner: secapp
--

CREATE SEQUENCE fhir_etl.condition_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fhir_etl.condition_id_seq OWNER TO secapp;

--
-- Name: condition_id_seq; Type: SEQUENCE OWNED BY; Schema: fhir_etl; Owner: secapp
--

ALTER SEQUENCE fhir_etl.condition_id_seq OWNED BY fhir_etl.condition.id;


--
-- Name: observation; Type: TABLE; Schema: fhir_etl; Owner: secapp
--

CREATE TABLE fhir_etl.observation (
    id integer NOT NULL,
    patient_id integer NOT NULL,
    observation_date timestamp without time zone,
    category character varying(256),
    code character varying(256),
    code_scheme character varying(256),
    display text,
    value character varying(256),
    unit character varying(64),
    cancer_related boolean
);


ALTER TABLE fhir_etl.observation OWNER TO secapp;

--
-- Name: observation_id_seq; Type: SEQUENCE; Schema: fhir_etl; Owner: secapp
--

CREATE SEQUENCE fhir_etl.observation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fhir_etl.observation_id_seq OWNER TO secapp;

--
-- Name: observation_id_seq; Type: SEQUENCE OWNED BY; Schema: fhir_etl; Owner: secapp
--

ALTER SEQUENCE fhir_etl.observation_id_seq OWNED BY fhir_etl.observation.id;


--
-- Name: patient; Type: TABLE; Schema: fhir_etl; Owner: secapp
--

CREATE TABLE fhir_etl.patient (
    id integer NOT NULL,
    fhir_id character varying(64) NOT NULL,
    name character varying(256) NOT NULL,
    gender character(1),
    dob timestamp without time zone,
    marital_status character(1),
    race character varying(256),
    ethnicity character varying(256)
);


ALTER TABLE fhir_etl.patient OWNER TO secapp;

--
-- Name: patient_id_seq; Type: SEQUENCE; Schema: fhir_etl; Owner: secapp
--

CREATE SEQUENCE fhir_etl.patient_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fhir_etl.patient_id_seq OWNER TO secapp;

--
-- Name: patient_id_seq; Type: SEQUENCE OWNED BY; Schema: fhir_etl; Owner: secapp
--

ALTER SEQUENCE fhir_etl.patient_id_seq OWNED BY fhir_etl.patient.id;


--
-- Name: procedure; Type: TABLE; Schema: fhir_etl; Owner: secapp
--

CREATE TABLE fhir_etl.procedure (
    id integer NOT NULL,
    patient_id integer NOT NULL,
    procedure_date timestamp without time zone,
    code character varying(256),
    code_scheme character varying(256),
    display text,
    cancer_related boolean
);


ALTER TABLE fhir_etl.procedure OWNER TO secapp;

--
-- Name: procedure_id_seq; Type: SEQUENCE; Schema: fhir_etl; Owner: secapp
--

CREATE SEQUENCE fhir_etl.procedure_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fhir_etl.procedure_id_seq OWNER TO secapp;

--
-- Name: procedure_id_seq; Type: SEQUENCE OWNED BY; Schema: fhir_etl; Owner: secapp
--

ALTER SEQUENCE fhir_etl.procedure_id_seq OWNED BY fhir_etl.procedure.id;


--
-- Name: condition id; Type: DEFAULT; Schema: fhir_etl; Owner: secapp
--

ALTER TABLE ONLY fhir_etl.condition ALTER COLUMN id SET DEFAULT nextval('fhir_etl.condition_id_seq'::regclass);


--
-- Name: observation id; Type: DEFAULT; Schema: fhir_etl; Owner: secapp
--

ALTER TABLE ONLY fhir_etl.observation ALTER COLUMN id SET DEFAULT nextval('fhir_etl.observation_id_seq'::regclass);


--
-- Name: patient id; Type: DEFAULT; Schema: fhir_etl; Owner: secapp
--

ALTER TABLE ONLY fhir_etl.patient ALTER COLUMN id SET DEFAULT nextval('fhir_etl.patient_id_seq'::regclass);


--
-- Name: procedure id; Type: DEFAULT; Schema: fhir_etl; Owner: secapp
--

ALTER TABLE ONLY fhir_etl.procedure ALTER COLUMN id SET DEFAULT nextval('fhir_etl.procedure_id_seq'::regclass);


--
-- Name: condition condition_pkey; Type: CONSTRAINT; Schema: fhir_etl; Owner: secapp
--

ALTER TABLE ONLY fhir_etl.condition
    ADD CONSTRAINT condition_pkey PRIMARY KEY (id);


--
-- Name: observation observation_pkey; Type: CONSTRAINT; Schema: fhir_etl; Owner: secapp
--

ALTER TABLE ONLY fhir_etl.observation
    ADD CONSTRAINT observation_pkey PRIMARY KEY (id);


--
-- Name: patient patient_fhir_id_key; Type: CONSTRAINT; Schema: fhir_etl; Owner: secapp
--

ALTER TABLE ONLY fhir_etl.patient
    ADD CONSTRAINT patient_fhir_id_key UNIQUE (fhir_id);


--
-- Name: patient patient_pkey; Type: CONSTRAINT; Schema: fhir_etl; Owner: secapp
--

ALTER TABLE ONLY fhir_etl.patient
    ADD CONSTRAINT patient_pkey PRIMARY KEY (id);


--
-- Name: procedure procedure_pkey; Type: CONSTRAINT; Schema: fhir_etl; Owner: secapp
--

ALTER TABLE ONLY fhir_etl.procedure
    ADD CONSTRAINT procedure_pkey PRIMARY KEY (id);


--
-- Name: condition_date_idx; Type: INDEX; Schema: fhir_etl; Owner: secapp
--

CREATE INDEX condition_date_idx ON fhir_etl.condition USING btree (condition_date);


--
-- Name: condition_patient_id_idx; Type: INDEX; Schema: fhir_etl; Owner: secapp
--

CREATE INDEX condition_patient_id_idx ON fhir_etl.condition USING btree (patient_id);


--
-- Name: observation_date_idx; Type: INDEX; Schema: fhir_etl; Owner: secapp
--

CREATE INDEX observation_date_idx ON fhir_etl.observation USING btree (observation_date);


--
-- Name: observation_patient_id_idx; Type: INDEX; Schema: fhir_etl; Owner: secapp
--

CREATE INDEX observation_patient_id_idx ON fhir_etl.observation USING btree (patient_id);


--
-- Name: procedure_date_idx; Type: INDEX; Schema: fhir_etl; Owner: secapp
--

CREATE INDEX procedure_date_idx ON fhir_etl.procedure USING btree (procedure_date);


--
-- Name: procedure_patient_id_idx; Type: INDEX; Schema: fhir_etl; Owner: secapp
--

CREATE INDEX procedure_patient_id_idx ON fhir_etl.procedure USING btree (patient_id);


--
-- Name: condition condition_patient_fk; Type: FK CONSTRAINT; Schema: fhir_etl; Owner: secapp
--

ALTER TABLE ONLY fhir_etl.condition
    ADD CONSTRAINT condition_patient_fk FOREIGN KEY (patient_id) REFERENCES fhir_etl.patient(id) ON DELETE CASCADE;


--
-- Name: observation observation_patient_fk; Type: FK CONSTRAINT; Schema: fhir_etl; Owner: secapp
--

ALTER TABLE ONLY fhir_etl.observation
    ADD CONSTRAINT observation_patient_fk FOREIGN KEY (patient_id) REFERENCES fhir_etl.patient(id) ON DELETE CASCADE;


--
-- Name: procedure procedure_patient_fk; Type: FK CONSTRAINT; Schema: fhir_etl; Owner: secapp
--

ALTER TABLE ONLY fhir_etl.procedure
    ADD CONSTRAINT procedure_patient_fk FOREIGN KEY (patient_id) REFERENCES fhir_etl.patient(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

