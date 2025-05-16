THIS JOB WAS RETIRED. This table has been replaced by the CL_SBI.TARGET.BOOKOFBUSINESS table, owned by CLBI.

This job creates a Book of Business table, which includes all Partner SBI policies in force with some added on information like if the customer also has a CA policy or a PL policy and if the customer is on the do not contact list.

The code is saved here: \\\prog1\east\wrkgrp\nfs\sas_prod\CNTL\SBI\SBI Emails Sends\Book of Business\

The job runs at 8am daily.

It creates in the BISSCLAcqSBI server:
  - dbo.BookOfBusiness
  - dbo.DailyPIFs

Data sources for the code include:
  - CL_SBI.PUBLISHED.BIT_HOLISTICFUNNEL_VW
  - BDE tables (SQL Server mss-p1-bde-01,57842)
  - CUSTOMERHUB_PROFILES Snowflake tables
  - CAW
  - CQW
  - MDW_COPY
