/*libname CAW odbc dsn=DB2P schema=CAW read_isolation_level=RU %db2conn(dsn=DB2P);*/
libname DB2TMP odbc %db2conn(db2p);

/*******************************************************************/
/*******************Accounting calendar fields**********************/
/*******************************************************************/
PROC SQL;
CONNECT TO ODBC (%db2conn(db2p));
CREATE TABLE Date AS SELECT * FROM CONNECTION TO ODBC
(SELECT DT_VAL, ACCT_MO, ACCT_CCYY, ACCT_CCYYMM, ACCT_DT, YEAR_NBR, MO_NBR, DAY_NBR, ACCT_WK_IN_MO FROM DSE.Date);
DISCONNECT FROM ODBC;
QUIT;

PROC SQL;
SELECT DT_VAL, /*Today's date*/
case when ACCT_MO = 1 then input(cat((ACCT_CCYY-1),'12'),6.) else (ACCT_CCYYMM-1) end as CM, /*Current Month*/
case when ACCT_MO in (1,2) then input(cat((ACCT_CCYY-1),(ACCT_MO+10)),6.) else (ACCT_CCYYMM-2) end as LM, /*Last Month*/
case when ACCT_MO = 1 then input(cat((ACCT_CCYY-1),'01'),6.) else input(cat((ACCT_CCYY),'01'),6.) end as CSM, /*Current YTD Start Month*/
case when ACCT_MO = 1 then input(cat((ACCT_CCYY-1),'12'),6.)-100 else (ACCT_CCYYMM-101) end as LYM, /*Current Month Last Year*/
case when ACCT_MO = 1 then input(cat((ACCT_CCYY-2),'01'),6.) else input(cat((ACCT_CCYY-1),'01'),6.) end as LSM, /*Last YTD Start Month*/
case when ACCT_MO in (1,2,3) then input(cat((ACCT_CCYY-1),(ACCT_MO+9)),6.) else (ACCT_CCYYMM-3) end as T3,	/*T3 Start Month*/
case when ACCT_MO in (1,2,3) then input(cat((ACCT_CCYY-1),'0',(ACCT_MO+6)),6.) when ACCT_MO in (4,5,6) then input(cat((ACCT_CCYY-1),(ACCT_MO+6)),6.) else (ACCT_CCYYMM-6) end as T6, /*T6 Start Month*/
case when ACCT_MO = 1 then input(cat((ACCT_CCYY-1),'01'),6.) else (ACCT_CCYYMM-100) end as T12, /*T12 Start Month*/
case when ACCT_MO = 1 then input(cat((ACCT_CCYY-2),'01'),6.) else (ACCT_CCYYMM-200) end as T24, /*T24 Start Month*/
case when ACCT_MO = 1 then input(cat((ACCT_CCYY-3),'01'),6.) else input(cat((ACCT_CCYY-2),'01'),6.) end as LSM2, /*2 Years Prior YTD Start Month*/
case when ACCT_MO in (2,5,8,11) then 5 when ACCT_MO = 1 AND ACCT_CCYY in (2020,2025,2030) then 5 else 4 end as CW, /*Number of Weeks in Current Month*/
case when ACCT_MO in (3,6,9,12) then 5 when ACCT_MO = 2 AND ACCT_CCYY in (2020,2025,2030) then 5 else 4 end as LW /*Number of Weeks in Last Month*/
INTO :DT_VAL, :CM, :LM, :CSM, :LYM, :LSM, :T3, :T6, :T12, :T24, :LSM2, :CW, :LW
FROM Date WHERE DT_VAL = today();
QUIT;

%put &DT_VAL, &CM., &LM., &CSM., &LYM., &LSM., &T3., &T6., &T12., &T24., &LSM2., &CW., &LW.;

/*Bringing in date range fields*/
PROC SQL;
CONNECT TO ODBC (%db2conn(db2p));
DROP TABLE DB2TMP.Date;
QUIT;

PROC SQL;
CREATE TABLE DB2TMP.Date AS SELECT * FROM Date;
CONNECT TO ODBC (%db2conn(db2p));
CREATE TABLE ACCT_CAL AS SELECT * FROM CONNECTION TO ODBC
(
WITH CTE_BeginDate AS
(
SELECT DT_VAL, ACCT_CCYYMM, row_number() over (partition by ACCT_DT order by DT_VAL) as BeginDate FROM Date
)
,CTE_EndDate AS
(
SELECT DT_VAL, ACCT_CCYYMM, row_number() over (partition by ACCT_DT order by DT_VAL desc) as EndDate FROM Date
)
,CTE_FirstDay AS
(
SELECT DT_VAL, YEAR_NBR, MO_NBR FROM Date WHERE DAY_NBR = 1
)
,CTE_Months AS
(
SELECT DISTINCT ACCT_CCYYMM, ACCT_WK_IN_MO, ACCT_CCYY, ACCT_MO FROM Date
)
SELECT D.ACCT_CCYYMM as ACCT_DT,
	B.DT_VAL as Month_Begin,
	E.DT_VAL as Month_End,
	A.DT_VAL as ACCT_DT_DISPLAY,
	D.ACCT_WK_IN_MO as Weeks
FROM CTE_Months D
	LEFT JOIN CTE_BeginDate B ON D.ACCT_CCYYMM = B.ACCT_CCYYMM AND B.BeginDate = 1
	LEFT JOIN CTE_EndDate E ON D.ACCT_CCYYMM = E.ACCT_CCYYMM AND E.EndDate = 1
	LEFT JOIN CTE_FirstDay A ON D.ACCT_CCYY = A.YEAR_NBR AND D.ACCT_MO = A.MO_NBR
ORDER BY D.ACCT_CCYYMM desc);
DISCONNECT FROM ODBC;
DROP TABLE DB2TMP.Date;
QUIT;


