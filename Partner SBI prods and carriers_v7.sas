/*
USE OTHER CODE FOR AWP - 202204 AWP table wasn't created

V5 moves away from On and off platform carriers, and focuses on Current vs All others
5a replaces ClCntl.Sbi_Funnel with CLAcq.SBI_Funnel
6 redoes the entire Sbi_Details query to used macros, so that I can change it to reflect E&S NB + RB sales
	Actually it doesn't. I realized afterwards that I don't need to change E&S since I'm already breaking out sales and RB
	But I did correct 201912 Renewal to calculate renewal*.8 - was referencing sale*.8 before
*/
	/*** Partner SBI Detail for file outside of HLD ***/

/* MAKE SURE THIS IS UP TO DATE *******************************************/

%let CurrentCarriers = ('Hiscox','Homesite','Liberty Mutual','Liberty','Markel','AmTrust','Evanston','CNA','Nationwide','MSA','Progressive','Arch');
%let currentCarrierCodes = ('HISCO1', 'HXBIT1', 'ZHISX1','HOMIN1', 'XHOMCC', 'XHOME1','LBDIR1', 'LIBER1', 'ZLIBMU','L-AFCC','L-OHCS','L-SECU','L-WEST'
	'ZMARKL','FIRST1','CNADIR', 'ZCNAC1','CNA001','NADCX1', 'N-ASUR','AMTRU1','EVAIN1','PGRBOP','MAIAM1','ZMAIM1','A-ARCH');

libname CLAcq &SQLEng noprompt="DSN=SQLServer; Server=MSS-P1-BISS-01; DATABASE=BISSCLAcqSBI;" schema=dbo &bulkparms read_isolation_level=RU;
libname BIT &SQLEng noprompt="DSN=SQLServer; Server=MSS-P1-PCA-06; DATABASE=SmallBusinessInsurance;" schema=BIT &bulkparms read_isolation_level=RU;

/* Replacing BIT date tables: */
PROC SQL;
CONNECT TO ODBC (%db2conn(db2p));
CREATE TABLE Date AS SELECT * FROM CONNECTION TO ODBC
(SELECT DT_VAL, ACCT_MO, ACCT_CCYY, ACCT_CCYYMM, ACCT_WK_IN_MO FROM DSE.Date); DISCONNECT FROM ODBC; QUIT;

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

/* Base list for breakouts */
PROC SQL;
CONNECT TO &SQLEng(noprompt="DSN=SQLServer; Server=MSS-P1-BISS-01; database=BISSCLAcqSBI;" &bulkparms read_isolation_level=RU);
CREATE TABLE SBI_base AS SELECT * FROM CONNECTION TO &SQLEng
(SELECT DISTINCT PartnerCarrierName,
	carriercode,
	productcode
FROM dbo.SBI_Funnel_Holistic);
QUIT;

