/***************************************************************/
/*** Pulling in sales since Jan 2024. Calculating their LTV. ***/
/******** Exporting to BISS server for digital to use. *********/
/***************************************************************/

/*** Uncomment lines at the import section (row 23) and the PLE join (row 157) when a new quarterly PLE file is available. ***/

/*Current date & time*/
/*%let StartTime = %sysfunc(datetime(), datetime20.);*/

/*** BIT rep rate per minute from Chandan ***/
%let RatePerMin2024 = 2.3;
%let RatePerMin2025 = 2.5;
/*** Bundle and extend rate from Control (Joe Geng) ***/
%let BundleExtend2024 = 70;
%let BundleExtend2025 = 78;

/*** Making variable names for PLE files. ***/
%let Q4_2026 = 202611; %let Q3_2026 = 202608; %let Q2_2026 = 202605; %let Q1_2026 = 202602;
%let Q4_2025 = 202511; %let Q3_2025 = 202508; %let Q2_2025 = 202505; %let Q1_2025 = 202502;
%let Q4_2024 = 202411; %let Q3_2024 = 202408; %let Q2_2024 = 202405; %let Q1_2024 = 202402;

/*** Import PLE by carrier & product, PLE state relativity, and PLE BECA relativity ***/
/************************ Uncomment file import when applicable ***********************/
/*Q2 2025*//*PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q2_2025..xlsx" 
	dbms=xlsx REPLACE OUT = CarrierProductPLE&Q2_2025 (KEEP = Product Carrier PLE); SHEET = "CarrierProduct"; RUN;
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q2_2025..xlsx"
	dbms=xlsx REPLACE OUT = StateRelativity&Q2_2025 (KEEP = State StateRelativity); SHEET = "State"; RUN;
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q2_2025..xlsx"
	dbms=xlsx REPLACE OUT = BECARelativity&Q2_2025 (KEEP = BECA BECARelativity); SHEET = "BECA"; RUN;*/
/*Q3 2025*//*PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q3_2025..xlsx" 
	dbms=xlsx REPLACE OUT = CarrierProductPLE&Q3_2025 (KEEP = Product Carrier PLE); SHEET = "CarrierProduct"; RUN;
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q3_2025..xlsx"
	dbms=xlsx REPLACE OUT = StateRelativity&Q3_2025 (KEEP = State StateRelativity); SHEET = "State"; RUN;
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q3_2025..xlsx"
	dbms=xlsx REPLACE OUT = BECARelativity&Q3_2025 (KEEP = BECA BECARelativity); SHEET = "BECA"; RUN;*/
/*Q4 2025*//*PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q4_2025..xlsx" 
	dbms=xlsx REPLACE OUT = CarrierProductPLE&Q4_2025 (KEEP = Product Carrier PLE); SHEET = "CarrierProduct"; RUN;
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q4_2025..xlsx"
	dbms=xlsx REPLACE OUT = StateRelativity&Q4_2025 (KEEP = State StateRelativity); SHEET = "State"; RUN;
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q4_2025..xlsx"
	dbms=xlsx REPLACE OUT = BECARelativity&Q4_2025 (KEEP = BECA BECARelativity); SHEET = "BECA"; RUN;*/
/*Q1 2026*//*PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q1_2026..xlsx" 
	dbms=xlsx REPLACE OUT = CarrierProductPLE&Q1_2026 (KEEP = Product Carrier PLE); SHEET = "CarrierProduct"; RUN;
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q1_2026..xlsx"
	dbms=xlsx REPLACE OUT = StateRelativity&Q1_2026 (KEEP = State StateRelativity); SHEET = "State"; RUN;
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q1_2026..xlsx"
	dbms=xlsx REPLACE OUT = BECARelativity&Q1_2026 (KEEP = BECA BECARelativity); SHEET = "BECA"; RUN;*/
/*Q2 2026*//*PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q2_2026..xlsx" 
	dbms=xlsx REPLACE OUT = CarrierProductPLE&Q2_2026 (KEEP = Product Carrier PLE); SHEET = "CarrierProduct"; RUN;
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q2_2026..xlsx"
	dbms=xlsx REPLACE OUT = StateRelativity&Q2_2026 (KEEP = State StateRelativity); SHEET = "State"; RUN;
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q2_2026..xlsx"
	dbms=xlsx REPLACE OUT = BECARelativity&Q2_2026 (KEEP = BECA BECARelativity); SHEET = "BECA"; RUN;*/
