/********************************/
/*** Today's Book of Business ***/
/********************************/
/* Current date & time */
%let StartTime = %sysfunc(datetime(), datetime20.);

/* PIFs - replaced Holistic Funnel BISS source with SF source - IW 20250414*/
PROC SQL;
%sf_ref_acs_tok(warehouse=FREE_THE_DATA_XS);
CREATE TABLE PIFs AS SELECT * FROM CONNECTION TO ODBC
(SELECT P.*
FROM CL_SBI.PUBLISHED.BIT_HOLISTICFUNNEL_VW P
WHERE P.IsInForce = 1);
QUIT;

/* Contact info */
PROC SQL;
CONNECT TO &SQLEng (dsn=EPICCloud authdomain=BDE &bulkparms);
CREATE TABLE BDE_Contact_Info AS SELECT * FROM CONNECTION TO &SQLEng
(SELECT CLNT.UniqEntity,
	CLNT.NameOf as Customer_Name,
	CN.FirstName,
	CN.LastName,
	CNUM.Number,
	case when CNUM.CallPermission = 'Y' then 'Permission Obtained'
		when CNUM.CallPermission = 'D' then 'Did Not Obtain'
		when CNUM.CallPermission = 'N' then 'Do Not Call'
		else '' end as CallPermission,
	CEM.EmailWeb as Email,
	CA.Address1,
	CA.City,
	CA.CdStateCode as State,
	CA.PostalCode
FROM dbo.Client CLNT
	LEFT JOIN dbo.ContactName CN on CLNT.UniqContactNamePrimary = CN.UniqContactName
	LEFT JOIN dbo.ContactNumber CNUM on CN.UniqContactNumberMain = CNUM.UniqContactNumber
	LEFT JOIN dbo.ContactNumber CEM on CN.UniqContactNumberEmailMain = CEM.UniqContactNumber
	LEFT JOIN dbo.ContactAddress CA on CN.UniqContactAddressMain = CA.UniqContactAddress
WHERE CEM.EmailWeb <> '' and CEM.EmailWeb not like '%www%' and CEM.EmailWeb not like '%http%' and CEM.EmailWeb <> 'FALSE'
	AND CEM.EmailWeb IS NOT NULL AND CEM.EmailWeb LIKE '%@%.%' AND CEM.EmailWeb NOT LIKE '%..%'
	AND CEM.EmailWeb NOT LIKE '%.@%' AND CEM.EmailWeb NOT LIKE '%@.%' AND CEM.EmailWeb NOT LIKE '%.cm'
	AND CEM.EmailWeb NOT LIKE '%.co' AND CEM.EmailWeb NOT LIKE '%.or' AND CEM.EmailWeb NOT LIKE '%.ne'
	AND CEM.EmailWeb NOT LIKE '%''%' AND CEM.EmailWeb NOT LIKE '-%' AND CEM.EmailWeb NOT LIKE '.%'
	AND CEM.EmailWeb NOT LIKE '%-' AND CEM.EmailWeb NOT LIKE '%@%@%');
QUIT;

/* Joining on the contact info */
PROC SQL;
CREATE TABLE PIFsAndBDE AS
SELECT P.*,
	BDE.Customer_Name,
	BDE.FirstName,
	BDE.LastName,
	BDE.Number,
	BDE.CallPermission,
	BDE.Email,
	BDE.Address1,
	BDE.City,
	BDE.State,
	BDE.PostalCode
FROM PIFs (drop=Prefix FirstName MiddleName Suffix LastName) P
	LEFT JOIN BDE_Contact_Info BDE ON P.UniqEntity = BDE.UniqEntity;
QUIT;

/* Code from Josh King to see if email address is in system for Do Not Contact */
PROC SORT data=PIFsAndBDE (keep=Email) out=EMAIL nodupkey; by Email; RUN;

