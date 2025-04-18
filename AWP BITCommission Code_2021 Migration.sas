/*Always check the anti-join base table*/

/*PROC SQL;
SELECT RPT_acct_dt as Month
INTO :Month
FROM BIT.Acct_Cal_Current;
QUIT;*/
/* Replacing BIT date tables: */
PROC SQL;
CONNECT TO ODBC (%db2conn(db2p));
CREATE TABLE Date AS SELECT * FROM CONNECTION TO ODBC
(SELECT DT_VAL, ACCT_MO, ACCT_CCYY, ACCT_CCYYMM FROM DSE.Date); DISCONNECT FROM ODBC; QUIT;

PROC SQL;
SELECT case when ACCT_MO = 1 then input(cat((ACCT_CCYY-1),'12'),6.) else (ACCT_CCYYMM-1) end as Month
INTO :Month
FROM Date WHERE DT_VAL = today();
QUIT;

%put &Month.;

/*************** Epic 2021 aka the BDE Table  *******************/
PROC SQL;
CONNECT TO &SQLEng (dsn=EPICCloud authdomain=BDE &bulkparms);
CREATE TABLE SERVICESUMMARY AS SELECT * FROM CONNECTION TO &SQLEng (SELECT	* FROM dbo.SERVICESUMMARY);
CREATE TABLE LINE AS SELECT * FROM CONNECTION TO &SQLEng (SELECT	* FROM dbo.LINE);
CREATE TABLE CDLINESTATUS AS SELECT * FROM CONNECTION TO &SQLEng (SELECT	* FROM dbo.CDLINESTATUS);
CREATE TABLE COMPANY AS SELECT * FROM CONNECTION TO &SQLEng (SELECT	* FROM dbo.COMPANY);
CREATE TABLE CLIENT AS SELECT * FROM CONNECTION TO &SQLEng (SELECT	* FROM dbo.CLIENT);
CREATE TABLE BROKER AS SELECT * FROM CONNECTION TO &SQLEng (SELECT	* FROM dbo.BROKER);
CREATE TABLE COMMISSIONAGREEMENT AS SELECT * FROM CONNECTION TO &SQLEng (SELECT	* FROM dbo.COMMISSIONAGREEMENT);
CREATE TABLE POLICY  AS SELECT * FROM CONNECTION TO &SQLEng (SELECT	* FROM dbo.POLICY);
CREATE TABLE TRANSDETAIL AS SELECT * FROM CONNECTION TO &SQLEng (SELECT	* FROM dbo.TRANSDETAIL);
CREATE TABLE TRANSHEAD AS SELECT * FROM CONNECTION TO &SQLEng (SELECT	* FROM dbo.TRANSHEAD);
CREATE TABLE TRANSCODE AS SELECT * FROM CONNECTION TO &SQLEng (SELECT	* FROM dbo.TRANSCODE);
CREATE TABLE CDPOLICYLINETYPE AS SELECT * FROM CONNECTION TO &SQLEng (SELECT	* FROM dbo.CDPolicyLineType);
CREATE TABLE AGENCY AS SELECT * FROM CONNECTION TO &SQLEng (SELECT	* FROM dbo.AGENCY);
CREATE TABLE CONTRACTADDRESS AS SELECT * FROM CONNECTION TO &SQLEng (SELECT	* FROM dbo.CONTACTADDRESS);
CREATE TABLE LKPOLICYSOURCE AS SELECT * FROM CONNECTION TO &SQLEng (SELECT	* FROM dbo.LKPOLICYSOURCE);
CREATE TABLE ConfigureLkLanguageResource AS SELECT * FROM CONNECTION TO &SQLEng (SELECT	* FROM dbo.ConfigureLkLanguageResource);
QUIT;

