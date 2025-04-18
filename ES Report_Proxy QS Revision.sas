/*Changed signon to sas version from txt version*/
Options NOCONNECTMETACONNECTION;
%include '/home/a114064/signon3.sas';

/*Pull Epic Production Funnel*/
PROC SQL;
CREATE TABLE Epic2018QF AS
SELECT DISTINCT
	Compress(Compress(P.PolicyNumber),'#') AS PolicyNumber,
	P.PolicyNumber AS ActualPolicyNumber,
	P.UniqPolicy,
	B.Lookup_Code,
	Compress(L.LineIDNumber,"-") as LineIDNumber,
	CL.NameOf AS BusinessName,
	L.CdStateCodeIssuing as State,
	BECA.BECAIntent AS AMSBECA,
	LS.CdLineStatusCode,
	DATEPART(P.EffectiveDate) AS EffectiveDate FORMAT DATE9.,
	DATEPART(P.ExpirationDate) AS ExpirationDate FORMAT DATE9.,
	CASE WHEN today() >= DATEPART(P.EffectiveDate) AND today() < DATEPART(P.ExpirationDate) THEN 1 ELSE 0 END AS PIFCnt,
	(CASE 
		WHEN P.AnnualizedPremium > 0 THEN P.AnnualizedPremium 
		WHEN P.EstimatedPremium > 0  THEN P.EstimatedPremium 
		WHEN P.LastDownloadedPremium > 0  THEN P.LastDownloadedPremium
    	WHEN P.BilledPremium then P.BilledPremium ELSE 0 END) AS TotalWrittenPremium,
	CASE WHEN LS.CdLineStatusCode = 'PD' THEN 1 ELSE 0 END AS PartnerDecline,
	CASE WHEN LS.CdLineStatusCode = 'CUD' THEN 1 ELSE 0 END AS CustomerDecline,
	CASE WHEN LS.CdLineStatusCode IN ('NWQ','UWR') THEN 1 ELSE 0 END AS UnderwritingRef,
	1 AS QfCnt
FROM
	BDEP.Policy P
        INNER JOIN BDEP.Line L ON L.UniqPolicy = P.UniqPolicy
        INNER JOIN BDEP.Company C ON C.UniqEntity = L.UniqEntityCompanyIssuing
		INNER JOIN BDEP.CdLineStatus LS ON L.UniqCdLineStatus = LS.UniqCdLineStatus
		LEFT JOIN BDEP.Client CL ON P.UniqEntity = CL.UniqEntity
		LEFT JOIN 
	(SELECT
		*
	FROM
		BIT.Customer B 
	WHERE 
		B.EpicVersion = 2018)
	B	ON P.UniqEntity = B.Unique_Entity
		LEFT JOIN
	(
	SELECT DISTINCT 
		UniqEntity,
		InsertedDate AS VarInsertedDate,
		MAX(InsertedDate) AS MaxInsertedDate FORMAT DATETIME22.3,
		OptionCode AS BECAIntent
	FROM
		BDEP.ENTITYAGENCYDEFINED AS A
	WHERE
		UPPER(A.CATEGORYCODE) LIKE '%BECALABEL%'
	GROUP BY
		UniqEntity
	HAVING 
		MaxInsertedDate = VarInsertedDate) 
	BECA ON P.UniqEntity = BECA.UniqEntity
WHERE
	C.LookupCode = 'EVAIN1'
	AND PolicyNumber IS NOT NULL
	AND LS.CdLineStatusCode NOT IN ('ECQ','ECU','DUP','DUQ','ERR')
	AND UPPER(PolicyNumber) NOT LIKE '%EPICDUP%'
	AND UPPER(PolicyNumber) NOT LIKE '%EPICTEST%'
;
QUIT;

PROC SQL;
CREATE TABLE Epic2018QF AS
SELECT
	*,
	(CASE WHEN CdLineStatusCode = 'CAN' then ROUND((365-(intck('DAY',EffectiveDate,ExpirationDate)))/365 * TotalWrittenPremium,.01) ELSE 0 END) *-1 AS CancelledPremium,
	TotalWrittenPremium - (CASE WHEN CdLineStatusCode = 'CAN' THEN ROUND((365-(intck('DAY',EffectiveDate,ExpirationDate)))/365*TotalWrittenPremium,.01) ELSE 0 end) as NetPremium