PROC SQL;
%sf_ref_acs_tok(warehouse=FREE_THE_DATA_S, sf_create_tmp=Email);
CREATE TABLE PreferencesScrub AS SELECT Email FORMAT $80. INFORMAT $80. LENGTH 80 /*to not send*/ FROM CONNECTION TO ODBC
(SELECT DISTINCT t.Email
FROM CUSTOMERHUB_PROFILES.TARGET.vw_DimEmailAddress AS DEA
	INNER JOIN &sf_read_tmp1 t ON DEA.EmailAddress=t.Email
	INNER JOIN CUSTOMERHUB_PROFILES.TARGET.vw_FactCustomerInsuranceAgreementContactPoint AS FCIACPt
		ON dea.DimEmailAddressID = fciacpt.DimAddressID
		AND fciacpt.CurrentHistoryRowInd = 1
		AND fciacpt.AddressTypeCode = 'EMAIL'
	LEFT JOIN CUSTOMERHUB_PROFILES.TARGET.vw_FactCustomerInsuranceAgreementContactPref AS FCIACPR
		ON fciacpt.CustomerInsuranceAgreementContactPointId = FCIACPR.CustomerInsuranceAgreementContactPointId
		AND FCIACPR.CurrentHistoryRowInd = 1 /*CURRENT PREF*/
		AND FCIACPR.ActiveRowInd=1 /*PIF*/
		AND FCIACPR.RoleCode in ('PNI', 'SPOUSE','OWNER')
		AND FCIACPR.PrefName IN ('NEWF') 	
		AND FCIACPR.DimPrefStatusID = 3  /* not enrolled	*/
	LEFT JOIN CUSTOMERHUB_PROFILES.TARGET.vw_FactCustomerInsuranceAgreementContactPref AS FCIACPR2
		ON  FCIACPR.CustomerInsuranceAgreementContactPointId = FCIACPR2.CustomerInsuranceAgreementContactPointId
		AND FCIACPR2.CurrentHistoryRowInd = 1
		AND FCIACPR2.ActiveRowInd = 1
		AND FCIACPR2.RoleCode in ('PNI', 'SPOUSE','OWNER')
		AND FCIACPR2.PrefName IN ('UNSB') /*unsubscribe*/
		AND FCIACPR2.DimPrefStatusID = 2  /* enrolled	*/ 
WHERE FCIACPR.CustomerInsuranceAgreementContactPointId IS NOT NULL 
	OR FCIACPR2.CustomerInsuranceAgreementContactPointId IS NOT NULL
GROUP BY t.Email
HAVING MAX(CASE WHEN FCIACPR2.CustomerInsuranceAgreementContactPointId IS NOT NULL THEN 1 ELSE 0 END)=1 
	OR MAX(CASE WHEN FCIACPR.CustomerInsuranceAgreementContactPointId IS NOT NULL THEN 1 ELSE 0 END)=1
ORDER BY 1);
DISCONNECT FROM ODBC;
QUIT;

/* Indicate customers we can contact or not */
PROC SQL;
CREATE TABLE PIFsAndBDE2 AS
SELECT DISTINCT A.*,
	case when strip(lower(B.Email)) is null then 'N'
		else 'Y' end as OnDoNotContact
FROM PIFsAndBDE A
	LEFT JOIN PreferencesScrub B on strip(lower(A.Email)) = strip(lower(B.Email));
QUIT;

/* Customer matching with SBI and CA */
proc sql;
connect to odbc (%db2conn(db2p));
create table Auto_Data as select * from connection to odbc
(select distinct
    p.POL_ID_CHAR,
    pd.POL_STRT_DT,
    pd.POL_STOP_DT,
    p.FRST_INSD_FRST_NAM,
    p.FRST_INSD_LAST_NAM,
    p.SCND_INSD_FRST_NAM,
    p.SCND_INSD_LAST_NAM,
	case when upper(cqw.email_adrs) <> 'NONE' or cqw.email_adrs <>'' then cqw.email_adrs
		when p.ESIGN_EMAIL_ADRS <>'' then p.ESIGN_EMAIL_ADRS 
		else '' end
		as Email_address,
	p.ESIGN_EMAIL_ADRS ,
	CQW.EMAIL_ADRS,
    p.DBA_NAM,
    p.DBA_NAM_LINE2,
    p.DBA_IND,
    p.INSD_NAM,
    p.INSD_ORG_TYP,
    p.INSD_PHN_NBR,
    p.PRIM_DLVR_ADR_TXT,
    p.ADRS_CITY_NAM,
    p.ADRS_ST_CD,
    p.EXTND_ZIP_CD,
    bt.BMT,
	R.DSTRBT_CHNL
from CAW.POLICY p 
	inner join CAW.POL_DATES pd
		on pd.POL_ID_CHAR = p.POL_ID_CHAR
    	and pd.RENW_SFX_NBR = p.RENW_SFX_NBR
    	and pd.POL_EXPR_YR = p.POL_EXPR_YR
	left join CAW.BUSTYP bt
		on p.SIC_CD = bt.CV_INDSTR_CLSS_CD
	left join
		(SELECT A.CV_QT_KEY,
			A.EMAIL_ADRS,
			A.TRAN_TM
		 FROM CQW.QT_PUB_VIEW A
			INNER JOIN
				(SELECT CQW.CV_QT_KEY,
					max(CQW.TRAN_TM) as TRAN_TM
				 FROM CQW.QT_PUB_VIEW CQW
				 GROUP BY CQW.CV_QT_KEY) B
			   ON A.CV_QT_KEY = B.CV_QT_KEY
			   AND A.TRAN_TM = B.TRAN_TM) CQW
		on p.cv_qt_key = cqw.cv_qt_key
	left join CAW.RT_MAN_MDL R
		on R.RT_MAN_CD= P.RT_MAN_CD
where pd.pol_in_frc='Y');
quit;

