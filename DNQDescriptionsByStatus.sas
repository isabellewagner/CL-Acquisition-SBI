
/* KP Update 2024-10-24 - Added check on QuoteCarrierRqstResponseDetail table to only grab the most recent record from each carrier */

Options NOCONNECTMETACONNECTION;
%include '/home/a114064/signon.txt';

%LET StartMo = '202201';

/*Pull the fields needed from BQX QMD*/
/*Replaced SQL source for BQX with SF source*/
PROC SQL;
%sf_ref_acs_tok (warehouse=FREE_THE_DATA_L);
CREATE TABLE qte AS SELECT * FROM CONNECTION TO ODBC
(SELECT DISTINCT
	QuoteNumber as "QuoteNumber",
	SelectedCoverage as "SelectedCoverage",
	BECAIntent as "BECAIntent",
	BusinessState as "BusinessState",
	ProgMonth as "ACCT_CCYYMM"
FROM 
	CL_SBI.Published.BQX_QuoteMasterDetail);
QUIT;

/*Pull the request status for technical and ineligible status codes*/
/*Replaced SQL source for BQX with SF source*/
PROC SQL;
%sf_ref_acs_tok (warehouse=FREE_THE_DATA_L);
CREATE TABLE rqst AS SELECT * FROM CONNECTION TO ODBC
(SELECT DISTINCT 
	Quote_Number as "QuoteNumber",
	Carrier_Name as "CarrierName",
	Carrier_Request_Status as "CarrierRequestStatus",
	Carrier_Request_Id as "CarrierRequestId"
FROM 
	CL_SBI.Published.QuoteCarrierRqstResponseDetail A
WHERE 
	Carrier_Request_Status in ('failed','ineligible')
    	AND A.Last_Updated_Time_stamp = (SELECT MAX(A2.Last_Updated_Time_stamp) 
                                     	 FROM CL_SBI.PUBLISHED.QUOTECARRIERRQSTRESPONSEDETAIL A2                                                 
                                     	 WHERE A.Quote_Number = A2.Quote_Number));
QUIT;

/*Pull the DNQ Descriptions*/
/*Replaced SQL source for BQX with SF source*/
PROC SQL;
%sf_ref_acs_tok (warehouse=FREE_THE_DATA_L);
CREATE TABLE dnq2 AS SELECT * FROM CONNECTION TO ODBC
(SELECT DISTINCT
	Quote_Number as "QuoteNumber",
	DNQ_Description as "DNQDescription",
	Carrier_Request_Id as "CarrierRequestId"
FROM
	CL_SBI.Published.QuoteCarrierDNQDetail
WHERE
	DNQ_Message <> 'SuccessPendingAction');
QUIT;

DATA dnq;
SET dnq2;
where DNQDescription NOT IN ("General Liability (v7)","Declined","Terminal risk decision.","The request is invalid.", "Expected a retrieve URL",
				"Workers' Compensation (v7)","Quote has been declined, and cannot be edited.","Invalid response status '403' for fein endpoint",
				"Based upon the data provided, CNA is unable to complete the rating process. Please review and correct the error condition(s) before resubmitting.",
				"Failed to create quote","We are unable to return a quote for GL in CA for your agency.", "This risk includes California location exposures that are not within appetite for agents outside California.",
				"Businessowners", "Expected a premium", "Expected a policy id", "Expected a 200 status code");
RUN;

/*Merge (Inner Join) the DNQ Descriptions and the Carrier Request Statuses*/
proc sort data = rqst; by QuoteNumber CarrierRequestId; run;
proc sort data = dnq; by QuoteNumber CarrierRequestId; run;

DATA RqstAndDNQ;
MERGE
	rqst (IN=A)
	dnq (IN=B);
BY QuoteNumber CarrierRequestId;

IF A=1 && B=1;

RUN;

/*Merge (Inner Join) the DNQ Descriptions, Carrier Request Statuses and BQX Data*/
proc sort data = RqstAndDNQ; by QuoteNumber; run;
proc sort data = Qte; by QuoteNumber; run;