/*Import commission table into SAS to use*/
PROC IMPORT DATAFILE = "/sso/win_wrkgrp/CNTL/General Agency/Accounting/A-R Files/A_R Commission Table_MASTER_test.xlsx"
	dbms=xlsx REPLACE
	OUT = COMMISSION_TBL(KEEP = COMMISSIONKEY STATE CARRIER CARRIER2 PRODUCT TRANS_CD COMM_RT AGENT_RT TIER);
	SHEET = "COMMISSION MASTER";
RUN;

/*Grabbing carrier partner table here instead of a libname*/
PROC SQL;
CONNECT TO &SQLEng(noprompt="DSN=SQLServer; Server=MSS-P1-PCA-06; database=SmallBusinessInsurance;" &bulkparms read_isolation_level=RU);
CREATE TABLE carrier_partner AS SELECT * FROM CONNECTION TO &SQLEng
(SELECT DISTINCT PremiumPayable, PartnerCarrierName FROM BIT.Carrier_Partner); QUIT;

PROC SQL;
CREATE TABLE PolicySource AS
SELECT DISTINCT PS.UniqLkPolicySource,
	LR.ResourceText
FROM LkPolicySource as PS
	LEFT JOIN ConfigureLkLanguageResource as LR
		ON LR.ConfigureLkLanguageResourceID = PS.ConfigureLkLanguageResourceID
WHERE PS.UniqLkPolicySource NE -1;
QUIT;

PROC SQL;
CREATE TABLE PolicyCounts AS
SELECT DISTINCT B.LOOKUPCODE AS BROKER,
	CO.LOOKUPCODE AS CARRIER,
	CP.PartnerCarrierName AS CARRIER_NAME,
	LC.CDLINESTATUSCODE,
	S.ACTION,
	CASE WHEN B.LOOKUPCODE in ('APCADIR-01','PROGADV-01') THEN 'DIR' 
		ELSE 'AGD' END AS CHANNEL,
	P.POLICYNUMBER,
	CL.NAMEOF AS CUSTOMER,
	L.CdStateCodeIssuing AS STATE,
	ps.ResourceText AS PRODUCT FORMAT $4. INFORMAT $4.,
	CASE WHEN PLT2.CDPOLICYLINETYPECODE = 'CPKG' THEN 'BOP' 
		WHEN PLT2.CDPOLICYLINETYPECODE = 'UMBR' THEN 'BOP' 
		ELSE PLT2.CDPOLICYLINETYPECODE END AS LINE,
	P.EFFECTIVEDATE AS POLICY_EFF_DT,
	S.EFFECTIVEDATE AS CHANGE_EFF_DT,
	P.ANNUALIZEDPREMIUM,
	P.ESTIMATEDPREMIUM,
	P.LASTDOWNLOADEDPREMIUM,
	P.UNIQORIGINALPOLICY,
	P.UNIQPOLICY,
	CASE WHEN P.UNIQORIGINALPOLICY = P.UNIQPOLICY THEN 'N' 
		ELSE 'R' END AS TRANSCODE,
	CA.SITEID AS AGT_CD,
	L.UpdatedDate,
	DT.Acct_CCYYMM as Acct_Mo,
	CASE WHEN CO.LOOKUPCODE = 'EVAIN1' THEN 'Wholesale' 
		ELSE 'Retail' end as CarrierCategory
FROM SERVICESUMMARY S
		LEFT JOIN POLICY P ON S.UNIQPOLICY = P.UNIQPOLICY
		LEFT join LINE L ON P.UNIQPOLICY = L.UNIQPOLICY
		left JOIN CDPOLICYLINETYPE PLT2 ON PLT2.UniqCdPolicyLineType = p.UniqCdPolicyLineType 
		LEFT JOIN CDLINESTATUS LC ON L.UNIQCDLINESTATUS = LC.UNIQCDLINESTATUS
		LEFT JOIN COMPANY CO ON L.UNIQENTITYCOMPANYBILLING = CO.UNIQENTITY
		left join carrier_partner cp ON co.lookupcode=cp.PremiumPayable
		LEFT JOIN CLIENT CL ON P.UNIQENTITY = CL.UNIQENTITY
		LEFT JOIN BROKER B ON CL.UNIQBROKER = B.UNIQENTITY
		LEFT JOIN CONTRACTADDRESS CA ON CA.UNIQENTITY = CL.UNIQBROKER
		LEFT JOIN policysource ps ON ps.UniqLkPolicySource = P.UniqLkPolicySource
		left join date dt ON datepart(S.EFFECTIVEDATE)=dt.dt_val