/*standardize fields for customer matching */
data SBI_base;
set PIFsAndBDE2;
format customer_phone $30. customer_email $80. customer_first_name customer_last_name $40. customer_state $2. customer_zip $5.;
uniq_id_b=_n_; /* Set this to _m for 'match' and _b for 'base' */
customer_phone=Number;
customer_email=Email;
customer_first_name=FirstName;
customer_last_name=LastName;
customer_state=State;
customer_zip=PostalCode;
run;

data auto_match;
set Auto_Data;
format customer_phone $30. customer_email $80. customer_first_name customer_last_name $40. customer_state $2. customer_zip $5.;
uniq_id_m=_n_; /* Set this to _m for 'match' and _b for 'base' */
customer_phone=INSD_PHN_NBR;
customer_email=Email_address;
customer_first_name=FRST_INSD_FRST_NAM;
customer_last_name=FRST_INSD_LAST_NAM;
customer_state=ADRS_ST_CD;
customer_zip=EXTND_ZIP_CD;
run;


/* Match CA and BI */
/* 	BaseDataSet = your base data set in which you're trying to match (remove) records from the MatchDataSet
	BaseList = a suffix for your created tables to identify which tables are apart of the base group
	MatchDataSet = your (base) table in which you're having records matched to
	MatchList = a suffix for your created tables that are among your Match data sets
*/


/* Update macro table references below */

%macro Matches (BaseDataSet=, BaseList=, MatchDataSet=, MatchList=);

data ph_&Baselist. (keep=uniq_id_b customer_phone)
	em_&Baselist. (keep=uniq_id_b customer_email)
	n_a_&Baselist. (keep=uniq_id_b Customer_First_Name Customer_Last_Name customer_state customer_zip);
	set &BaseDataSet.;

	if customer_phone ne '' and customer_phone ne '0000000000' and customer_phone ne '1111111111'  and customer_phone ne '9999999999' then
		output ph_&Baselist.;

	if customer_email ne '' then
		output em_&Baselist.;

	if Customer_First_Name ne '' then
		output n_a_&Baselist.;
run;

data ph_&MatchList. (keep=uniq_id_m customer_phone DSTRBT_CHNL POL_ID_CHAR)
	em_&MatchList. (keep=uniq_id_m customer_email DSTRBT_CHNL POL_ID_CHAR)
	n_a_&MatchList. (keep=uniq_id_m Customer_First_Name Customer_Last_Name customer_state customer_zip DSTRBT_CHNL POL_ID_CHAR);
	set &MatchDataSet.;

	if customer_phone ne '' and customer_phone ne '0000000000' and customer_phone ne '1111111111'  and customer_phone ne '9999999999' then
		output ph_&MatchList.;

	if customer_email ne '' then
		output em_&MatchList.;

	if Customer_First_Name ne '' then
		output n_a_&MatchList.;
run;

%mend Matches;
%Matches (BaseDataSet=SBI_base, BaseList=SBI, MatchDataSet=auto_match, MatchList=Auto);
quit;



%macro Matches_2 (BaseDataSet=, BaseList=, MatchDataSet=, MatchList=);
/********************************************************************************************************
						Start Phone Number matching
********************************************************************************************************/
data ph_&BaseList._2;
	set ph_&BaseList.;
	Length PhoneNumber $100.;
	PhoneNumber=compress(customer_phone, ,"AP");
	drop customer_phone;
run;

data ph_&MatchList._2;
	set ph_&MatchList.;
	Length PhoneNumber $100.;
	PhoneNumber=compress(customer_phone, ,"AP");
	drop customer_phone;
run;

proc sort data=ph_&BaseList._2;
	by phonenumber;
run;

proc sort data=ph_&MatchList._2;
	by phonenumber;
run;

data ph_matched_&BaseList. ph_not_matched_&BaseList. ph_not_matched_&MatchList.;
	merge 	ph_&BaseList._2 (in=inA)
		ph_&MatchList._2 (in=inB);
	by phonenumber;

	if inA and inB then
		output ph_matched_&BaseList. ;
	else if inA then
		output ph_not_matched_&BaseList.;
	else if inB then
		output ph_not_matched_&MatchList.;
run;

proc sort data= ph_matched_&BaseList. out=ph_matched_&BaseList._1 (keep=uniq_id_b phonenumber DSTRBT_CHNL POL_ID_CHAR) nodupkey;
	by uniq_id_b;
run;


%mend Matches_2;
%Matches_2 (BaseDataSet=SBI_base, BaseList=SBI, MatchDataSet=auto_match, MatchList=Auto);
quit;

/********************************************************************************************************
							Start Email matching
********************************************************************************************************/


%Macro Matches_3 (BaseDataSet=, BaseList=, MatchDataSet=, MatchList=);