/*Q3 2026*//*PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q3_2026..xlsx" 
	dbms=xlsx REPLACE OUT = CarrierProductPLE&Q3_2026 (KEEP = Product Carrier PLE); SHEET = "CarrierProduct"; RUN;
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q3_2026..xlsx"
	dbms=xlsx REPLACE OUT = StateRelativity&Q3_2026 (KEEP = State StateRelativity); SHEET = "State"; RUN;
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q3_2026..xlsx"
	dbms=xlsx REPLACE OUT = BECARelativity&Q3_2026 (KEEP = BECA BECARelativity); SHEET = "BECA"; RUN;*/
/*Q4 2026*//*PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q4_2026..xlsx" 
	dbms=xlsx REPLACE OUT = CarrierProductPLE&Q4_2026 (KEEP = Product Carrier PLE); SHEET = "CarrierProduct"; RUN;
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q4_2026..xlsx"
	dbms=xlsx REPLACE OUT = StateRelativity&Q4_2026 (KEEP = State StateRelativity); SHEET = "State"; RUN;
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q4_2026..xlsx"
	dbms=xlsx REPLACE OUT = BECARelativity&Q4_2026 (KEEP = BECA BECARelativity); SHEET = "BECA"; RUN;*/

PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q1_2025..xlsx"
	dbms=xlsx REPLACE OUT = CarrierProductPLE&Q1_2025 (KEEP = Product Carrier PLE); SHEET = "CarrierProduct"; RUN;

PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q1_2025..xlsx"
	dbms=xlsx REPLACE OUT = StateRelativity&Q1_2025 (KEEP = State StateRelativity); SHEET = "State"; RUN;

PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q1_2025..xlsx"
	dbms=xlsx REPLACE OUT = BECARelativity&Q1_2025 (KEEP = BECA BECARelativity); SHEET = "BECA"; RUN;

PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q4_2024..xlsx" 
	dbms=xlsx REPLACE OUT = CarrierProductPLE&Q4_2024 (KEEP = Product Carrier PLE); SHEET = "CarrierProduct"; RUN;

PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q4_2024..xlsx"
	dbms=xlsx REPLACE OUT = StateRelativity&Q4_2024 (KEEP = State StateRelativity); SHEET = "State"; RUN;

PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q4_2024..xlsx"
	dbms=xlsx REPLACE OUT = BECARelativity&Q4_2024 (KEEP = BECA BECARelativity); SHEET = "BECA"; RUN;

PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q3_2024..xlsx"
	dbms=xlsx REPLACE OUT = CarrierProductPLE&Q3_2024 (KEEP = Product Carrier PLE); SHEET = "CarrierProduct"; RUN;

PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q3_2024..xlsx"
	dbms=xlsx REPLACE OUT = StateRelativity&Q3_2024 (KEEP = State StateRelativity); SHEET = "State"; RUN;

PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q3_2024..xlsx"
	dbms=xlsx REPLACE OUT = BECARelativity&Q3_2024 (KEEP = BECA BECARelativity); SHEET = "BECA"; RUN;

PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q2_2024..xlsx"
	dbms=xlsx REPLACE OUT = CarrierProductPLE&Q2_2024 (KEEP = Product Carrier PLE); SHEET = "CarrierProduct"; RUN;

PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q2_2024..xlsx"
	dbms=xlsx REPLACE OUT = StateRelativity&Q2_2024 (KEEP = State StateRelativity); SHEET = "State"; RUN;

PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q2_2024..xlsx"
	dbms=xlsx REPLACE OUT = BECARelativity&Q2_2024 (KEEP = BECA BECARelativity); SHEET = "BECA"; RUN;

PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q1_2024..xlsx"
	dbms=xlsx REPLACE OUT = CarrierProductPLE&Q1_2024 (KEEP = Product Carrier PLE); SHEET = "CarrierProduct"; RUN;

PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q1_2024..xlsx"
	dbms=xlsx REPLACE OUT = StateRelativity&Q1_2024 (KEEP = State StateRelativity); SHEET = "State"; RUN;

PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE &Q1_2024..xlsx"
	dbms=xlsx REPLACE OUT = BECARelativity&Q1_2024 (KEEP = BECA BECARelativity); SHEET = "BECA"; RUN;


/*** Import commission table in to get commission rates for each carrier ***/
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/General Agency/Accounting/A-R Files/A_R Commission Table_MASTER_test.xlsx"
	dbms=xlsx REPLACE OUT = COMMISSION_TBL (KEEP = COMMISSIONKEY STATE CARRIER CARRIER2 PRODUCT TRANS_CD COMM_RT AGENT_RT TIER);
	SHEET = "COMMISSION MASTER";
