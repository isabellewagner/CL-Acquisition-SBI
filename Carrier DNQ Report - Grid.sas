
/* KP Update 2024-10-24 - Added check on QuoteCarrierRqstResponseDetail table to only grab the most recent record from each carrier */

/*SF replaced SQL for BQX tables, have to rename variables to match previous upper/lower case*/
PROC SQL;
%sf_ref_acs_tok (warehouse=FREE_THE_DATA_L);
CREATE TABLE QMDData AS SELECT * FROM CONNECTION TO ODBC
(SELECT SelectedCoverage as "SelectedCoverage",
	BusinessName as "BusinessName",
	BusinessState as "BusinessState",
	QuoteNumber as "QuoteNumber",
	QuoteCreatedDate as "QuoteCreatedDate",
    QuoteCompletedDate as "QuoteCompletedDate",
	TotalQuotedPremium as "TotalQuotedPremium",
	RecommendedCarrierName as "RecommendedCarrierName",
	RecommendedCarrierQuoteNumber as "RecommendedCarrierQuoteNumber",
	SelectedCarrierName as "SelectedCarrierName",
	QuoteOrigin as "QuoteOrigin",
	ProgressiveSubCategory as "ProgressiveSubCategory",
	BusinessTypeDescription as "BusinessTypeDescription",
	BecaIntent as "BecaIntent",
	QFOnlineCnt as "QFOnlineCnt",
	QFOfflineCnt as "QFOfflineCnt",
	QFCnt as "QFCnt",
	SaleCnt as "SaleCnt",
	IsQuoteTest as "IsQuoteTest"
FROM CL_SBI.Published.BQX_QuoteMasterDetail
WHERE ProgMonth >= '202201');
QUIT;

/*SF replaced SQL for BQX tables*/
PROC SQL;
%sf_ref_acs_tok (warehouse=FREE_THE_DATA_L);
CREATE TABLE DNQCarrierName AS SELECT * FROM CONNECTION TO ODBC
(SELECT DISTINCT Quote_Number as "QuoteNumber",
	Carrier_Name as "CarrierName",
	1 as "DNQFlag"
FROM CL_SBI.Published.QuoteCarrierDNQDetail A
WHERE DNQ_Message <> 'SuccessPendingAction'
AND A.Last_Updated_Time_stamp = (SELECT MAX(A2.Last_Updated_Time_stamp) 
                                 FROM CL_SBI.PUBLISHED.QUOTECARRIERRQSTRESPONSEDETAIL A2                                                 
                                 WHERE A.Quote_Number = A2.Quote_Number)
ORDER BY Quote_Number,
	Carrier_Name);
QUIT;

PROC TRANSPOSE DATA = DNQCarrierName 
OUT = DNQCarrierName_Trans; 
VAR CarrierName;
BY QuoteNumber;
RUN;

DATA DNQOut;
SET DNQCarrierName_Trans;

IF FIND(Col1,'Hiscox','i') THEN HiscoxDNQ = 1;
ELSE IF FIND(Col2,'Hiscox','i') THEN HiscoxDNQ = 1;
ELSE IF FIND(Col3,'Hiscox','i') THEN HiscoxDNQ = 1;
ELSE IF FIND(Col4,'Hiscox','i') THEN HiscoxDNQ = 1;
ELSE IF FIND(Col5,'Hiscox','i') THEN HiscoxDNQ = 1;
ELSE IF FIND(Col6,'Hiscox','i') THEN HiscoxDNQ = 1;
ELSE IF FIND(Col7,'Hiscox','i') THEN HiscoxDNQ = 1;
ELSE HiscoxDNQ = 0;

IF FIND(Col1,'Homesite','i') THEN HomesiteDNQ = 1;
ELSE IF FIND(Col2,'Homesite','i') THEN HomesiteDNQ = 1;
ELSE IF FIND(Col3,'Homesite','i') THEN HomesiteDNQ = 1;
ELSE IF FIND(Col4,'Homesite','i') THEN HomesiteDNQ = 1;
ELSE IF FIND(Col5,'Homesite','i') THEN HomesiteDNQ = 1;
ELSE IF FIND(Col6,'Homesite','i') THEN HomesiteDNQ = 1;
ELSE IF FIND(Col7,'Homesite','i') THEN HomesiteDNQ = 1;
ELSE HomesiteDNQ = 0;