/*******************************************/
/***************CL Auto*********************/
/*******************************************/
/*CAQ for QS, added 10/9/24*/
PROC SQL;
CONNECT TO &SQLEng(noprompt="DSN=SQLServer; Server=MSS-P1-BISS-01; database=BISSCLDigitalAnalytics;" &bulkparms read_isolation_level=RU);
CREATE TABLE CAQBase AS SELECT * FROM CONNECTION TO &SQLEng
(SELECT Quote_Start_Year_Month as Acct_Dt,
	case when Channel = 'Agency' then 'A'
		when Channel = 'Direct' then 'D'
		else '' end as CHNL_CD,
	cast('Auto' as varchar(20)) as Product,
	count(*) as QS
FROM dbo.Commercial_Auto_Quoting
WHERE Quote_Start_Year_Month >= (&LSM2.-100) AND Quote_Start_Year_Month <= &CM.
GROUP BY Channel, Quote_Start_Year_Month
ORDER BY Channel, Quote_Start_Year_Month desc);
QUIT;

/*CLCQ for QF & sales*/
PROC SQL;
CONNECT TO ODBC (noprompt="DSN=SQLSERVER; Server=MSS-P1-PCA-06; database=FSScoreCard;" &bulkparms read_isolation_level=RU);
CREATE TABLE CLCQBase AS SELECT * FROM CONNECTION TO ODBC
(SELECT Q.QF_Month as Acct_Dt,
	Q.CHNL_CD,
	cast('Auto' as varchar(20)) as Product,
	Q.QF,
	S.Sales
FROM /*QF by month, by channel*/
	(SELECT cast(Q.QT_ACCT_CCYYMM as integer) as QF_Month, Q.CHNL_CD, sum(Q.QF_CNT) as QF
	FROM CLCQ.CLAutoQuoteMaster Q
	WHERE Q.QF_CNT = 1 AND Q.RISK_TYPE <> 'TN' AND (cast(Q.QT_ACCT_CCYYMM as integer) between (&LSM2.-100) AND &CM.)
	GROUP BY cast(Q.QT_ACCT_CCYYMM as integer), Q.CHNL_CD) Q
LEFT JOIN /*Sales by month, by channel*/
	(SELECT cast(S.SALE_ACCT_CCYYMM as integer) as Sale_Month, S.CHNL_CD, sum(S.SALE_CNT) as Sales
	FROM CLCQ.CLAutoQuoteMaster S
	WHERE S.SALE_CNT = 1 AND S.RISK_TYPE <> 'TN' AND (cast(S.SALE_ACCT_CCYYMM as integer) between (&LSM2.-100) AND &CM.)
	GROUP BY cast(S.SALE_ACCT_CCYYMM as integer), S.CHNL_CD) S
ON Q.QF_Month = S.Sale_Month
AND Q.CHNL_CD = S.CHNL_CD
ORDER BY Q.QF_Month desc);
DISCONNECT FROM ODBC;
QUIT;

PROC SQL;
CONNECT TO ODBC (%db2conn(db2p));
DROP TABLE DB2TMP.CAQBase;
DROP TABLE DB2TMP.CLCQBase;
DROP TABLE DB2TMP.ACCT_CAL;
QUIT;

/*CAW for PIFs & WP*/
PROC SQL;
CREATE TABLE DB2TMP.CAQBase AS SELECT * FROM CAQBase;
CREATE TABLE DB2TMP.CLCQBase AS SELECT * FROM CLCQBase;
CREATE TABLE DB2TMP.Acct_Cal AS SELECT * FROM ACCT_CAL;
CONNECT TO ODBC (%db2conn(db2p));
CREATE TABLE Auto AS SELECT * FROM CONNECTION TO ODBC
( 
WITH CTE_Auto_PIFs AS /*Monthly CAW PIFs for Agency & Direct (no longer using Foresight)*/
(
SELECT AC.ACCT_DT,
	RM.DSTRBT_CHNL,
	COUNT(DISTINCT POL.PHYS_POL_KEY) AS PIFs
FROM CAW.POLICY POL
	INNER JOIN CAW.RT_MAN_MDL RM ON POL.RT_MAN_CD = RM.RT_MAN_CD 
	LEFT JOIN CAW.POL_DATES PD ON POL.PHYS_POL_KEY = PD.PHYS_POL_KEY
	LEFT JOIN ACCT_CAL AC ON PD.POL_STRT_DT <= CAST(AC.Month_End AS DATE) AND PD.POL_STOP_DT > CAST(AC.Month_End AS DATE)
WHERE AC.ACCT_DT >= (&LSM2.-100) AND AC.ACCT_DT <= &CM.
	AND POL.POL_MOCK_IND = 'N'
	AND RM.RISK_TYP_CD <> 'TN'
GROUP BY RM.DSTRBT_CHNL, AC.ACCT_DT
)
,CTE_Auto_WP AS /*Written Premium for Agency & Direct each month*/
(
SELECT RM.DSTRBT_CHNL,
	AC.ACCT_DT,
	SUM(MPL.WRT_PREM_AMT) AS DWP
FROM CAW.POLICY POL 
	INNER JOIN CAW.MNTHLY_POL_PL MPL ON POL.PHYS_POL_KEY = MPL.PHYS_POL_KEY AND POL.ST_CD = MPL.ST_CD 
	INNER JOIN CAW.RT_MAN_MDL RM ON POL.RT_MAN_CD = RM.RT_MAN_CD 
	LEFT JOIN ACCT_CAL AC ON MPL.ACC_DT = CAST(AC.ACCT_DT_DISPLAY AS DATE)
WHERE AC.ACCT_DT >= (&LSM2.-100) AND AC.ACCT_DT <= &CM.
	AND POL.POL_MOCK_IND = 'N'
	AND RM.RISK_TYP_CD <> 'TN'
	AND RM.DSTRBT_CHNL in ('A','D')
GROUP BY RM.DSTRBT_CHNL, AC.ACCT_DT
)
SELECT Q.Acct_Dt,
	case when Q.CHNL_CD = 'A' then 'Agency'
		when Q.CHNL_CD = 'D' then 'Direct'
		else '' end as Channel,
	Q.Product,
	QS.QS,
	Q.QF,
	Q.Sales,
	P.PIFs,
	W.DWP
FROM CLCQBase Q
	LEFT JOIN CAQBase QS
		ON Q.Acct_Dt = QS.Acct_Dt AND Q.CHNL_CD = QS.CHNL_CD
	LEFT JOIN CTE_Auto_PIFs P
		ON Q.Acct_Dt = P.Acct_Dt AND Q.CHNL_CD = P.DSTRBT_CHNL
	LEFT JOIN CTE_Auto_WP W
		ON Q.Acct_Dt = W.Acct_Dt AND Q.CHNL_CD = W.DSTRBT_CHNL
ORDER BY Q.Acct_Dt desc
);
DISCONNECT FROM ODBC;
DROP TABLE DB2TMP.CAQBase;
DROP TABLE DB2TMP.CLCQBase;
DROP TABLE DB2TMP.ACCT_CAL;
QUIT;