/*Switched to Holistic Funnel*/
PROC SQL;
CREATE TABLE Sbi_Details AS
SELECT case when b.partnercarriername in &currentCarriers. then b.partnercarriername else 'All Others' end as currentCarriers,
	b.PartnerCarrierName,
	b.carriercode,
	b.productcode,
	case when b.productcode in ('BOP', 'BOP-GARAGE') then 'BOP'
	when b.productcode in ('CGL', 'GL') then 'CGL'
	when b.productcode in ('PL', 'EO', 'PL1') then 'PL'
	when b.productcode in ('WCOM', 'WC') then 'WC'
	else 'Other' end as ProductCode2,

	T12CY.Sale_Cnt_201912_fix_T12_CY,
	T12CY.Renewal_Cnt_201912_fix_T12_CY,
	T12CY.nb_prem_201912_fix_T12_CY,
	T12CY.rb_prem_201912_fix_T12_CY,
	T12CY.Writ_prem_201912_fix_T12_CY,

	T12PY.Sale_Cnt_201912_fix_T12_PY,
	T12PY.Renewal_Cnt_201912_fix_T12_PY,
	T12PY.nb_prem_201912_fix_T12_PY,
	T12PY.rb_prem_201912_fix_T12_PY,
	T12PY.Writ_prem_201912_fix_T12_PY,

	T3CY.Sale_Cnt_201912_fix_T3_CY,
	T3CY.Renewal_Cnt_201912_fix_T3_CY,
	T3CY.nb_prem_201912_fix_T3_CY,
	T3CY.rb_prem_201912_fix_T3_CY,
	T3CY.Writ_prem_201912_fix_T3_CY,

	T3PY.Sale_Cnt_201912_fix_T3_PY,
	T3PY.Renewal_Cnt_201912_fix_T3_PY,
	T3PY.nb_prem_201912_fix_T3_PY,
	T3PY.rb_prem_201912_fix_T3_PY,
	T3PY.Writ_prem_201912_fix_T3_PY,

	YTDCY.Sale_Cnt_201912_fix_YTD_CY,
	YTDCY.Renewal_Cnt_201912_fix_YTD_CY,
	YTDCY.nb_prem_201912_fix_YTD_CY,
	YTDCY.rb_prem_201912_fix_YTD_CY,
	YTDCY.Writ_prem_201912_fix_YTD_CY,

	YTDPY.Sale_Cnt_201912_fix_YTD_PY,
	YTDPY.Renewal_Cnt_201912_fix_YTD_PY,
	YTDPY.nb_prem_201912_fix_YTD_PY,
	YTDPY.rb_prem_201912_fix_YTD_PY,
	YTDPY.Writ_prem_201912_fix_YTD_PY,

	CMCY.Sale_Cnt_201912_fix_CM_CY,
	CMCY.Renewal_Cnt_201912_fix_CM_CY,
	CMCY.nb_prem_201912_fix_CM_CY,
	CMCY.rb_prem_201912_fix_CM_CY,
	CMCY.Writ_prem_201912_fix_CM_CY,

	CMPY.Sale_Cnt_201912_fix_CM_PY,
	CMPY.Renewal_Cnt_201912_fix_CM_PY,
	CMPY.nb_prem_201912_fix_CM_PY,
	CMPY.rb_prem_201912_fix_CM_PY,
	CMPY.Writ_prem_201912_fix_CM_PY

FROM SBI_Base B
LEFT JOIN
	(SELECT	carriercode, productcode, 
		sum(case when acct_dt in (201912) then Sale*.8	else Sale end) as Sale_Cnt_201912_fix_T12_CY,
		sum(case when acct_dt in (201912) then renewal*.8	else renewal end) as Renewal_Cnt_201912_fix_T12_CY,
		sum(case when acct_dt in (201912) then nb_prem*.8 else nb_prem end) as nb_prem_201912_fix_T12_CY,
		sum(case when acct_dt in (201912) then rb_prem*.8 else rb_prem end) as rb_prem_201912_fix_T12_CY,
		sum(case when acct_dt in (201912) then WrittenPremium*.8 else WrittenPremium end) as Writ_prem_201912_fix_T12_CY
		
	FROM CLAcq.SBI_Funnel_Holistic
	WHERE (acct_dt between &T12CYS and &CM)
 	GROUP BY carriercode, productcode
	)as T12CY
		on B.carriercode = T12CY.carriercode and B.productcode=T12CY.productcode