FROM
	Epic2018QF
;
QUIT;

/*Pull in Producer Related Information Based on Servicing Codes in Epic 2018*/
proc sql;
create table Servicing as
Select distinct	
	P.UniqPolicy,
	sr.CdServicingRoleCode,
	E.NameOf
from
	BDEP.policy p
		join BDEP.line l on p.UniqPolicy = l.UniqPolicy
		join BDEP.LineEmployeeServicingJT les on l.UniqLine = les.UniqLine
		join BDEP.Employee e on les.UniqEntity = e.UniqEntity
		join BDEP.CdServicingRole sr on Les.UniqCdServicingRole = sr.UniqCdServicingRole
GROUP BY
	P.UniqPolicy
;
quit;

proc sort data = Servicing nodupkey; by uniqpolicy CdServicingRoleCode; RUN;
proc sort data = Servicing; by uniqpolicy CdServicingRoleCode nameof; run;

PROC TRANSPOSE DATA=Servicing OUT=Servicing_Trans (DROP = _NAME_ _LABEL_); *NAME=UniqPolicy;
 ID CdServicingRoleCode;
 VAR nameof;
 BY notsorted UniqPolicy;
RUN;

proc sql;
create table Epic2018QF_Servicing AS
SELECT
	A.*,
	B.QTE AS OriginallyQuotedBy,
	B.PRO AS ESProducer,
	B.UPD AS LastUpdatedBy
FROM
	Epic2018QF A
		LEFT JOIN Servicing_Trans B ON A.UniqPolicy = B.UniqPolicy
;
QUIT;

DATA QFScrubbed;
SET Epic2018QF_Servicing;

IF Substr(PolicyNumber,1,3) NE '3AA' THEN DO;
	IF Substr(PolicyNumber,1,2) NE 'QT' THEN PolicyNumber = 'QT'||PolicyNumber;
END;

IF CdLineStatusCode IN ('CAN','NEW','NON','PLB','PRA','REI','REN','REW','RIS','RNR') THEN SaleCnt = 1; ELSE SaleCnt = 0;

IF TotalWrittenPremium = 0 THEN DELETE;
IF TotalWrittenPremium = . THEN DELETE;

If SaleCnt = 0 THEN PIFCnt = 0;
If SaleCnt = 0 THEN TotalWrittenPremium = 0; 
If SaleCnt = 0 THEN CancelledPremium = 0; 
If SaleCnt = 0 THEN NetPremium = 0; 

RUN;

PROC SORT DATA = QFScrubbed; BY Lookup_Code EffectiveDate; RUN;

DATA RBSale (KEEP = UniqPolicy RBFlag);
SET QFScrubbed;

IF SaleCnt = 1;

IF Lag(Lookup_Code) = Lookup_Code THEN RBFlag = 1; 
IF CdLineStatusCode = 'REN' THEN RBFlag = 1; 

IF Lag(Lookup_Code) = Lookup_Code THEN DO;
	Difference = datepart(EffectiveDate) - Lag(datepart(ExpirationDate));
	END;

If Difference > 7 THEN RBFlag = 0;

RUN;

PROC SQL;
CREATE TABLE QFandRB AS
SELECT
	A.*,
	CASE WHEN B.RBFlag = . THEN 0 ELSE RBFlag END AS RBFlag
FROM
	QFScrubbed A 
		LEFT JOIN RBSale B ON A.UniqPolicy = B.UniqPolicy
;
QUIT;

PROC SQL;
CREATE TABLE Employees AS
SELECT DISTINCT 
	EMPL_ID,
	EMPL_NAM
FROM
	DSE.Employee_View
ORDER BY 
	Empl_id
;
QUIT;

proc sort data = employees nodupkey; by empl_id; run;

