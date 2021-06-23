BEGIN TRANSACTION;
create table criteria_types_bak_06_2021 as select * from criteria_types;

INSERT INTO criteria_types VALUES(1,'biomarker_exc','Biomarker Exclusion','Biomarker Exclusion','Y','Exclusion',20);
INSERT INTO criteria_types VALUES(2,'biomarker_inc','Biomarker Inclusion','Biomarker Inclusion','Y','Inclusion',30);
INSERT INTO criteria_types VALUES(3,'immunotherapy_exc','Immunotherapy Exclusion','Immunotherapy Exclusion','N','Exclusion',10);
INSERT INTO criteria_types VALUES(4,'chemotherapy_exc','Chemotherapy Exclusion','Chemotherapy Exclusion','N','Exclusion',40);
INSERT INTO criteria_types VALUES(5,'hiv_exc','HIV Exclusion','HIV Exclusion','Y','Exclusion',50);
INSERT INTO criteria_types VALUES(6,'plt','PLT','Platelets','Y','Inclusion',2010);
INSERT INTO criteria_types VALUES(7,'wbc','WBC','White Blood Count','Y','Inclusion',2020);
INSERT INTO criteria_types VALUES(8,'perf','Performance Status','Performance Status','Y','Inclusion',2030);
INSERT INTO criteria_types VALUES(11,'bmets','Brain Mets','brain mets','Y','Exclusion',60);
INSERT INTO criteria_types VALUES(12,'pt_inc','PT Inclusion','Prior therapy inclusion criteria (includes chemotherapy & immunotherapy)','Y','Inclusion',70);
INSERT INTO criteria_types VALUES(17,'surg','Prior Surgery','Prior therapy: surgery exclusion','N','Exclusion',50);
INSERT INTO criteria_types VALUES(18,'pt_exc','PT Exclusion','chemotherapy, immunotherapy','Y','Exclusion',80);
COMMIT;