RUN;


/*** Grabbing quotes/sales since 202401 from SF's Holistic Funnel ***/
PROC SQL;
%sf_ref_acs_tok(warehouse=FREE_THE_DATA_S);
CREATE TABLE RecentSales AS SELECT * FROM CONNECTION TO ODBC
(SELECT H.UNIQENTITY,
	H.UNIQPOLICY,
	H.UNIQORIGINALPOLICY,
	H.QUOTENUMBER,
	case when H.PRODUCTCODE like 'BOP%' then 'BOP'
		when H.PRODUCTCODE like '%GL' then 'GL'
		when H.PRODUCTCODE like 'PL%' then 'PL'
		when H.PRODUCTCODE like 'WC%' then 'WCOM'
		when H.PRODUCTCODE = 'Website' then 'GL'
	else 'Other' end as PRODUCTCODE,
	case when H.PARTNERCARRIER in ('AmTrust','Arch','CNA','Evanston','Hiscox','Homesite','Liberty Mutual',
		'Markel','Nationwide','Progressive') then H.PARTNERCARRIER
	else 'Other' end as PARTNERCARRIER,
	H.BECAINTENT,
	H.PROGRESSIVEBUSINESSVERTICALS,
	H.STATECODE,
	cast(H.EFFECTIVEDATE as date) as EFFECTIVEDATE,
	cast(H.EXPIRATIONDATE as date) as EXPIRATIONDATE,
	/*cast(H.COHBEGINDATE as date) as COHBEGINDATE,
	cast(H.COHENDDATE as date) as COHENDDATE,*/
	cast(H.TOTALWRITTENPREMIUM as decimal(12,2)) as TOTALWRITTENPREMIUM,
	H.POLICYTERM,
	H.CARRIERCODE,
	H.QUOTECREATEDDATE,
	to_number(H.EFFECTIVEMONTH) as EFFECTIVEMONTH
FROM CL_SBI.PUBLISHED.BIT_HOLISTICFUNNEL_VW H
WHERE to_number(H.EFFECTIVEMONTH) >= 202401
	AND H.EFFECTIVEDATE < current_date()
	AND H.SALECNT = 1);
QUIT;

/*** Joining on the most recent PLE and relativity values ***/
PROC SQL;
CREATE TABLE RecentSales2 AS
SELECT B.*,
	B.CONTROLPLE * B.STATERELATIVITY * B.BECARELATIVITY as ADJUSTEDPLE,
	cat(strip(B.CARRIERCODE),strip(B.CARRIERCODE),'N','1') as COMMISSIONKEY,
	cat(strip(B.CARRIERCODE),strip(B.CARRIERCODE),'R','1') as RENEWALCOMMISSIONKEY
