/********************************/
/***SBI Funnel - Holistic Code***/
/********************************/

/* Version Notes:
Changed source to Snowflake holistic funnel table for QS, QF, sales, renewals, premiums, and PIFs
(used to be EpicQuotes and EpicPolicy, then BISS holistic funnel).*/

/*Farthest back we look for this report*/
%LET START_YRMO = 201801;

/* Getting fiscal calendar dates: */
PROC SQL;
CONNECT TO ODBC (%db2conn(db2p));
CREATE TABLE Acct_Cal AS SELECT * FROM CONNECTION TO ODBC
(SELECT ACCT_CCYYMM as Acct_Dt,
	min(DT_VAL) as Month_Begin,
	max(DT_VAL) as Month_End,
	ACCT_WK_IN_MO as Weeks
FROM DSE.Date
GROUP BY ACCT_CCYYMM, ACCT_WK_IN_MO);
QUIT;

/*Pull in base table for sales & renewals*/
PROC SQL;
%sf_ref_acs_tok (warehouse=FREE_THE_DATA_L);
CREATE TABLE ES_Sales AS SELECT * FROM CONNECTION TO ODBC
(SELECT Q.uniqentity as "uniqentity",
	Q.epicversion as "epicversion",
	Q.policynumber as "policynumber",
	Q.uniqpolicy as "uniqpolicy",
	case when Q.CoverageCode in ('GL','CGL','Website') then 'GL'
		when Q.CoverageCode in ('PL','PL1') then 'PL'
		when Q.CoverageCode in ('WC','WCOM') then 'WCOM'
	else Q.CoverageCode end as "productcode",
	Q.policystatus as "policystatus",
	Q.carriercode as "carriercode",
	Q.effectivedate as "effectivedate",
	Q.expirationdate as "expirationdate",
	Q.TotalWrittenPremium as "TotalWrittenPremium",
	Q.isrenewal as "isrenewal",
	Q.IsBQXQuote as "IsBQXQuote"
FROM CL_SBI.Published.BIT_HOLISTICFUNNEL_VW Q
WHERE Q.SaleCnt = 1 OR Q.RenewalCnt = 1
ORDER BY Q.uniqentity, Q.effectivedate);
QUIT;

/*Turning list of sales into 1/0 PIF, NB PIF, and RB PIF indicators by month*/
PROC SQL;
CREATE TABLE SBI_pif_1 AS
SELECT DISTINCT cal.acct_dt as acct_dt,
	/*cal.acct_dt_display,*/
	ep.epicversion,
	ep.uniqpolicy,
	case when datepart(ep.effectivedate) <= cal.month_end and datepart(ep.expirationdate) > cal.month_end then 1 else 0 end as total_pif,
	case when isrenewal='N' and 
		datepart(ep.effectivedate) <= cal.month_end and datepart(ep.expirationdate) > cal.month_end then 1 else 0 end as NB_pif,
	case when isrenewal='Y' and 
		datepart(ep.effectivedate) <= cal.month_end and datepart(ep.expirationdate) > cal.month_end then 1 else 0 end as RB_pif,
	ep.productcode,
	ep.carriercode,
	ep.isrenewal,
	cal.weeks as weeks,
	ep.IsBQXQuote
FROM ES_Sales ep
	 INNER JOIN acct_cal cal ON datepart(ep.effectivedate) <= cal.month_end AND datepart(ep.expirationdate) > cal.month_end
WHERE cal.ACCT_dt >= &START_YRMO;
QUIT;

/*Summarizing PIFs*/
PROC SQL;
CREATE TABLE sbi_pif_2 AS
SELECT acct_dt,
	/*acct_dt_display,*/
	epicversion,
	sum(total_pif) as total_pif,
	sum(nb_pif) as nb_pif,
	sum(rb_pif) as rb_pif,
	productcode,
	carriercode,
	weeks,
	IsBQXQuote
FROM sbi_pif_1
GROUP BY acct_dt, /*acct_dt_display,*/ epicversion, productcode, carriercode, weeks, IsBQXQuote;
QUIT;

/*Monthly sales, renewals, & premiums view*/
PROC SQL;
CREATE TABLE sbi_policies_1 AS
SELECT cal.acct_dt as acct_dt,
	/*cal.acct_dt_display,*/
	ep.uniqentity,
	ep.uniqpolicy,
	ep.epicversion,
	case when ep.isrenewal='N' then 1 else 0 end as Sale,
	case when ep.isrenewal='Y' then 1 else 0 end as Renewal,
	case when ep.isrenewal='N' then TotalWrittenPremium else 0 end as NB_Prem,
	case when ep.isrenewal='Y' then TotalWrittenPremium else 0 end as RB_Prem,
	TotalWrittenPremium,
	ep.productcode,
	ep.carriercode,
	cal.weeks as weeks,
	ep.IsBQXQuote
