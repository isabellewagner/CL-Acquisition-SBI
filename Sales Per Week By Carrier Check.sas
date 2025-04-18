/***Health of SBI data***/
/***Fourth check is sales per carrier, per week***/
/***Run this weekly to monitor data validity***/

/*Today's date*/
DATA Today; dt_val = put(today(),date9.); RUN;
PROC SQL; SELECT dt_val INTO: dt_val FROM Today; QUIT;

/*Policies effective/sold in the last year.*/
/*Checking up to last week's data, so 5 days before Wed (when code is run) is last Fri. Fri is last day of week.*/
PROC SQL;
CONNECT TO &SQLEng(noprompt="DSN=SQLServer; Server=MSS-P1-PCA-06; database=SmallBusinessInsurance;" &bulkparms read_isolation_level=RU);
CREATE TABLE RecentlyEffective AS SELECT * FROM CONNECTION TO &SQLEng
(SELECT DISTINCT
	C.PartnerCarrierName as PartnerCarrier,
	E.ProductCode,
	E.IsRenewal,
	count(E.PolicyNumber) as SoldPolicies,
	E.EffectiveDate
FROM BIT.EPICPolicy E
	LEFT JOIN BIT.Carrier_Partner C ON E.CarrierCode = C.LookUpCode
WHERE E.EffectiveDate >= dateadd(year,-1,dateadd(day,-5,getdate())) AND E.EffectiveDate <= dateadd(day,-5,getdate())
	AND E.PolicyStatus not in ('DUP','DUQ','ERR')
GROUP BY C.PartnerCarrierName, E.ProductCode, E.IsRenewal, E.EffectiveDate
ORDER BY E.EffectiveDate);
QUIT;

libname DSE odbc dsn=DB2P schema=DSE read_isolation_level=RU %db2conn(dsn=DB2P);

/*Total sales (or policies becoming effective) per week, by carrier*/
PROC SQL;
CREATE TABLE RecentlyEffective2 AS
SELECT R.PartnerCarrier,
	sum(R.SoldPolicies) as TotalSales,
	D.Acct_CCYYMMWW as Acct_Week_Dt
FROM RecentlyEffective R
	LEFT JOIN DSE.Date D ON datepart(R.EffectiveDate) = D.Dt_Val
WHERE PartnerCarrier <> ''
GROUP BY R.PartnerCarrier, D.Acct_CCYYMMWW
ORDER BY R.PartnerCarrier, D.Acct_CCYYMMWW desc;
QUIT;

libname DSE clear;

/*95th percentile of sales per week*/
PROC SQL;
CREATE TABLE Stats AS
SELECT PartnerCarrier,
	mean(TotalSales) as AvgSales,
	std(TotalSales) as StdSales,
	mean(TotalSales) + 2*std(TotalSales) as UpperLimit,
	mean(TotalSales) - 2*std(TotalSales) as LowerLimit
FROM RecentlyEffective2
GROUP BY PartnerCarrier;
QUIT;

/*Making an indicator for if the sales count is outside the 95%*/
PROC SQL;
CREATE TABLE RecentlyEffective3 AS
SELECT R.PartnerCarrier,
	R.TotalSales,
	R.Acct_Week_Dt,
	S.AvgSales,
	S.StdSales,
	S.UpperLimit,
	S.LowerLimit,
	case when (R.TotalSales > S.UpperLimit OR R.TotalSales < S.LowerLimit) then 1
	else 0 end as SalesFlag 
FROM RecentlyEffective2 R
	LEFT JOIN Stats S ON R.PartnerCarrier = S.PartnerCarrier;
QUIT;

/*Week the check is being done on*/
PROC SQL;
CREATE TABLE CurrWeek AS
SELECT max(Acct_Week_Dt) as CurrWeek
FROM RecentlyEffective3;
QUIT;

/*Output of this week's data if it falls outside of the mean + 2 std dev (has a SalesFlag)*/
PROC SQL;
CREATE TABLE FinalOutput AS
SELECT R.*
FROM RecentlyEffective3 R
	INNER JOIN CurrWeek C ON R.Acct_Week_Dt = C.CurrWeek
WHERE SalesFlag = 1;
QUIT;

/*Name output location*/
libname OUTFILE XLSX "/sso/win_wrkgrp/CNTL/SBI/Adhoc/Health of the Data Check/Output/Sales_Per_Week_Outliers_&dt_val..xlsx";

/*Write table to there*/
PROC DATASETS library = OUTFILE;
	copy in = WORK out = OUTFILE;
	select FinalOutput;
RUN;
QUIT;

libname OUTFILE clear;

/*Only sending the email to myself if there are observations w/ outlier sales per week*/
%macro send_email;

	%let dsid = %sysfunc(open(work.FinalOutput(where=(TotalSales > 0))));
	%let nobs = %sysfunc(attrn(&dsid,nlobsf));
	%let rc = %sysfunc(close(&dsid));

	%if &nobs > 0 %then %do;

/*Email myself the Excel output*/
DATA _null_;
file sendit email
	from="isabelle_e_wagner@progressive.com"
	to=("isabelle_e_wagner@progressive.com")
	/*cc=("isabelle_e_wagner@progressive.com")*/
	subject="Sales per Week by Carrier Outliers"
	/*importance="High"*/
	attach=("/sso/win_wrkgrp/CNTL/SBI/Adhoc/Health of the Data Check/Output/Sales_Per_Week_Outliers_&dt_val..xlsx"
			content_type="application/xlsx");
put 'Attached is a list of carriers with a sum of sales that is an outlier by 2 std dev for last week.';
put;
put 'END OF MESSAGE';
RUN;

%end;
%mend;
%send_email;