/*Pull BQX Evanston Production*/
/*BQX source changed to SF from SQL*/
PROC SQL;
%sf_ref_acs_tok (warehouse=FREE_THE_DATA_L);
CREATE TABLE QuoteMasterDetail AS SELECT * FROM CONNECTION TO ODBC
(SELECT 
	BusinessState as "State",
	BECAIntent as "BECAIntent",
	BusinessPhoneNumber as "BusinessPhoneNumber",
	BusinessEmailAddress as "BusinessEmailAddress",
	UniqPolicy as "UniqPolicy",
	EpicVersion as "EpicVersion",
	QuoteNumber as "QuoteNumber",
	QuoteDate as "QuoteDate",
	RHEvanstonCnt as "RHEvanstonCnt",
	QIEvanstonCnt as "QIEvanstonCnt",
	(CASE WHEN RecommendedCarrierName = 'Evanston' AND QIOutcome = 'QI Rate Present' THEN 1 ELSE 0 END) AS "EvanstonQFOnline",
	FirstAgentId as "FirstAgentId",
	LastAgentId as "LastAgentId",
	IsQuoteTest as "IsQuoteTest"
FROM
	CL_SBI.Published.BQX_QuoteMasterDetail
WHERE
	IsQuoteTest = 'N'
	AND (RhEvanstonCnt = 1
		OR QIEvanstonCnt = 1
		OR (RecommendedCarrierName = 'Evanston' AND QIOutcome = 'QI Rate Present'))
);
QUIT;

PROC SQL;
CREATE TABLE BQXProduction AS
SELECT
	A.State,
	A.BECAIntent,
	A.BusinessPhoneNumber,
	A.BusinessEmailAddress,
	A.UniqPolicy,
	A.EpicVersion,
	CASE WHEN E1.Empl_ID NE '' THEN compress(E1.EMPL_NAM) ELSE A.FirstAgentID END AS FirstAgentID,
	CASE WHEN E2.Empl_ID NE '' THEN compress(E2.EMPL_NAM) ELSE A.LastAgentID END AS LastAgentID,
	compress(A.QuoteNumber,"-") as QuoteNumber,
	A.QuoteDate as Date,
	A.RHEvanstonCnt,
	A.QIEvanstonCnt,
	A.EvanstonQFOnline
FROM
	QuoteMasterDetail A
		LEFT JOIN Employees E1 ON A.FirstAgentID = E1.Empl_ID
		LEFT JOIN Employees E2 ON A.LastAgentID = E2.Empl_ID
WHERE
	A.QuoteDate >= '18FEB2019'D
;
QUIT;

/******************************************************EPIC DATA***************************************************************/
PROC SQL;
CREATE TABLE EpicBQX AS
SELECT DISTINCT
	MAX(CASE WHEN B.QuoteNumber NE '' THEN B.Date ELSE A.EffectiveDate END) AS QuoteDate FORMAT Date9.,
	A.*,
	CASE WHEN B.EvanstonQFOnline = 1 THEN 1 ELSE 0 END AS EvanstonQFOnline,
	FirstAgentID,
	LastAgentID,
	BECAIntent
FROM
	QFandRB A
		LEFT JOIN BQXProduction B ON A.UniqPolicy = B.UniqPolicy
GROUP BY
	A.UniqPolicy
;
QUIT;

PROC SORT DATA = EpicBQX; BY UniqPolicy DESCENDING EvanstonQFOnline; RUN;

DATA EpicBQXNoDups;
FORMAT Date DATE9.;
SET EpicBQX;

IF LAG(UniqPolicy) = UniqPolicy THEN LagVar = 1; ELSE LagVar = 0;

IF LAGVAR = 0;
Date = QuoteDate;
drop lagvar QuoteDate;

IF EvanstonQFOnline = 1 THEN QFOnlineCnt = 1; ELSE QFOnlineCnt = 0; 
IF QFOnlineCnt = 1 THEN QFOfflineCnt = 0; ELSE QFOfflineCnt = 1;

IF EvanstonQFOnline = 1 && SaleCnt = 1 THEN SaleOnlineCnt = 1; ELSE SaleOnlineCnt = 0; 
IF EvanstonQFOnline = 0 && SaleCnt = 1 THEN SaleOfflineCnt = 1; ELSE SaleOfflineCnt = 0; 

IF BECAIntent = '' THEN BECAIntent = AMSBECA;

RUN;

PROC SORT DATA = EpicBQXNODups; BY UniqPolicy DESCENDING SaleCnt; RUN;

/*Added this step and next so Quotes and Sales tab would still have data.*/
DATA EpicBQXNODups_QStab;
SET EpicBQXNoDups;