WHERE DT.Acct_CCYYMM between 201901 and &month.
	AND DATEPART(S.InsertedDate) < TODAY()
	AND	S.ACTION IN ('N','R','C','I')
	AND S.STATUS <> 'P'
	AND S.DESCRIPTIONOF <> 'BAUT'
	AND PLT2.CdPolicyLineTypeCode <> 'BAUT'
	AND CO.LOOKUPCODE <> 'PROCO1'
	AND LC.CDLINESTATUSCODE <> 'ERR'
	AND LC.CDLINESTATUSCODE <> 'DUP'
	AND LC.CDLINESTATUSCODE <> 'DUQ'
	AND UPPER(P.PolicyNumber) NOT LIKE '%DNU%'
	AND CA.SITEID<>'';
QUIT;

DATA PolicyCounts;
SET PolicyCounts;
IF Product = '' THEN Product = Line; Else Product = Product;
IF CarrierCategory = 'Wholesale' THEN Product = Line; Else Product = Product;
drop Line CarrierIssuing;
RUN;

DATA Retail;
SET PolicyCounts;
IF CarrierCategory = 'Retail';
Drop CarrierCategory;
RUN;

/* In order to properly get New/Renewals, need to grab rest of E&S policies to be able to compare uniqpolicy */
proc sql;
create table Policycounts_2 as
select distinct
	p.uniqentity
	,p.uniqpolicy
	,p.effectivedate
	,LC.CDLINESTATUSCODE
FROM
	WORK.SERVICESUMMARY S 
		INNER JOIN WORK.POLICY P ON S.UNIQPOLICY = P.UNIQPOLICY
		inner join WORK.LINE L ON  P.UNIQPOLICY = L.UNIQPOLICY 
		INNER JOIN WORK.CDLINESTATUS LC ON L.UNIQCDLINESTATUS = LC.UNIQCDLINESTATUS
		INNER JOIN COMPANY CO ON L.UNIQENTITYCOMPANYBILLING = CO.UNIQENTITY

where 
	S.ACTION IN ('N','R','C','I')	
	and S.STATUS <> 'P'
	and CO.LookupCode = 'EVAIN1'
order by 
	p.uniqentity,
	p.effectivedate
;
quit;

DATA Policycounts_3;
SET Policycounts_2;
IF Lag(uniqentity) = uniqentity or CDLINESTATUSCODE='REN' THEN TRANSCODE = 'R'; else TRANSCODE='N';
RUN;

proc sql;
create table Wholesale as
select
	p.BROKER
	, p.CARRIER
	, p.CARRIER_NAME
	, p.CDLINESTATUSCODE
	, p.ACTION
	, p.CHANNEL
	, P.POLICYNUMBER
	, p.CUSTOMER
	, p.STATE
	, p.PRODUCT
	, P.POLICY_EFF_DT
	, p.CHANGE_EFF_DT 
	, P.ANNUALIZEDPREMIUM
	, P.ESTIMATEDPREMIUM
	, P.LASTDOWNLOADEDPREMIUM
	, P.UNIQORIGINALPOLICY
	, P.UNIQPOLICY
	,pl.TRANSCODE
	, p.AGT_CD
	, p.UpdatedDate,
	p.acct_mo
from 
	policycounts p
		left join policycounts_3 pl on p.uniqpolicy=pl.uniqpolicy
where
	carriercategory = 'Wholesale'
;
quit;

proc sql;
create table PolicyCounts_comb as
select a.* from Retail a
union 
select b.* from Wholesale b
;quit;