IF FIND(Col1,'Liberty Mutual','i') THEN LibertyDNQ = 1;
ELSE IF FIND(Col2,'Liberty Mutual','i') THEN LibertyDNQ = 1;
ELSE IF FIND(Col3,'Liberty Mutual','i') THEN LibertyDNQ = 1;
ELSE IF FIND(Col4,'Liberty Mutual','i') THEN LibertyDNQ = 1;
ELSE IF FIND(Col5,'Liberty Mutual','i') THEN LibertyDNQ = 1;
ELSE IF FIND(Col6,'Liberty Mutual','i') THEN LibertyDNQ = 1;
ELSE IF FIND(Col7,'Liberty Mutual','i') THEN LibertyDNQ = 1;
ELSE LibertyDNQ = 0;

IF FIND(Col1,'Markel','i') THEN MarkelDNQ = 1;
ELSE IF FIND(Col2,'Markel','i') THEN MarkelDNQ = 1;
ELSE IF FIND(Col3,'Markel','i') THEN MarkelDNQ = 1;
ELSE IF FIND(Col4,'Markel','i') THEN MarkelDNQ = 1;
ELSE IF FIND(Col5,'Markel','i') THEN MarkelDNQ = 1;
ELSE IF FIND(Col6,'Markel','i') THEN MarkelDNQ = 1;
ELSE MarkelDNQ = 0;

IF FIND(Col1,'CNA','i') THEN CNADNQ = 1;
ELSE IF FIND(Col2,'CNA','i') THEN CNADNQ = 1;
ELSE IF FIND(Col3,'CNA','i') THEN CNADNQ = 1;
ELSE IF FIND(Col4,'CNA','i') THEN CNADNQ = 1;
ELSE IF FIND(Col5,'CNA','i') THEN CNADNQ = 1;
ELSE IF FIND(Col6,'CNA','i') THEN CNADNQ = 1;
ELSE IF FIND(Col7,'CNA','i') THEN CNADNQ = 1;
ELSE CNADNQ = 0;

IF FIND(Col1,'Evanston','i') THEN EvanstonDNQ = 1;
ELSE IF FIND(Col2,'Evanston','i') THEN EvanstonDNQ = 1;
ELSE IF FIND(Col3,'Evanston','i') THEN EvanstonDNQ = 1;
ELSE IF FIND(Col4,'Evanston','i') THEN EvanstonDNQ = 1;
ELSE IF FIND(Col5,'Evanston','i') THEN EvanstonDNQ = 1;
ELSE IF FIND(Col6,'Evanston','i') THEN EvanstonDNQ = 1;
ELSE IF FIND(Col7,'Evanston','i') THEN EvanstonDNQ = 1;
ELSE EvanstonDNQ = 0;

IF FIND(Col1,'Amtrust','i') THEN AmtrustDNQ = 1;
ELSE IF FIND(Col2,'Amtrust','i') THEN AmtrustDNQ = 1;
ELSE IF FIND(Col3,'Amtrust','i') THEN AmtrustDNQ = 1;
ELSE IF FIND(Col4,'Amtrust','i') THEN AmtrustDNQ = 1;
ELSE IF FIND(Col5,'Amtrust','i') THEN AmtrustDNQ = 1;
ELSE IF FIND(Col6,'Amtrust','i') THEN AmtrustDNQ = 1;
ELSE IF FIND(Col7,'Amtrust','i') THEN AmtrustDNQ = 1;
ELSE AmtrustDNQ = 0;