/****************************************************/
/***************Manufactured BOP*********************/
/****************************************************/
/*CHANGED TO SNOWFLAKE SOURCE 9/20/24, changed anchoring dates 10/9/24*/
PROC SQL;
%sf_ref_acs_tok (warehouse=FREE_THE_DATA_XS, sf_create_tmp=Acct_Cal);
CREATE TABLE ManufacturedBOP AS SELECT * FROM CONNECTION TO ODBC
(SELECT QS.Acct_Dt,
	QS.Channel,
	cast('Manufactured BOP' as varchar(20)) as Product,
	QS.QS,
	QF.QF,
	S.Sales,
	P.PIFs as PIFs,
	PM.DWP as DWP
FROM /*Quote Starts*/
	(SELECT QS.ProgMonth as Acct_Dt, /*Quote Starts*/
		QS.Channel,
		sum(QS.QSCnt) as QS
	FROM CL_SBI.PUBLISHED_ODS.BOP_QUOTEMASTERDETAIL_VW QS
	WHERE QS.ProgMonth between (&LSM2.-100) and &CM.
	GROUP BY QS.ProgMonth, QS.Channel) QS
LEFT JOIN /*Quote Finishes*/
	(SELECT A.Acct_Dt,
		QF.Channel,
		sum(QF.QFCnt) as QF
	FROM CL_SBI.PUBLISHED_ODS.BOP_QUOTEMASTERDETAIL_VW QF
		LEFT JOIN &sf_read_tmp1 A ON QF.QuoteCompletedDate <= A.Month_End AND QF.QuoteCompletedDate >= A.Month_Begin
	WHERE A.Acct_Dt between (&LSM2.-100) and &CM.
	GROUP BY A.Acct_Dt, QF.Channel) QF
ON QS.Acct_Dt = QF.Acct_Dt
AND QS.Channel = QF.Channel
LEFT JOIN /*Sales*/
	(SELECT A.Acct_Dt,
		S.Channel,
		sum(S.SaleCnt) as Sales
	FROM CL_SBI.PUBLISHED_ODS.BOP_QUOTEMASTERDETAIL_VW S
		LEFT JOIN &sf_read_tmp1 A ON S.SaleDate <= A.Month_End AND S.SaleDate >= A.Month_Begin
	WHERE A.Acct_Dt between (&LSM2.-100) and &CM.
	GROUP BY A.Acct_Dt, S.Channel) S
ON QS.Acct_Dt = S.Acct_Dt
AND QS.Channel = S.Channel
LEFT JOIN /*PIFs*/
	(SELECT A.Acct_Dt,
		P.Channel,
		count(P.PolicyNbr) as PIFs
	FROM CL_SBI.PUBLISHED_ODS.BOP_POLICYMASTERDETAIL_VW P
		LEFT JOIN &sf_read_tmp1 A ON P.PolicyTermEffectiveDate <= A.Month_End AND P.PolicyTermStopDate > A.Month_End
	WHERE A.Acct_Dt between (&LSM2.-100) and &CM.
	GROUP BY A.Acct_Dt, P.Channel) P
ON QS.Acct_Dt = P.Acct_Dt
AND QS.Channel = P.Channel
LEFT JOIN /*DWP*/
	(SELECT PM.ProgAccountingMonth,
		PM.Channel,
		sum(PM.WrittenPremiumAmt) as DWP
	FROM CL_SBI.PUBLISHED_ODS.BOP_POLICYMASTERMONTHLY_VW PM
	WHERE PM.ProgAccountingMonth between (&LSM2.-100) and &CM.
	GROUP BY PM.ProgAccountingMonth, PM.Channel) PM
ON QS.Acct_Dt = PM.ProgAccountingMonth
AND QS.Channel = PM.Channel
ORDER BY QS.Acct_Dt, QS.Channel);
QUIT;


