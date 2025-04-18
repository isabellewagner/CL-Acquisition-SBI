/***Health of SBI data***/
/***Follow up/addition to first check. Added a check of all policy premiums (grouped by product) in addition to the check of
	Evanston premiums. Using > 3 st dev above average for all.
	Also, if premium is within 20% above or below the quoted/previous premium, the record is removed.
	Started grabbing policies with a $0 written premium, added 1/14/25.***/
/***Run this weekly to monitor data validity***/

/*Today's date*/
DATA Today; dt_val = put(today(),date9.); RUN;
PROC SQL; SELECT dt_val INTO: dt_val FROM Today; QUIT;

/*Policies effective in the last 3 years, EXCLUDING Evanston*/
PROC SQL;
CONNECT TO &SQLEng(noprompt="DSN=SQLServer; Server=MSS-P1-PCA-06; database=SmallBusinessInsurance;" &bulkparms read_isolation_level=RU);
CREATE TABLE Policies AS SELECT * FROM CONNECTION TO &SQLEng
(SELECT E.*,
	C.PartnerCarrierName as PartnerCarrier,
	case when E.ProductCode like 'Website%' then 'GL' /*replacing Website w/ GL*/
		else E.ProductCode end as ProductCode2
FROM BIT.EpicPolicy E
	LEFT JOIN BIT.Carrier_Partner C ON E.CarrierCode = C.LookUpCode
WHERE E.CarrierName <> 'Evanston'
	AND E.EffectiveDate >= dateadd(year,-3,getdate())
	AND E.PolicyStatus not in ('DUP','DUQ','ERR'));
QUIT;

/*BQX quotes from Snowflake table*/
PROC SQL;
%sf_ref_acs_tok (warehouse=FREE_THE_DATA_L);
CREATE TABLE QuoteMasterDetail AS SELECT * FROM CONNECTION TO ODBC
(SELECT Q.*
FROM CL_SBI.Published.BQX_QuoteMasterDetail Q
WHERE Q.IsQuoteTest = 'N'
	AND Q.ProgMonth >= '201904');
QUIT;

/*Limit EpicPolicy to the last year of data for more recent premium averages*/
DATA Policies2; SET Policies; if EffectiveDate >= intnx(year,today(),-1); RUN;

PROC SORT data=Policies2;
	by /*PartnerCarrier*/ ProductCode2;
RUN;

/*Mean and standard deviation of the Epic total written premiums, split by product code*/
PROC SUMMARY data=Policies2;
	BY /*PartnerCarrier*/ ProductCode2;
	var TotalWrittenPremium;
	output out=stats (keep=/*PartnerCarrier*/ ProductCode2 mean std) mean=mean std=std;
RUN;

/*Creating 3 std dev limits*/
PROC SQL;
CREATE TABLE stats2 AS
SELECT P.*,
	S.mean,
	S.std,
	S.mean + 3*S.std as upper_limit,
	S.mean - 3*S.std as lower_limit
FROM Policies2 P
	LEFT JOIN stats S
		ON /*P.PartnerCarrier = S.PartnerCarrier
		AND*/ P.ProductCode2 = S.ProductCode2;
QUIT;

/*Flagging policies if the premium is outside of these*/
DATA Policies3;
SET stats2;
if TotalWrittenPremium > upper_limit then WrittenPremiumFlag = 1;
else if TotalWrittenPremium < lower_limit then WrittenPremiumFlag = 1;
else if TotalWrittenPremium = 0 then WrittenPremiumFlag = 1;
else WrittenPremiumFlag = 0;
RUN;

/*Policies with premiums outside of the 3 std deviations, also inserted into/changed in the system in the last 7 days*/
DATA FlaggedPolicies;
SET Policies3;
if WrittenPremiumFlag = 1
	AND (datepart(AMSInsertedDate) >= today()-7
			OR datepart(AMSUpdatedDate) >= today()-7
			OR datepart(EffectiveDate) >= today()-7);
RUN;

/*Joining 1. quoting information to compare the quoted premium vs total written premium if it's first term
		  2. previous term's information to compare the prior premium vs current premium if it's past first term*/