DROP AMSBECA;
RUN;

PROC SQL;
CREATE TABLE EpicBQXNODups_QStab AS 
SELECT DISTINCT
	*
FROM
	EpicBQXNODups_QStab
;
QUIT;
/*END*/

DATA EpicBQXNODups;
SET EpicBQXNoDups;

DROP AMSBECA 
/*Newly added to DROP Clause*/
UniqPolicy Lookup_Code OriginallyQuotedBy ESProducer LastUpdatedBy BusinessName BUSPhoneNumber RESPhoneNumber ACTPhoneNumber MOBPhoneNumber PhoneNumber;
RUN;

/*Newly Added Step*/
PROC SQL;
CREATE TABLE EpicBQXNoDups AS 
SELECT DISTINCT
	*
FROM
	EpicBQXNoDups
;
QUIT;

PROC SORT DATA = EpicBQXNoDups; BY PolicyNumber; RUN;

data lagcheck;
set EpicBQXNoDups;

IF DATE >= '01FEB2022'D;
if lag(PolicyNumber) = PolicyNumber THEN lagvar = 1; 

RUN;

DATA Lags;
SET LagCheck;

IF LagVar = 1;

if lag(PolicyNumber) = PolicyNumber THEN lagvarnew = 1; 

/*IF Lagvarnew = .;*/
RUN;

/*Stop here*/

/*Proxy Rockhopper Completes*/
PROC SQL;
CREATE TABLE PCATCompletes AS
SELECT 		
	A.RunOnDate as Date,
	State,
	count(A.VisitSummaryID) as RHEvanstonCnt
FROM		
	BIT.PCAT_Visits A
/*		LEFT JOIN DSE.DATE B ON input(RunOnDate, yymmdd10.) = B.DT_VAL*/
		LEFT JOIN DSE.DATE B ON RunOnDate = B.DT_VAL
WHERE		
	RunOnDate >= '18FEB2019'D
/*	AND UserType = 2*/
	AND (Message LIKE ('%9364%')
	OR Message LIKE ('%465%'))
GROUP BY
	Date,
	State
ORDER BY
	Date,
	State
;
QUIT;

/*Pull BQX Evanston Question Set (which will have records that are not in the BQX Production Funnel)*/
PROC SQL;
%sf_ref_acs_tok(warehouse=FREE_THE_DATA_L, sf_create_tmp=quotemasterdetail);
CREATE TABLE EvanstonQuestionSet AS SELECT * FROM CONNECTION TO odbc
(SELECT DISTINCT 
	QMD.QuoteDate as "Date",
	count(distinct qad.quote_Number) as "EvanstonQuestionSet"
FROM 
	CL_SBI.Published.QuoteQuestionAnswerDetail QAD
		INNER JOIN CL_SBI.Published.QuoteQuestionDetail QQD ON QQD.Question_Id = QAD.Question_Id
		LEFT JOIN &sf_read_tmp1 qmd on qad.quote_number = qmd.quotenumber
WHERE 
	lower(QQD.Question_Text) like 'evanston_use_subcontractors%'
	and qmd.IsQuoteTest = 'N'
GROUP BY
	QMD.QuoteDate)
;
DISCONNECT FROM odbc;
QUIT;

proc delete data = quotemasterdetail; run;

/*New SF source for PDW Telecom data*/
PROC SQL;
%sf_ref_acs_tok(warehouse=FREE_THE_DATA_S);
CREATE TABLE Calls AS
SELECT * FROM CONNECTION TO ODBC
	(SELECT
		IntrvlStartDate as "IntrvlStartDate",
		SUM(SkillOfferedCallsCnt) as "CallsOffered",
		SUM(SkillAbandonedCallsCnt) as "AbandonedCalls",
		SUM(HandledCallsCnt) as "CallsAnswered"
	FROM
		TELECOM.PUBLISHED.DIMSKILL A,
		TELECOM.PUBLISHED.FACTSKILLSTATS B
	WHERE
		A.SkillName = 'CS_AU_LI_MARKEL'
		AND SkillOfferedCallsCnt > 0
		AND to_date(B.IntrvlStartDate) >= '2019-02-18'
		AND A.DimSkillID = B.DimSkillID
	GROUP BY
		IntrvlStartDate
	ORDER BY
		IntrvlStartDate
);
DISCONNECT FROM ODBC;
QUIT;