/****************************************************/
/********************Partner SBI*********************/
/****************************************************/
/****CHANGED TO HOLISTIC FUNNEL 8/19/24****/
PROC SQL;
CONNECT TO &SQLEng(noprompt="DSN=SQLServer; Server=MSS-P1-BISS-01; database=BISSCLAcqSBI;" &bulkparms read_isolation_level=RU);
CREATE TABLE Epic_Funnel AS SELECT * FROM CONNECTION TO &SQLEng
(SELECT Acct_Dt as Acct_Dt,
	cast('Direct' as varchar(20)) as Channel,
	cast('Partner SBI' as varchar(20)) as Product,
	sum(QS) as QS,
	sum(QF) as QF,
	sum(Sale) as Sales,
	sum(Total_PIF) as PIFs,
	cast(NULL as INT) as DWP /*don't have DWP for partner SBI*/
FROM dbo.SBI_Funnel_Holistic
WHERE Acct_Dt >= (&LSM2.-100) AND Acct_Dt <= &CM.
GROUP BY Acct_Dt
ORDER BY Acct_Dt desc);
QUIT;


/******************************************************/
/************Making an Agency & Direct combo***********/
/******************************************************/
PROC SQL;
CREATE TABLE AgencyAndDirectAuto AS
SELECT Acct_Dt, 'Total' as Channel, Product, sum(QS) as QS, sum(QF) as QF, sum(Sales) as Sales, sum(PIFs) as PIFs, sum(DWP) as DWP
FROM Auto
GROUP BY Acct_Dt, Product;
QUIT;

PROC SQL;
CREATE TABLE AgencyAndDirectBOP AS
SELECT Acct_Dt, 'Total' as Channel, Product, sum(QS) as QS, sum(QF) as QF, sum(Sales) as Sales, sum(PIFs) as PIFs, sum(DWP) as DWP
FROM ManufacturedBOP
GROUP BY Acct_Dt, Product;
QUIT;

PROC SQL;
CREATE TABLE AgencyAndDirectSBI AS
SELECT Acct_Dt, 'Total' as Channel, Product, sum(QS) as QS, sum(QF) as QF, sum(Sales) as Sales, sum(PIFs) as PIFs, sum(DWP) as DWP
FROM Epic_Funnel
GROUP BY Acct_Dt, Product;
QUIT;


/***********************************************************************/
/***********Combining Auto, BOP, & SBI's QF, sale, PIF, WP**************/
/***********************************************************************/
DATA AllProducts;
length Channel $ 6;
SET AgencyAndDirectAuto
	Auto
	AgencyAndDirectBOP
	ManufacturedBOP
	AgencyAndDirectSBI
	Epic_Funnel;
RUN;


/*Normalizing by # of weeks*/
PROC SQL;
CREATE TABLE AllProductsNorm AS
SELECT C.Acct_Dt,
	year(A.Acct_Dt_Display) as Year,
	month(A.Acct_Dt_Display) as Month,
	C.Channel,
	C.Product,
	C.QS,
	C.QS/A.Weeks as QS_Norm,
	C.QF,
	C.QF/A.Weeks as QF_Norm,
	C.Sales,
	C.Sales/A.Weeks as Sales_Norm,
	C.PIFs,
	C.DWP,
	C.DWP/A.Weeks as DWP_Norm,
	A.Weeks
FROM AllProducts C
	LEFT JOIN Acct_Cal A
		ON C.Acct_Dt = A.Acct_Dt
ORDER BY C.Product, C.Channel, C.Acct_Dt;
QUIT;

/*Getting YTD numbers*/
DATA AllProductsNormYTD;
SET AllProductsNorm;
by Product Channel Year;
if first.Year then do;
	QS_YTD = QS;
	QF_YTD = QF;
	Sales_YTD = Sales;
	DWP_YTD = DWP;
	Weeks_YTD = Weeks;
	end;
else do;
	QS_YTD + QS;
	QF_YTD + QF;
	Sales_YTD + Sales;
	DWP_YTD + DWP;
	Weeks_YTD + Weeks;
	end;
RUN;

PROC SORT data=AllProductsNormYTD;
by Product Channel Acct_Dt;
RUN;

/*Rolling 12 metrics*/
DATA AllProductsNorm (drop= x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11);
SET AllProductsNormYTD; BY Product Channel Acct_Dt;
RETAIN x1-x11 QS_Roll12;
x1 =lag1(QS); x2 =lag2(QS); x3 =lag3(QS); x4 =lag4(QS); x5 =lag5(QS); x6 =lag6(QS);
x7 =lag7(QS); x8 =lag8(QS); x9 =lag9(QS); x10=lag10(QS); x11=lag11(QS);
IF _N_ = 1 THEN QS_Roll12 = QS;
ELSE IF _N_ < 12 THEN QS_Roll12 + QS;
ELSE QS_Roll12 = sum(QS,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11);
RUN;

DATA AllProductsNorm0 (drop= x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11);
SET AllProductsNorm; BY Product Channel Acct_Dt;
RETAIN x1-x11 QS_Norm_Roll12;
x1 =lag1(QS_Norm); x2 =lag2(QS_Norm); x3 =lag3(QS_Norm); x4 =lag4(QS_Norm); x5 =lag5(QS_Norm); x6 =lag6(QS_Norm);
x7 =lag7(QS_Norm); x8 =lag8(QS_Norm); x9 =lag9(QS_Norm); x10=lag10(QS_Norm); x11=lag11(QS_Norm);
IF _N_ = 1 THEN QS_Norm_Roll12 = QS_Norm;
ELSE IF _N_ < 12 THEN QS_Norm_Roll12 + QS_Norm;
ELSE QS_Norm_Roll12 = sum(QS_Norm,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11);
RUN;