FROM (
	SELECT B.*,
		case /*when B.EFFECTIVEMONTH >= &Q4_2026 then C&Q4_2026..PLE
			when B.EFFECTIVEMONTH >= &Q3_2026 and B.EFFECTIVEMONTH < &Q4_2026 then C&Q3_2026..PLE
			when B.EFFECTIVEMONTH >= &Q2_2026 and B.EFFECTIVEMONTH < &Q3_2026 then C&Q2_2026..PLE
			when B.EFFECTIVEMONTH >= &Q1_2026 and B.EFFECTIVEMONTH < &Q2_2026 then C&Q1_2026..PLE
			when B.EFFECTIVEMONTH >= &Q4_2025 and B.EFFECTIVEMONTH < &Q1_2026 then C&Q4_2025..PLE
			when B.EFFECTIVEMONTH >= &Q3_2025 and B.EFFECTIVEMONTH < &Q4_2025 then C&Q3_2025..PLE
			when B.EFFECTIVEMONTH >= &Q2_2025 and B.EFFECTIVEMONTH < &Q3_2025 then C&Q2_2025..PLE*/
			when B.EFFECTIVEMONTH >= &Q1_2025 /*and B.EFFECTIVEMONTH < &Q2_2025*/ then C&Q1_2025..PLE
			when B.EFFECTIVEMONTH >= &Q4_2024 and B.EFFECTIVEMONTH < &Q1_2025 then C&Q4_2024..PLE
			when B.EFFECTIVEMONTH >= &Q3_2024 and B.EFFECTIVEMONTH < &Q4_2024 then C&Q3_2024..PLE
			when B.EFFECTIVEMONTH >= &Q2_2024 and B.EFFECTIVEMONTH < &Q3_2024 then C&Q2_2024..PLE
			when B.EFFECTIVEMONTH < &Q2_2024 then C&Q1_2024..PLE
		else 0 end as CONTROLPLE,
		case /*when B.EFFECTIVEMONTH >= &Q4_2026 AND SR&Q4_2026..STATERELATIVITY is not null then SR&Q4_2026..STATERELATIVITY
			when B.EFFECTIVEMONTH >= &Q3_2026 and B.EFFECTIVEMONTH < &Q4_2026 AND SR&Q3_2026..STATERELATIVITY is not null then SR&Q3_2026..STATERELATIVITY
			when B.EFFECTIVEMONTH >= &Q2_2026 and B.EFFECTIVEMONTH < &Q3_2026 AND SR&Q2_2026..STATERELATIVITY is not null then SR&Q2_2026..STATERELATIVITY
			when B.EFFECTIVEMONTH >= &Q1_2026 and B.EFFECTIVEMONTH < &Q2_2026 AND SR&Q1_2026..STATERELATIVITY is not null then SR&Q1_2026..STATERELATIVITY
			when B.EFFECTIVEMONTH >= &Q4_2025 and B.EFFECTIVEMONTH < &Q1_2026 AND SR&Q4_2025..STATERELATIVITY is not null then SR&Q4_2025..STATERELATIVITY
			when B.EFFECTIVEMONTH >= &Q3_2025 and B.EFFECTIVEMONTH < &Q4_2025 AND SR&Q3_2025..STATERELATIVITY is not null then SR&Q3_2025..STATERELATIVITY
			when B.EFFECTIVEMONTH >= &Q2_2025 and B.EFFECTIVEMONTH < &Q3_2025 AND SR&Q2_2025..STATERELATIVITY is not null then SR&Q2_2025..STATERELATIVITY*/
			when B.EFFECTIVEMONTH >= &Q1_2025 /*and B.EFFECTIVEMONTH < &Q2_2025*/ AND SR&Q1_2025..STATERELATIVITY is not null then SR&Q1_2025..STATERELATIVITY
			when B.EFFECTIVEMONTH >= &Q4_2024 and B.EFFECTIVEMONTH < &Q1_2025 AND SR&Q4_2024..STATERELATIVITY is not null then SR&Q4_2024..STATERELATIVITY
			when B.EFFECTIVEMONTH >= &Q3_2024 and B.EFFECTIVEMONTH < &Q4_2024 AND SR&Q3_2024..STATERELATIVITY is not null then SR&Q3_2024..STATERELATIVITY
			when B.EFFECTIVEMONTH >= &Q2_2024 and B.EFFECTIVEMONTH < &Q3_2024 AND SR&Q2_2024..STATERELATIVITY is not null then SR&Q2_2024..STATERELATIVITY
			when B.EFFECTIVEMONTH < &Q2_2024 AND SR&Q1_2024..STATERELATIVITY is not null then SR&Q1_2024..STATERELATIVITY
		else 1 end as STATERELATIVITY,
		case /*when B.EFFECTIVEMONTH >= &Q4_2026 AND BR&Q4_2026..BECARELATIVITY is not null then BR&Q4_2026..BECARELATIVITY
			when B.EFFECTIVEMONTH >= &Q3_2026 and B.EFFECTIVEMONTH < &Q4_2026 AND BR&Q3_2026..BECARELATIVITY is not null then BR&Q3_2026..BECARELATIVITY
			when B.EFFECTIVEMONTH >= &Q2_2026 and B.EFFECTIVEMONTH < &Q3_2026 AND BR&Q2_2026..BECARELATIVITY is not null then BR&Q2_2026..BECARELATIVITY
			when B.EFFECTIVEMONTH >= &Q1_2026 and B.EFFECTIVEMONTH < &Q2_2026 AND BR&Q1_2026..BECARELATIVITY is not null then BR&Q1_2026..BECARELATIVITY
			when B.EFFECTIVEMONTH >= &Q4_2025 and B.EFFECTIVEMONTH < &Q1_2026 AND BR&Q4_2025..BECARELATIVITY is not null then BR&Q4_2025..BECARELATIVITY
			when B.EFFECTIVEMONTH >= &Q3_2025 and B.EFFECTIVEMONTH < &Q4_2025 AND BR&Q3_2025..BECARELATIVITY is not null then BR&Q3_2025..BECARELATIVITY
			when B.EFFECTIVEMONTH >= &Q2_2025 and B.EFFECTIVEMONTH < &Q3_2025 AND BR&Q2_2025..BECARELATIVITY is not null then BR&Q2_2025..BECARELATIVITY*/
			when B.EFFECTIVEMONTH >= &Q1_2025 /*and B.EFFECTIVEMONTH < &Q2_2025*/ AND BR&Q1_2025..BECARELATIVITY is not null then BR&Q1_2025..BECARELATIVITY
			when B.EFFECTIVEMONTH >= &Q4_2024 and B.EFFECTIVEMONTH < &Q1_2025 AND BR&Q4_2024..BECARELATIVITY is not null then BR&Q4_2024..BECARELATIVITY
			when B.EFFECTIVEMONTH >= &Q3_2024 and B.EFFECTIVEMONTH < &Q4_2024 AND BR&Q3_2024..BECARELATIVITY is not null then BR&Q3_2024..BECARELATIVITY
			when B.EFFECTIVEMONTH >= &Q2_2024 and B.EFFECTIVEMONTH < &Q3_2024 AND BR&Q2_2024..BECARELATIVITY is not null then BR&Q2_2024..BECARELATIVITY
			when B.EFFECTIVEMONTH < &Q2_2024 AND BR&Q1_2024..BECARELATIVITY is not null then BR&Q1_2024..BECARELATIVITY
		else 1 end as BECARELATIVITY
	FROM RecentSales B
		/*LEFT JOIN CarrierProductPLE&Q4_2026 C&Q4_2026 ON B.PARTNERCARRIER = C&Q4_2026..Carrier AND B.PRODUCTCODE = C&Q4_2026..Product
		LEFT JOIN StateRelativity&Q4_2026 SR&Q4_2026 ON B.StateCode = SR&Q4_2026..State
		LEFT JOIN BECARelativity&Q4_2026 BR&Q4_2026 ON B.BECAINTENT = BR&Q4_2026..BECA*/
		/*LEFT JOIN CarrierProductPLE&Q3_2026 C&Q3_2026 ON B.PARTNERCARRIER = C&Q3_2026..Carrier AND B.PRODUCTCODE = C&Q3_2026..Product
		LEFT JOIN StateRelativity&Q3_2026 SR&Q3_2026 ON B.StateCode = SR&Q3_2026..State
		LEFT JOIN BECARelativity&Q3_2026 BR&Q3_2026 ON B.BECAINTENT = BR&Q3_2026..BECA*/
		/*LEFT JOIN CarrierProductPLE&Q2_2026 C&Q2_2026 ON B.PARTNERCARRIER = C&Q2_2026..Carrier AND B.PRODUCTCODE = C&Q2_2026..Product
		LEFT JOIN StateRelativity&Q2_2026 SR&Q2_2026 ON B.StateCode = SR&Q2_2026..State
		LEFT JOIN BECARelativity&Q2_2026 BR&Q2_2026 ON B.BECAINTENT = BR&Q2_2026..BECA*/
		/*LEFT JOIN CarrierProductPLE&Q1_2026 C&Q1_2026 ON B.PARTNERCARRIER = C&Q1_2026..Carrier AND B.PRODUCTCODE = C&Q1_2026..Product
		LEFT JOIN StateRelativity&Q1_2026 SR&Q1_2026 ON B.StateCode = SR&Q1_2026..State
		LEFT JOIN BECARelativity&Q1_2026 BR&Q1_2026 ON B.BECAINTENT = BR&Q1_2026..BECA*/
		/*LEFT JOIN CarrierProductPLE&Q4_2025 C&Q4_2025 ON B.PARTNERCARRIER = C&Q4_2025..Carrier AND B.PRODUCTCODE = C&Q4_2025..Product
		LEFT JOIN StateRelativity&Q4_2025 SR&Q4_2025 ON B.StateCode = SR&Q4_2025..State
		LEFT JOIN BECARelativity&Q4_2025 BR&Q4_2025 ON B.BECAINTENT = BR&Q4_2025..BECA*/
		/*LEFT JOIN CarrierProductPLE&Q3_2025 C&Q3_2025 ON B.PARTNERCARRIER = C&Q3_2025..Carrier AND B.PRODUCTCODE = C&Q3_2025..Product
		LEFT JOIN StateRelativity&Q3_2025 SR&Q3_2025 ON B.StateCode = SR&Q3_2025..State
		LEFT JOIN BECARelativity&Q3_2025 BR&Q3_2025 ON B.BECAINTENT = BR&Q3_2025..BECA*/
		/*LEFT JOIN CarrierProductPLE&Q2_2025 C&Q2_2025 ON B.PARTNERCARRIER = C&Q2_2025..Carrier AND B.PRODUCTCODE = C&Q2_2025..Product
		LEFT JOIN StateRelativity&Q2_2025 SR&Q2_2025 ON B.StateCode = SR&Q2_2025..State
		LEFT JOIN BECARelativity&Q2_2025 BR&Q2_2025 ON B.BECAINTENT = BR&Q2_2025..BECA*/
		LEFT JOIN CarrierProductPLE&Q1_2025 C&Q1_2025 ON B.PARTNERCARRIER = C&Q1_2025..Carrier AND B.PRODUCTCODE = C&Q1_2025..Product
		LEFT JOIN StateRelativity&Q1_2025 SR&Q1_2025 ON B.StateCode = SR&Q1_2025..State
		LEFT JOIN BECARelativity&Q1_2025 BR&Q1_2025 ON B.BECAINTENT = BR&Q1_2025..BECA
		LEFT JOIN CarrierProductPLE&Q4_2024 C&Q4_2024 ON B.PARTNERCARRIER = C&Q4_2024..Carrier AND B.PRODUCTCODE = C&Q4_2024..Product
		LEFT JOIN StateRelativity&Q4_2024 SR&Q4_2024 ON B.StateCode = SR&Q4_2024..State
		LEFT JOIN BECARelativity&Q4_2024 BR&Q4_2024 ON B.BECAINTENT = BR&Q4_2024..BECA
		LEFT JOIN CarrierProductPLE&Q3_2024 C&Q3_2024 ON B.PARTNERCARRIER = C&Q3_2024..Carrier AND B.PRODUCTCODE = C&Q3_2024..Product
		LEFT JOIN StateRelativity&Q3_2024 SR&Q3_2024 ON B.StateCode = SR&Q3_2024..State 
		LEFT JOIN BECARelativity&Q3_2024 BR&Q3_2024 ON B.BECAINTENT = BR&Q3_2024..BECA
		LEFT JOIN CarrierProductPLE&Q2_2024 C&Q2_2024 ON B.PARTNERCARRIER = C&Q2_2024..Carrier AND B.PRODUCTCODE = C&Q2_2024..Product
		LEFT JOIN StateRelativity&Q2_2024 SR&Q2_2024 ON B.StateCode = SR&Q2_2024..State
		LEFT JOIN BECARelativity&Q2_2024 BR&Q2_2024 ON B.BECAINTENT = BR&Q2_2024..BECA
		LEFT JOIN CarrierProductPLE&Q1_2024 C&Q1_2024 ON B.PARTNERCARRIER = C&Q1_2024..Carrier AND B.PRODUCTCODE = C&Q1_2024..Product
		LEFT JOIN StateRelativity&Q1_2024 SR&Q1_2024 ON B.StateCode = SR&Q1_2024..State
		LEFT JOIN BECARelativity&Q1_2024 BR&Q1_2024 ON B.BECAINTENT = BR&Q1_2024..BECA) B;