Data Calls; 
  Retain Date;
  Set Calls;
  Format Date Date9.;
  Date = DATEPART(IntrvlStartDate);
  drop IntrvlStartDate;
run;

/******************************************************COMBINE IT ALL TOGETHER**********************************************************/
DATA QuoteStartMeasures;
SET BQXProduction PCATCompletes EvanstonQuestionSet Calls;
EffectiveDate = Date;
RUN;

PROC SORT data = QuoteStartMeasures; BY Date EffectiveDate State BECAIntent; RUN;

PROC SUMMARY DATA = QuoteStartMeasures;
BY Date EffectiveDate State BECAIntent;
VAR RHEvanstonCnt QIEvanstonCnt EvanstonQFOnline EvanstonQuestionSet CallsOffered AbandonedCalls CallsAnswered;
OUTPUT OUT = QuoteStartMeasuresSum (DROP = _TYPE_ _FREQ_) SUM=;
RUN;

PROC SORT data = EpicBQXNoDups; BY Date EffectiveDate State BECAIntent; RUN;

PROC SUMMARY DATA = EpicBQXNoDups;
BY Date EffectiveDate State BECAIntent;
VAR QFCnt QFOnlineCnt QFOfflineCnt SaleCnt SaleOnlineCnt SaleOfflineCnt PIFCnt TotalWrittenPremium CancelledPremium NetPremium;
OUTPUT OUT = QFSaleFinalSum (DROP = _TYPE_ _FREQ_) SUM=;
RUN;

DATA FinalAggregate;
SET QuoteStartMeasuresSum QFSaleFinalSum;
RUN;

PROC SORT DATA = FinalAggregate; BY Date EffectiveDate State BECAIntent; RUN;

PROC SUMMARY DATA = FinalAggregate;
BY Date EffectiveDate State BECAIntent;
VAR RHEvanstonCnt QIEvanstonCnt EvanstonQFOnline EvanstonQuestionSet QFCnt QFOnlineCnt QFOfflineCnt SaleCnt SaleOnlineCnt SaleOfflineCnt PIFCnt TotalWrittenPremium CancelledPremium NetPremium CallsOffered AbandonedCalls CallsAnswered;
OUTPUT OUT = FinalAggregateSum (DROP = _TYPE_ _FREQ_) SUM=;
RUN;

data FinalAggregateSum;
    set FinalAggregateSum;
    array nm(*) _numeric_ ;
    do _n_ = 1 to dim(nm);
    nm(_n_) = coalesce(nm(_n_),0);
    END;
    DROP i;
LastUpdatedDate = today();
FORMAT LastUpdatedDate DATE9.;
RUN;

/*Switched to SF for BQX from SQL*/
PROC SQL;
%sf_ref_acs_tok (warehouse=FREE_THE_DATA_L);
CREATE TABLE Yields1 AS SELECT * FROM CONNECTION TO ODBC
(SELECT DISTINCT 
	QuoteCreatedDate as "QuoteCreatedDate",
	SUM(QSCnt) AS "QSCnt",
	SUM(RHCnt) AS "RHCnt",
	SUM(QICnt) AS "QICnt",
	SUM(QFCnt) AS "QFCnt"
FROM 
	CL_SBI.Published.BQX_QuoteMasterDetail
WHERE 
	IsQuoteTest = 'N'
	AND SelectedCoverage = 'CGL'
GROUP BY 
	QuoteCreatedDate
ORDER BY 
	QuoteCreatedDate);
QUIT;

DATA Yields2;
SET Yields1;

RHYield = RHCnt/QSCnt;
QIYield = QICnt/QSCnt;
QSQFYield = QFCnt/QSCnt;

FORMAT RHYield PERCENT10.2 QIYield PERCENT10.2  QSQFYield PERCENT10.2;
RUN;

PROC SQL;
CREATE TABLE FinalAggregateSum2 AS 
SELECT 
	A.*,
	B.RHYield,
	B.QIYield,
	B.QSQFYield
FROM
	FinalAggregateSum A
		LEFT JOIN Yields2 B ON A.Date = B.QuoteCreatedDate
;
QUIT;