LEFT JOIN
	(SELECT	carriercode, productcode, 
		sum(case when acct_dt in (201912) then Sale*.8	else Sale end) as Sale_Cnt_201912_fix_T12_PY,
		sum(case when acct_dt in (201912) then renewal*.8	else renewal end) as Renewal_Cnt_201912_fix_T12_PY,
		sum(case when acct_dt in (201912) then nb_prem*.8 else nb_prem end) as nb_prem_201912_fix_T12_PY,
		sum(case when acct_dt in (201912) then rb_prem*.8 else rb_prem end) as rb_prem_201912_fix_T12_PY,
		sum(case when acct_dt in (201912) then WrittenPremium*.8 else WrittenPremium end) as Writ_prem_201912_fix_T12_PY
	FROM CLAcq.SBI_Funnel_Holistic
	WHERE (acct_dt between &T12PYS and &YoYS)
 	GROUP BY carriercode, productcode
	)as T12PY
		on B.carriercode = T12PY.carriercode and B.productcode=T12PY.productcode

LEFT JOIN
	(SELECT carriercode, productcode, 
		sum(case when acct_dt in (201912) then Sale*.8	else Sale end) as Sale_Cnt_201912_fix_T3_CY,
		sum(case when acct_dt in (201912) then renewal*.8	else renewal end) as Renewal_Cnt_201912_fix_T3_CY,
		sum(case when acct_dt in (201912) then nb_prem*.8 else nb_prem end) as nb_prem_201912_fix_T3_CY,
		sum(case when acct_dt in (201912) then rb_prem*.8 else rb_prem end) as rb_prem_201912_fix_T3_CY,
		sum(case when acct_dt in (201912) then WrittenPremium*.8 else WrittenPremium end) as Writ_prem_201912_fix_T3_CY
	FROM CLAcq.SBI_Funnel_Holistic
	WHERE (acct_dt between &T3CYS and &CM)
 	GROUP BY carriercode, productcode
	)as T3CY
		on B.carriercode = T3CY.carriercode and B.productcode=T3CY.productcode

LEFT JOIN
	(SELECT carriercode, productcode, 
		sum(case when acct_dt in (201912) then Sale*.8	else Sale end) as Sale_Cnt_201912_fix_T3_PY,
		sum(case when acct_dt in (201912) then renewal*.8	else renewal end) as Renewal_Cnt_201912_fix_T3_PY,
		sum(case when acct_dt in (201912) then nb_prem*.8 else nb_prem end) as nb_prem_201912_fix_T3_PY,
		sum(case when acct_dt in (201912) then rb_prem*.8 else rb_prem end) as rb_prem_201912_fix_T3_PY,
		sum(case when acct_dt in (201912) then WrittenPremium*.8 else WrittenPremium end) as Writ_prem_201912_fix_T3_PY
	FROM CLAcq.SBI_Funnel_Holistic
	WHERE (acct_dt between &T3PYS and &YoYS)
 	GROUP BY carriercode, productcode
	)as T3PY
		on B.carriercode = T3PY.carriercode and B.productcode=T3PY.productcode

LEFT JOIN
	(SELECT	carriercode, productcode, 
		sum(case when acct_dt in (201912) then Sale*.8	else Sale end) as Sale_Cnt_201912_fix_YTD_CY,
		sum(case when acct_dt in (201912) then renewal*.8	else renewal end) as Renewal_Cnt_201912_fix_YTD_CY,
		sum(case when acct_dt in (201912) then nb_prem*.8 else nb_prem end) as nb_prem_201912_fix_YTD_CY,
		sum(case when acct_dt in (201912) then rb_prem*.8 else rb_prem end) as rb_prem_201912_fix_YTD_CY,
		sum(case when acct_dt in (201912) then WrittenPremium*.8 else WrittenPremium end) as Writ_prem_201912_fix_YTD_CY
	FROM CLAcq.SBI_Funnel_Holistic
	WHERE (acct_dt between &YTDCYS and &CM)
 	GROUP BY carriercode, productcode
	)as YTDCY
		on B.carriercode = YTDCY.carriercode and B.productcode=YTDCY.productcode