PROC SQL;
CREATE TABLE FlaggedPolicies2 AS
SELECT F.PartnerCarrier as CurrentCarrier,
	case when F.PolicyTerm > 1 then P.PartnerCarrier
		when F.PolicyTerm = 1 AND Q.SelectedCarrierName = '' then Q.RecommendedCarrierName
		else Q.SelectedCarrierName end as PreviousCarrier,
	F.PolicyNumber,
	F.PolicyStatus,
	datepart(F.EffectiveDate) as EffectiveDate format=date9.,
	datepart(F.ExpirationDate) as ExpirationDate format=date9.,
	F.TotalWrittenPremium as CurrentPremium format=dollar11.2,
	case when F.PolicyTerm > 1 then P.TotalWrittenPremium
		when F.PolicyTerm = 1 AND Q.SelectedCarrierPremium = 0 then Q.RecommendedCarrierPremium
		else Q.SelectedCarrierPremium end as PreviousPremium format=dollar11.2,
	F.ProductCode as CurrentProduct,
	case when F.PolicyTerm > 1 then P.ProductCode2
		when F.PolicyTerm = 1 AND Q.SelectedCoverage = 'CGL' then 'GL'
		when F.PolicyTerm = 1 AND Q.SelectedCoverage = 'WC' then 'WCOM'
		else Q.SelectedCoverage end as PreviousProduct,
	datepart(F.CancelDate) as CancelDate format=date9.,
	F.IsRenewal, F.CancelReason, F.IsInForce, F.AMSInsertedDate, F.AMSUpdatedDate, Q.QuoteNumber as QuoteNumber,
	Q.QuoteCreatedDate as QuoteCreatedDate, Q.BECAIntent as BECAIntent, F.UniqEntity, F.UniqPolicy, F.UniqOriginalPolicy,
	F.mean format=dollar11.2, F.std format=dollar11.2, F.upper_limit format=dollar11.2
FROM FlaggedPolicies F
	LEFT JOIN QuoteMasterDetail Q ON F.UniqOriginalPolicy = Q.UniqPolicy
	LEFT JOIN Policies P ON F.UniqOriginalPolicy = P.UniqOriginalPolicy AND F.PolicyTerm = (P.PolicyTerm+1);
QUIT;

/*Remove records if they are within ~20% of their quoted premium or their previous record's premium*/
DATA FlaggedPolicies3;
SET FlaggedPolicies2;
if CurrentPremium > PreviousPremium*1.2 then PremChgFlag = 1;
else if CurrentPremium < PreviousPremium*0.8 then PremChgFlag = 1;
else if PreviousPremium = . or PreviousPremium = 0 then PremChgFlag = 1;
else PremChgFlag = 0;
RUN;

DATA FlaggedPolicies4 (drop=PremChgFlag);
SET FlaggedPolicies3;
if PremChgFlag = 1;
RUN;

PROC SORT data=FlaggedPolicies4; by PolicyStatus CurrentCarrier; RUN;


/*Policies effective in the last year, ONLY Evanston*/
PROC SQL;
CONNECT TO &SQLEng(noprompt="DSN=SQLServer; Server=MSS-P1-PCA-06; database=SmallBusinessInsurance;" &bulkparms read_isolation_level=RU);
CREATE TABLE EvanstonPolicies AS SELECT * FROM CONNECTION TO &SQLEng
(SELECT E.*,
	case when E.ProductCode like 'Website%' then 'GL' /*replacing Website w/ GL*/
		else E.ProductCode end as ProductCode2
FROM BIT.EpicPolicy E
WHERE E.CarrierName = 'Evanston'
	AND E.EffectiveDate >= dateadd(year,-1,getdate())
	AND E.PolicyStatus not in ('DUP','DUQ','ERR'));
QUIT;

/*Mean and standard deviation of the Epic total written premiums*/
PROC SUMMARY data=EvanstonPolicies;
	var TotalWrittenPremium;
	output out=stats (keep=mean std) mean=mean std=std;
RUN;

/*Creating 3 std dev limits, flagging policies if the premium is outside of these*/
DATA EvanstonPolicies2;
	if _n_=1 then do;
		SET stats;
		upper_limit = mean + 3*std;
		lower_limit = mean - 3*std;
		retain upper_limit lower_limit;
	end;
SET EvanstonPolicies;
if TotalWrittenPremium > upper_limit then WrittenPremiumFlag = 1;
else if TotalWrittenPremium < lower_limit then WrittenPremiumFlag = 1;
else if TotalWrittenPremium = 0 then WrittenPremiumFlag = 1;
else WrittenPremiumFlag = 0;
RUN;

/*Policies with premiums outside of the 3 std deviations, also inserted into/changed in the system in the last 7 days*/
DATA EvanstonFlaggedPolicies;
SET EvanstonPolicies2;
if WrittenPremiumFlag = 1
	AND (datepart(AMSInsertedDate) >= today()-7
			OR datepart(AMSUpdatedDate) >= today()-7
			OR datepart(EffectiveDate) >= today()-7);
RUN;