DATA Total;
MERGE
	RqstAndDNQ (IN=A)
	Qte (IN=B);
BY QuoteNumber;

IF A=1 && B=1;

IF ACCT_CCYYMM >= &StartMo.;

RUN;

PROC SQL;
CREATE TABLE TotalDNQS AS
SELECT DISTINCT
	SelectedCoverage,
	CarrierName,
	ACCT_CCYYMM,
	BECAIntent,
	BusinessState,
	COUNT(DISTINCT CASE WHEN CarrierRequestStatus = 'failed' THEN QuoteNumber END) as TotalTechnicalFailures,
	COUNT(DISTINCT CASE WHEN CarrierRequestStatus = 'ineligible' THEN QuoteNumber END) as TotalEligibilityFailures,
	COUNT(DISTINCT QuoteNumber) as TotalDNQS
FROM
	Total
GROUP BY
	SelectedCoverage,
	CarrierName,
	ACCT_CCYYMM,
	BECAIntent,
	BusinessState
;
QUIT;

/*Technical DNQs*/
PROC SQL;
CREATE TABLE TotalDescriptionFailed AS
SELECT DISTINCT
	DNQDescription,
	SelectedCoverage,
	CarrierName,
	ACCT_CCYYMM,
	BECAIntent,
	BusinessState,
	COUNT(DISTINCT QuoteNumber) as QuoteCount
FROM
	Total
WHERE
	CarrierRequestStatus = 'failed'
GROUP BY
	DNQDescription,
	SelectedCoverage,
	CarrierName,
	ACCT_CCYYMM,
	BECAIntent,
	BusinessState
ORDER BY
	SelectedCoverage,
	CarrierName,
	ACCT_CCYYMM,
	BECAIntent,
	BusinessState,
	QuoteCount DESC
;
QUIT;

DATA TotalDescriptionFailedOBS (DROP=QuoteCount);
SET TotalDescriptionFailed;
BY SelectedCoverage CarrierName ACCT_CCYYMM BECAIntent BusinessState;

IF LAG(ACCT_CCYYMM) NE ACCT_CCYYMM THEN OBSCount = 1; ELSE OBSCount+1;

RUN;

PROC SORT DATA = TotalDescriptionFailedOBS; BY DNQDescription SelectedCoverage CarrierName ACCT_CCYYMM BECAIntent BusinessState; RUN;
PROC SORT DATA = Total; BY DNQDescription SelectedCoverage CarrierName ACCT_CCYYMM BECAIntent BusinessState; RUN;

DATA TotalDescriptionFailedOBS_1;
MERGE 
	TotalDescriptionFailedOBS (IN=A)
	Total (IN=B);
BY DNQDescription SelectedCoverage CarrierName ACCT_CCYYMM BECAIntent BusinessState;
IF A=1;
RUN;

PROC SQL;
CREATE TABLE TotalDescriptionFailedOBS_1B AS
SELECT DISTINCT
	A.DNQDescription,
	A.SelectedCoverage,
	A.CarrierName,
	A.ACCT_CCYYMM,
	A.BECAIntent,
	A.BusinessState,
	COUNT(DISTINCT CASE WHEN A.DNQDescription = B.DNQDescription THEN A.QuoteNumber END) AS TotalDistinctCount,
	COUNT(DISTINCT CASE WHEN A.DNQDescription NE B.DNQDescription THEN A.QuoteNumber END) AS Matched
FROM
	TotalDescriptionFailedOBS_1 A
		LEFT JOIN Total B ON A.QuoteNumber = B.QuoteNumber
WHERE
	A.CarrierRequestStatus = 'failed'
	and B.CarrierRequestStatus = 'failed'
GROUP BY
	A.DNQDescription,
	A.SelectedCoverage,
	A.CarrierName,
	A.ACCT_CCYYMM,
	A.BECAIntent,
	A.BusinessState
ORDER BY
	A.SelectedCoverage,
	A.CarrierName,
	A.ACCT_CCYYMM,
	A.BECAIntent,
	A.BusinessState,
	TotalDistinctCount DESC