/*Create commission key and add zero for all null values in the AnnualizedPremium, EstimatedPremium, LastDownloadedPremium*/
DATA PolicyCommissionKey;
SET POLICYCOUNTS_comb; 
COMMISSIONKEY = (TRIM(CARRIER)||TRIM(CARRIER)||TRIM(TRANSCODE)||'1');
IF ANNUALIZEDPREMIUM = '.' THEN ANNUALIZEDPREMIUM=0; ELSE ANNUALIZEDPREMIUM=ANNUALIZEDPREMIUM;
IF ESTIMATEDPREMIUM = '.' THEN ESTIMATEDPREMIUM=0; ELSE ESTIMATEDPREMIUM=ESTIMATEDPREMIUM;
IF LASTDOWNLOADEDPREMIUM = '.' THEN LASTDOWNLOADEDPREMIUM=0; ELSE LASTDOWNLOADEDPREMIUM=LASTDOWNLOADEDPREMIUM;

IF Product NE 'BAUT';
IF Product = 'CPKG' THEN Product = 'BOP';
IF Product = 'CUMB' THEN Product = 'UMBR';

RUN;

/*Total Rows: 314,768*/

/*Add Premium and Commission Rates to the policies that have state specific commission */
PROC SQL;
CREATE TABLE StatePremiumCommission AS
SELECT
	P.Broker
	, P.CARRIER
	, P.CARRIER_NAME
	, P.CdLineStatusCode	
	, P.Action	
	, P.CHANNEL
	, P.AGT_CD	
	, P.PolicyNumber	
	, P.CUSTOMER
	, P.STATE	
	, P.PRODUCT	
	, P.POLICY_EFF_DT
	, P.CHANGE_EFF_DT	
	, P.AnnualizedPremium	
	, P.EstimatedPremium	
	, P.LastDownloadedPremium	
	, CASE 	
			WHEN P.LastDownloadedPremium <>0 THEN P.LastDownloadedPremium
			WHEN P.EstimatedPremium <>0 THEN P.EstimatedPremium
			WHEN P.ANNUALIZEDPREMIUM <>0 THEN P.ANNUALIZEDPREMIUM
			ELSE 0 END AS PREMIUM
	, P.TRANSCODE	
	, P.COMMISSIONKEY
	, C.COMMISSIONKEY AS COMMISION_TBL_KEY
	, C.COMM_RT
	, p.uniqpolicy
	, p.Acct_Mo

FROM
	PolicyCommissionKey P 
		LEFT JOIN Commission_tbl C on P.COMMISSIONKEY = C.COMMISSIONKEY and P.Product = C.Product	and P.State = C.State
where
	C.Comm_rt is not null
;
QUIT;
/*State Only: 2467*/

/*Add Premium and Commission Rates to the policies that do not have state specific commission */
PROC SQL;
CREATE TABLE NonStatePremiumCommission AS
SELECT
	P.Broker
	, P.CARRIER
	, P.CARRIER_NAME
	, P.CdLineStatusCode	
	, P.Action	
	, P.CHANNEL	
	, P.AGT_CD
	, P.PolicyNumber	
	, P.CUSTOMER
	, P.STATE	
	, P.PRODUCT	
	, P.POLICY_EFF_DT	
/*	, P.POLICY_EXP_DT*/
	, P.CHANGE_EFF_DT	
	, P.AnnualizedPremium	
	, P.EstimatedPremium	
	, P.LastDownloadedPremium	
	, CASE WHEN P.LastDownloadedPremium <>0 THEN P.LastDownloadedPremium
			WHEN P.EstimatedPremium <>0 THEN P.EstimatedPremium
			WHEN P.ANNUALIZEDPREMIUM <>0 THEN P.ANNUALIZEDPREMIUM
			ELSE 0 END AS PREMIUM
	, P.TRANSCODE	
	, P.COMMISSIONKEY
	, C.COMMISSIONKEY AS COMMISION_TBL_KEY
	, C.COMM_RT
	, p.uniqpolicy
	, p.Acct_Mo
