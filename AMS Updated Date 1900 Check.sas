/***Health of SBI data***/
/***Check is for AMSUpdatedDate of 1900-01-01***/
/***Run this biweekly to monitor data validity***/

/*Today's date*/
DATA Today; dt_val = put(today(),date9.); RUN;
PROC SQL; SELECT dt_val INTO: dt_val FROM Today; QUIT;

/*AMSUpdatedDate of 1900-01-01 in the data. Inserted in the last two weeks.*/
PROC SQL;
CONNECT TO &SQLEng(noprompt="DSN=SQLServer; Server=MSS-P1-PCA-06; database=SmallBusinessInsurance;" &bulkparms read_isolation_level=RU);
CREATE TABLE AMSUpdatedDate AS SELECT * FROM CONNECTION TO &SQLEng
(SELECT C.Lookup_Code,
	E.PolicyNumber,
	C.Customer_Name,
	E.EffectiveDate,
	E.ExpirationDate,
	E.AMSInsertedDate,
	E.AMSUpdatedDate,
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
	LEFT JOIN BIT.Customer C			
		ON E.UniqEntity = C.Unique_Entity
WHERE year(E.AMSUpdatedDate) = 1900
	AND year(E.EffectiveDate) >= 2024
	AND E.AMSInsertedDate >= getdate()-14
	AND E.AMSInsertedDate <= getdate()
	AND E.PolicyStatus not in ('DUP','DUQ','ERR')
	/*using inserted in the system in the last 14 days b/c updated date is 1900*/
ORDER BY E.EffectiveDate desc, E.UniqPolicy, E.PolicyTerm);
QUIT;

/*Name output location*/
libname OUTFILE XLSX "/sso/win_wrkgrp/CNTL/SBI/Adhoc/Health of the Data Check/Output/AMS_Updated_1900_&dt_val..xlsx";

/*Write table to there*/
PROC DATASETS library = OUTFILE;
	copy in = WORK out = OUTFILE;
	select AMSUpdatedDate;
RUN;
QUIT;

libname OUTFILE clear;

/*Only sending the email if there are 1/1/1900 observations*/
%macro send_email;

	%let dsid = %sysfunc(open(work.AMSUpdatedDate(where=(UniqEntity > 0))));
	%let nobs = %sysfunc(attrn(&dsid,nlobsf));
	%let rc = %sysfunc(close(&dsid));

	%if &nobs > 0 %then %do;

/*Email Goonlawee and myself the Excel output*/
DATA _null_;
file sendit email
	from="isabelle_e_wagner@progressive.com"
	to=("goonlawee_rywitwattana@progressive.com")
	cc=("isabelle_e_wagner@progressive.com")
	subject="AMS Updated Date of 1/1/1900"
	/*importance="High"*/
	attach=("/sso/win_wrkgrp/CNTL/SBI/Adhoc/Health of the Data Check/Output/AMS_Updated_1900_&dt_val..xlsx"
			content_type="application/xlsx");
put 'Attached are policies with an AMS Updated Date of 1/1/1900. This list is limited to policies that have been inserted into the system in the last 14 days.';
put;
put 'Please reach out to Isabelle Wagner with any questions. Thank you!';
RUN;

%end;
%mend;
%send_email;