;
QUIT;

DATA TotalDescriptionFailedOBS_1C;
RETAIN DNQDescription SelectedCoverage CarrierName ACCT_CCYYMM BECAIntent BusinessState Matched StandAlone TotalDistinctCount;
SET TotalDescriptionFailedOBS_1B;

StandAlone = TotalDistinctCount-Matched;
RUN;

PROC SQL;
CREATE TABLE TotalDescriptionFailedOBS_1D AS
SELECT 
	A.*,
	B.TotalTechnicalFailures,
	B.TotalDNQS,
	'Technical' as CarrierRequestStatus
FROM
	TotalDescriptionFailedOBS_1C A
		LEFT JOIN TotalDNQS B ON A.SelectedCoverage = B.SelectedCoverage AND A.CarrierName = B.CarrierName AND A.ACCT_CCYYMM = B.ACCT_CCYYMM AND A.BECAIntent = B.BECAIntent AND A.BusinessState = B.BusinessState
ORDER BY
	SelectedCoverage,
	CarrierName,
	ACCT_CCYYMM,
	BECAIntent,
	BusinessState,
	TotalDistinctCount DESC
;
QUIT;
/*This step may not be necessary*/
/*DATA TotalDescriptionFailedOBS_1E;*/
DATA TotalDescriptionFailedOBS_1E;
SET TotalDescriptionFailedOBS_1D;
TotalDistinctvsStatus = TotalDistinctCount/TotalTechnicalFailures;
TotalStatusFails=TotalTechnicalFailures;
TotalDistinctvsTotal = TotalDistinctCount/TotalDNQS;
FORMAT TotalDistinctvsStatus PERCENT10.2;
FORMAT TotalDistinctvsTotal PERCENT10.2;
RUN;

/*PROC EXPORT
DATA=TotalDescriptionFailedOBS_1E 
OUTFILE= "/sso/win_wrkgrp/Public/SBI/Adhoc/&CarrierNam &TODAY_TITLE..XLSX" 
DBMS=xlsx REPLACE; SHEET = "FailedOBS";
RUN;*/


/*Eligibility*/

PROC SQL;
CREATE TABLE TotalDescriptionineligible AS
SELECT
	DNQDescription,
	SelectedCoverage,
	CarrierName,
	ACCT_CCYYMM,
	BECAIntent,
	BusinessState,
	COUNT(DISTINCT QuoteNumber) as QuoteCount
FROM
	Total
WHERE
	CarrierRequestStatus = 'ineligible'
GROUP BY
	DNQDescription,
	SelectedCoverage,
	CarrierName,
	ACCT_CCYYMM,
	BECAIntent,
	BusinessState
ORDER BY
	SelectedCoverage,
	CarrierName,
	ACCT_CCYYMM,
	BECAIntent,
	BusinessState,
	QuoteCount DESC
;
QUIT;

DATA TotalDescriptionineligibleOBS (DROP=QuoteCount);
SET TotalDescriptionineligible;
BY SelectedCoverage CarrierName ACCT_CCYYMM BECAIntent 	BusinessState;

IF LAG(ACCT_CCYYMM) NE ACCT_CCYYMM THEN OBSCount = 1; ELSE OBSCount+1;
/*IF LAG(SelectedCoverage) NE SelectedCoverage THEN OBSCount = 1; ELSE OBSCount+1;*/
/*IF OBSCount =< 5;*/
RUN;

PROC SORT DATA = TotalDescriptionineligibleOBS; BY DNQDescription SelectedCoverage CarrierName ACCT_CCYYMM BECAIntent BusinessState; RUN;
PROC SORT DATA = Total; BY DNQDescription SelectedCoverage CarrierName ACCT_CCYYMM BECAIntent BusinessState; RUN;

DATA TotalDescriptionineligibleOBS_1;
MERGE 
	TotalDescriptionineligibleOBS (IN=A)
	Total (IN=B);