FROM
	PolicyCommissionKey P 
		LEFT JOIN Commission_tbl C on P.COMMISSIONKEY = C.COMMISSIONKEY and P.Product = C.Product and C.State ='ZZ'
where 
	C.Comm_rt is not null
;
QUIT;
/*Non-State Specific: 307,648*/

/*Combine state and non state tables built above*/

PROC SQL;
CREATE TABLE PremiumCommissionPrep AS
SELECT  *
FROM
	StatePremiumCommission 
	union all 
	
	select * from NonStatePremiumCommission;

quit;

/*This gives all of the policies in which there's no commission rate. Most, but not all of these policies should be for Progressive. These are 
  all of the policies being omitted. If there are more than 500 policies that are not PGR BOP, this should signal a code review is required*/
proc sql;
create table anti_join_base as
select a.*
from policycounts_comb a
	left join PremiumCommissionPrep b on a.uniqpolicy=b.uniqpolicy
where b.uniqpolicy is null;
quit;

/*This gives different commission tiers for Nationwide policies. However, we can't distinguish between tiers in AMS */
PROC SQL;
CREATE TABLE ExceptionReport AS
SELECT distinct p.*,c.*
FROM PolicyCommissionKey P 
	LEFT JOIN Commission_tbl C
		on P.Carrier = C.Carrier
		and P.TRANSCODE = C.TRANS_CD
where P.COMMISSIONKEY <> C.COMMISSIONKEY
	and (C.STATE = 'ZZ' or C.State = P.State)
	and P.Product = C.Product;
QUIT;

PROC SQL;
CREATE TABLE PremiumCommission AS
SELECT  distinct
	P.Broker
	, P.CARRIER
	, P.CARRIER_NAME
	, P.CdLineStatusCode	
	, P.Action	
	, P.CHANNEL	
	, P.AGT_CD
	, P.PolicyNumber	
	, P.CUSTOMER
	, P.STATE	
	, P.PRODUCT	
	, DATEPART(P.POLICY_EFF_DT)AS Policy_Eff_Dt FORMAT mmddyy10.	
/*	, P.POLICY_EXP_DT*/

/*	, P.ANNUALIZEDPREMIUM*/
/*	, P.EstimatedPremium*/
/*	, P.LastDownloadedPremium*/
	, P.PREMIUM
	, CASE WHEN P.ACTION='C' THEN ROUND((365-((P.CHANGE_EFF_DT/86400)-(P.POLICY_EFF_DT/86400)))/365*P.PREMIUM,.01) ELSE 0 END AS CAN_PREM

	, P.COMM_RT
	, CASE WHEN P.ACTION='C' THEN ROUND((365-((P.CHANGE_EFF_DT/86400)-(P.POLICY_EFF_DT/86400)))/365*P.PREMIUM*-1,.01) 
		   WHEN	P.ACTION='I' THEN ROUND((365-((P.CHANGE_EFF_DT/86400)-(P.POLICY_EFF_DT/86400)))/365*P.PREMIUM,.01) 
		   ELSE ROUND(P.PREMIUM,.01) END AS AdjustedPremium
	, CASE WHEN P.ACTION='C' THEN ROUND((365-((P.CHANGE_EFF_DT/86400)-(P.POLICY_EFF_DT/86400)))/365*P.PREMIUM*P.COMM_RT*-1,.01) 
		   WHEN	P.ACTION='I' THEN ROUND((365-((P.CHANGE_EFF_DT/86400)-(P.POLICY_EFF_DT/86400)))/365*P.PREMIUM*P.COMM_RT,.01) 
				ELSE ROUND(P.PREMIUM*P.COMM_RT,.01) END AS Comm
	, DATEPART(P.CHANGE_EFF_DT) AS Change_Eff_Dt FORMAT mmddyy10.	
	, CASE WHEN (P.ACTION='N' and P.CdLineStatusCode = 'BIN') THEN 1
		   WHEN (P.ACTION='R' and P.CdLineStatusCode = 'REN') THEN 1
		   WHEN (P.ACTION='N' and P.CdLineStatusCode = 'REN') THEN 1
		   WHEN (P.ACTION='R' and P.CdLineStatusCode = 'BIN') THEN 1
		   WHEN (P.ACTION='N' and P.CdLineStatusCode = 'END') THEN 1
		   WHEN (P.ACTION='R' and P.CdLineStatusCode = 'END') THEN 1
		   WHEN (P.ACTION='N' and P.CdLineStatusCode = 'CAN') THEN 1
		   WHEN (P.ACTION='R' and P.CdLineStatusCode = 'CAN') THEN 1
		   WHEN (P.ACTION='N' and P.CdLineStatusCode = 'REW') THEN 1
		   WHEN (P.ACTION='R' and P.CdLineStatusCode = 'REW') THEN 1
		   WHEN (P.ACTION='N' and P.CdLineStatusCode = 'NEW') THEN 1
		   ELSE 0 END AS DenominatorCount
	, P.TRANSCODE	
	, P.COMMISSIONKEY
	, p.uniqpolicy
	, p.Acct_Mo