LEFT JOIN
	(SELECT carriercode, productcode, 
		sum(case when acct_dt in (201912) then Sale*.8	else Sale end) as Sale_Cnt_201912_fix_YTD_PY,
		sum(case when acct_dt in (201912) then renewal*.8	else renewal end) as Renewal_Cnt_201912_fix_YTD_PY,
		sum(case when acct_dt in (201912) then nb_prem*.8 else nb_prem end) as nb_prem_201912_fix_YTD_PY,
		sum(case when acct_dt in (201912) then rb_prem*.8 else rb_prem end) as rb_prem_201912_fix_YTD_PY,
		sum(case when acct_dt in (201912) then WrittenPremium*.8 else WrittenPremium end) as Writ_prem_201912_fix_YTD_PY
	FROM CLAcq.SBI_Funnel_Holistic
	WHERE (acct_dt between &YTDPYS and &YoYs)
 	GROUP BY carriercode, productcode
	)as YTDPY
		on B.carriercode = YTDPY.carriercode and B.productcode=YTDPY.productcode

LEFT JOIN
	(SELECT carriercode, productcode, 
		sum(case when acct_dt in (201912) then Sale*.8	else Sale end) as Sale_Cnt_201912_fix_CM_CY,
		sum(case when acct_dt in (201912) then renewal*.8	else renewal end) as Renewal_Cnt_201912_fix_CM_CY,
		sum(case when acct_dt in (201912) then nb_prem*.8 else nb_prem end) as nb_prem_201912_fix_CM_CY,
		sum(case when acct_dt in (201912) then rb_prem*.8 else rb_prem end) as rb_prem_201912_fix_CM_CY,
		sum(case when acct_dt in (201912) then WrittenPremium*.8 else WrittenPremium end) as Writ_prem_201912_fix_CM_CY
	FROM CLAcq.SBI_Funnel_Holistic
	WHERE (acct_dt=&CM)
 	GROUP BY carriercode, productcode
	)as CMCY
		on B.carriercode = CMCY.carriercode and B.productcode=CMCY.productcode

LEFT JOIN
	(SELECT carriercode, productcode, 
		sum(case when acct_dt in (201912) then Sale*.8	else Sale end) as Sale_Cnt_201912_fix_CM_PY,
		sum(case when acct_dt in (201912) then renewal*.8	else renewal end) as Renewal_Cnt_201912_fix_CM_PY,
		sum(case when acct_dt in (201912) then nb_prem*.8 else nb_prem end) as nb_prem_201912_fix_CM_PY,
		sum(case when acct_dt in (201912) then rb_prem*.8 else rb_prem end) as rb_prem_201912_fix_CM_PY,
		sum(case when acct_dt in (201912) then WrittenPremium*.8 else WrittenPremium end) as Writ_prem_201912_fix_CM_PY
	FROM CLAcq.SBI_Funnel_Holistic
	WHERE (acct_dt=&YoYS)
 	GROUP BY carriercode, productcode
	)as CMPY
		on B.carriercode = CMPY.carriercode and B.productcode=CMPY.productcode;
QUIT;

PROC EXPORT
DATA=Sbi_Details 
OUTFILE= "/sso/win_wrkgrp/CNTL/SBI/RTB/CL Acquisition and SBI Monthly/SAS Exports/Sbi_Details.txt"
DBMS=TAB Replace;
RUN;