BY DNQDescription SelectedCoverage CarrierName ACCT_CCYYMM BECAIntent BusinessState;
IF A=1;
/*IF OBS = 1;*/
RUN;

PROC SQL;
CREATE TABLE TotalDescriptionineligibleOBS_1B AS
SELECT
	A.DNQDescription,
	A.SelectedCoverage,
	A.CarrierName,
	A.ACCT_CCYYMM,
	A.BECAIntent,
	A.BusinessState,
	COUNT(DISTINCT CASE WHEN A.DNQDescription = B.DNQDescription THEN A.QuoteNumber END) AS TotalDistinctCount,
	COUNT(DISTINCT CASE WHEN A.DNQDescription NE B.DNQDescription THEN A.QuoteNumber END) AS Matched
FROM
	TotalDescriptionineligibleOBS_1 A
		LEFT JOIN Total B ON A.QuoteNumber = B.QuoteNumber
WHERE
	A.CarrierRequestStatus = 'ineligible' 
	and B.CarrierRequestStatus = 'ineligible'
GROUP BY
	A.DNQDescription,
	A.SelectedCoverage,
	A.CarrierName,
	A.ACCT_CCYYMM,
	A.BECAIntent,
	A.BusinessState
ORDER BY
	A.SelectedCoverage,
	A.CarrierName,
	A.ACCT_CCYYMM,
	A.BECAIntent,
	A.BusinessState,
	TotalDistinctCount DESC
;
QUIT;

DATA TotalDescriptionineligibleOBS_1C;
RETAIN DNQDescription SelectedCoverage CarrierName ACCT_CCYYMM BECAIntent BusinessState Matched StandAlone TotalDistinctCount;
SET TotalDescriptionineligibleOBS_1B;

StandAlone = TotalDistinctCount-Matched;
RUN;

PROC SQL;
CREATE TABLE TotalDescriptionineligibleOBS_1D AS
SELECT 
	A.*,
	B.TotalEligibilityFailures,
	B.TotalDNQS,
	'Eligible' as CarrierRequestStatus
FROM
	TotalDescriptionineligibleOBS_1C A
		LEFT JOIN TotalDNQS B ON A.SelectedCoverage = B.SelectedCoverage AND A.CarrierName = B.CarrierName AND A.ACCT_CCYYMM = B.ACCT_CCYYMM AND A.BECAIntent = B.BECAIntent AND A.BusinessState = B.BusinessState
ORDER BY
	SelectedCoverage,
	CarrierName,
	ACCT_CCYYMM,
	BECAIntent,
	BusinessState,
	TotalDistinctCount DESC
;
QUIT;
/*This step may not be necessary*/
/*DATA TotalDescriptionineligibleOBS_1E;*/
DATA TotalDescriptionineligibleOBS_1E;
SET TotalDescriptionineligibleOBS_1D;
TotalDistinctvsStatus = TotalDistinctCount/TotalEligibilityFailures;
TotalStatusFails=TotalEligibilityFailures;
TotalDistinctvsTotal = TotalDistinctCount/TotalDNQS;
FORMAT TotalDistinctvsStatus PERCENT10.2;
FORMAT TotalDistinctvsTotal PERCENT10.2;
RUN;


/*OVERALL*/


PROC SQL;
CREATE TABLE TotalDescriptioninAll AS
SELECT
	DNQDescription,
	SelectedCoverage,
	CarrierName,
	ACCT_CCYYMM,
	BECAIntent,
	BusinessState,
	COUNT(DISTINCT QuoteNumber) as QuoteCount
FROM
	Total
GROUP BY
	DNQDescription,
	SelectedCoverage,
	CarrierName,
	ACCT_CCYYMM,
	BECAIntent,
	BusinessState
ORDER BY
	SelectedCoverage,
	CarrierName,
	ACCT_CCYYMM,
	BECAIntent,
	BusinessState,
	QuoteCount DESC
;
QUIT;

DATA TotalDescriptioninAllOBS (DROP=QuoteCount);
SET TotalDescriptioninAll;
BY SelectedCoverage CarrierName ACCT_CCYYMM BECAIntent	BusinessState;

