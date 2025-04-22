Lifetime Value (LTV) model code is run at 8am daily as a scheduled job in SAS.

The LTV Code for Paid Search Application imports the last 90 days of sales and assigns each an LTV. These values are used in paid search marketing. The data set is written out to BISSCLAcqSBI.dbo.Sale_LTV_T3 in the mss-p1-biss-01 SQL server.

The LTV Code for History Table imports sales since 2024 and assigns each an LTV. These values are used for direct mail. The data set is written out to BISSCLAcqSBI.dbo.Sale_LTV_Since2024 in the mss-p1-biss-01 SQL server.

Manual change to LTV documents/codes are required quarterly (in Feb, May, Aug, & Nov). This includes:
  - A new PLE file for the quarter.
    1. Create a copy of the most recent PLE file (PLE YYYYMM) located here: \\\prog1\east\wrkgrp\nfs\sas_prod\CNTL\SBI\Projects\LTV\
    2. Rename it with the current month's name.
    3. Open this month's SBI Retention file located here: \\\prog1\east\wrkgrp\SHARED\Retention\SBI Retention\
    4. In the new PLE file, substitute in the values from the SBI Retention report for each segment's PLE.
  - In LTV Code for Paid Search Application:
    1. Rename the PLE file being imported in the 3 PROC IMPORTs to the newest version of the file.
  - In LTV Code for History Table:
    1. Uncomment the 3 relevant PROC IMPORTs for the quarter.
    2. Uncomment the newest PLE file join in the PROC SQL statement creating the table called RecentSales2.

Manual changes are also required annually (~Jan) when CL Control has a new value for:
  - BIT rep rate per minute. Chandan Pathak/Dan Brahler/Joe Geng have provided this in past years.
    1. In LTV Code for Paid Search Application, the new rate can overwrite the previous rate.
    2. In LTV Code for History Table, the new rate should be added and code uncommented in the query making QuoteInfoAdded2.
  - Bundle & Extend. Chandan Pathak/Dan Brahler/Joe Geng have provided this in past years.
    1. In LTV Code for Paid Search Application, the new value can overwrite the previous value.
    2. In LTV Code for History Table, the new value should be added and code uncommented in the query making QuoteInfoAdded2.
