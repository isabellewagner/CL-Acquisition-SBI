This code creates a summarized table of the Partner SBI Holistic Funnel metrics. The output is used in the SBI Funnel and Daily PIF Tableau dashboard.
  Link to the dashboard: https://tableauserver/#/site/CommercialLines/views/PartnerSBIFunnel-HolisticDraft/PartnerSBIHolisticFunnel?:iid=1
  The table is written to BISSCLAcqSBI.dbo.SBI_Funnel_Holistic

The code is saved here:
  \\\prog1\east\wrkgrp\nfs\sas_prod\CNTL\SBI\RTB\Partner SBI Funnel\

It is a scheduled job set to run at 8am every day. The code should only take ~1 min to run.

The data sources for this job include:
  - CL_SBI.PUBLISHED.BIT_HOLISTICFUNNEL_VW
  - DSE.Date
  - In the mss-p1-pca-06 SQL Server, BIT tables in the SmallBusinessInsurance database.
