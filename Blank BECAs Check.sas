/***Health of SBI data***/
/***Check if BECA intent is being populated in last week's data***/
/***Run this Wednesday weekly to monitor data validity***/

/*Grab last week's Null vs. Populated BECA quoting data and compare to historical (T2-8)*/
PROC SQL;
%sf_ref_acs_tok (warehouse=FREE_THE_DATA_L);
CREATE TABLE CompareNulls AS SELECT * FROM CONNECTION TO ODBC
(SELECT A.BECAType,
	A.QuoteStarts as LastWeekQuoteStarts,
	A.PctTotal as LastWeekPcts,
	B.QuoteStarts as SixMonthQuoteStarts,
	B.PctTotal as SixMonthPcts,
	B.PctTotal*1.1 as SixMonthMaxPct,
	case when A.PctTotal > B.PctTotal*1.1 then 1
	else 0 end as BlankBECAFlag
FROM
	(SELECT case when Q.BECAIntent is null or Q.BECAIntent = '' then 'Null'
			else 'Populated' end as BECAType,
		sum(Q.QSCnt) as QuoteStarts,
		count(*) * 100.0 / sum(count(*)) over() as PctTotal
	FROM CL_SBI.Published.BQX_QuoteMasterDetail Q
	WHERE Q.QuoteCreatedDate >= current_date()-10
		AND Q.QuoteCreatedDate <= current_date()-4
		AND Q.IsQuoteTest = 'N'
	GROUP BY BECAType) A
LEFT JOIN
	(SELECT case when Q.BECAIntent is null or Q.BECAIntent = '' then 'Null'
			else 'Populated' end as BECAType,
		sum(Q.QSCnt) as QuoteStarts,
		count(*) * 100.0 / sum(count(*)) over() as PctTotal
	FROM CL_SBI.Published.BQX_QuoteMasterDetail Q
	WHERE Q.QuoteCreatedDate >= current_date()-240
		AND Q.QuoteCreatedDate <= current_date()-60
		AND Q.IsQuoteTest = 'N'
	GROUP BY BECAType) B
	ON A.BECAType = B.BECAType
WHERE A.BECAType = 'Null');
QUIT;

/*Only sending the email if there are more than 10% above average NULL BECAs*/
%macro send_email;

	%let dsid = %sysfunc(open(work.CompareNulls(where=(BlankBECAFlag > 0))));
	%let nobs = %sysfunc(attrn(&dsid,nlobsf));
	%let rc = %sysfunc(close(&dsid));

	%if &nobs > 0 %then %do;

/*Email myself that there's an outlier*/
DATA _null_;
file sendit email
	from="isabelle_e_wagner@progressive.com"
	to="isabelle_e_wagner@progressive.com"
	subject="Higher Than Average NULL BECAs"
	/*importance="High"*/
	/*attach=("/sso/win_wrkgrp/CNTL/SBI/Adhoc/Health of the Data Check/Output/Duplicate_Policy_&dt_val..xlsx"
			content_type="application/xlsx")*/;
put 'Last week has more than 10% above average NULL BECAs in the BQX_QuoteMasterDetail table.';
put;
put 'Take a look at NULL volume. The Top BECA and PBV Rankings Report is useful for this.';
put;
RUN;

%end;
%mend;
%send_email;