QUIT;

/*** Add NB commission rates to the policies ***/
PROC SQL;
CREATE TABLE PolicyCommission AS
(SELECT B.*,
	C.COMM_RT as COMMISSIONRATE,
	'StateSpecific' as COMMISSIONTYPE
FROM RecentSales2 B
	LEFT JOIN Commission_Tbl C
		ON B.COMMISSIONKEY = C.COMMISSIONKEY
		AND B.PRODUCTCODE = C.PRODUCT
		AND B.STATECODE = C.STATE
WHERE C.COMM_RT is not null)
UNION ALL
(SELECT B.*,
	C.COMM_RT as COMMISSIONRATE,
	'NotStateSpecific' as COMMISSIONTYPE
FROM RecentSales2 B
	LEFT JOIN Commission_Tbl C
		ON B.COMMISSIONKEY = C.COMMISSIONKEY
		AND B.PRODUCTCODE = C.PRODUCT
		AND C.STATE = 'ZZ'
WHERE C.COMM_RT is not null)
UNION ALL
(SELECT B.*,
	0.15 as COMMISSIONRATE,
	'GenericRate' as COMMISSIONTYPE
FROM RecentSales2 B
	LEFT JOIN Commission_Tbl C
		ON B.COMMISSIONKEY = C.COMMISSIONKEY
		AND B.PRODUCTCODE = C.PRODUCT
WHERE C.COMM_RT is null);
QUIT;

