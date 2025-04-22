Link to the report: https://tableauserver/#/site/CommercialLines/views/ESProductionFunnel_V4/TotalESProduction?:iid=1

The code is saved here:
  \\\prog1\east\wrkgrp\nfs\sas_prod\CNTL\SBI\RTB\ES Report\

It is scheduled to run daily at 9am.

The data sources for this job includes:
  - BQX tables in Snowflake (CL_SBI.PUBLISHED).
  - BDE tables in SQL (mss-p1-bde-01,57842).
  - BIT tables in SQL SmallBusinessInsurance (mss-p1-pca-06).
  - DSE tables.
  - CLAcq table in SQL (BISSCLAcqSBI.dbo.EvanstonRolloutPhases).
  
The job exports tables to the BISSCLAcqSBI SQL Server.