/*Switched to Holistic Funnel*/
PROC SQL;
CREATE TABLE Sbi_Details_monthly AS
SELECT acct_dt,
	case when partnercarriername in &currentCarriers. then partnercarriername else 'All Others' end as currentCarriers,
	PartnerCarrierName as PartnerCarrierName,
	carriercode,
	productcode,
	case when productcode in ('BOP', 'BOP-GARAGE') then 'BOP'
		when productcode in ('CGL', 'GL') then 'CGL'
		when productcode in ('PL', 'EO', 'PL1') then 'PL'
		when productcode in ('WCOM', 'WC') then 'WC'
	else 'Other' end as ProductCode2,

	sum(case when acct_dt in (201912) then Sale*.8	else Sale end) as Sale_Cnt_201912_fix,
	sum(case when acct_dt in (201912) then renewal*.8	else renewal end) as Renewal_Cnt_201912_fix,
	sum(case when acct_dt in (201912) then nb_prem*.8 else nb_prem end) as nb_prem_201912_fix,
	sum(case when acct_dt in (201912) then rb_prem*.8 else rb_prem end) as rb_prem_201912_fix,
	sum(case when acct_dt in (201912) then WrittenPremium*.8 else WrittenPremium end) as Writ_prem_201912_fix,

	sum(Sale_Cnt_Normalized) as Sale_Cnt_Normalized,
	sum(Renewal_Cnt_Normalized) as Renewal_Cnt_Normalized,
	sum(NB_Prem_Normalized) as NB_Prem_Normalized,
	sum(RB_Prem_Normalized) as RB_Prem_Normalized,
	sum(WP_Normalized) as Writ_Prem_Normalized,
	case when acct_dt between &T12CYS and &CM then 1 else 0 end as T12CY,
	case when acct_dt between &T12PYS and &YoYS then 1 else 0 end as T12PY,
	case when acct_dt between &T3CYS and &CM then 1 else 0 end as T3CY,
	case when acct_dt between &T3PYS and &YoYS then 1 else 0 end as T3PY,
	case when acct_dt between &YTDCYS and &CM then 1 else 0 end as YTDCY,
	case when acct_dt between &YTDPYS and &YoYs then 1 else 0 end as YTDPY,
	case when acct_dt=&CM then 1 else 0 end as CMCY,
	case when acct_dt=&YoYS then 1 else 0 end as CMPY
FROM CLAcq.SBI_Funnel_Holistic
WHERE acct_dt>=&T12PYS
GROUP BY acct_dt,
	partnercarriername,
	carriercode,
	productcode;
QUIT;

PROC EXPORT
DATA=Sbi_Details_monthly 
OUTFILE= "/sso/win_wrkgrp/CNTL/SBI/RTB/CL Acquisition and SBI Monthly/SAS Exports/Sbi_Details_monthly.txt"
DBMS=TAB Replace;
RUN;


/* Replaced BISS Holistic Funnel with Snowflake Holistic Funnel - IW 20250414*/
PROC SQL;
%sf_ref_acs_tok (warehouse=FREE_THE_DATA_XS);
CREATE TABLE BQX_Cov AS SELECT * FROM CONNECTION TO ODBC
(SELECT DISTINCT /*reformatting coverage to how BQX has it*/
	case when CoverageCode in ('GL','CGL','Website') then 'CGL'
		when CoverageCode in ('PL','PL1') then 'PL'
		when CoverageCode in ('WC','WCOM') then 'WC'
		when CoverageCode in ('BOP','BOP-GARAGE') then 'BOP'
	else 'Other' end as "selectedcoverage"
FROM CL_SBI.Published.BIT_HolisticFunnel_VW);
QUIT;

/* Replaced BISS Holistic Funnel with Snowflake Holistic Funnel - IW 20250414*/
PROC SQL;
%sf_ref_acs_tok (warehouse=FREE_THE_DATA_XS);
CREATE TABLE BQX_Base_2 AS SELECT * FROM CONNECTION TO ODBC
(SELECT to_number(QuoteStartMonth) as "QuoteStartMonth",
	to_number(QuoteFinishMonth) as "QuoteFinishMonth",
	case when CoverageCode in ('GL','CGL','Website') then 'CGL'
		when CoverageCode in ('PL','PL1') then 'PL'
		when CoverageCode in ('WC','WCOM') then 'WC'
		when CoverageCode in ('BOP','BOP-GARAGE') then 'BOP'
	else 'Other' end as "selectedcoverage",
	QSCnt as "QSCnt", QFCnt as "QFCnt"
FROM CL_SBI.Published.BIT_HolisticFunnel_VW);
QUIT;

