/***Health of SBI data***/
/***Third check is product code missing from BIT.EPICPolicy table***/
/***Run this biweekly to monitor data validity***/

/*Today's date*/
DATA Today; dt_val = put(today(),date9.); RUN;
PROC SQL; SELECT dt_val INTO: dt_val FROM Today; QUIT;

/*Policy missing product code. Filtered to policies in force.*/
PROC SQL;
CONNECT TO &SQLEng(noprompt="DSN=SQLServer; Server=MSS-P1-PCA-06; database=SmallBusinessInsurance;" &bulkparms read_isolation_level=RU);
CREATE TABLE MissingProductCode AS SELECT * FROM CONNECTION TO &SQLEng
(SELECT DISTINCT
	C.Lookup_Code,
	E.PolicyNumber,
	E.ProductCode,
	E.PolicyTerm,
	E.EffectiveDate,
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
WHERE E.IsInForce = 1
	AND E.PolicyStatus not in ('DUP','DUQ','ERR')
	AND E.AMSUpdatedDate >= getdate()-14 AND E.AMSUpdatedDate <= getdate() /*added/updated in the last 2 weeks*/
	AND (E.ProductCode is null OR E.ProductCode = '')
ORDER BY C.Lookup_Code, E.PolicyNumber);
QUIT;

/*Name output location*/
libname OUTFILE XLSX "/sso/win_wrkgrp/CNTL/SBI/Adhoc/Health of the Data Check/Output/Missing_Product_Code_&dt_val..xlsx";

/*Write table to there*/
PROC DATASETS library = OUTFILE;
	copy in = WORK out = OUTFILE;
	select MissingProductCode;
RUN;
QUIT;

libname OUTFILE clear;

/*Only sending the email if there are observations w/ missing product codes*/
%macro send_email;

	%let dsid = %sysfunc(open(work.MissingProductCode(where=(IsInForce > 0))));
	%let nobs = %sysfunc(attrn(&dsid,nlobsf));
	%let rc = %sysfunc(close(&dsid));

	%if &nobs > 0 %then %do;

/*Email Goonlawee and myself the Excel output*/
DATA _null_;
file sendit email
	from="isabelle_e_wagner@progressive.com"
	to=("goonlawee_rywitwattana@progressive.com")
	cc=("isabelle_e_wagner@progressive.com")
	subject="Policies Missing A Product Code"
	/*importance="High"*/
	attach=("/sso/win_wrkgrp/CNTL/SBI/Adhoc/Health of the Data Check/Output/Missing_Product_Code_&dt_val..xlsx"
			content_type="application/xlsx");
put 'Attached are policies in force that are missing a product code (this is the field called Source in Applied). This policy list is filtered to policies that have been added or updated in the last 2 weeks.';
put;
put 'Please reach out to Isabelle Wagner with any questions. Thank you!';
RUN;

%end;
%mend;
%send_email;