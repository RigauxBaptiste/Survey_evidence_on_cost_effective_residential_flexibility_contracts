/********************************************************************
 Paper title   : Survey evidence on cost-effective residential flexibility contracts
                 for electric vehicles and heat pumps 
 Paper authors : Baptiste Rigaux (*), Sam Hamels, Marten Ovaere
 Affiliation   : Department of Economics, Ghent University (Belgium)
 Contact       : (*) baptiste.rigaux@ugent.be
 Date          : 2026 Feb 3rd
********************************************************************/

***** Paper available at: https://wps-feb.ugent.be/Papers/wp_25_1130.pdf

***** Replication instructions:

To replicate the paper’s results, download the whole directory, open the script Main.do, 
update the root directory to where the files are stored on your machine, and ensure 
all dependencies listed are installed from SSC. Copy mixlcorr.ado into Stata’s 
ado/plus/m directory before running the programs.

Tables and figures are generated in the Results subfolder. Intermediate files are not used
directly in the paper but serve as steps toward producing the final results and figures.

Estimation .ster files are provided. Main.do explains how these files were obtained, including
the commands and starting values used, as generating them from scratch can take several days.

Some results are also displayed directly in the Stata console for reporting in the text.

***** Data: 

The survey data used in this paper has been anonymized. Only responses from participants
who explicitly provided consent at the start of the survey are included, i.e. said "Yes"
to the following consent form, presented either in English, Dutch or French:

"""
Please read the text carefully and answer the question below.

The survey, conducted by Ghent University (Belgium), aims to investigate to what extent households can change their electricity demand over time. This survey is part of the "FlexSys" project. The questions are about your energy consumption preferences, your comfort levels and also general socio-demographic data. The survey is anonymous : no information that can be linked to your identity is collected. Data processing will remove the Prolific IDs from the final dataset. Anonymous answers will be used for the project and will be kept for at least 5 years after the publication/implementation of the project. Anonymous answers may be shared with other parties involved in the "FlexSys" project and may be shared online and/or with other parties and researchers not involved in the project .

The answers to the survey will be treated according to the EU regulation 2016/679 (GDPR). For more information, please contact: baptiste.rigaux@ugent.be (Baptiste Rigaux, Department of Economics, Faculty of Economics and Business, Ghent University).

"""