PROC SQL;
CREATE TABLE BQX_Base AS
SELECT QS.ACCT_DT,
	QS.selectedcoverage,
	QS.QS_Cnt_201912_fix,
	QF.QF_Cnt_201912_fix
FROM (SELECT QuoteStartMonth as ACCT_DT,
			selectedcoverage,
			case when QuoteStartMonth in (201912) then sum(QSCnt)*0.8 else sum(QSCnt) end as QS_Cnt_201912_fix
		FROM BQX_Base_2
		WHERE QuoteStartMonth >= &T12PYS and QuoteStartMonth <= &CM
		GROUP BY QuoteStartMonth, selectedcoverage) QS
LEFT JOIN (SELECT QuoteFinishMonth as ACCT_DT,
				selectedcoverage,
				case when QuoteFinishMonth in (201912) then sum(QFCnt)*0.8 else sum(QFCnt) end as QF_Cnt_201912_fix
			FROM BQX_Base_2
			WHERE QuoteFinishMonth >= &T12PYS and QuoteFinishMonth <= &CM
			GROUP BY QuoteFinishMonth, selectedcoverage) QF
	ON QS.ACCT_DT = QF.ACCT_DT
	AND QS.selectedcoverage = QF.selectedcoverage;
QUIT;

%macro BQXTables (BegDt=,EndDt=,TabNm=,FieldNm=);
proc sql;
create table &TabNm. as
select
	selectedcoverage,
	sum(QS_Cnt_201912_fix) as QS_Cnt_201912_fix_&FieldNm.,
	sum(QF_Cnt_201912_fix) as QF_Cnt_201912_fix_&FieldNm.

from BQX_Base
where (acct_dt between &BegDt and &EndDt)
group by selectedcoverage
;
quit;
;
quit;
%mend BQXTables;
%BQXTables (Begdt=&T12CYS,	EndDt=&CM,		TabNm=BQXT12CY,	FieldNm=T12CY);
%BQXTables (BegDt=&T12PYS,	EndDt=&YoYS,	TaBNm=BQXT12PY,	FieldNm=T12PY);
%BQXTables (BegDt=&T3CYS, 	EndDt=&CM,		TabNm=BQXT3CY,	FieldNm=T3CY);
%BQXTables (BegDt=&T3PYS, 	EndDt=&YoYS, 	TabNm=BQXT3PY,	FieldNm=T3PY);
%BQXTables (BegDt=&YTDCYS,	EndDt=&CM,	 	TabNm=BQXYTDCY,	FieldNm=YTDCY);
%BQXTables (BegDt=&YTDPYS,	EndDt=&YoYs,	TabNm=BQXYTDPY,	FieldNm=YTDPY);
%BQXTables (BegDt=&CM,		EndDt=&CM,		TabNm=BQXCMCY,	FieldNm=CMCY);
%BQXTables (BegDt=&YoYS,	EndDt=&YoYS,	TabNm=BQXCMPY,	FieldNm=CMPY);
quit;


PROC SQL;
CREATE TABLE BQX_Prods_Qs_QF AS
SELECT a.*,b.*,c.*,d.*,e.*,f.*,g.*,h.*,i.*
FROM 		bqx_cov		a 
LEFT JOIN	BQXT12CY	b	ON a.selectedcoverage=b.selectedcoverage
LEFT JOIN	BQXT12PY	c	ON a.selectedcoverage=c.selectedcoverage
LEFT JOIN	BQXT3CY		d	ON a.selectedcoverage=d.selectedcoverage
LEFT JOIN	BQXT3PY		e	ON a.selectedcoverage=e.selectedcoverage
LEFT JOIN	BQXYTDCY	f	ON a.selectedcoverage=f.selectedcoverage
LEFT JOIN	BQXYTDPY	g	ON a.selectedcoverage=g.selectedcoverage
LEFT JOIN	BQXCMCY		h	ON a.selectedcoverage=h.selectedcoverage
LEFT JOIN	BQXCMPY		i	ON a.selectedcoverage=i.selectedcoverage;
quit;