proc sql;
	/*Anti joining all matched customers from Phone to emails */
	create table em_&Baselist._2 as
		select distinct a.*
			from em_&Baselist. a
				left join ph_matched_&BaseList._1 b on a.uniq_id_b=b.uniq_id_b
					where b.uniq_id_b is null
	;
quit;

/*Deleting previous datasets since I max out # of tables created by end*/
proc datasets library=work nolist; 
delete ph_&BaseList. ph_&MatchList. ph_&BaseList._2 ph_&MatchList._2
		ph_matched_&BaseList. ph_not_matched_&BaseList. ph_not_matched_&MatchList.;
quit;

data em_&Baselist._3;
	set em_&Baselist._2;
	Length Email $100.;
	Email = compress(customer_email, , "PS");
	drop customer_email;
run;

data em_&MatchList._2;
	set em_&MatchList.;
	Length Email $100.;
	Email = compress(customer_email, , "PS");
	drop customer_email;
run;

proc sort data=em_&Baselist._3;
	by Email;
run;

proc sort data=em_&MatchList._2;
	by Email;
run;

data em_matched_&BaseList. em_not_matched_&BaseList. em_not_matched_&MatchList.;
	merge 	em_&Baselist._3 (in=inA)
		em_&MatchList._2 (in=inB);
	by email;

	if inA and inB then
		output em_matched_&BaseList. ;
	else if inA then
		output  em_not_matched_&BaseList.;
	else if inB then
		output em_not_matched_&MatchList.;
run;

proc sort data= em_matched_&BaseList.  out=em_matched_&BaseList._1  (keep=uniq_id_b Email DSTRBT_CHNL POL_ID_CHAR) nodupkey;
	by uniq_id_b;
run;

%mend Matches_3;
%Matches_3 (BaseDataSet=SBI_base, BaseList=SBI, MatchDataSet=auto_match, MatchList=Auto);
quit;


/********************************************************************************************************
			Start Name/Address matching
********************************************************************************************************/

%Macro Matches_4 (BaseDataSet=, BaseList=, MatchDataSet=, MatchList=);
proc sql;
	/*Anti joining all matched customers from phone, and emails, to name/address set */
	create table n_a_&BaseList._2 as
		select a.*
			from  n_a_&BaseList. a
				left join ph_matched_&BaseList._1  b on a.uniq_id_b=b.uniq_id_b
				left join em_matched_&BaseList._1  c on a.uniq_id_b=c.uniq_id_b
					where b.uniq_id_b is null
						and c.uniq_id_b is null
	;
quit;

/*Deleting previous datasets since I max out # of tables created by end*/
proc datasets library=work nolist; 
delete em_&BaseList. em_&MatchList. em_&BaseList._2 em_&BaseList._3 em_&MatchList._2
		em_matched_&BaseList. em_not_matched_&BaseList. em_not_matched_&MatchList.;
quit;

data n_a_&BaseList._3;
	set n_a_&BaseList._2;
	length fn1 $4. ln1 $4. PostCode $5.;
	FN1=lowcase(substr(customer_first_name,1,4));
	LN1=lowcase(substr(customer_last_name,1,4));
	PostCode=compress(customer_zip);
run;

data n_a_&MatchList._2;
	set n_a_&MatchList.;
	length fn1 $4. ln1 $4. PostCode $5.;
	FN1=lowcase(substr(customer_first_name,1,4));
	LN1=lowcase(substr(customer_last_name,1,4));
	PostCode=compress(customer_zip);
run;

proc sql;
	create table n_a_matched_&BaseList. as
		select distinct
			b.uniq_id_b,
			b.fn1,
			b.ln1,
			b.PostCode,
			c.DSTRBT_CHNL,
			c.POL_ID_CHAR
		from n_a_&BaseList._3 b,
			n_a_&MatchList._2 c
		where
			(b.fn1 = c.fn1 and b.ln1=c.ln1 )
			and (b.PostCode = c.PostCode)
	;
quit;

proc sort data= n_a_matched_&BaseList. out=n_a_matched_&BaseList._1 (keep=uniq_id_b DSTRBT_CHNL POL_ID_CHAR) nodupkey;
	by uniq_id_b;
run;

/* Combine all 3 matches */
proc sql;
	create table Matched_&BaseList. as
		select distinct p.uniq_id_b, 'P' as Match_Source, p.DSTRBT_CHNL, p.POL_ID_CHAR from ph_matched_&BaseList._1 p
			union
		select distinct e.uniq_id_b, 'E' as Match_Source, e.DSTRBT_CHNL, e.POL_ID_CHAR from em_matched_&BaseList._1 e
			union
		select distinct a.uniq_id_b, 'A' as Match_Source, a.DSTRBT_CHNL, a.POL_ID_CHAR from n_a_matched_&BaseList._1 a
	;
quit;

