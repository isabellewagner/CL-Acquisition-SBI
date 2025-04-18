/***Health of SBI data***/
/***Second check is customer (client) information missing from BIT.Customer table***/
/***Run this biweekly to monitor data validity***/

/*Today's date*/
DATA Today; dt_val = put(today(),date9.); RUN;
PROC SQL; SELECT dt_val INTO: dt_val FROM Today; QUIT;

/*Customers missing contact information. Filtered to new business only (term 1) and in force.*/
PROC SQL;
CONNECT TO &SQLEng(noprompt="DSN=SQLServer; Server=MSS-P1-PCA-06; database=SmallBusinessInsurance;" &bulkparms read_isolation_level=RU);
CREATE TABLE MissingCustomerInfo AS SELECT * FROM CONNECTION TO &SQLEng
(SELECT DISTINCT
	case when (C.Customer_Name is null OR trim(lower(C.Customer_Name)) in ('','n/a','na','unknown','unk')
			OR C.FirstName is null OR trim(lower(C.FirstName)) in ('','n/a','na','unknown','unk')
			OR C.LastName is null OR trim(lower(C.LastName)) in ('','n/a','na','unknown','unk'))
			AND trim(lower(C.Address)) not in ('','n/a','na','unknown','unk') AND C.Address is not null
			AND trim(lower(C.City)) not in ('','n/a','na','unknown','unk') AND C.City is not null
			AND trim(lower(C.State)) not in ('','n/a','na','zz','unknown','unk') AND C.State is not null
			AND trim(lower(C.Zip_Code)) not in ('','n/a','na','00000','unknown','unk') AND C.Zip_Code is not null
			AND trim(lower(C.PhoneNumber)) not in ('','n/a','na','1111111111','2222222222','3333333333','4444444444','5555555555','6666666666','7777777777','8888888888','9999999999','unknown','unk') AND C.PhoneNumber is not null
			AND trim(lower(C.Email)) not in ('','n/a','na','false','unknown','unk') AND C.Email is not null then 'Customer Name'
		when C.Customer_Name is not null AND trim(lower(C.Customer_Name)) not in ('','n/a','na','unknown','unk')
			AND C.FirstName is not null AND trim(lower(C.FirstName)) not in ('','n/a','na','unknown','unk')
			AND C.LastName is not null AND trim(lower(C.LastName)) not in ('','n/a','na','unknown','unk')
			AND (C.Address is null OR trim(lower(C.Address)) in ('','n/a','na','unknown','unk')
			OR C.City is null OR trim(lower(C.City)) in ('','n/a','na','unknown','unk')
			OR C.State is null OR trim(lower(C.State)) in ('','n/a','na','zz','unknown','unk')
			OR C.Zip_Code is null OR trim(lower(C.Zip_Code)) in ('','n/a','na','00000','unknown','unk'))
			AND trim(lower(C.PhoneNumber)) not in ('','n/a','na','1111111111','2222222222','3333333333','4444444444','5555555555','6666666666','7777777777','8888888888','9999999999','unknown','unk') AND C.PhoneNumber is not null
			AND trim(lower(C.Email)) not in ('','n/a','na','false','unknown','unk') AND C.Email is not null then 'Address'
		when C.Customer_Name is not null AND trim(lower(C.Customer_Name)) not in ('','n/a','na','unknown','unk')
			AND C.FirstName is not null AND trim(lower(C.FirstName)) not in ('','n/a','na','unknown','unk')
			AND C.LastName is not null AND trim(lower(C.LastName)) not in ('','n/a','na','unknown','unk')
			AND trim(lower(C.Address)) not in ('','n/a','na','unknown','unk') AND C.Address is not null
			AND trim(lower(C.City)) not in ('','n/a','na','unknown','unk') AND C.City is not null
			AND trim(lower(C.State)) not in ('','n/a','na','zz','unknown','unk') AND C.State is not null
			AND trim(lower(C.Zip_Code)) not in ('','n/a','na','00000','unknown','unk') AND C.Zip_Code is not null
			AND (trim(lower(C.PhoneNumber)) in ('','n/a','na','1111111111','2222222222','3333333333','4444444444','5555555555','6666666666','7777777777','8888888888','9999999999','unknown','unk') OR C.PhoneNumber is null)
			AND trim(lower(C.Email)) not in ('','n/a','na','false','unknown','unk') AND C.Email is not null then 'Phone Number'
		when C.Customer_Name is not null AND trim(lower(C.Customer_Name)) not in ('','n/a','na','unknown','unk')
			AND C.FirstName is not null AND trim(lower(C.FirstName)) not in ('','n/a','na','unknown','unk')
			AND C.LastName is not null AND trim(lower(C.LastName)) not in ('','n/a','na','unknown','unk')
			AND trim(lower(C.Address)) not in ('','n/a','na','unknown','unk') AND C.Address is not null
			AND trim(lower(C.City)) not in ('','n/a','na','unknown','unk') AND C.City is not null
			AND trim(lower(C.State)) not in ('','n/a','na','zz','unknown','unk') AND C.State is not null
			AND trim(lower(C.Zip_Code)) not in ('','n/a','na','00000','unknown','unk') AND C.Zip_Code is not null
			AND trim(lower(C.PhoneNumber)) not in ('','n/a','na','1111111111','2222222222','3333333333','4444444444','5555555555','6666666666','7777777777','8888888888','9999999999','unknown','unk') AND C.PhoneNumber is not null
			AND (trim(lower(C.Email)) in ('','n/a','na','false','unknown','unk') OR C.Email is null) then 'Email'
	else 'Multiple' end as MissingField,
	C.Lookup_Code,
	C.Customer_Name,
	/*E.PolicyNumber,*/
	C.FirstName,
	C.LastName,
	C.PhoneNumber,
	C.Email,
	C.Address,
	C.Address2,
	C.City,
	C.State,
	C.Zip_Code,
	C.ContactNameType,
	/*E.ProductCode,
	E.PolicyStatus,
	E.CarrierName,
	E.AMSInsertedDate as PolicyAMSInsertedDate,
	E.AMSUpdatedDate as PolicyAMSUpdatedDate,*/
	C.AMSInsertedDate as CustomerAMSInsertedDate,
	/*E.PolicyTerm,*/
	E.UniqEntity
	/*E.UniqPolicy,
	E.UniqOriginalPolicy*/
FROM BIT.EPICPolicy E
	LEFT JOIN BIT.Customer C ON E.UniqEntity = C.Unique_Entity
WHERE E.IsInForce = 1
	AND E.PolicyStatus not in ('DUP','DUQ','ERR')
	AND E.PolicyTerm = 1
	AND E.AMSUpdatedDate >= getdate()-14 AND E.AMSUpdatedDate <= getdate() /*this add/update was done in the last 2 weeks*/
	AND (C.Customer_Name is null OR trim(lower(C.Customer_Name)) in ('','n/a','na','unknown','unk')
		OR C.FirstName is null OR trim(lower(C.FirstName)) in ('','n/a','na','unknown','unk')
		OR C.LastName is null OR trim(lower(C.LastName)) in ('','n/a','na','unknown')
		OR C.PhoneNumber is null OR trim(lower(C.PhoneNumber)) in ('','n/a','na','1111111111','2222222222','3333333333','4444444444','5555555555','6666666666','7777777777','8888888888','9999999999','unknown','unk')
		OR C.Email is null OR trim(lower(C.Email)) in ('','n/a','na','false','unknown','unk')
		OR C.Address is null OR trim(lower(C.Address)) in ('','n/a','na','unknown','unk')
		OR C.City is null OR trim(lower(C.City)) in ('','n/a','na','unknown','unk')
		OR C.State is null OR trim(lower(C.State)) in ('','n/a','na','zz','unknown','unk')
		OR C.Zip_Code is null OR trim(lower(C.Zip_Code)) in ('','n/a','na','00000','unknown','unk'))
ORDER BY MissingField, C.Lookup_Code/*, E.PolicyNumber*/);
QUIT;