/*Joining quoting information to compare the quoted premium vs total written premium*/
PROC SQL;
CREATE TABLE EvanstonFlaggedPolicies2 AS
SELECT F.CarrierName as CurrentCarrier,
	case when Q.SelectedCarrierName = '' then Q.RecommendedCarrierName else Q.SelectedCarrierName end as QuotedCarrier,
	F.PolicyNumber,
	F.PolicyStatus,
	datepart(F.EffectiveDate) as EffectiveDate format=date9.,
	datepart(F.ExpirationDate) as ExpirationDate format=date9.,
	F.TotalWrittenPremium as CurrentPremium format=dollar11.2,
	case when Q.SelectedCarrierPremium = 0 then Q.RecommendedCarrierPremium else Q.SelectedCarrierPremium end as QuotedPremium format=dollar11.2,
	F.ProductCode as CurrentProduct,
	case when Q.SelectedCoverage = 'CGL' then 'GL'
		when Q.SelectedCoverage = 'WC' then 'WCOM'
		else Q.SelectedCoverage end as QuotedProduct,
	datepart(F.CancelDate) as CancelDate format=date9.,
	F.IsRenewal, F.CancelReason, F.IsInForce, F.AMSInsertedDate, F.AMSUpdatedDate, F.IsBQX, Q.QuoteNumber as QuoteNumber,
	Q.QuoteCreatedDate as QuoteCreatedDate, Q.BECAIntent as BECAIntent, F.UniqEntity, F.UniqPolicy, F.UniqOriginalPolicy,
	F.mean format=dollar11.2, F.std format=dollar11.2, F.upper_limit format=dollar11.2
FROM EvanstonFlaggedPolicies F
	LEFT JOIN QuoteMasterDetail Q ON F.UniqOriginalPolicy = Q.UniqPolicy;
QUIT;

/*Remove records if they are within ~20% of their quoted premium or their previous record's premium*/
DATA EvanstonFlaggedPolicies3;
SET EvanstonFlaggedPolicies2;
if CurrentPremium > QuotedPremium*1.2 then PremChgFlag = 1;
else if CurrentPremium < QuotedPremium*0.8 then PremChgFlag = 1;
else if QuotedPremium = . or QuotedPremium = 0 then PremChgFlag = 1;
else PremChgFlag = 0;
RUN;

DATA EvanstonFlaggedPolicies4 (drop=PremChgFlag);
SET EvanstonFlaggedPolicies3;
if PremChgFlag = 1;
RUN;

PROC SORT data=EvanstonFlaggedPolicies4; by PolicyStatus; RUN;


/*Exporting each data set into the same file and re-formatting the headers & zoom*/
ods excel file="/sso/win_wrkgrp/CNTL/SBI/Adhoc/Health of the Data Check/Output/Outlier_Premiums_&dt_val..xlsx";

ods excel options(sheet_name="Carriers w.o Evanston" autofit_width="yes" zoom="80");

PROC PRINT data=FlaggedPolicies4 noobs style(header)=[just=center font_weight=bold font_size=12pt];
RUN;

ods excel options(sheet_name="Evanston" autofit_width="yes" zoom="80");

PROC PRINT data=EvanstonFlaggedPolicies4 noobs style(header)=[just=center font_weight=bold font_size=12pt];
RUN;

ods excel close;


/*Email Jeannette, Mark, and myself the Excel output*/
DATA _null_;
file sendit email
	from="isabelle_e_wagner@progressive.com"
	to=("isabelle_e_wagner@progressive.com" "jeannette_g_cullen@progressive.com")
	cc=("mark_semple@progressive.com")
	subject="Policies With Outlier Premiums"
	/*importance="High"*/
	attach=("/sso/win_wrkgrp/CNTL/SBI/Adhoc/Health of the Data Check/Output/Outlier_Premiums_&dt_val..xlsx"
			content_type="application/xlsx");
put 'Attached is a list of policies changed in the system in the last 7 days with an outlier premium (by 3 std dev, by product).';
put;
put 'The policies are separated into an all carriers (excluding Evanston) tab and an Evanston tab.';
put 'If there are no outliers in a group, there will be no tab for it.';
/*put '	- All carriers, excluding Evanston.';
put '		~ This tab is further filtered to policies that are written for more than a 20% difference from what it was:';
put '			> Quoted for OR';
put '			> Written for in the previous term';
put ' 	- Evanston only.';
put '		~ This tab is further filtered to policies that are written for more than a 20% difference from what it was quoted for.';*/
put;
put 'Please reach out if you have any questions.';
put 'Thank you,';
put 'Isabelle Wagner';
RUN;