/* actually join back to base set and create indicator for matches */
proc sql;
	create table &BaseDataSet._1 as
		select b.*,
		case when c.uniq_id_b is not null then 1 else 0 end as Match_Ind,
		c.dstrbt_chnl,
		c.POL_ID_CHAR
			from &BaseDataSet. b
				left join Matched_&BaseList. c on b.uniq_id_b=c.uniq_id_b
	;
quit;
%mend Matches_4;
%Matches_4 (BaseDataSet=SBI_base, BaseList=SBI, MatchDataSet=auto_match, MatchList=Auto);
quit;


/*****************************Personal Lines Matching*******************************/
PROC SQL;
%sf_ref_acs_tok(warehouse=FREE_THE_DATA_L);
CREATE TABLE PLCustomers AS SELECT * FROM CONNECTION TO ODBC
(SELECT DISTINCT P.POL_ID_NBR,
	MIAD.FRST_NAM,
	MIAD.LST_NAM,
	MIAD.PRIM_DLVR_ADR_TXT,
	MIAD.CITY_NAM,
	MIAD.ADDR_ST_CD,
	MIAD.PSTL_CD,
	DEA.EmailAddress,
	MIAD.HM_PHN_AREA_CD,
	MIAD.HM_PHN_NBR,
	MIAD.WRK_PHN_AREA_CD,
	MIAD.WRK_PHN_NBR,
	MIAD.ALT_PHN_NBR as OtherPhone
FROM MDW_COPY.Target.POLICY_GRG P
	LEFT JOIN MDW_COPY.Target.INS_NAME_ADDR MIAD
		ON P.ST_CD = MIAD.ST_CD
		AND P.RPT_BSNS_CD = MIAD.RPT_BSNS_CD
		AND P.POL_ID_CHAR = MIAD.POL_ID_CHAR
		AND P.RENW_SFX_NBR = MIAD.RENW_SFX_NBR
		AND P.POL_EXPR_YR = MIAD.POL_EXPR_YR
	LEFT JOIN CUSTOMERHUB_PROFILES.Target.VW_DimInsuranceAgreementTermPlus C
		ON C.StateNumber = P.ST_CD
		AND C.PolicyNbr = P.POL_ID_CHAR
		AND C.PolicyTermRenewalCnt = P.RENW_CNT
		AND C.PolicyTermExpirationYearNbr = P.POL_EXPR_YR
	LEFT JOIN CUSTOMERHUB_PROFILES.Target.VW_FactCustomerInsuranceAgreementContactPoint FCIACPT
		ON C.DimInsuranceAgreementId = FCIACPT.DimInsuranceAgreementID
	LEFT JOIN CUSTOMERHUB_PROFILES.Target.VW_DIMEMAILADDRESS DEA
		ON FCIACPT.dimaddressid = DEA.DIMEMAILADDRESSID
WHERE P.POL_EFF_DT <= current_date()
	AND P.POL_EXPR_DT >= current_date()
	AND P.POL_EFF_DT <> P.POL_EXPR_DT
	AND C.ProductCode = 'AA' /*"Aligned Auto"*/
	AND C.InsAgreeTermBaseFlg = 'N'
	AND FCIACPT.AddressTypeCode = 'EMAIL'
	AND FCIACPT.CurrentHistoryRowInd = 1
	AND FCIACPT.ActiveRowInd = 1);
DISCONNECT FROM ODBC;
QUIT;

/*There are 3 phone number fields so prioritizing work phone, then home phone, then other phone (SNI).*/
DATA PLContactInfo;
SET PLCustomers;
HomePhone = input(cat(HM_PHN_AREA_CD,HM_PHN_NBR),10.);
WorkPhone = input(cat(WRK_PHN_AREA_CD,WRK_PHN_NBR),10.);
if WorkPhone in (0,.) then do;
	if HomePhone in (0,.) then PhoneNbr = OtherPhone;
	else PhoneNbr = HomePhone;
	end;
else PhoneNbr = WorkPhone;
RUN;

data PL_match; /*auto_match*/
set PLContactInfo;
format customer_phone $30. customer_email $80. customer_first_name customer_last_name $40. customer_state $2. customer_zip $5.;
uniq_id_m=_n_; /* Set this to _m for 'match' and _b for 'base' */
customer_phone=strip(PhoneNbr);
customer_email=lowcase(EMAILADDRESS);
customer_first_name=lowcase(FRST_NAM);
customer_last_name=lowcase(LST_NAM);
customer_state=lowcase(ADDR_ST_CD);
customer_zip=PSTL_CD;
run;

/*standardize fields for customer matching */
data SBI_base;
set SBI_Base_1 (drop=uniq_id_b);
format customer_phone $30. customer_email $80. customer_first_name customer_last_name $40. customer_state $2. customer_zip $5.;
uniq_id_b=_n_; /* Set this to _m for 'match' and _b for 'base' */
customer_phone=Number;
customer_email=lowcase(Email);
customer_first_name=lowcase(FirstName);
customer_last_name=lowcase(LastName);
customer_state=lowcase(State);
customer_zip=PostalCode;
run;

