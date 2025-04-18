/***Health of SBI data***/
/***Check is duplicate UniqPolicy/PolicyNumber in BIT.EPICPolicy table***/
/***Run this biweekly to monitor data validity***/

/*Today's date*/
DATA Today; dt_val = put(today(),date9.); RUN;
PROC SQL; SELECT dt_val INTO: dt_val FROM Today; QUIT;

/*Duplicate UniqPolicy in the data. Updated in the last two weeks. Catching CPKG policies.*/
PROC SQL;
CONNECT TO &SQLEng(noprompt="DSN=SQLServer; Server=MSS-P1-PCA-06; database=SmallBusinessInsurance;" &bulkparms read_isolation_level=RU);
CREATE TABLE DuplicateUniqPolicy AS SELECT * FROM CONNECTION TO &SQLEng
(SELECT C.Lookup_Code,
	E.PolicyNumber,
	C.Customer_Name,
	E.EffectiveDate,
	E.ExpirationDate,
	E.PolicyStatus,
	E.ProductCode,
	E.CarrierCode,
	E.IsInForce,
	E.PolicyTerm,
	E.CancelDate,
	E.CancelReason,
	E.IsRenewal,
	E.UniqEntity,
	E.UniqPolicy,
	E.UniqOriginalPolicy			
FROM BIT.EPICPolicy E				
	INNER JOIN (SELECT UniqPolicy, count(PolicyNumber) as Cnt			
				FROM BIT.EPICPolicy
				GROUP BY UniqPolicy
				HAVING count(PolicyNumber) > 1) A
		ON E.UniqPolicy = A.UniqPolicy	
	LEFT JOIN BIT.Customer C			
		ON E.UniqEntity = C.Unique_Entity
WHERE E.AMSUpdatedDate >= getdate()-14 AND E.AMSUpdatedDate <= getdate() /*updated (so added or changed) in the system in the last 14 days*/
ORDER BY E.EffectiveDate desc, E.UniqPolicy, E.PolicyTerm);
QUIT;

/*Duplicate PolicyNumbers, effective on same day. Updated in the last two weeks.*/
PROC SQL;
CONNECT TO &SQLEng(noprompt="DSN=SQLServer; Server=MSS-P1-PCA-06; database=SmallBusinessInsurance;" &bulkparms read_isolation_level=RU);
CREATE TABLE DuplicatePolicyNbr AS SELECT * FROM CONNECTION TO &SQLEng
(SELECT C.Lookup_Code,
	E.PolicyNumber,
	C.Customer_Name,
	E.EffectiveDate,
	E.ExpirationDate,
	E.PolicyStatus,
	E.ProductCode,
	E.CarrierCode,
	E.IsInForce,
	E.PolicyTerm,
	E.CancelDate,
	E.CancelReason,
	E.IsRenewal,
	E.UniqEntity,
	E.UniqPolicy,
	E.UniqOriginalPolicy
FROM BIT.EPICPolicy E				
	INNER JOIN (SELECT PolicyNumber, EffectiveDate, count(UniqPolicy) as Cnt /*in the table more than once*/			
				FROM BIT.EPICPolicy
				GROUP BY PolicyNumber, EffectiveDate
				HAVING count(UniqPolicy) > 1) A
		ON E.PolicyNumber = A.PolicyNumber
		AND E.EffectiveDate = A.EffectiveDate
	LEFT JOIN (SELECT PolicyNumber, max(AMSUpdatedDate) as MaxUpdateTime /*most recent update date (for last 2 weeks)*/
				FROM BIT.EPICPolicy
				GROUP BY PolicyNumber) B
		ON E.PolicyNumber = B.PolicyNumber
	LEFT JOIN BIT.Customer C			
		ON E.UniqEntity = C.Unique_Entity
WHERE B.MaxUpdateTime >= getdate()-14 AND B.MaxUpdateTime <= getdate() /*updated (so added or changed) in the system in the last 14 days*/
ORDER BY E.EffectiveDate desc, E.PolicyNumber, E.PolicyTerm);
QUIT;