FROM 
	PremiumCommissionPrep P
WHERE
	cdlinestatuscode not in ('DUP','DUQ')
order by 
	P.Channel, 
	P.Carrier_Name, 
	P.PolicyNumber, 
	P.Action
;quit;

proc sql;
create table finalcommission1 as
select
	*
	,case when CARRIER = 'EVAIN1' then 'Y' else 'N' end as ES_Flag
	,case when CARRIER = 'CYBIN1' then 'Y' else 'N' end as Cyber_Flag
	,case when COMM_RT = 0 then 'Y' else 'N' end as MissingCommRT_Flag
	,case when PREMIUM = 0 then 'Y' else 'N' end as MissingPrem_Flag
	,case when UPCASE(CUSTOMER) like '%EPIC%TES%' 
		or upcase(customer) like '%TEST%' 
		or Upcase(policynumber) like '%EPIC%DUP%'
		or INDEX(POLICYNUMBER,'QT') 
		or INDEX(POLICYNUMBER,'9999999')
	  then 'Y' else 'N' end as Test_Flag
from premiumcommission
;quit;

Data FinalCommission2;
set finalcommission1;
IF ES_Flag ='N' && Cyber_Flag = 'N' && MissingCommRT_Flag = 'N' && MissingPrem_Flag = 'N' && Test_Flag ='N' 
	Then NoIssue_Flag ='Y'; Else NoIssue_Flag = 'N';
RUN;

/*Set up table for import */
proc sql;
create table FinalCommission3 as
select 
	broker,
	carrier,
	carrier_name,
	CdLineStatusCode,
	action,
	channel,
	AGT_CD as AgentCode,
	policynumber,
	customer,
	state,
	product,
	POLICY_EFF_DT,
	CHANGE_EFF_DT,
	PREMIUM,
	CAN_PREM,
	TRANSCODE,
	COMMISSIONKEY,
	COMM_RT,
	AdjustedPremium as NetPremium,
	COMM,
	DenominatorCount,
	ES_Flag as ESFlag,
	Cyber_Flag as CyberFlag,
	MissingCommRT_Flag as MissingCommRtFlag,
	MissingPrem_Flag as MissingPremFlag,
	Test_Flag as TestFlag,
	NoIssue_Flag as NoIssueFlag,
	Acct_Mo
from FinalCommission2
where test_flag='N'
;quit;