/* Match PL and BI */
/* 	BaseDataSet = your base data set in which you're trying to match (remove) records from the MatchDataSet
	BaseList = a suffix for your created tables to identify which tables are apart of the base group
	MatchDataSet = your (base) table in which you're having records matched to
	MatchList = a suffix for your created tables that are among your Match data sets
*/

/* Update macro table references below */
%macro Matches (BaseDataSet=, BaseList=, MatchDataSet=, MatchList=);

data ph_&Baselist. (keep=uniq_id_b customer_phone)
	em_&Baselist. (keep=uniq_id_b customer_email)
	n_a_&Baselist. (keep=uniq_id_b Customer_First_Name Customer_Last_Name customer_state customer_zip);
	set &BaseDataSet.;

	if customer_phone ne '' and customer_phone ne '0' and customer_phone ne '0000000000' and customer_phone ne '1111111111'  and customer_phone ne '9999999999' then
		output ph_&Baselist.;

	if customer_email ne '' then
		output em_&Baselist.;

	if Customer_First_Name ne '' then
		output n_a_&Baselist.;
run;

data ph_&MatchList. (keep=uniq_id_m customer_phone POL_ID_NBR)
	em_&MatchList. (keep=uniq_id_m customer_email POL_ID_NBR)
	n_a_&MatchList. (keep=uniq_id_m Customer_First_Name Customer_Last_Name customer_state customer_zip POL_ID_NBR);
	set &MatchDataSet.;

	if customer_phone ne '' and customer_phone ne '0000000000' and customer_phone ne '1111111111'  and customer_phone ne '9999999999' then
		output ph_&MatchList.;

	if customer_email ne '' then
		output em_&MatchList.;

	if Customer_First_Name ne '' then
		output n_a_&MatchList.;
run;

%mend Matches;
%Matches (BaseDataSet=SBI_base, BaseList=SBI, MatchDataSet=pl_match, MatchList=Auto);
quit;



%macro Matches_2 (BaseDataSet=, BaseList=, MatchDataSet=, MatchList=);
/********************************************************************************************************
						Start Phone Number matching
********************************************************************************************************/
data ph_&BaseList._2;
	set ph_&BaseList.;
	Length PhoneNumber $100.;
	PhoneNumber=compress(customer_phone, ,"AP");
	drop customer_phone;
run;

data ph_&MatchList._2;
	set ph_&MatchList.;
	Length PhoneNumber $100.;
	PhoneNumber=compress(customer_phone, ,"AP");
	drop customer_phone;
run;

proc sort data=ph_&BaseList._2;
	by phonenumber;
run;

proc sort data=ph_&MatchList._2;
	by phonenumber;
run;

data ph_matched_&BaseList. ph_not_matched_&BaseList. ph_not_matched_&MatchList.;
	merge 	ph_&BaseList._2 (in=inA)
		ph_&MatchList._2 (in=inB);
	by phonenumber;

	if inA and inB then
		output ph_matched_&BaseList. ;
	else if inA then
		output ph_not_matched_&BaseList.;
	else if inB then
		output ph_not_matched_&MatchList.;
run;

proc sort data= ph_matched_&BaseList. out=ph_matched_&BaseList._1 (keep=uniq_id_b phonenumber POL_ID_NBR) nodupkey;
	by uniq_id_b;
run;

%mend Matches_2;
%Matches_2 (BaseDataSet=SBI_base, BaseList=SBI, MatchDataSet=pl_match, MatchList=Auto);
quit;

/********************************************************************************************************
							Start Email matching
********************************************************************************************************/
%Macro Matches_3 (BaseDataSet=, BaseList=, MatchDataSet=, MatchList=);

proc sql;
	/*Anti joining all matched customers from Phone to emails */
	create table em_&Baselist._2 as
		select distinct a.*
			from em_&Baselist. a
				left join ph_matched_&BaseList._1 b on a.uniq_id_b=b.uniq_id_b
					where b.uniq_id_b is null
	;
quit;

/*Deleting previous datasets since I max out # of tables created by end*/
proc datasets library=work nolist; 
delete ph_&BaseList. ph_&MatchList. ph_&BaseList._2 ph_&MatchList._2
		ph_matched_&BaseList. ph_not_matched_&BaseList. ph_not_matched_&MatchList.;
quit;

data em_&Baselist._3;
	set em_&Baselist._2;
	Length Email $100.;
	Email = compress(customer_email, , "PS");
	drop customer_email;
run;

data em_&MatchList._2;
	set em_&MatchList.;
	Length Email $100.;
	Email = compress(customer_email, , "PS");
	drop customer_email;
run;

proc sort data=em_&Baselist._3;
	by Email;
run;