/*Duplicate PolicyNumbers, with different UniqEntities/LookupCodes. Updated in the last two weeks.*/
PROC SQL;
CONNECT TO &SQLEng(noprompt="DSN=SQLServer; Server=MSS-P1-PCA-06; database=SmallBusinessInsurance;" &bulkparms read_isolation_level=RU);
CREATE TABLE DuplicatePolicyNbr2 AS SELECT * FROM CONNECTION TO &SQLEng
(SELECT C.Lookup_Code,
	E.PolicyNumber,
	C.Customer_Name,
	E.EffectiveDate,
	E.ExpirationDate,
	E.PolicyStatus,
	E.ProductCode,
	E.CarrierCode,
	E.IsInForce,
	E.PolicyTerm,
	E.CancelDate,
	E.CancelReason,
	E.IsRenewal,
	E.UniqEntity,
	E.UniqPolicy,
	E.UniqOriginalPolicy
FROM BIT.EPICPolicy E				
	INNER JOIN (SELECT PolicyNumber, count(distinct UniqEntity) as Cnt /*different UniqEntities for same policy*/		
				FROM BIT.EPICPolicy
				GROUP BY PolicyNumber
				HAVING count(distinct UniqEntity) > 1) A
		ON E.PolicyNumber = A.PolicyNumber
	LEFT JOIN (SELECT PolicyNumber, max(AMSUpdatedDate) as MaxUpdateTime /*most recent update date (for last 2 weeks)*/
				FROM BIT.EPICPolicy
				GROUP BY PolicyNumber) B
		ON E.PolicyNumber = B.PolicyNumber
	LEFT JOIN BIT.Customer C			
		ON E.UniqEntity = C.Unique_Entity
WHERE B.MaxUpdateTime >= getdate()-14 AND B.MaxUpdateTime <= getdate() /*updated (so added or changed) in the system in the last 14 days*/
ORDER BY E.PolicyNumber, E.EffectiveDate desc, E.PolicyTerm);
QUIT;

/*Joining all duplicates together*/
PROC SQL;
CREATE TABLE AllDups AS
SELECT * FROM DuplicateUniqPolicy
UNION
SELECT * FROM DuplicatePolicyNbr
UNION
SELECT * FROM DuplicatePolicyNbr2;
QUIT;

/*Name output location*/
libname OUTFILE XLSX "/sso/win_wrkgrp/CNTL/SBI/Adhoc/Health of the Data Check/Output/Duplicate_Policy_&dt_val..xlsx";

/*Write table to there*/
PROC DATASETS library = OUTFILE;
	copy in = WORK out = OUTFILE;
	select AllDups;
RUN;
QUIT;

libname OUTFILE clear;

/*Only sending the email if there are duplicate observations*/
%macro send_email;

	%let dsid = %sysfunc(open(work.AllDups(where=(UniqEntity > 0))));
	%let nobs = %sysfunc(attrn(&dsid,nlobsf));
	%let rc = %sysfunc(close(&dsid));

	%if &nobs > 0 %then %do;

/*Email Goonlawee and myself the Excel output*/
DATA _null_;
file sendit email
	from="isabelle_e_wagner@progressive.com"
	to=("goonlawee_rywitwattana@progressive.com")
	cc=("isabelle_e_wagner@progressive.com")
	subject="Duplicate Policies in Applied"
	/*importance="High"*/
	attach=("/sso/win_wrkgrp/CNTL/SBI/Adhoc/Health of the Data Check/Output/Duplicate_Policy_&dt_val..xlsx"
			content_type="application/xlsx");
put 'Attached are duplicate policies in our data and in Applied. This list is limited to policies that have been added or updated in the system in the last 14 days.';
put;
put 'Please reach out to Isabelle Wagner with any questions. Thank you!';
RUN;

%end;
%mend;
%send_email;