PROC EXPORT
DATA=BQX_Prods_Qs_QF 
OUTFILE= "/sso/win_wrkgrp/CNTL/SBI/RTB/CL Acquisition and SBI Monthly/SAS Exports/BQX_Prods_Qs_QF.txt"
DBMS=TAB Replace;
RUN;

/*Switched data source to Holistic Funnel*/
PROC SQL;
CREATE TABLE BQXData_monthly AS
SELECT a.ACCT_DT,
	a.selectedcoverage,
	a.QS_Cnt_201912_fix,
	case when a.ACCT_DT in (201912) then (a.QS_Cnt_201912_fix/0.8)/cal.weeks
		else a.QS_Cnt_201912_fix/cal.weeks end as QS_Cnt_Normalized,
	a.QF_Cnt_201912_fix,
	case when a.ACCT_DT in (201912) then (a.QF_Cnt_201912_fix/0.8)/cal.weeks
		else a.QF_Cnt_201912_fix/cal.weeks end as QF_Cnt_Normalized,
	case when a.acct_dt between &T12CYS and &CM then 1 else 0 end as T12CY,
	case when a.acct_dt between &T12PYS and &YoYS then 1 else 0 end as T12PY,
	case when a.acct_dt between &T3CYS and &CM then 1 else 0 end as T3CY,
	case when a.acct_dt between &T3PYS and &YoYS then 1 else 0 end as T3PY,
	case when a.acct_dt between &YTDCYS and &CM then 1 else 0 end as YTDCY,
	case when a.acct_dt between &YTDPYS and &YoYs then 1 else 0 end as YTDPY,
	case when a.acct_dt=&CM then 1 else 0 end as CMCY,
	case when a.acct_dt=&YoYS then 1 else 0 end as CMPY,
	cal.weeks	
FROM BQX_Base a
	left join bit.acct_cal cal on a.ACCT_DT = cal.ACCT_DT
WHERE a.ACCT_dt >=&T12PYS. and a.acct_dt <=&CM.
/*group by a.acct_dt, a.selectedcoverage, cal.weeks*/
order by a.ACCT_DT desc;
QUIT;

PROC EXPORT
DATA=BQXData_monthly 
OUTFILE= "/sso/win_wrkgrp/CNTL/SBI/RTB/CL Acquisition and SBI Monthly/SAS Exports/BQX_Prods_By_Month.txt"
DBMS=TAB Replace;
RUN;


/* Replacing BIT date tables: */
PROC SQL;
CREATE TABLE acct_dt AS
SELECT
	sum(case when acct_dt between &T12CYS and &Cm then weeks end) as Weeks_T12_CY,
	sum(case when acct_dt between &T12PYS and &YoYS then weeks end) as Weeks_T12_PY,
	sum(case when acct_dt between &T3CYS and &CM then weeks end) as Weeks_T3_CY,
	sum(case when acct_dt between &T3PYS and &YoYS then weeks end) as Weeks_T3_PY,
	sum(case when acct_dt between &YTDCYS and &CM then weeks end) as Weeks_YTD_CY,
	sum(case when acct_dt between &YTDPYS and &YoYS then weeks end) as Weeks_YTD_PY,
	sum(case when acct_dt between &CM and &CM then weeks end) as Weeks_CM_CY,
	sum(case when acct_dt between &YoYS and &YoYS then weeks end) as Weeks_CM_PY
FROM (SELECT DISTINCT ACCT_CCYYMM as acct_dt, ACCT_WK_IN_MO as weeks FROM Date);
QUIT;

PROC EXPORT
DATA=acct_dt 
OUTFILE= "/sso/win_wrkgrp/CNTL/SBI/RTB/CL Acquisition and SBI Monthly/SAS Exports/acct_dt.txt"
DBMS=TAB Replace;
RUN;