DATA AllProductsNorm1 (drop= x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11);
SET AllProductsNorm0; BY Product Channel Acct_Dt;
RETAIN x1-x11 QF_Roll12;
x1 =lag1(QF); x2 =lag2(QF); x3 =lag3(QF); x4 =lag4(QF); x5 =lag5(QF); x6 =lag6(QF);
x7 =lag7(QF); x8 =lag8(QF); x9 =lag9(QF); x10=lag10(QF); x11=lag11(QF);
IF _N_ = 1 THEN QF_Roll12 = QF;
ELSE IF _N_ < 12 THEN QF_Roll12 + QF;
ELSE QF_Roll12 = sum(QF,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11);
RUN;

DATA AllProductsNorm2 (drop= x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11);
SET AllProductsNorm1; BY Product Channel Acct_Dt;
RETAIN x1-x11 QF_Norm_Roll12;
x1 =lag1(QF_Norm); x2 =lag2(QF_Norm); x3 =lag3(QF_Norm); x4 =lag4(QF_Norm); x5 =lag5(QF_Norm); x6 =lag6(QF_Norm);
x7 =lag7(QF_Norm); x8 =lag8(QF_Norm); x9 =lag9(QF_Norm); x10=lag10(QF_Norm); x11=lag11(QF_Norm);
IF _N_ = 1 THEN QF_Norm_Roll12 = QF_Norm;
ELSE IF _N_ < 12 THEN QF_Norm_Roll12 + QF_Norm;
ELSE QF_Norm_Roll12 = sum(QF_Norm,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11);
RUN;

DATA AllProductsNorm3 (drop= x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11);
SET AllProductsNorm2; BY Product Channel Acct_Dt;
RETAIN x1-x11 Sales_Roll12;
x1 =lag1(Sales); x2 =lag2(Sales); x3 =lag3(Sales); x4 =lag4(Sales); x5 =lag5(Sales); x6 =lag6(Sales);
x7 =lag7(Sales); x8 =lag8(Sales); x9 =lag9(Sales); x10=lag10(Sales); x11=lag11(Sales);
IF _N_ = 1 THEN Sales_Roll12 = Sales;
ELSE IF _N_ < 12 THEN Sales_Roll12 + Sales;
ELSE Sales_Roll12 = sum(Sales,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11);
RUN;

DATA AllProductsNorm4 (drop= x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11);
SET AllProductsNorm3; BY Product Channel Acct_Dt;
RETAIN x1-x11 Sales_Norm_Roll12;
x1 =lag1(Sales_Norm); x2 =lag2(Sales_Norm); x3 =lag3(Sales_Norm); x4 =lag4(Sales_Norm); x5 =lag5(Sales_Norm); x6 =lag6(Sales_Norm);
x7 =lag7(Sales_Norm); x8 =lag8(Sales_Norm); x9 =lag9(Sales_Norm); x10=lag10(Sales_Norm); x11=lag11(Sales_Norm);
IF _N_ = 1 THEN Sales_Norm_Roll12 = Sales_Norm;
ELSE IF _N_ < 12 THEN Sales_Norm_Roll12 + Sales_Norm;
ELSE Sales_Norm_Roll12 = sum(Sales_Norm,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11);
RUN;

DATA AllProductsNorm5 (drop= x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11);
SET AllProductsNorm4; BY Product Channel Acct_Dt;
RETAIN x1-x11 DWP_Roll12;
x1 =lag1(DWP); x2 =lag2(DWP); x3 =lag3(DWP); x4 =lag4(DWP); x5 =lag5(DWP); x6 =lag6(DWP);
x7 =lag7(DWP); x8 =lag8(DWP); x9 =lag9(DWP); x10=lag10(DWP); x11=lag11(DWP);
IF _N_ = 1 THEN DWP_Roll12 = DWP;
ELSE IF _N_ < 12 THEN DWP_Roll12 + DWP;
ELSE DWP_Roll12 = sum(DWP,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11);
RUN;

DATA AllProductsNorm6 (drop= x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11);
SET AllProductsNorm5; BY Product Channel Acct_Dt;
RETAIN x1-x11 DWP_Norm_Roll12;
x1 =lag1(DWP_Norm); x2 =lag2(DWP_Norm); x3 =lag3(DWP_Norm); x4 =lag4(DWP_Norm); x5 =lag5(DWP_Norm); x6 =lag6(DWP_Norm);
x7 =lag7(DWP_Norm); x8 =lag8(DWP_Norm); x9 =lag9(DWP_Norm); x10=lag10(DWP_Norm); x11=lag11(DWP_Norm);
IF _N_ = 1 THEN DWP_Norm_Roll12 = DWP_Norm;
ELSE IF _N_ < 12 THEN DWP_Norm_Roll12 + DWP_Norm;
ELSE DWP_Norm_Roll12 = sum(DWP_Norm,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11);
RUN;

DATA AllProductsNorm7 (drop= x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11);
SET AllProductsNorm6; BY Product Channel Acct_Dt;
RETAIN x1-x11 Weeks_Roll12;
x1 =lag1(Weeks); x2 =lag2(Weeks); x3 =lag3(Weeks); x4 =lag4(Weeks); x5 =lag5(Weeks); x6 =lag6(Weeks);
x7 =lag7(Weeks); x8 =lag8(Weeks); x9 =lag9(Weeks); x10=lag10(Weeks); x11=lag11(Weeks);
IF _N_ = 1 THEN Weeks_Roll12 = Weeks;
ELSE IF _N_ < 12 THEN Weeks_Roll12 + Weeks;
ELSE Weeks_Roll12 = sum(Weeks,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11);
RUN;

/*Create MoM dataset*/
PROC SQL;
CREATE TABLE PriorMonthData AS
SELECT case when Month = 12 then Year+1
	else Year end as Year,
	case when Month = 12 then 1
	else Month+1 end as Month,
	Channel, Product, QS as QS_PM, QS_Norm as QS_Norm_PM, QF as QF_PM, QF_Norm as QF_Norm_PM, Sales as Sales_PM,
	Sales_Norm as Sales_Norm_PM, PIFs as PIFs_PM, DWP as DWP_PM, DWP_Norm as DWP_Norm_PM