/*** Add RB commission rates to the policies ***/
PROC SQL;
CREATE TABLE PolicyCommission2 AS
(SELECT B.*,
	C.COMM_RT as RENEWALCOMMISSIONRATE,
	'StateSpecific' as RENEWALCOMMISSIONTYPE
FROM PolicyCommission B
	LEFT JOIN Commission_Tbl C
		ON B.RENEWALCOMMISSIONKEY = C.COMMISSIONKEY
		AND B.PRODUCTCODE = C.PRODUCT
		AND B.STATECODE = C.STATE
WHERE C.COMM_RT is not null)
UNION ALL
(SELECT B.*,
	C.COMM_RT as RENEWALCOMMISSIONRATE,
	'NotStateSpecific' as RENEWALCOMMISSIONTYPE
FROM PolicyCommission B
	LEFT JOIN Commission_Tbl C
		ON B.RENEWALCOMMISSIONKEY = C.COMMISSIONKEY
		AND B.PRODUCTCODE = C.PRODUCT
		AND C.STATE = 'ZZ'
WHERE C.COMM_RT is not null)
UNION ALL
(SELECT B.*,
	0.15 as RENEWALCOMMISSIONRATE,
	'GenericRate' as RENEWALCOMMISSIONTYPE
FROM PolicyCommission B
	LEFT JOIN Commission_Tbl C
		ON B.RENEWALCOMMISSIONKEY = C.COMMISSIONKEY
		AND B.PRODUCTCODE = C.PRODUCT
WHERE C.COMM_RT is null);
QUIT;

