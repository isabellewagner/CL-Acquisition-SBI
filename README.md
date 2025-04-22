These jobs are meant to check for inaccurate/improperly formatted data in our BIT/BQX tables.

All jobs are saved here:
  - \\\prog1\east\wrkgrp\nfs\sas_prod\CNTL\SBI\Adhoc\Health of the Data Check\

Missing Customer Information Check
  - Runs at 9am bi-weekly Tuesdays.
  - Checks for customers missing emails, phone numbers, etc.
  - Data pulled from SQL Server mss-p1-pca-06 SmallBusinessInsurance.
  - Exports an Excel file and conditionally sends an email if this data quality issue is occurring.

Missing Product Code Check
  - Runs at 9am bi-weekly Tuesdays.
  - Checks for a missing product code on a policy.
  - Data pulled from SQL Server mss-p1-pca-06 SmallBusinessInsurance.
  - Exports an Excel file and conditionally sends an email if this data quality issue is occurring.

Missing Cancel Date Check
  - Runs at 9am bi-weekly Tuesdays.
  - Checks for canceled policies (by CAN status) that are missing a cancel date.
  - Data pulled from SQL Server mss-p1-pca-06 SmallBusinessInsurance.
  - Exports an Excel file and conditionally sends an email if this data quality issue is occurring.

Duplicate Policies Check
  - Runs at 9am bi-weekly Tuesdays.
  - Checks for policies with the same policy number & effective date.
  - Data pulled from SQL Server mss-p1-pca-06 SmallBusinessInsurance.
  - Exports an Excel file and conditionally sends an email if this data quality issue is occurring.

AMS Updated 1900 Policies Check
  - Runs at 9am bi-weekly Tuesdays.
  - Checks for policies with an AMSLastUpdatedDate of 1900-01-01.
  - Data pulled from SQL Server mss-p1-pca-06 SmallBusinessInsurance.
  - Exports an Excel file and conditionally sends an email if this data quality issue is occurring.

Sales Per Week Outlier Check
  - Runs at 4am weekly Wednesdays.
  - Checks for an outlier number of sales by carrier for the previous week.
  - Data pulled from SQL Server mss-p1-pca-06 SmallBusinessInsurance.
  - Exports an Excel file and conditionally sends an email if this data quality issue is occurring.

Outlier Policy Premium Check
  - Runs at 4am weekly Wednesdays.
  - Checks for policy premiums that are outliers compared to other policies written by that carrier.
  - Data pulled from:
      - SQL Server mss-p1-pca-06 SmallBusinessInsurance
      - Snowflake CL_SBI.Published BQX tables
  - Exports an Excel file and conditionally sends an email if this data quality issue is occurring.

Blank BECAs in QMD Check
  - Runs at 8am weekly Wednesdays.
  - Checks for a higher proportion of quotes having blank BECAIntents as compared to historic data.
  - Data pulled from Snowflake CL_SBI.Published BQX tables
  - Exports an Excel file and conditionally sends an email if this data quality issue is occurring.