/*Add in every day by every day's rate. */

DATA FinalAggregateSumQS;
SET FinalAggregateSum2;

/*Added for illustration purposes*/
OQuoteStartRHE = RHEvanstonCnt/.57;
OQuoteStartQIE = QIEvanstonCnt/.26;
OQuoteStartQIR = EvanstonQFOnline/.26;

OQuoteStart = OQuoteStartRHE+OQuoteStartQIE+OQuoteStartQIR;
/*End*/

QuoteStartRHE = RHEvanstonCnt/RHYield;
QuoteStartQIE = QIEvanstonCnt/QIYield;
QuoteStartQIR = EvanstonQFOnline/QIYield;

QuoteStart = QFCnt/QSQFYield/.8812;

/*QuoteStart = QuoteStartRHE+QuoteStartQIE+QuoteStartQIR;*/

RUN;

PROC SQL;
CREATE TABLE EandSAgg AS
SELECT
	B.ACCT_CCYYMM,
	B.ACCT_CCYYMMWW,
	C.ACCT_CCYYMM as EffectiveACCT_CCYYMM,
	C.ACCT_CCYYMMWW as EffectiveACCT_CCYYMMWW,
	A.*,
	S.ST_NAM,
	CASE WHEN R.Phase = '' THEN 'Unknown' ELSE R.Phase END AS Phase
FROM
	FinalAggregateSumQS A
		LEFT JOIN DSE.Date B ON A.Date = B.DT_VAL
		LEFT JOIN DSE.Date C ON A.EffectiveDate = C.DT_VAL
		LEFT JOIN DSE.State S ON A.State = S.ALPHA_ST_CD
		LEFT JOIN CLAcq.EvanstonRolloutPhases R ON UPPER(S.ST_NAM) = UPPER(R.State)
;
QUIT;

DATA EandSAgg;
FORMAT State $100.;
SET EandSAgg;
State = PROPCASE(ST_NAM);
DROP ST_NAM;
RUN;

PROC SQL;
SELECT
	EffectiveACCT_CCYYMM,
	SUM(QuoteStart) AS QSCnt
FROM
	EandSAgg
GROUP BY
	EffectiveACCT_CCYYMM
;
QUIT;

/*Remove the word new from the table name if approved.*/
PROC DELETE DATA = CLAcq.EandSAgg; RUN;

PROC SQL;
CREATE TABLE CLAcq.EandSAgg AS
SELECT
	*
FROM
	EandSAgg
;
QUIT;

/*Remove the word new from the table name if approved.*/
PROC DELETE DATA = CLAcq.EandSQFandSales; RUN;

/*Remove the word new from the table name if approved.*/
PROC SQL;
CREATE TABLE CLAcq.EandSQFandSales AS
SELECT
	A.*,
	B.ACCT_CCYYMM as QuoteAccountingMonth,
	C.ACCT_CCYYMM as EffectiveAccountingMonth
FROM
	EpicBQXNODups_QStab A
		LEFT JOIN DSE.Date B ON A.Date = B.DT_VAL
		LEFT JOIN DSE.Date C ON A.EffectiveDate = C.DT_VAL
;
QUIT;

PROC SQL;
CREATE TABLE Months AS
SELECT DISTINCT
	ACCT_CCYYMM,
	min(DT_VAL) as MinDate,
	max(DT_VAL) as MaxDate
FROM
	DSE.DATE
WHERE
	DT_VAL <= TODAY()
	and ACCT_CCYYMM NE .
GROUP BY
	ACCT_CCYYMM
;
QUIT;

PROC DELETE DATA = CLAcq.ESPIF; RUN;

/*Remove the word new from the table name if approved.*/
PROC SQL;
CREATE TABLE CLAcq.ESPIF AS
SELECT
	B.ACCT_CCYYMM,
	SUM(CASE WHEN A.EffectiveDate <= B.MaxDate and A.ExpirationDate > B.MaxDate THEN 1 ELSE 0 END) AS PIF
FROM 
	EpicBQXNoDups A
		inner join Months B on A.EffectiveDate <= B.MaxDate and A.ExpirationDate >= B.MinDate
WHERE 
	SaleCnt = 1
GROUP BY
	ACCT_CCYYMM
;
QUIT;