IF FIND(Col1,'Nationwide','i') THEN NationwideDNQ = 1;
ELSE IF FIND(Col2,'Nationwide','i') THEN NationwideDNQ = 1;
ELSE IF FIND(Col3,'Nationwide','i') THEN NationwideDNQ = 1;
ELSE IF FIND(Col4,'Nationwide','i') THEN NationwideDNQ = 1;
ELSE IF FIND(Col5,'Nationwide','i') THEN NationwideDNQ = 1;
ELSE IF FIND(Col6,'Nationwide','i') THEN NationwideDNQ = 1;
ELSE IF FIND(Col7,'Nationwide','i') THEN NationwideDNQ = 1;
ELSE NationwideDNQ = 0;

IF FIND(Col1,'Progressive','i') THEN ProgressiveDNQ = 1;
ELSE IF FIND(Col2,'Progressive','i') THEN ProgressiveDNQ = 1;
ELSE IF FIND(Col3,'Progressive','i') THEN ProgressiveDNQ = 1;
ELSE IF FIND(Col4,'Progressive','i') THEN ProgressiveDNQ = 1;
ELSE IF FIND(Col5,'Progressive','i') THEN ProgressiveDNQ = 1;
ELSE IF FIND(Col6,'Progressive','i') THEN ProgressiveDNQ = 1;
ELSE IF FIND(Col7,'Progressive','i') THEN ProgressiveDNQ = 1;
ELSE ProgressiveDNQ = 0;

IF FIND(Col1,'Arch','i') THEN ArchDNQ = 1;
ELSE IF FIND(Col2,'Arch','i') THEN ArchDNQ = 1;
ELSE IF FIND(Col3,'Arch','i') THEN ArchDNQ = 1;
ELSE IF FIND(Col4,'Arch','i') THEN ArchDNQ = 1;
ELSE IF FIND(Col5,'Arch','i') THEN ArchDNQ = 1;
ELSE IF FIND(Col6,'Arch','i') THEN ArchDNQ = 1;
ELSE IF FIND(Col7,'Arch','i') THEN ArchDNQ = 1;
ELSE ArchDNQ = 0;

DNQFlag = 1;

DROP COL1 COL2 COL3 COL4 COL5 COL6 COL7 _NAME_ _LABEL_;
RUN;

PROC SORT DATA = QMDData; BY QuoteNumber; RUN;
PROC SORT DATA = DNQOut; BY QuoteNumber; RUN;

DATA QMDFinalData;
MERGE
	QMDData (IN = A)
	DNQOut (IN = B);
BY
	QuoteNumber;

	IF A = 1;

RUN;

PROC STDIZE OUT=QMDFinalData REPONLY MISSING=0; RUN;

/*SF replaced SQL for BQX tables*/
PROC SQL;
%sf_ref_acs_tok (warehouse=FREE_THE_DATA_L);
CREATE TABLE DNQTab AS SELECT * FROM CONNECTION TO ODBC
(SELECT A.Quote_Id as "QuoteId",
	A.Quote_Number as "QuoteNumber",
	A.PartitionDate as "PartitionDate",
	A.Carrier_Request_Id as "CarrierRequestId",
	A.Carrier_Name as "CarrierName",
	A.Carrier_Request_Start_Time_Stamp as "CarrierRequestStartTimestamp",
	A.Carrier_Request_Finish_Time_Stamp as "CarrierRequestFinishTimestamp",
	A.DNQ_Code as "DNQCode",
	A.DNQ_Message as "DNQMessage",
	A.DNQ_Description as "DNQDescription",
	A.Created_Time_Stamp as "CreatedTimestamp",
	A.Created_By as "Createdby",
	A.Last_Updated_Time_Stamp as "LastUpdatedTimestamp",
	A.Last_Updated_By as "LastUpdatedby",
	A.System_Insert_Date_Time as "SystemInsertDatetime",
	B.SelectedCoverage as "SelectedCoverage",	
	B.BusinessName as "BusinessName",
	/*B.QuoteNumber as "QuoteNumber",*/ /*already get QuoteNumber from A*/
	B.QuoteCreatedDate as "QuoteCreatedDate",
	B.QuoteCompletedDate as "QuoteCompletedDate",	
	B.TotalQuotedPremium as "TotalQuotedPremium",
	B.RecommendedCarrierName as "RecommendedCarrierName",
	B.RecommendedCarrierQuoteNumber as "RecommendedCarrierQuoteNumber",
	B.SelectedCarrierName as "SelectedCarrierName",	
	B.QuoteOrigin as "QuoteOrigin",
	B.ProgressiveSubCategory as "ProgressiveSubCategory",
	B.BusinessTypeDescription as "BusinessTypeDescription",
	B.BecaIntent as "BecaIntent",
	B.QFOnlineCnt as "QFOnlineCnt",	
	B.QFOfflineCnt as "QFOfflineCnt",	
	B.QFCnt as "QFCnt",
	B.IsQuoteTest as "IsQuoteTest"
FROM CL_SBI.Published.QuoteCarrierDNQDetail A	
	LEFT JOIN CL_SBI.Published.BQX_QuoteMasterDetail B ON A.Quote_Number = B.QuoteNumber
WHERE A.DNQ_Message <> 'SuccessPendingAction'
	AND A.DNQ_Description <> 'Failed to create quote');