/*PROC SQL;
CREATE TABLE NegativeAWP AS
SELECT *
FROM FinalCommission3
WHERE Product = 'WCOM'
	and NetPremium<0
	and acct_mo>=202001;
QUIT;

PROC EXPORT
DATA=NegativeAWP 
OUTFILE= "/sso/win_wrkgrp/CNTL/SBI/RTB/CL Acquisition and SBI Monthly/SAS Exports/NegativeAWPs_02_03_23.xlsx"
DBMS=xlsx Replace;
RUN;*/

/*proc sql;
select RPT_acct_dt as CM, Prior_YTD_Acct_dt-200 as START_YRMO, T12_acct_dt as T12CYS, T12_acct_dt-100 as T12PYS, t3_acct_dt as T3CYS,
	t3_acct_dt-100 as T3PYS, YoY_acct_dt as YoYE, ytd_acct_dt as YTDCYS, prior_ytd_acct_dt as YTDPYS
into :CM, :START_YRMO, :T12CYS, :T12PYS, :T3CYS, :T3PYS, :YoYS, :YTDCYS, :YTDPYS
from bit.acct_cal_current
;quit; */
/*Replacing BIT date tables:*/
PROC SQL;
SELECT case when ACCT_MO = 1 then input(cat((ACCT_CCYY-1),'12'),6.) else (ACCT_CCYYMM-1) end as CM,
	case when ACCT_MO = 1 then input(cat((ACCT_CCYY-3),'01'),6.) else input(cat((ACCT_CCYY-2),'01'),6.) end as START_YRMO,
	case when ACCT_MO = 1 then input(cat((ACCT_CCYY-1),'01'),6.) else (ACCT_CCYYMM-100) end as T12CYS,
	case when ACCT_MO = 1 then input(cat((ACCT_CCYY-2),'01'),6.) else (ACCT_CCYYMM-200) end as T12PYS,
	case when ACCT_MO in (1,2,3) then input(cat((ACCT_CCYY-1),(ACCT_MO+9)),6.) else (ACCT_CCYYMM-3) end as T3CYS,
	case when ACCT_MO in (1,2,3) then input(cat((ACCT_CCYY-2),(ACCT_MO+9)),6.) else (ACCT_CCYYMM-103) end as T3PYS,
	case when ACCT_MO = 1 then input(cat((ACCT_CCYY-1),'12'),6.)-100 else (ACCT_CCYYMM-101) end as YoYE,
	case when ACCT_MO = 1 then input(cat((ACCT_CCYY-1),'01'),6.) else input(cat((ACCT_CCYY),'01'),6.) end as YTDCYS,
	case when ACCT_MO = 1 then input(cat((ACCT_CCYY-2),'01'),6.) else input(cat((ACCT_CCYY-1),'01'),6.) end as YTDPYS
INTO :CM, :START_YRMO, :T12CYS, :T12PYS, :T3CYS, :T3PYS, :YoYS, :YTDCYS, :YTDPYS
FROM Date
WHERE DT_VAL = today();
QUIT;

%put &CM., &START_YRMO., &T12CYS., &T12PYS., &T3CYS., &T3PYS., &YoYS., &YTDCYS., &YTDPYS.;

%let CurrentCarriers = ('Hiscox','Homesite','Liberty Mutual','Liberty','Markel','AmTrust','Evanston','CNA','Nationwide','MSA','PGRBOP','Arch');
%let currentCarrierCodes = ('HISCO1', 'HXBIT1', 'ZHISX1','HOMIN1', 'XHOMCC', 'XHOME1','LBDIR1', 'LIBER1', 'ZLIBMU','L-AFCC','L-OHCS','L-SECU',
	'L-WEST','ZMARKL','FIRST1','CNADIR','ZCNAC1','CNA001','NADCX1', 'N-ASUR','AMTRU1','EVAIN1','PGRBOP','MAIAM1', 'ZMAIM1','A-ARCH');



proc sql;
create table AWPBase as
select distinct
	awp.carrier_name as CarrierNameRollUp,
	awp.carrier,
	awp.product as productcode,
	awp.transcode
from FinalCommission3 awp
;
quit;


