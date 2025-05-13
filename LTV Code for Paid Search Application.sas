/********************************************************************/
/*** Pulling in the last 90 days of sales. Calculating their LTV. ***/
/*********** Exporting to BISS server for digital to use. ***********/
/********************************************************************/

/*Current date & time*/
/*%let StartTime = %sysfunc(datetime(), datetime20.);*/

/*** BIT rep rate per minute from Chandan for 2025 ***/
%let RatePerMin = 2.5; /*$2.30 in 2024*/
/*** Bundle and extend rate from Control (Joe Geng) for 2025 ***/
%let BundleExtend = 78; /*$70 in 2024*/

/*** Import commission table in to get commission rates for each carrier ***/
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/General Agency/Accounting/A-R Files/A_R Commission Table_MASTER_test.xlsx"
	dbms=xlsx REPLACE OUT = COMMISSION_TBL (KEEP = COMMISSIONKEY STATE CARRIER CARRIER2 PRODUCT TRANS_CD COMM_RT AGENT_RT TIER);
	SHEET = "COMMISSION MASTER";
RUN;

/*** Import PLE by carrier & product ***/
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE 202502.xlsx"
	dbms=xlsx REPLACE OUT = CarrierProductPLE (KEEP = Product Carrier PLE);
	SHEET = "CarrierProduct";
RUN;

/*** Import PLE state relativity ***/
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE 202502.xlsx"
	dbms=xlsx REPLACE OUT = StateRelativity (KEEP = State StateRelativity);
	SHEET = "State";
RUN;

/*** Import PLE BECA relativity ***/
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/SBI/Projects/LTV/PLE 202502.xlsx"
	dbms=xlsx REPLACE OUT = BECARelativity (KEEP = BECA BECARelativity);
	SHEET = "BECA";
RUN;


/*** Grabbing last 90 days of quotes/sales ***/
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
	H.QUOTECREATEDDATE
FROM CL_SBI.PUBLISHED.BIT_HOLISTICFUNNEL_VW H
WHERE H.QUOTECREATEDDATE >= (current_date()-90)
	AND H.QUOTECREATEDDATE < current_date()
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
		C.PLE as CONTROLPLE,
		case when SR.STATERELATIVITY is null then 1
		else SR.STATERELATIVITY end as STATERELATIVITY,
		case when BR.BECARELATIVITY is null then 1
		else BR.BECARELATIVITY end as BECARELATIVITY
	FROM RecentSales B
		LEFT JOIN CarrierProductPLE C
			ON B.PARTNERCARRIER = C.Carrier
			AND B.PRODUCTCODE = C.Product
		LEFT JOIN StateRelativity SR
			ON B.StateCode = SR.State
		LEFT JOIN BECARelativity BR
			ON B.BECAINTENT = BR.BECA) B;
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
	(Q.HANDLETIME/60) * &RatePerMin as HANDLECOST,
	case when Q.ADJUSTEDPLE <= 1 then
		(Q.ADJUSTEDPLE * Q.NBCOMMISSIONRATE * Q.TOTALWRITTENPREMIUM) + &BundleExtend - ((Q.HANDLETIME/60) * &RatePerMin)
		when Q.ADJUSTEDPLE > 1 then
		(1 * Q.NBCOMMISSIONRATE * Q.TOTALWRITTENPREMIUM) + ((Q.ADJUSTEDPLE - 1) * Q.RBCOMMISSIONRATE * Q.TOTALWRITTENPREMIUM) + &BundleExtend - ((Q.HANDLETIME/60) * &RatePerMin)
		else 0 end as LTV
FROM
	(SELECT C.UNIQENTITY, C.UNIQPOLICY, C.UNIQORIGINALPOLICY, C.QUOTENUMBER, C.PRODUCTCODE, C.PARTNERCARRIER, C.BECAINTENT,
		C.PROGRESSIVEBUSINESSVERTICALS, C.STATECODE, C.EFFECTIVEDATE, C.EXPIRATIONDATE, C.TOTALWRITTENPREMIUM, C.POLICYTERM,
		C.CONTROLPLE, C.STATERELATIVITY, C.BECARELATIVITY, C.ADJUSTEDPLE, C.COMMISSIONRATE as NBCOMMISSIONRATE,
		C.RENEWALCOMMISSIONRATE as RBCOMMISSIONRATE, C.QUOTECREATEDDATE,
		case when H.HANDLETIME = . then 0
		else H.HANDLETIME end as HANDLETIME
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

PROC DELETE DATA = CLAcq.Sale_LTV_T3; RUN;
DATA CLAcq.Sale_LTV_T3; SET Final2; RUN;


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
	subject="Daily LTV Code Run";
put "The LTV Code for Paid Search Application finished at &FinishTimet. and took &RunTime. minutes to complete.";
put;
put "The code started at &StartTime. and finished at &FinishTime..";
RUN;*/