/*Name output location*/
libname OUTFILE XLSX "/sso/win_wrkgrp/CNTL/SBI/Adhoc/Health of the Data Check/Output/Missing_Client_Info_&dt_val..xlsx";

/*Write table to there*/
PROC DATASETS library = OUTFILE;
	copy in = WORK out = OUTFILE;
	select MissingCustomerInfo;
RUN;
QUIT;

libname OUTFILE clear;

/*Only sending the email if there are observations w/ missing customer info*/
%macro send_email;

	%let dsid = %sysfunc(open(work.MissingCustomerInfo(where=(UniqEntity > 0))));
	%let nobs = %sysfunc(attrn(&dsid,nlobsf));
	%let rc = %sysfunc(close(&dsid));

	%if &nobs > 0 %then %do;

/*Email Goonlawee and myself the Excel output*/
DATA _null_;
file sendit email
	from="isabelle_e_wagner@progressive.com"
	to=("goonlawee_rywitwattana@progressive.com")
	cc=("isabelle_e_wagner@progressive.com")
	subject="Policies Missing Client Information"
	/*importance="High"*/
	attach=("/sso/win_wrkgrp/CNTL/SBI/Adhoc/Health of the Data Check/Output/Missing_Client_Info_&dt_val..xlsx"
			content_type="application/xlsx");
put 'Attached are customers with a term 1 active policy, updated in the last 2 weeks, that are missing:';
put '	1. Customer name, first name, or last name.';
put '		-This includes names written as "N/A" or "Unknown".';
put '	2. Address, city, state, or zip code.';
put '		-This includes state "ZZ" or zip "00000".';
put '	3. Phone number.';
put'		-This includes repetitive numbers, i.e. "999-999-9999".';
put '	4. Email address.';
put '		-This includes "False".';
put '	5. More than one of the above.';
put;
put 'Please reach out to Isabelle Wagner with any questions. Thank you!';
RUN;

%end;
%mend;
%send_email;