FROM AllProductsNorm7;
QUIT;

/*Create YoY dataset*/
PROC SQL;
CREATE TABLE PriorYearData AS
SELECT Year + 1 as Year, Month, Channel, Product, 
	QS as QS_LY, QS_Norm as QS_Norm_LY, QF as QF_LY, QF_Norm as QF_Norm_LY, Sales as Sales_LY, Sales_Norm as Sales_Norm_LY, 
	PIFs as PIFs_LY, DWP as DWP_LY, DWP_Norm as DWP_Norm_LY, QS_YTD as QS_LYTD, QF_YTD as QF_LYTD, Sales_YTD as Sales_LYTD, 
	DWP_YTD as DWP_LYTD, Weeks_YTD as Weeks_LYTD, QS_Roll12 as QS_Roll24, QS_Norm_Roll12 as QS_Norm_Roll24, QF_Roll12 as QF_Roll24,
	QF_Norm_Roll12 as QF_Norm_Roll24, Sales_Roll12 as Sales_Roll24, Sales_Norm_Roll12 as Sales_Norm_Roll24,
	DWP_Roll12 as DWP_Roll24, DWP_Norm_Roll12 as DWP_Norm_Roll24, Weeks_Roll12 as Weeks_Roll24
FROM AllProductsNorm7;
QUIT;

/*Join MoM and YoY datasets*/
PROC SQL;
CREATE TABLE AllProductsOverTime AS
SELECT A.*,
	/*MoM fields*/ M.QS_PM, M.QS_Norm_PM, M.QF_PM, M.QF_Norm_PM, M.Sales_PM, M.Sales_Norm_PM, M.PIFs_PM, M.DWP_PM, M.DWP_Norm_PM,
	M.QF_Norm_PM/M.QS_Norm_PM as QY_PM, M.Sales_Norm_PM/M.QF_Norm_PM as Conv_PM, 
	/*YoY fields*/Y.QS_LY, Y.QS_Norm_LY, Y.QF_LY, Y.QF_Norm_LY, Y.Sales_LY, Y.Sales_Norm_LY, Y.PIFs_LY, Y.DWP_LY, Y.DWP_Norm_LY,
	Y.QS_LYTD, Y.QF_LYTD, Y.Sales_LYTD, Y.DWP_LYTD, Y.Weeks_LYTD, Y.QS_Roll24, Y.QS_Norm_Roll24, Y.QF_Roll24, Y.QF_Norm_Roll24,
	Y.Sales_Roll24, Y.Sales_Norm_Roll24, Y.DWP_Roll24, Y.DWP_Norm_Roll24, Y.Weeks_Roll24
FROM AllProductsNorm7 A
	LEFT JOIN PriorMonthData M ON A.Year = M.Year AND A.Month = M.Month AND A.Channel = M.Channel AND A.Product = M.Product
	LEFT JOIN PriorYearData Y ON A.Year = Y.Year AND A.Month = Y.Month AND A.Channel = Y.Channel AND A.Product = Y.Product
ORDER BY Product, Channel, Acct_Dt;
QUIT;

DATA AllProductsFrozen;
SET AllProductsOverTime;
Conv = Sales/QF;
/********** Frozen PIF Targets **********/
if Product = 'Auto' AND Channel = 'Agency' then PIF_Target = 901676; /* KP Updated for 2025 */
else if Product = 'Auto' AND Channel = 'Direct' then PIF_Target = 211889; /* KP Updated for 2025 */
else if Product = 'Auto' AND Channel = 'Total' then PIF_Target = 1113565; /* KP Updated for 2025 */
else if Product = 'Manufactured BOP' then PIF_Target = 99303; /* KP Updated for 2025 */
else if Product = 'Partner SBI' then PIF_Target = 78220;
RUN;

PROC SQL; CREATE TABLE AllProductsFinal AS SELECT * FROM AllProductsFrozen WHERE Acct_Dt >= &LSM2. /*Removing extra year of data*/; QUIT;

PROC EXPORT
DATA=AllProductsFinal
OUTFILE= "/sso/win_wrkgrp/CNTL/SBI/Adhoc/Reporting Brainstorm/Main Data Export.xlsx"
DBMS=xlsx REPLACE;
RUN;



/****************************************************/
/********************** BQX *************************/
/****************************************************/

/*SF replaced SQL for BQX*/
PROC SQL;
%sf_ref_acs_tok (warehouse=FREE_THE_DATA_XS, sf_create_tmp=Acct_Cal);
CREATE TABLE BQXData1 AS SELECT * FROM CONNECTION TO ODBC
(SELECT A.Acct_Dt as "Acct_Dt",
	year(A.Acct_Dt_Display) as "Year",
	month(A.Acct_Dt_Display) as "Month",
	Q.QuoteOrigin as "QuoteOrigin",
	Q.SelectedCoverage as "SelectedCoverage",
	Q.QuoteLastRetrievedBy as "QuoteLastRetrievedBy",
	sum(Q.QSCnt) as QS,
	sum(Q.QSCnt)/A.Weeks as "QS_Norm",
	sum(Q.RHCnt) as RH,
	sum(Q.RHCnt)/A.Weeks as "RH_Norm",
	sum(Q.QICnt) as QI,
	sum(Q.QICnt)/A.Weeks as "QI_Norm",
	sum(Q.QFCnt) as QF,
	sum(Q.QFCnt)/A.Weeks as "QF_Norm",
	sum(Q.SaleCnt) as "Sales",
	sum(Q.SaleCnt)/A.Weeks as "Sales_Norm",
	sum(Q.PolicyPremium) as "NBPrem",
	sum(Q.PolicyPremium)/A.Weeks as "NBPrem_Norm",
	A.Weeks AS "Weeks"
FROM CL_SBI.Published.BQX_QuoteMasterDetail Q
	LEFT JOIN &sf_read_tmp1 A ON Q.QuoteCreatedDate between A.Month_Begin AND A.Month_End
WHERE Q.IsQuoteTest = 'N' AND A.Acct_Dt >= (&LSM2.-100) AND A.Acct_Dt <= &CM.
GROUP BY Q.QuoteOrigin, Q.SelectedCoverage, Q.QuoteLastRetrievedBy,
	A.Acct_Dt, year(A.Acct_Dt_Display), month(A.Acct_Dt_Display), A.Weeks, A.Acct_Dt_Display
ORDER BY Q.QuoteOrigin, Q.SelectedCoverage, Q.QuoteLastRetrievedBy, A.Acct_Dt);
QUIT;