QUIT;

/*SF replaced SQL for BQX tables*/
/*CarrierCalledData*/
PROC SQL;
%sf_ref_acs_tok (warehouse=FREE_THE_DATA_L);
CREATE TABLE CarrierCalled AS SELECT * FROM CONNECTION TO ODBC
(SELECT DISTINCT A.SelectedCoverage as "SelectedCoverage",
	A.BusinessState as "BusinessState",
	A.ProgressiveSubCategory as "ProgressiveSubCategory",
	A.BecaIntent as "BecaIntent",
	year(A.QuoteCreatedDate) as "Qt_Year",
	month(A.QuoteCreatedDate) as "Qt_month",
	Count(Distinct CASE WHEN B.Carrier_Name LIKE ('%Hiscox%') THEN B.Quote_Number END) AS "HiscoxCalled",
	Count(Distinct CASE WHEN B.Carrier_Name LIKE ('%Homesite%') THEN B.Quote_Number END) AS "HomesiteCalled",
	Count(Distinct CASE WHEN B.Carrier_Name LIKE ('%Liberty Mutual%') THEN B.Quote_Number END) AS "LibertyCalled",
	Count(Distinct CASE WHEN B.Carrier_Name LIKE ('%Markel%') THEN B.Quote_Number END) AS "MarkelCalled",
	Count(Distinct CASE WHEN B.Carrier_Name LIKE ('%CNA%') THEN B.Quote_Number END) AS "CNACalled",
	Count(Distinct CASE WHEN B.Carrier_Name LIKE ('%Evanston%') THEN B.Quote_Number END) AS "EvanstonCalled",
	Count(Distinct CASE WHEN B.Carrier_Name LIKE ('%AmTrust%') THEN B.Quote_Number END) AS "AmtrustCalled",
	Count(Distinct CASE WHEN B.Carrier_Name LIKE ('%Nationwide%') THEN B.Quote_Number END) AS "NationwideCalled",
	Count(Distinct CASE WHEN B.Carrier_Name LIKE ('%Progressive%') THEN B.Quote_Number END) AS "ProgressiveCalled",
	Count(Distinct CASE WHEN B.Carrier_Name LIKE ('%Arch%') THEN B.Quote_Number END) AS "ArchCalled",
	Count(Distinct CASE 
			WHEN B.Carrier_Name LIKE ('%Hiscox%') THEN B.Quote_Number
			WHEN B.Carrier_Name LIKE ('%Homesite%') THEN B.Quote_Number
			WHEN B.Carrier_Name LIKE ('%Liberty Mutual%') THEN B.Quote_Number
			WHEN B.Carrier_Name LIKE ('%Markel%') THEN B.Quote_Number
			WHEN B.Carrier_Name LIKE ('%CNA%') THEN B.Quote_Number
			WHEN B.Carrier_Name LIKE ('%Evanston%') THEN B.Quote_Number
			WHEN B.Carrier_Name LIKE ('%AmTrust%') THEN B.Quote_Number
			WHEN B.Carrier_Name LIKE ('%Nationwide%') THEN B.Quote_Number
			WHEN B.Carrier_Name LIKE ('%Progressive%') THEN B.Quote_Number
			WHEN B.Carrier_Name LIKE ('%Arch%') THEN B.Quote_Number
		END) AS "TotalOpportunity"
FROM CL_SBI.Published.BQX_QuoteMasterDetail A 
	LEFT JOIN CL_SBI.Published.QuoteCarrierRqstResponseDetail B 
        ON A.QuoteNumber = B.Quote_Number
        AND B.Last_Updated_Time_stamp = (SELECT MAX(B2.Last_Updated_Time_stamp) 
                                         FROM CL_SBI.PUBLISHED.QUOTECARRIERRQSTRESPONSEDETAIL B2                                                 
                                         WHERE B.Quote_Number = B2.Quote_Number)
WHERE A.IsQuoteTest = 'N'
	AND A.ProgMonth >= '202201'

GROUP BY A.SelectedCoverage,
	A.BusinessState,
	A.ProgressiveSubCategory,
	A.BecaIntent,
	year(A.QuoteCreatedDate),
	month(A.QuoteCreatedDate));
