/***Health of SBI data***/
/***Fifth check is canceled status policies missing a cancel date from BIT.EPICPolicy table***/
/***3/20/25: Adding policies where expiration - effective is not one year, but there's no cancel date/reason***/
/***Run this biweekly to monitor data validity***/

/*Today's date*/
DATA Today; dt_val = put(today(),date9.); RUN;
PROC SQL; SELECT dt_val INTO: dt_val FROM Today; QUIT;

/*Canceled policies (according to status) but missing a cancel date.*/
PROC SQL;
CONNECT TO &SQLEng(noprompt="DSN=SQLServer; Server=MSS-P1-PCA-06; database=SmallBusinessInsurance;" &bulkparms read_isolation_level=RU);
CREATE TABLE MissingCancelDate AS SELECT * FROM CONNECTION TO &SQLEng
(SELECT DISTINCT
	C.Lookup_Code,
	E.PolicyNumber,
	E.ProductCode,
	E.PolicyTerm,
	E.EffectiveDate,
	E.ExpirationDate,
	E.CancelDate,
	E.CancelReason,
	E.PolicyStatus,
	E.CarrierCode,
	E.CarrierName,
	E.Broker,
	E.IsInForce,
	E.UniqEntity,
	E.UniqPolicy,
	E.UniqOriginalPolicy
FROM BIT.EPICPolicy E
	LEFT JOIN BIT.Customer C ON E.UniqEntity = C.Unique_Entity
WHERE E.PolicyStatus = 'CAN'
	AND E.CancelDate is null
	AND E.AMSUpdatedDate >= getdate()-14 AND E.AMSUpdatedDate <= getdate() /*updated in the last 2 weeks only*/
	AND year(E.EffectiveDate) >= 2022 /*only fixing 2022 and newer policies*/
ORDER BY E.EffectiveDate desc, C.Lookup_Code, E.PolicyNumber);
QUIT;

/*Canceled policies (according to preemptive expiration date) but missing a cancel date/reason.*/
PROC SQL;
CONNECT TO &SQLEng(noprompt="DSN=SQLServer; Server=MSS-P1-PCA-06; database=SmallBusinessInsurance;" &bulkparms read_isolation_level=RU);
CREATE TABLE MissingCancelEverything AS SELECT * FROM CONNECTION TO &SQLEng
(SELECT DISTINCT
	C.Lookup_Code,
	E.PolicyNumber,
	E.ProductCode,
	E.PolicyTerm,
	E.EffectiveDate,
	E.ExpirationDate,
	E.CancelDate,
	E.CancelReason,
	E.PolicyStatus,
	E.CarrierCode,
	E.CarrierName,
	E.Broker,
	E.IsInForce,
	E.UniqEntity,
	E.UniqPolicy,
	E.UniqOriginalPolicy
FROM BIT.EPICPolicy E
	LEFT JOIN BIT.Customer C ON E.UniqEntity = C.Unique_Entity
WHERE (E.PolicyStatus <> 'CAN' OR E.CancelDate is null) /*should have both when canceled*/
	AND (E.ExpirationDate-E.EffectiveDate) <= 364 /*policy in force for less than all 365 days*/
	AND E.AMSUpdatedDate >= getdate()-14 AND E.AMSUpdatedDate <= getdate() /*updated in the last 2 weeks only*/
	AND year(E.EffectiveDate) >= 2022 /*only fixing 2022 and newer policies*/
ORDER BY E.EffectiveDate desc, C.Lookup_Code, E.PolicyNumber);
QUIT;

PROC SQL;
CREATE TABLE Combo AS
(SELECT * FROM MissingCancelDate)
UNION
(SELECT * FROM MissingCancelEverything);
QUIT;

/*Name output location*/
libname OUTFILE XLSX "/sso/win_wrkgrp/CNTL/SBI/Adhoc/Health of the Data Check/Output/Missing_Cancel_Date_&dt_val..xlsx";

/*Write table to there*/
PROC DATASETS library = OUTFILE;
	copy in = WORK out = OUTFILE;
	select Combo;
RUN;
QUIT;

libname OUTFILE clear;

/*Only sending the email if there are observations w/ missing cancel date*/
%macro send_email;

	%let dsid = %sysfunc(open(work.Combo(where=(PolicyTerm > 0))));
	%let nobs = %sysfunc(attrn(&dsid,nlobsf));
	%let rc = %sysfunc(close(&dsid));

	%if &nobs > 0 %then %do;

/*Email Goonlawee and myself the Excel output*/
DATA _null_;
file sendit email
	from="isabelle_e_wagner@progressive.com"
	to=("goonlawee_rywitwattana@progressive.com")
	cc=("isabelle_e_wagner@progressive.com")
	subject="Canceled Policies Missing A Cancel Date"
	/*importance="High"*/
	attach=("/sso/win_wrkgrp/CNTL/SBI/Adhoc/Health of the Data Check/Output/Missing_Cancel_Date_&dt_val..xlsx"
			content_type="application/xlsx");
put 'Attached are all canceled policies, updated in the last week, that are missing a cancel date or cancel reason.';
put;
put 'Please reach out to Isabelle Wagner with any questions. Thank you!';
RUN;

%end;
%mend;
%send_email;