proc sort data=em_&MatchList._2;
	by Email;
run;

data em_matched_&BaseList. em_not_matched_&BaseList. em_not_matched_&MatchList.;
	merge 	em_&Baselist._3 (in=inA)
		em_&MatchList._2 (in=inB);
	by email;

	if inA and inB then
		output em_matched_&BaseList. ;
	else if inA then
		output  em_not_matched_&BaseList.;
	else if inB then
		output em_not_matched_&MatchList.;
run;

proc sort data= em_matched_&BaseList.  out=em_matched_&BaseList._1  (keep=uniq_id_b Email POL_ID_NBR) nodupkey;
	by uniq_id_b;
run;

%mend Matches_3;
%Matches_3 (BaseDataSet=SBI_base, BaseList=SBI, MatchDataSet=pl_match, MatchList=Auto);
quit;


/********************************************************************************************************
			Start Name/Address matching
********************************************************************************************************/
%Macro Matches_4 (BaseDataSet=, BaseList=, MatchDataSet=, MatchList=);
proc sql;
	/*Anti joining all matched customers from phone, and emails, to name/address set */
	create table n_a_&BaseList._2 as
		select a.*
			from  n_a_&BaseList. a
				left join ph_matched_&BaseList._1  b on a.uniq_id_b=b.uniq_id_b
				left join em_matched_&BaseList._1  c on a.uniq_id_b=c.uniq_id_b
					where b.uniq_id_b is null
						and c.uniq_id_b is null
	;
quit;

/*Deleting previous datasets since I max out # of tables created by end*/
proc datasets library=work nolist; 
delete em_&BaseList. em_&MatchList. em_&BaseList._2 em_&BaseList._3 em_&MatchList._2
		em_matched_&BaseList. em_not_matched_&BaseList. em_not_matched_&MatchList.;
quit;

data n_a_&BaseList._3;
	set n_a_&BaseList._2;
	length fn1 $7. ln1 $7. PostCode $5.;
	FN1=lowcase(substr(customer_first_name,1,7));
	LN1=lowcase(substr(customer_last_name,1,7));
	PostCode=compress(customer_zip);
run;

data n_a_&MatchList._2;
	set n_a_&MatchList.;
	length fn1 $7. ln1 $7. PostCode $5.;
	FN1=lowcase(substr(customer_first_name,1,7));
	LN1=lowcase(substr(customer_last_name,1,7));
	PostCode=compress(customer_zip);
run;

proc sql;
	create table n_a_matched_&BaseList. as
		select distinct
			b.uniq_id_b,
			b.fn1,
			b.ln1,
			b.PostCode,
			c.POL_ID_NBR
		from n_a_&BaseList._3 b,
			n_a_&MatchList._2 c
		where
			(b.fn1 = c.fn1 and b.ln1=c.ln1 )
			and (b.PostCode = c.PostCode)
	;
quit;

proc sort data= n_a_matched_&BaseList. out=n_a_matched_&BaseList._1 (keep=uniq_id_b POL_ID_NBR) nodupkey;
	by uniq_id_b;
run;

/* Combine all 3 matches */
proc sql;
	create table Matched_&BaseList. as
		select distinct p.uniq_id_b, p.POL_ID_NBR, 'P' as Match_Source from ph_matched_&BaseList._1 p
			union
		select distinct e.uniq_id_b, e.POL_ID_NBR, 'E' as Match_Source from em_matched_&BaseList._1 e
			union
		select distinct a.uniq_id_b, a.POL_ID_NBR, 'A' as Match_Source from n_a_matched_&BaseList._1 a
	;
quit;

/* actually join back to base set and create indicator for matches */
proc sql;
	create table &BaseDataSet._2 as
		select b.*,
			case when c.uniq_id_b is not null then 1 else 0 end as PL_Match_Ind,
			c.POL_ID_NBR
			from &BaseDataSet. b
				left join Matched_&BaseList. c on b.uniq_id_b=c.uniq_id_b
/*					where c.uniq_id_b is null*/
	;
quit;
%mend Matches_4;
%Matches_4 (BaseDataSet=SBI_base, BaseList=SBI, MatchDataSet=pl_match, MatchList=Auto);
quit;


