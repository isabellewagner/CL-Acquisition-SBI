/*BQX*/

%LET StartDate = 202101;
%LET EndDate = 202212;

libname DSE odbc dsn=DB2P schema=DSE read_isolation_level=RU %db2conn(dsn=DB2P);

PROC SQL;
CREATE TABLE Dates AS
SELECT DISTINCT
	ACCT_CCYYMM AS X,
	CASE WHEN Acct_Mo = 1 THEN ACCT_CCYYMM -89 ELSE ACCT_CCYYMM - 1 END AS Y,
	input(cats(Acct_CcYy-1,put(acct_mo,z2.)),6.) as Z
FROM
	DSE.Date
WHERE
	Acct_CCYYMM >= &StartDate
	AND Acct_ccyymm <= &EndDate
ORDER BY
	Acct_ccyymm desc
;
QUIT;	

PROC SQL NOPRINT;
  SELECT 
	X,
	Y,
	Z,
	COUNT(*)
  INTO 
	:CurrentMonth SEPARATED BY ' ',
	:LastYearEnd SEPARATED BY ' ',
	:LastYearStart SEPARATED BY ' ',
	:COUNTER
  FROM 
	Dates;
QUIT;

/*SF replacing SQL for BQX data*/
PROC SQL;
%sf_ref_acs_tok (warehouse=FREE_THE_DATA_L);
CREATE TABLE Policy AS SELECT * FROM CONNECTION TO ODBC
(SELECT SelectedCoverage as "Product",
	QuoteCreatedDate as "QuoteCreatedDate",
	BusinessPhoneNumber as "BusinessPhoneNumber",
	BusinessState as "BusinessState",
	QFCnt as "QFCnt",
	SaleCnt as "SaleCnt"
FROM CL_SBI.Published.BQX_QuoteMasterDetail
WHERE IsQuoteTest = 'N');
QUIT;

/*%MACRO PULLDATA(CurrentMonth,LastYearEnd,LastYearStart);*/
%MACRO PULLDATA(X,Y,Z);
%DO I=1 %TO &COUNTER.;

PROC SQL;
CREATE TABLE CustomerMaster AS
SELECT DISTINCT 
	UPPER(A.BusinessPhoneNumber) AS Customer_Name,
	C.ACCT_CCYYMM,
	A.BusinessState as State,
	A.Product
FROM
	Policy A
		LEFT JOIN DSE.Date C ON QuoteCreatedDate  =  C.DT_VAL
WHERE
	C.ACCT_CCYYMM = %SCAN(&CurrentMonth.,&I.)
	and A.QFCnt = 1
;
QUIT;


PROC SQL;
CREATE TABLE CustomerPY AS
SELECT DISTINCT 
	UPPER(A.BusinessPhoneNumber) AS Customer_Name,
	C.ACCT_CCYYMM,
	A.BusinessState as State,
	A.Product
FROM
	Policy A
		LEFT JOIN DSE.Date C ON QuoteCreatedDate  =  C.DT_VAL
WHERE
	(C.ACCT_CCYYMM >= %SCAN(&LastYearStart.,&I.) 
	AND C.ACCT_CCYYMM < %SCAN(&LastYearEnd.,&I.))
	AND A.QFCnt = 1
;
QUIT;

PROC SQL;
CREATE TABLE NP12Customer AS
SELECT DISTINCT
	A.*,
	CASE WHEN B.Customer_Name NE '' THEN 0 ELSE 1 END AS NP12Ind
FROM
	CustomerMaster A
		LEFT JOIN CustomerPY B ON A.Customer_Name = B.Customer_Name and A.State = B.State and A.Product = B.Product
;
QUIT;

	%IF  &I. = 1 %THEN %DO;
	DATA NP12CustomerTable;
		SET NP12Customer;
	RUN;
	%END;
	%ELSE %DO;
	PROC APPEND BASE = NP12CustomerTable 		DATA = NP12Customer;
	RUN;
	%END;

%END;
%MEND;
%PULLDATA();
RUN;

PROC SQL;
CREATE TABLE Np12customertable AS
SELECT DISTINCT
	A.*
FROM
	Np12customertable A
		INNER JOIN Dates D ON A.ACCT_CCYYMM = D.X
;
QUIT;

PROC SORT DATA = Np12customertable; BY ACCT_CCYYMM State Product; RUN;

PROC SUMMARY DATA = Np12customertable;
BY ACCT_CCYYMM State Product;
VAR NP12Ind;
OUTPUT OUT = NP12Results (DROP = _TYPE_ _FREQ_) SUM=;
RUN;

PROC TRANSPOSE DATA=NP12Results OUT=NP12ResultsTranspose(DROP = _NAME_);
    BY ACCT_CCYYMM State;
/*    COPY variable(s);*/
    ID Product;
    VAR NP12Ind;
RUN;

PROC SQL;
CREATE TABLE Measures AS
SELECT DISTINCT 
	C.ACCT_CCYYMM,
	A.BusinessState as State,
	A.Product,
	SUM(QFCnt) AS QFCnt,
	SUM(SaleCnt) AS SaleCnt
FROM
	Policy A
		LEFT JOIN DSE.Date C ON A.QuoteCreatedDate = C.DT_VAL
WHERE
	C.ACCT_CCYYMM >= &&StartDate
	and QFCnt = 1
GROUP BY
	ACCT_CCYYMM,
	BusinessState,
	Product
;
QUIT;

PROC TRANSPOSE DATA=Measures OUT=QF (DROP = _NAME_);
    BY ACCT_CCYYMM State;
    ID Product;
    VAR QfCnt;
RUN;

PROC TRANSPOSE DATA=Measures OUT=Sales (DROP = _NAME_);
    BY ACCT_CCYYMM State;
    ID Product;
    VAR SaleCnt;
RUN;

PROC PRINT DATA = NP12ResultsTranspose NOOBS; RUN;
PROC PRINT DATA = QF NOOBS; RUN;
PROC PRINT DATA = sales NOOBS; RUN;

PROC SQL;
CREATE TABLE AllData AS
SELECT
	A.*,
	B.QfCnt,
	B.SaleCnt
FROM
	NP12Results A 
		LEFT JOIN Measures B ON A.Acct_ccyymm = B.Acct_ccyymm AND A.State = B.State AND A.Product = B.Product
;
QUIT;

PROC SUMMARY DATA = AllData;
BY ACCT_CCYYMM;
VAR NP12Ind QFCnt SaleCnt;
OUTPUT OUT = AllDataSum (DROP = _TYPE_ _FREQ_) SUM=;
RUN;

libname CLAcq &SQLEng noprompt="DSN=SQLServer; Server=MSS-P1-BISS-01; DATABASE=BISSCLAcqSBI;" schema=dbo &bulkparms read_isolation_level=RU;

DATA OldNP12ByState;
SET CLAcq.NP12ByState;
RUN;

PROC DELETE DATA = CLAcq.NP12ByState; RUN;
DATA CLAcq.NP12ByState;
SET AllData;
RUN;
