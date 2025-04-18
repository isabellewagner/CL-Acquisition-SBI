
/* KP Update 2024-10-24 - Added check on QuoteCarrierRqstResponseDetail table to only grab the most recent record from each carrier */


Options NOCONNECTMETACONNECTION;
%include '/home/a114064/signon.txt';


/*Replaced SQL source with SF source for BQX*/
PROC SQL;
%sf_ref_acs_tok (warehouse=FREE_THE_DATA_L);
CREATE TABLE PartnerCallsAndDNQSF AS SELECT * FROM CONNECTION TO ODBC
(SELECT DISTINCT
	A.Quote_Number as "QuoteNumber",
	B.BECAIntent as "BECAIntent",
	Count(Distinct a.Quote_Number) as "CarrierCalled",
	A.Carrier_Name as "CarrierName",
	count(distinct CASE WHEN A.Carrier_Request_Status in ('ineligible','failed') then a.quote_number end) as "DNQCnt",
	B.ProgMonth as "ProgMonth",
	B.QuoteCreatedDate as "QuoteCreatedDate",
	B.SelectedCoverage as "SelectedCoverage",
	B.BusinessState as "BusinessState"
FROM
	CL_SBI.Published.QuoteCarrierRqstResponseDetail A
		LEFT JOIN CL_SBI.Published.BQX_QuoteMasterDetail B ON A.Quote_Number = B.QuoteNumber
WHERE 
	B.IsQuoteTest='N'
    	AND A.Last_Updated_Time_stamp = (SELECT MAX(A2.Last_Updated_Time_stamp) 
                                     	 FROM CL_SBI.PUBLISHED.QUOTECARRIERRQSTRESPONSEDETAIL A2                                                 
                                     	 WHERE A.Quote_Number = A2.Quote_Number)
GROUP BY
	A.Carrier_Name,
	A.Quote_Number,
	B.BECAIntent,
	B.BusinessState,
	B.ProgMonth,
	B.QuoteCreatedDate,
	B.SelectedCoverage,
	B.BusinessState
ORDER BY
	A.Quote_Number,
	A.Carrier_Name,
	B.BECAIntent);
QUIT;

PROC SQL;
CREATE TABLE PartnerCallsAndDNQ AS
SELECT A.QuoteNumber,
	A.BECAIntent,
	A.CarrierCalled,
	A.CarrierName,
	A.DNQCnt,
	A.ProgMonth,
	D.ACCT_CCYYMMWW,
	A.QuoteCreatedDate,
	A.SelectedCoverage,
	A.BusinessState
FROM PartnerCallsAndDNQSF A
	LEFT JOIN DSE.Date D ON A.QuoteCreatedDate = D.DT_VAL;
QUIT;

PROC DELETE data = CLAcq.PartnerCallsAndDNQ; RUN;

DATA CLAcq.PartnerCallsAndDNQ;
SET PartnerCallsAndDNQ;
RUN;