/* Add bundle indicator */
PROC SQL;
CREATE TABLE Final AS
SELECT case when S.Match_Ind = 1 AND S.DSTRBT_CHNL = 'A' then 'Agency'
		when S.Match_Ind = 1 AND S.DSTRBT_CHNL = 'D' then 'Direct'
		else 'Not Bundled' end as CABundle,
	S.POL_ID_CHAR as CAPolicyChar,
		case when S.PL_Match_Ind = 1 then 'Bundled' else 'Not Bundled' end as PLBundle,
	S.POL_ID_NBR as PLPolicyNbr,
	S.OnDoNotContact, S.Customer_Name, S.FirstName, S.LastName, S.Number, S.CallPermission, S.Email, S.Address1, S.City, S.State,
	S.PostalCode, S.BECAIntent, S.SaleCnt, S.RenewalCnt, S.EffectiveMonth, S.UniqEntity, S.UniqPolicy, S.UniqOriginalPolicy,
	S.PolicyNumber, S.PolicyTerm, S.EffectiveDate, S.ExpirationDate, S.CancelDate, S.CancelReason, S.IsRenewal, S.Channel, S.Broker,
	S.PolicyStatus, S.StateCode, S.ProductCode, S.CarrierCode, S.PartnerCarrier, S.TotalWrittenPremium, S.Binder, S.PolicySoldDate,
	S.CohBeginDate, S.CohEndDate, S.IsInForce, S.RowStartDateTime, S.CreatedDate, S.LastUpdateDate, S.AMSInsertedDate, S.AMSUpdatedDate,
	S.LineIDNumber, S.IsBQX, S.PolicyLastDownLoadedPremium, S.PolicyEstimatedPremium, S.PolicyAnnualizedPremium,
	S.LineLastDownLoadedPremium, S.LineEstimatedPremium, S.LineAnnualizedPremium, S.EPICVersion, S.CarrierName,
	today() format yymmdd10. as DateRan
FROM SBI_Base_2 S;
QUIT;

/* Exporting the table to CLAcq */
libname CLAcq &SQLEng noprompt="DSN=SQLServer; Server=MSS-P1-BISS-01; DATABASE=BISSCLAcqSBI;" schema=dbo &bulkparms read_isolation_level=RU;

PROC DELETE DATA = CLAcq.BookOfBusiness; RUN;
DATA CLAcq.BookOfBusiness; SET Final; RUN;



/*** Grabbing bundle metrics: ***/
/* Policies, customers, bundled customers, SBI customers w/ CA, SBI customers w/ PL, and bundled SBI customers w/ CA */
PROC SQL;
CREATE TABLE PIFs AS
(SELECT count(A.UniqPolicy) as SBIPolicies,
	count(DISTINCT A.UniqEntity) as SBICustomers,
	B.MultiProd as SBIBundledCustomers,
	C.CABundledCustomers as SBIandCACustomers,
	D.PLBundledCustomers as SBIandPLCustomers,
	E.CAandSBIBundle as SBIBundledandCACustomers,
	today() format date9. as DateRan
FROM Final A
	LEFT JOIN (SELECT count(DISTINCT B.UniqEntity) as MultiProd
			   FROM (SELECT B.UniqEntity,
						count(B.UniqPolicy) as Cnt
					 FROM Final B
					 GROUP BY B.UniqEntity
					 HAVING count(B.UniqPolicy) > 1) B) B ON 1=1
	LEFT JOIN (SELECT count(DISTINCT UniqEntity) as CABundledCustomers
			   FROM Final
			   WHERE CABundle <> 'Not Bundled') C ON 1=1
	LEFT JOIN (SELECT count(DISTINCT UniqEntity) as PLBundledCustomers
			   FROM Final
			   WHERE PLBundle <> 'Not Bundled') D ON 1=1
	LEFT JOIN (SELECT count(DISTINCT E.UniqEntity) as CAandSBIBundle
			   FROM (SELECT E.UniqEntity,
						count(E.UniqPolicy) as Cnt,
						E.CABundle
					 FROM Final E
					 GROUP BY E.UniqEntity, E.CABundle
					 HAVING count(E.UniqPolicy) > 1) E
			   WHERE E.CABundle <> 'Not Bundled') E ON 1=1
GROUP BY B.MultiProd, C.CABundledCustomers, D.PLBundledCustomers, E.CAandSBIBundle);
QUIT;

/* Appending the table in CLAcq */
PROC APPEND base=CLAcq.DailyPIFs
	data=PIFs;
RUN;


/* Time when Book of Business code & Daily PIFs code finished */
%let FinishTime = %sysfunc(datetime(), datetime20.);
%let FinishTimet = %sysfunc(time(), hhmm.);

/***********************************************/
/*** Email to myself for confirmation of run ***/
/***********************************************/

/* Time it took to run the Book of Business & Daily PIFs code */
%let StartTimedt = %sysfunc(inputn(&StartTime., datetime20.));
%let FinishTimedt = %sysfunc(inputn(&FinishTime., datetime20.));
%let RunTime = %sysfunc(intck(minutes, &StartTimedt, &FinishTimedt));

DATA _null_;
file sendit email
	from="isabelle_e_wagner@progressive.com"
	to="isabelle_e_wagner@progressive.com"
	subject="Daily Book of Business Code Run";
put "The Book of Business & Daily PIFs code finished at &FinishTimet. and took &RunTime. minutes to complete.";
put;
put "The code started at &StartTime. and finished at &FinishTime..";
RUN;