%macro AWPTables (BegDt=,EndDt=,TabNm=, FieldNm=);
proc sql;
create table &TabNm. as
select
	awp.carrier_name as CarrierNameRollUp,
	awp.carrier,
	awp.product as productcode,
	awp.transcode,

	sum(netpremium) as NetPremium_&FieldNm.,
	sum(comm) as comm_&FieldNm.,
	sum(denominatorcount) as DenominatorCount_&FieldNm.

from FinalCommission3 awp
where (ACCT_mo between &BegDt and &EndDt)
group by	awp.carrier_name,
	awp.carrier,
	awp.product,
	awp.transcode
;
quit;
%mend AWPTables;
%AWPTables (Begdt=&T12CYS,	EndDt=&CM,		TabNm=AWPT12CY,	FieldNm=T12CY);
%AWPTables (BegDt=&T12PYS,	EndDt=&YoYS,	TaBNm=AWPT12PY,	FieldNm=T12PY);
%AWPTables (BegDt=&T3CYS, 	EndDt=&CM,		TabNm=AWPT3CY,	FieldNm=T3CY);
%AWPTables (BegDt=&T3PYS, 	EndDt=&YoYS, 	TabNm=AWPT3PY,	FieldNm=T3PY);
%AWPTables (BegDt=&YTDCYS,	EndDt=&CM,	 	TabNm=AWPYTDCY,	FieldNm=YTDCY);
%AWPTables (BegDt=&YTDPYS,	EndDt=&YoYs,	TabNm=AWPYTDPY,	FieldNm=YTDPY);
%AWPTables (BegDt=&CM,		EndDt=&CM,		TabNm=AWPCMCY,	FieldNm=CMCY);
%AWPTables (BegDt=&YoYS,	EndDt=&YoYS,	TabNm=AWPCMPY,	FieldNm=CMPY);
quit;

proc sql;
create table AWP as
select a.*,b.*,c.*,d.*,e.*,f.*,g.*,h.*,i.*
from 		AWPBase		a 
left join	AWPT12CY	b	on a.Carrier=b.Carrier and a.productcode=b.productcode and a.transcode=b.transcode
left join	AWPT12PY	c	on a.Carrier=c.Carrier and a.productcode=c.productcode and a.transcode=c.transcode
left join	AWPT3CY		d	on a.Carrier=d.Carrier and a.productcode=d.productcode and a.transcode=d.transcode
left join	AWPT3PY		e	on a.Carrier=e.Carrier and a.productcode=e.productcode and a.transcode=e.transcode
left join	AWPYTDCY	f	on a.Carrier=f.Carrier and a.productcode=f.productcode and a.transcode=f.transcode
left join	AWPYTDPY	g	on a.Carrier=g.Carrier and a.productcode=g.productcode and a.transcode=g.transcode
left join	AWPCMCY		h	on a.Carrier=h.Carrier and a.productcode=h.productcode and a.transcode=h.transcode
left join	AWPCMPY		i	on a.Carrier=i.Carrier and a.productcode=i.productcode and a.transcode=i.transcode;
quit;

proc sql;
create table AWP_2 as
select
	case when a.productcode in ('BOP', 'BOP-GARAGE') then 'BOP'
	when a.productcode in ('CGL', 'GL') then 'CGL'
	when a.productcode in ('PL', 'EO', 'PL1') then 'PL'
	when a.productcode in ('WCOM', 'WC') then 'WC'
	else 'Other' end as productcode2,
a.*
from AWP a
;
quit;

proc sql;
create table AWP_3 as
select
case when CarrierNameRollUp in &CurrentCarriers. then carriernamerollup else 'All Others' end as CurrentCarriers,
*
from awp_2
;
quit;


PROC EXPORT
DATA=AWP_3 
OUTFILE= "/sso/win_wrkgrp/CNTL/SBI/RTB/CL Acquisition and SBI Monthly/SAS Exports/AWP.txt"
DBMS=TAB Replace;
RUN;