FROM es_sales ep
	LEFT JOIN acct_cal cal on datepart(ep.EffectiveDate) between cal.month_begin and cal.month_end
WHERE cal.ACCT_dt >= &START_YRMO;
QUIT;

/*Summarizing sales and renewals view*/
PROC SQL;
CREATE TABLE sbi_policies_2 AS
SELECT acct_dt,
	/*acct_dt_display,*/
	epicversion,
	sum(Sale) as Sale,
	sum(Renewal) as Renewal,
	sum(NB_Prem) as NB_Prem,
	sum(RB_Prem) as RB_Prem,
	sum(TotalWrittenPremium) as WrittenPremium,
	Productcode,
	carriercode,
	weeks,
	IsBQXQuote
FROM SBI_Policies_1
GROUP BY acct_dt, /*acct_dt_display,*/ epicversion, Productcode, carriercode, weeks, IsBQXQuote;
QUIT;

/*Pull in base table for all quote finishes*/
PROC SQL;
%sf_ref_acs_tok(warehouse=FREE_THE_DATA_XS);
CREATE TABLE SBI_Quotes AS SELECT * FROM CONNECTION TO ODBC
(SELECT to_number(QuoteFinishMonth) as "acct_dt", /*QF anchored to QF date*/
	QuoteEpicVersion as "epicversion",
	QFCnt as "QF",
	case when CoverageCode in ('GL','CGL','Website') then 'GL'
		when CoverageCode in ('PL','PL1') then 'PL'
		when CoverageCode in ('WC','WCOM') then 'WCOM'
	else CoverageCode end as "productcode",
	EPICCarrier as "carriercode",
	IsBQXQuote as "IsBQXQuote"
FROM CL_SBI.PUBLISHED.BIT_HOLISTICFUNNEL_VW
WHERE QFCnt = 1);
QUIT;

/*Summarizing & adding calendar metrics (weeks) to quote finish table*/
PROC SQL;
CREATE TABLE sbi_quotes_1 AS
SELECT H.acct_dt,
	/*cal.acct_dt_display,*/
	H.epicversion,
	sum(H.QF) as QF,
	H.productcode,
	H.carriercode,
	cal.weeks as weeks,
	H.IsBQXQuote
FROM SBI_Quotes H
	LEFT JOIN acct_cal cal ON H.acct_dt = cal.acct_dt
WHERE H.acct_dt >= &START_YRMO
GROUP BY H.acct_dt, /*cal.acct_dt_display,*/ H.epicversion, H.productcode, H.carriercode, cal.weeks, H.IsBQXQuote;
QUIT;

/*Pull in base table for all quote STARTS*/
PROC SQL;
%sf_ref_acs_tok(warehouse=FREE_THE_DATA_XS);
CREATE TABLE SBI_QS AS SELECT * FROM CONNECTION TO ODBC
(SELECT to_number(QuoteStartMonth) as "acct_dt", /*QS anchored to QS date*/
	QuoteEpicVersion as "epicversion",
	QSCnt as "QS",
	case when CoverageCode in ('GL','CGL','Website') then 'GL'
		when CoverageCode in ('PL','PL1') then 'PL'
		when CoverageCode in ('WC','WCOM') then 'WCOM'
	else CoverageCode end as "productcode",
	EPICCarrier as "carriercode",
	IsBQXQuote as "IsBQXQuote"
FROM CL_SBI.PUBLISHED.BIT_HOLISTICFUNNEL_VW
WHERE QSCnt = 1);
QUIT;

/*Summarizing & adding calendar metrics (weeks) to quote start table*/
PROC SQL;
CREATE TABLE SBI_QS_1 AS
SELECT H.acct_dt,
	/*cal.acct_dt_display,*/
	H.epicversion,
	sum(H.QS) as QS,
	H.productcode,
	H.carriercode,
	cal.weeks as weeks,
	H.IsBQXQuote
FROM SBI_QS H
	LEFT JOIN acct_cal cal ON H.acct_dt = cal.acct_dt
WHERE H.acct_dt >= &START_YRMO
GROUP BY H.acct_dt, /*cal.acct_dt_display,*/ H.epicversion, H.productcode, H.carriercode, cal.weeks, H.IsBQXQuote;
QUIT;

/*Union categorical variables together*/
PROC SQL;
CREATE TABLE Union_EQ_EP_Base AS
SELECT DISTINCT acct_dt, /*acct_dt_display,*/ epicversion, productcode, carriercode, weeks, IsBQXQuote FROM sbi_quotes_1
UNION ALL
SELECT DISTINCT acct_dt, /*acct_dt_display,*/ epicversion, productcode, carriercode, weeks, IsBQXQuote FROM sbi_policies_2
UNION ALL
SELECT DISTINCT acct_dt, /*acct_dt_display,*/ epicversion, productcode, carriercode, weeks, IsBQXQuote FROM sbi_pif_2
UNION ALL
SELECT DISTINCT acct_dt, /*acct_dt_display,*/ epicversion, productcode, carriercode, weeks, IsBQXQuote FROM SBI_QS_1;
QUIT;