PROC SORT data=BQXData1;
by QuoteOrigin SelectedCoverage QuoteLastRetrievedBy Year;
RUN;

DATA BQXData2;
SET BQXData1;
by QuoteOrigin SelectedCoverage QuoteLastRetrievedBy Year;
if first.Year then do;
	QS_YTD = QS;
	RH_YTD = RH;
	QI_YTD = QI;
	QF_YTD = QF;
	Sales_YTD = Sales;
	NBPrem_YTD = NBPrem;
	Weeks_YTD = Weeks;
	end;
else do;
	QS_YTD + QS;
	RH_YTD + RH;
	QI_YTD + QI;
	QF_YTD + QF;
	Sales_YTD + Sales;
	NBPrem_YTD + NBPrem;
	Weeks_YTD + Weeks;
	end;
RUN;

PROC SORT data=BQXData2;
by QuoteOrigin SelectedCoverage QuoteLastRetrievedBy Acct_Dt;
RUN;

/*Rolling 12 metrics*/
DATA BQXNorm1 (drop= x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11);
SET BQXData2; BY QuoteOrigin SelectedCoverage QuoteLastRetrievedBy Acct_Dt;
RETAIN x1-x11 QS_Roll12;
x1 =lag1(QS); x2 =lag2(QS); x3 =lag3(QS); x4 =lag4(QS); x5 =lag5(QS); x6 =lag6(QS);
x7 =lag7(QS); x8 =lag8(QS); x9 =lag9(QS); x10=lag10(QS); x11=lag11(QS);
IF _N_ = 1 THEN QS_Roll12 = QS;
ELSE IF _N_ < 12 THEN QS_Roll12 + QS;
ELSE QS_Roll12 = sum(QS,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11);
RUN;

DATA BQXNorm2 (drop= x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11);
SET BQXNorm1; BY QuoteOrigin SelectedCoverage QuoteLastRetrievedBy Acct_Dt;
RETAIN x1-x11 RH_Roll12;
x1 =lag1(RH); x2 =lag2(RH); x3 =lag3(RH); x4 =lag4(RH); x5 =lag5(RH); x6 =lag6(RH);
x7 =lag7(RH); x8 =lag8(RH); x9 =lag9(RH); x10=lag10(RH); x11=lag11(RH);
IF _N_ = 1 THEN RH_Roll12 = RH;
ELSE IF _N_ < 12 THEN RH_Roll12 + RH;
ELSE RH_Roll12 = sum(RH,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11);
RUN;

DATA BQXNorm3 (drop= x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11);
SET BQXNorm2; BY QuoteOrigin SelectedCoverage QuoteLastRetrievedBy Acct_Dt;
RETAIN x1-x11 QI_Roll12;
x1 =lag1(QI); x2 =lag2(QI); x3 =lag3(QI); x4 =lag4(QI); x5 =lag5(QI); x6 =lag6(QI);
x7 =lag7(QI); x8 =lag8(QI); x9 =lag9(QI); x10=lag10(QI); x11=lag11(QI);
IF _N_ = 1 THEN QI_Roll12 = QI;
ELSE IF _N_ < 12 THEN QI_Roll12 + QI;
ELSE QI_Roll12 = sum(QI,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11);
RUN;

DATA BQXNorm4 (drop= x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11);
SET BQXNorm3; BY QuoteOrigin SelectedCoverage QuoteLastRetrievedBy Acct_Dt;
RETAIN x1-x11 QF_Roll12;
x1 =lag1(QF); x2 =lag2(QF); x3 =lag3(QF); x4 =lag4(QF); x5 =lag5(QF); x6 =lag6(QF);
x7 =lag7(QF); x8 =lag8(QF); x9 =lag9(QF); x10=lag10(QF); x11=lag11(QF);
IF _N_ = 1 THEN QF_Roll12 = QF;
ELSE IF _N_ < 12 THEN QF_Roll12 + QF;
ELSE QF_Roll12 = sum(QF,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11);
RUN;

DATA BQXNorm5 (drop= x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11);
SET BQXNorm4; BY QuoteOrigin SelectedCoverage QuoteLastRetrievedBy Acct_Dt;
RETAIN x1-x11 Sales_Roll12;
x1 =lag1(Sales); x2 =lag2(Sales); x3 =lag3(Sales); x4 =lag4(Sales); x5 =lag5(Sales); x6 =lag6(Sales);
x7 =lag7(Sales); x8 =lag8(Sales); x9 =lag9(Sales); x10=lag10(Sales); x11=lag11(Sales);
IF _N_ = 1 THEN Sales_Roll12 = Sales;
ELSE IF _N_ < 12 THEN Sales_Roll12 + Sales;
ELSE Sales_Roll12 = sum(Sales,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11);
RUN;