/*** Getting BIT rep phone time for quotes ***/
PROC SQL;
%sf_ref_acs_tok(warehouse=FREE_THE_DATA_XS);
CREATE TABLE QuoteHandleTime AS SELECT * FROM CONNECTION TO ODBC
(SELECT C.BQXAPPLICATIONID as QUOTENUMBER,
	sum(C.TALK)+sum(C.WORKTIME)+sum(C.HOLD) as HANDLETIME
FROM CL_WORKFORCE_MANAGEMENT.ODS.QUOTE_TO_CALL C
/*WHERE C.BIT_SALE = 1*/
GROUP BY C.BQXAPPLICATIONID
HAVING sum(C.BIT_Sale) >= 1);
QUIT;

/*** Joining on the handle time/cost and calculating LTV ***/
PROC SQL;
CREATE TABLE QuoteInfoAdded2 AS
SELECT Q.*,
	(Q.HANDLETIME/60) * RatePerMin as HANDLECOST,
	case when Q.ADJUSTEDPLE <= 1 then
		(Q.ADJUSTEDPLE * Q.NBCOMMISSIONRATE * Q.TOTALWRITTENPREMIUM) + BundleExtend - ((Q.HANDLETIME/60) * RatePerMin)
		when Q.ADJUSTEDPLE > 1 then
		(1 * Q.NBCOMMISSIONRATE * Q.TOTALWRITTENPREMIUM) + ((Q.ADJUSTEDPLE - 1) * Q.RBCOMMISSIONRATE * Q.TOTALWRITTENPREMIUM) + BundleExtend - ((Q.HANDLETIME/60) * RatePerMin)
		else 0 end as LTV
FROM
	(SELECT C.UNIQENTITY, C.UNIQPOLICY, C.UNIQORIGINALPOLICY, C.QUOTENUMBER, C.PRODUCTCODE, C.PARTNERCARRIER, C.BECAINTENT,
		C.PROGRESSIVEBUSINESSVERTICALS, C.STATECODE, C.EFFECTIVEDATE, C.EXPIRATIONDATE, C.TOTALWRITTENPREMIUM, C.POLICYTERM,
		C.CONTROLPLE, C.STATERELATIVITY, C.BECARELATIVITY, C.ADJUSTEDPLE, C.COMMISSIONRATE as NBCOMMISSIONRATE,
		C.RENEWALCOMMISSIONRATE as RBCOMMISSIONRATE, C.QUOTECREATEDDATE,
		case when H.HANDLETIME = . then 0
		else H.HANDLETIME end as HANDLETIME,
		case when year(EffectiveDate) = 2024 then &RatePerMin2024
			when year(EffectiveDate) >= 2025 then &RatePerMin2025
			/*when year(EffectiveDate) = 2026 then &RatePerMin2026*/
			else 0 end as RatePerMin,
		case when year(EffectiveDate) = 2024 then &BundleExtend2024
			when year(EffectiveDate) >= 2025 then &BundleExtend2025
			/*when year(EffectiveDate) = 2026 then &BundleExtend2026*/
			else 0 end as BundleExtend
	FROM PolicyCommission2 C
		LEFT JOIN QuoteHandleTime H
			ON C.QUOTENUMBER = H.QUOTENUMBER) Q;
QUIT;