/*Grabbing carrier partner code table*/
PROC SQL;
CONNECT TO &SQLEng(noprompt="DSN=SQLServer; Server=MSS-P1-PCA-06; database=SmallBusinessInsurance;" &bulkparms read_isolation_level=RU);
CREATE TABLE Carrier_Partner AS SELECT * FROM CONNECTION TO &SQLEng
(SELECT * FROM BIT.Carrier_Partner;); QUIT;

/*Adding year & month, adding partner carrier name w/ carrier code*/
PROC SQL;
CREATE TABLE Base_Table AS
SELECT DISTINCT b.acct_dt,
	input(substr(put(b.acct_dt,6.),1,4),4.) as Year,
	input(substr(put(b.acct_dt,6.),5,2),2.) as Month,
	/*year(datepart(b.Acct_Dt_Display)) as Year,
	month(datepart(b.Acct_Dt_Display)) as Month,*/
	b.epicversion,
	b.productcode,
	b.carriercode,
	case when cp.partnercarriername = '' then b.carriercode else cp.partnercarriername end as partnercarriername,
	b.weeks,
	b.IsBQXQuote
FROM Union_EQ_EP_Base b
	LEFT JOIN carrier_partner cp ON b.carriercode=cp.premiumpayable
ORDER BY b.acct_dt, b.epicversion;
QUIT;

/*Joining all metrics together*/
PROC SQL;
CREATE TABLE SBI_Funnel_1 AS
SELECT b.acct_dt as acct_dt,
	b.year as year,
	b.month as month,
	b.weeks as weeks,
	b.epicversion as epicversion,
	b.productcode as productcode,
	b.carriercode as carriercode,
	b.partnercarriername as partnercarriername,
	b.IsBQXQuote as IsBQXQuote,
	
	qs.qs as qs,
	qs.qs/b.weeks as QS_Cnt_Normalized,
	q.qf as qf,
	q.qf/b.weeks as QF_Cnt_Normalized,
	p.sale as sale,
	p.sale/b.weeks as Sale_Cnt_Normalized,
	p.renewal as renewal,
	p.Renewal/b.weeks as Renewal_Cnt_Normalized,
	p.nb_prem as nb_prem,
	p.NB_Prem/b.weeks as NB_Prem_Normalized,
	p.rb_prem as rb_prem,
	p.RB_Prem/b.weeks as RB_Prem_Normalized,
	p.WrittenPremium as WrittenPremium,
	p.WrittenPremium/b.weeks as WP_Normalized,

	pif.total_pif as total_pif,
	pif.nb_pif as nb_pif,
	pif.rb_pif as rb_pif,

	today() format yymmdd10. as DateRan
FROM base_table	b
	LEFT OUTER JOIN sbi_quotes_1 q /*quote finishes*/
		ON b.acct_dt=q.acct_dt
		AND b.epicversion=q.epicversion
		AND b.productcode=q.productcode
		AND b.carriercode=q.carriercode
		AND b.IsBQXQuote=q.IsBQXQuote
	LEFT OUTER JOIN sbi_policies_2 p /*sales, renewals, premiums*/
		ON b.acct_dt=p.acct_dt
		AND b.epicversion=p.epicversion 
		AND b.productcode=p.productcode
		AND b.carriercode=p.carriercode
		AND b.IsBQXQuote=p.IsBQXQuote
	LEFT OUTER JOIN sbi_pif_2 pif /*PIFs*/
		ON b.acct_dt=pif.acct_dt 
		AND b.epicversion=pif.epicversion
		AND b.productcode=pif.productcode
		AND b.carriercode=pif.carriercode
		AND b.IsBQXQuote=pif.IsBQXQuote
	LEFT OUTER JOIN SBI_QS_1 qs /*quote starts*/
		ON b.acct_dt=qs.acct_dt
		AND b.epicversion=qs.epicversion
		AND b.productcode=qs.productcode
		AND b.carriercode=qs.carriercode
		AND b.IsBQXQuote=qs.IsBQXQuote
WHERE b.ACCT_dt >= &START_YRMO 
ORDER BY b.acct_dt, b.epicversion, b.productcode, b.carriercode, b.IsBQXQuote;
QUIT;


/*********************************************/
/***Exporting the summarized table to CLAcq***/
/*********************************************/
libname CLAcq &SQLEng noprompt="DSN=SQLServer; Server=MSS-P1-BISS-01; DATABASE=BISSCLAcqSBI;" schema=dbo &bulkparms read_isolation_level=RU;

PROC DELETE DATA = CLAcq.SBI_Funnel_Holistic; RUN;
DATA CLAcq.SBI_Funnel_Holistic; SET sbi_funnel_1; RUN;