IF LAG(ACCT_CCYYMM) NE ACCT_CCYYMM THEN OBSCount = 1; ELSE OBSCount+1;
/*IF LAG(SelectedCoverage) NE SelectedCoverage THEN OBSCount = 1; ELSE OBSCount+1;*/
/*IF OBSCount =< 5;*/
RUN;

PROC SORT DATA = TotalDescriptioninAllOBS; BY DNQDescription SelectedCoverage CarrierName ACCT_CCYYMM BECAIntent BusinessState; RUN;
PROC SORT DATA = Total; BY DNQDescription SelectedCoverage CarrierName ACCT_CCYYMM BECAIntent BusinessState; RUN;

DATA TotalDescriptioninAllOBS_1;
MERGE 
	TotalDescriptioninAllOBS (IN=A)
	Total (IN=B);
BY DNQDescription SelectedCoverage CarrierName ACCT_CCYYMM BECAIntent BusinessState;
IF A=1;
/*IF OBS = 1;*/
RUN;

PROC SQL;
CREATE TABLE TotalDescriptioninAllOBS_1B AS
SELECT
	A.DNQDescription,
	A.SelectedCoverage,
	A.CarrierName,
	A.ACCT_CCYYMM,
	A.BECAIntent,
	A.BusinessState,
	COUNT(DISTINCT CASE WHEN A.DNQDescription = B.DNQDescription THEN A.QuoteNumber END) AS TotalDistinctCount,
	COUNT(DISTINCT CASE WHEN A.DNQDescription NE B.DNQDescription THEN A.QuoteNumber END) AS Matched
FROM
	TotalDescriptioninAllOBS_1 A
		LEFT JOIN Total B ON A.QuoteNumber = B.QuoteNumber
GROUP BY
	A.DNQDescription,
	A.SelectedCoverage,
	A.CarrierName,
	A.ACCT_CCYYMM,
	A.BECAIntent,
	A.BusinessState
ORDER BY
	A.SelectedCoverage,
	A.CarrierName,
	A.ACCT_CCYYMM,
	A.BECAIntent,
	A.BusinessState,
	TotalDistinctCount DESC
;
QUIT;

DATA TotalDescriptioninAllOBS_1C;
RETAIN DNQDescription SelectedCoverage CarrierName ACCT_CCYYMM BECAIntent BusinessState Matched StandAlone TotalDistinctCount;
SET TotalDescriptioninAllOBS_1B;

StandAlone = TotalDistinctCount-Matched;
RUN;

PROC SQL;
CREATE TABLE TotalDescriptioninAllOBS_1D AS
SELECT 
	A.*,
	B.TotalDNQS,
	'Total' AS CarrierRequestStatus
FROM
	TotalDescriptioninAllOBS_1C A
		LEFT JOIN TotalDNQS B ON A.SelectedCoverage = B.SelectedCoverage AND A.CarrierName = B.CarrierName AND A.ACCT_CCYYMM = B.ACCT_CCYYMM AND A.BECAIntent = B.BECAIntent AND A.BusinessState = B.BusinessState
ORDER BY
	SelectedCoverage,
	CarrierName,
	ACCT_CCYYMM,
	BECAIntent,
	BusinessState,
	TotalDistinctCount DESC
;
QUIT;
/*This step may not be necessary*/
DATA TotalDescriptioninAllOBS_1E;
SET TotalDescriptioninAllOBS_1D;

TotalDistinctvsStatus = TotalDistinctCount/TotalDNQS;
FORMAT TotalDistinctvsStatus PERCENT10.2;
RUN;

DATA DNQByStatus;
SET TotalDescriptionFailedOBS_1E TotalDescriptionineligibleOBS_1E TotalDescriptioninAllOBS_1E;
RUN;


PROC DELETE DATA=CLACQ.DNQByStatus; RUN;
DATA CLACQ.DNQByStatus; SET DNQByStatus; RUN;