QUIT;

DATA CarrierCalled;
SET CarrierCalled;
TotalCalled = HiscoxCalled+HomesiteCalled+LibertyCalled+MarkelCalled+CNACalled+EvanstonCalled+AmtrustCalled+NationwideCalled+ProgressiveCalled+ArchCalled;
RUN;

/*CarrierDNQData*/
PROC SQL;
CREATE TABLE CarrierDNQ AS
SELECT DISTINCT A.SelectedCoverage,
	A.BusinessState,
	A.ProgressiveSubCategory,
	A.BecaIntent,
	year(datepart(A.QuoteCreatedDate)) as Qt_Year,
	month(datepart(A.QuoteCreatedDate)) as Qt_month,
	SUM(HiscoxDNQ) AS HiscoxDNQ,
	SUM(HomesiteDNQ) AS HomesiteDNQ,
	SUM(LibertyDNQ) AS LibertyDNQ,
	SUM(MarkelDNQ) AS MarkelDNQ,
	SUM(CNADNQ) AS CNADNQ,
	SUM(EvanstonDNQ) AS EvanstonDNQ,
	SUM(AmtrustDNQ) AS AmtrustDNQ,
	SUM(NationwideDNQ) AS NationwideDNQ,
	SUM(ProgressiveDNQ) AS ProgressiveDNQ,
	SUM(ArchDNQ) AS ArchDNQ,
	SUM(DNQFlag) AS TotalDNQ
FROM QMDFinalData A 
WHERE A.isQuoteTest = 'N'
GROUP BY A.SelectedCoverage,
	A.BusinessState,
	A.ProgressiveSubCategory,
	A.BecaIntent,
	year(datepart(A.QuoteCreatedDate)),
	month(datepart(A.QuoteCreatedDate));
QUIT;

PROC SORT DATA = CarrierCalled; BY SelectedCoverage BusinessState ProgressiveSubCategory BecaIntent Qt_Year Qt_Month; RUN;
PROC SORT DATA = CarrierDNQ; BY SelectedCoverage BusinessState ProgressiveSubCategory BecaIntent Qt_Year Qt_Month; RUN;

DATA CarrierCalledDNQ;
MERGE
	CarrierCalled
	CarrierDNQ;
BY SelectedCoverage BusinessState ProgressiveSubCategory BecaIntent Qt_Year Qt_Month;

RUN;

libname CLAcq &SQLEng noprompt="DSN=SQLServer; Server=MSS-P1-BISS-01; DATABASE=BISSCLAcqSBI;" schema=dbo &bulkparms read_isolation_level=RU;

PROC DELETE DATA = CLAcq.DNQTab; RUN;

DATA CLAcq.DNQTab;
SET DNQTab;
RUN;

PROC DELETE DATA = CLAcq.CarrierCalledDNQ; RUN;

DATA CLAcq.CarrierCalledDNQ;
SET CarrierCalledDNQ;
RUN;