DATA BQXNorm6 (drop= x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11);
SET BQXNorm5; BY QuoteOrigin SelectedCoverage QuoteLastRetrievedBy Acct_Dt;
RETAIN x1-x11 NBPrem_Roll12;
x1 =lag1(NBPrem); x2 =lag2(NBPrem); x3 =lag3(NBPrem); x4 =lag4(NBPrem); x5 =lag5(NBPrem); x6 =lag6(NBPrem);
x7 =lag7(NBPrem); x8 =lag8(NBPrem); x9 =lag9(NBPrem); x10=lag10(NBPrem); x11=lag11(NBPrem);
IF _N_ = 1 THEN NBPrem_Roll12 = NBPrem;
ELSE IF _N_ < 12 THEN NBPrem_Roll12 + NBPrem;
ELSE NBPrem_Roll12 = sum(NBPrem,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11);
RUN;

DATA BQXNorm7 (drop= x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11);
SET BQXNorm6; BY QuoteOrigin SelectedCoverage QuoteLastRetrievedBy Acct_Dt;
RETAIN x1-x11 Weeks_Roll12;
x1 =lag1(Weeks); x2 =lag2(Weeks); x3 =lag3(Weeks); x4 =lag4(Weeks); x5 =lag5(Weeks); x6 =lag6(Weeks);
x7 =lag7(Weeks); x8 =lag8(Weeks); x9 =lag9(Weeks); x10=lag10(Weeks); x11=lag11(Weeks);
IF _N_ = 1 THEN Weeks_Roll12 = Weeks;
ELSE IF _N_ < 12 THEN Weeks_Roll12 + Weeks;
ELSE Weeks_Roll12 = sum(Weeks,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11);
RUN;

/*Create MoM dataset*/
PROC SQL;
CREATE TABLE PriorMonthData AS
SELECT case when Month = 12 then Year+1
	else Year end as Year,
	case when Month = 12 then 1
	else Month+1 end as Month,
	QuoteOrigin, SelectedCoverage, QuoteLastRetrievedBy, QS as QS_PM, RH as RH_PM, QI as QI_PM, QF as QF_PM, Sales as Sales_PM, 
	NBPrem as NBPrem_PM, Weeks as Weeks_PM
FROM BQXNorm7;
QUIT;

/*Create YoY dataset*/
PROC SQL;
CREATE TABLE PriorYearData AS
SELECT Year + 1 as Year, Month, QuoteOrigin, SelectedCoverage, QuoteLastRetrievedBy, 
	QS as QS_LY, RH as RH_LY, QI as QI_LY, QF as QF_LY, Sales as Sales_LY, NBPrem as NBPrem_LY, Weeks as Weeks_LY,
	QS_YTD as QS_LYTD, RH_YTD as RH_LYTD, QI_YTD as QI_LYTD, QF_YTD as QF_LYTD, Sales_YTD as Sales_LYTD, NBPrem_YTD as NBPrem_LYTD,
	Weeks_YTD as Weeks_LYTD, QS_Roll12 as QS_Roll24, RH_Roll12 as RH_Roll24, QI_Roll12 as QI_Roll24, QF_Roll12 as QF_Roll24,
	Sales_Roll12 as Sales_Roll24, NBPrem_Roll12 as NBPrem_Roll24, Weeks_Roll12 as Weeks_Roll24
FROM BQXNorm7;
QUIT;

/*Join MoM and YoY datasets*/
PROC SQL;
CREATE TABLE BQXOverTime AS
SELECT A.*,
	/*MoM fields*/ M.QS_PM, M.RH_PM, M.QI_PM, M.QF_PM, M.Sales_PM, M.NBPrem_PM, M.Weeks_PM, 
	/*YoY fields*/ Y.QS_LY, Y.RH_LY, Y.QI_LY, Y.QF_LY, Y.Sales_LY, Y.NBPrem_LY, Y.Weeks_LY, Y.QS_LYTD, Y.RH_LYTD, Y.QI_LYTD,
	Y.QF_LYTD, Y.Sales_LYTD, Y.NBPrem_LYTD, Y.Weeks_LYTD, Y.QS_Roll24, Y.RH_Roll24, Y.QI_Roll24, Y.QF_Roll24, Y.Sales_Roll24,
	Y.NBPrem_Roll24, Y.Weeks_Roll24
FROM BQXNorm7 A
	LEFT JOIN PriorMonthData M ON A.Year = M.Year AND A.Month = M.Month AND A.QuoteOrigin = M.QuoteOrigin 
		AND A.SelectedCoverage = M.SelectedCoverage AND A.QuoteLastRetrievedBy = M.QuoteLastRetrievedBy
	LEFT JOIN PriorYearData Y ON A.Year = Y.Year AND A.Month = Y.Month AND A.QuoteOrigin = Y.QuoteOrigin 
		AND A.SelectedCoverage = Y.SelectedCoverage AND A.QuoteLastRetrievedBy = Y.QuoteLastRetrievedBy
WHERE A.Acct_Dt >= &LSM2.
ORDER BY A.QuoteOrigin, A.SelectedCoverage, A.QuoteLastRetrievedBy, A.Acct_Dt;
QUIT;


/*Exporting BQX data with QS, QF, sales, and nb premium, including monthly, YTD, normalized*/
PROC EXPORT
DATA=BQXOverTime 
OUTFILE= "/sso/win_wrkgrp/CNTL/SBI/Adhoc/Reporting Brainstorm/BQX Data Export.xlsx"
DBMS=xlsx REPLACE;
SHEET="BQX Data";
RUN;