/*** Joining average & upper bound LTV ***/
PROC SQL;
CREATE TABLE Final AS
SELECT Q.QUOTENUMBER,
	Q.PRODUCTCODE,
	Q.PARTNERCARRIER,
	Q.BECAINTENT,
	Q.STATECODE,
	case when Q.LTV > A.UpperBound then A.UpperBound
		when Q.LTV < A.LowerBound then A.LowerBound
		else Q.LTV end as LTV, /*LTV with 1 std dev limits*/
	case when Q.LTV > A.UpperBound OR Q.LTV < A.LowerBound then 1
		else 0 end as OUTLIERLTVIND,
	A.UPPERBOUND as UPPERBOUNDLTV, A.LOWERBOUND AS LOWERBOUNDLTV, A.AVGLTV, A.STDDEVLTV, Q.LTV as UNADJUSTEDLTV,
	Q.HANDLETIME,
	Q.HANDLECOST,
	Q.PROGRESSIVEBUSINESSVERTICALS,
	Q.EFFECTIVEDATE,
	Q.EXPIRATIONDATE,
	Q.TOTALWRITTENPREMIUM,
	Q.POLICYTERM,
	Q.CONTROLPLE,
	Q.STATERELATIVITY,
	Q.BECARELATIVITY,
	Q.ADJUSTEDPLE,
	Q.NBCOMMISSIONRATE,
	Q.RBCOMMISSIONRATE,
	Q.QUOTECREATEDDATE,
	Q.UNIQENTITY,
	Q.UNIQPOLICY,
	Q.UNIQORIGINALPOLICY,
	today() format yymmdd10. as DateRan
FROM QuoteInfoAdded2 Q
	LEFT JOIN
		/*** Getting avg/std dev LTV for sales ***/
		/*** Decided to make range 1 std dev from mean 4/11/25 ***/
		(SELECT avg(LTV) as AVGLTV,
			std(LTV) as STDDEVLTV,
			avg(LTV) + std(LTV) as UpperBound,
			avg(LTV) - std(LTV) as LowerBound
		FROM QuoteInfoAdded2) A ON 1=1;
QUIT;

PROC SQL;
CREATE TABLE Final2 AS
SELECT QUOTENUMBER, PRODUCTCODE, PARTNERCARRIER, BECAINTENT, STATECODE,
	((LTV/AVGLTV)*100) as INDEXEDVALUE,
	LTV, OUTLIERLTVIND, UPPERBOUNDLTV, LOWERBOUNDLTV, AVGLTV, STDDEVLTV, UNADJUSTEDLTV, HANDLETIME, HANDLECOST,
	PROGRESSIVEBUSINESSVERTICALS, EFFECTIVEDATE, EXPIRATIONDATE, TOTALWRITTENPREMIUM, POLICYTERM, CONTROLPLE, STATERELATIVITY,
	BECARELATIVITY, ADJUSTEDPLE, NBCOMMISSIONRATE, RBCOMMISSIONRATE, QUOTECREATEDDATE, UNIQENTITY, UNIQPOLICY, UNIQORIGINALPOLICY,
	DATERAN
FROM Final;
QUIT;

/*********************************************/
/***Exporting the summarized table to CLAcq***/
/*********************************************/
libname CLAcq &SQLEng noprompt="DSN=SQLServer; Server=MSS-P1-BISS-01; DATABASE=BISSCLAcqSBI;" schema=dbo &bulkparms read_isolation_level=RU;

PROC DELETE DATA = CLAcq.Sale_LTV_Since2024; RUN;
DATA CLAcq.Sale_LTV_Since2024; SET Final2; RUN;


/*********************************************/
/***Email to myself for confirmation of run***/
/*********************************************/

/*Time when code finished, and time it took to run*/
/*%let FinishTime = %sysfunc(datetime(), datetime20.);
%let FinishTimet = %sysfunc(time(), hhmm.);
%let FinishTimedt = %sysfunc(inputn(&FinishTime., datetime20.));
%let StartTimedt = %sysfunc(inputn(&StartTime., datetime20.));
%let RunTime = %sysfunc(intck(minutes, &StartTimedt, &FinishTimedt));

DATA _null_;
file sendit email
	from="isabelle_e_wagner@progressive.com"
	to="isabelle_e_wagner@progressive.com"
	subject="Daily LTV Code Run - Data Since 2024 Code";
put "The LTV Code for Direct Mail Application finished at &FinishTimet. and took &RunTime. minutes to complete.";
put;
put "The code started at &StartTime. and finished at &FinishTime..";
RUN;*/