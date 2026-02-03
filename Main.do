/********************************************************************
 Paper title   : Survey evidence on cost-effective residential flexibility contracts
                 for electric vehicles and heat pumps 
 Paper authors : Baptiste Rigaux (*), Sam Hamels, Marten Ovaere
 Affiliation   : Department of Economics, Ghent University (Belgium)
 Contact       : (*) baptiste.rigaux@ugent.be
 Date          : 2026 Feb 3rd

 Description : Main:
 This script executes the entire analysis.

 Input :
 - root/Data/Panel_survey+CE_anonymized.dta : a Stata data file with a panel of 
                                              survey and choice experiment 
											  responses. Data was pre-formatted
											  into a panel for choice data
											  analysis, pre-cleaned, and curated
											  for privacy concerns.
 - root/Script_KR_Simulation_procedure.do: script for Section 5.2.3--6.2											  
 - root/Script_Cost_effectiveness_calc.do: script for Section 6.3 
											  
 Outputs are stored in: root/Results/ ... 
 Intermediate files are stored in: root/Intermediate/...
 Console outputs are used in the text of the paper. 

********************************************************************/

*-----------------------------*
* 0. Preamble
*-----------------------------*

version 17
clear all
set more off

// Warning: the script makes use of SSC commands: 
	// ssc mixlogit
	// ssc install heatplot (needed fot the mixlcorr.ado command provided)
	// ssc install dcreate
	// and possibly others (they will appear in the console if not installed)
	
// Additionnally, we developped 'mixlcorr.ado' based on 'mixlcov.ado' (Arne Risa
// Hole, available in SSC with mixlogit). It is provided with the replication 
// files. Please download it and place it in Stata's ado/plus/m directory.

*-----------------------------*
* 1. Paths
*-----------------------------*

* Root (change that with your directory)
global root "C:/..." 

* Relative paths
global dataDir          "$root/Data"
global resultsDir       "$root/Results"
global intermediateDir  "$root/Intermediate"
global estimationDir    "$root/Intermediate/Estimation files"

*-----------------------------*
* 2. Data preparation
*-----------------------------*

capture program drop data_preparation_CE
program define data_preparation_CE

*----------------------------------------------------------*
* 
* Program: data_preparation_CE 
*
* This script prepares the survey panel data for choice model estimation for
* both choice experiments.
*
* The program:
*  - Labels categorical variables according to the
*    Qualtrics survey design
*  - Converts frequency categories into annual equivalents (easier)
*  - Creates dummy variables for attribute levels
*  - Constructs interaction terms with monetary attributes
*  - Defines global macros for alternative model specifications
*
* Input:
*   - Panel_survey+CE_anonymized.dta: a Stata data file with anonymized survey
*									  and choice experiment responses. 
*
* Output:
*   - Dataset "$data/Panel_ready.dta" for analysis. 
*   - Global macros defining model specifications
*
*----------------------------------------------------------*

version 17 

// Load anonymized panel survey and choice experiment data
use "$dataDir/Panel_survey+CE_anonymized.dta", clear

// Label categorical variables according to the Qualtrics survey coding
label define timing_ev_l 0 "PM (11h-17h)" 1 "Evening (17h-23h)" 2 "Night (23h-5h)" 3 "AM (5h-11h)"
label define timing_hp_l 0 "PM (11h-17h)" 1 "Evening (17h-23h)" 2 "Night (23h-5h)" 3 "AM (5h-11h)"
label values timing_ev timing_ev_l
label values timing_hp timing_hp_l

// Convert frequency categories into evenly spread annual interventions
label define freq_ev_l 0 "Once a week" 1 "Once a month" 2 "Once every 2 months" 3 "Once a year" 
label define freq_hp_l 0 "Once a week" 1 "Once a month" 2 "Once every 2 months" 3 "Once a year"
label values freq_ev freq_ev_l
label values freq_hp freq_hp_l

gen freq_ev_cont = 0
label variable freq_ev_cont "Number of evenly spread interventions per year (EV)"
replace freq_ev_cont = 1 if freq_ev == 3
replace freq_ev_cont = 6 if freq_ev == 2
replace freq_ev_cont = 12 if freq_ev == 1
replace freq_ev_cont = 52 if freq_ev == 0

gen freq_hp_cont = 0
label variable freq_hp_cont "Number of evenly spread interventions per year (HP)"
replace freq_hp_cont = 1 if freq_hp == 3
replace freq_hp_cont = 6 if freq_hp == 2
replace freq_hp_cont = 12 if freq_hp == 1
replace freq_hp_cont = 52 if freq_hp == 0

// Dummyfication:

	// Dummy variables for EV comfort impact (driving range)	
	capture drop range_150 range_100 range_50
	gen range_150 = (range_ev == 150)
	gen range_100 = (range_ev == 100)
	gen range_50 = (range_ev == 50)

	// Dummy variables for HP comfort impact (guaranteed indoor temperature)
	capture drop temp_18 temp_17 temp_16
	gen temp_18 = (temp_hp == 18)
	gen temp_17 = (temp_hp == 17)
	gen temp_16 = (temp_hp == 16)	
	
	// Dummy variables for intervention frequency levels
	capture drop freq_ev_6 freq_ev_12 freq_ev_52 
	gen freq_ev_6 = (freq_ev_cont == 6) 
	gen freq_ev_12 = (freq_ev_cont == 12)
	gen freq_ev_52 = (freq_ev_cont == 52)
	
	capture drop freq_hp_6 freq_hp_12 freq_hp_52 
	gen freq_hp_6 = (freq_hp_cont == 6) 
	gen freq_hp_12 = (freq_hp_cont == 12)
	gen freq_hp_52 = (freq_hp_cont == 52)
	
	// Dummy variables for intervention start time
	capture drop timing_ev_Ev timing_ev_Ni timing_ev_AM
	gen timing_ev_Ev = (timing_ev == 1)
	gen timing_ev_Ni = (timing_ev == 2)
	gen timing_ev_AM = (timing_ev == 3)
	
	capture drop timing_hp_Ev timing_hp_Ni timing_hp_AM
	gen timing_hp_Ev = (timing_hp == 1)
	gen timing_hp_Ni = (timing_hp == 2)
	gen timing_hp_AM = (timing_hp == 3)

// Interaction terms between monetary attribute and intervention frequency
capture drop inter_euro_freq_ev 
gen inter_euro_freq_ev = euro_ev * freq_ev_cont
	
capture drop inter_euro_freq_hp 
gen inter_euro_freq_hp = euro_hp * freq_hp_cont

// Alternative-specific constant for the opt-out option
gen asc = (alternative_index == 3)
	
// Define global macros for alternative model specifications
global model1_ev range_ev freq_ev_cont timing_ev_Ev timing_ev_Ni timing_ev_AM asc 
global model2_ev range_150 range_100 range_50 freq_ev_6 freq_ev_12 freq_ev_52 timing_ev_Ev timing_ev_Ni timing_ev_AM asc 
global model3_ev range_150 range_100 range_50 freq_ev_6 freq_ev_12 freq_ev_52 timing_ev_Ev timing_ev_Ni timing_ev_AM asc inter_euro_freq_ev 

global model1_hp temp_hp freq_hp_cont timing_hp_Ev timing_hp_Ni timing_hp_AM  asc 
global model2_hp temp_18 temp_17 temp_16 freq_hp_6 freq_hp_12 freq_hp_52 timing_hp_Ev timing_hp_Ni timing_hp_AM asc 
global model3_hp temp_18 temp_17 temp_16 freq_hp_6 freq_hp_12 freq_hp_52 timing_hp_Ev timing_hp_Ni timing_hp_AM asc inter_euro_freq_hp
	
end

capture program drop filter_online_respondent
program define filter_online_respondent

*----------------------------------------------------------*
* Program: filter_online_respondent
*
* Filters online panel survey respondents based on comprehension
* and attention checks.
*
* The program:
*  - Counts the number of unique online respondents before filtering
*  - Removes respondents failing attention/comprehension checks
*    among online (= non-cooperative) respondents
*  - Reports the number and share of respondents removed
*  - Re-maps response_id from 1..end.
*
* Input:
*   - Dataset in memory containing response-level survey/CE data
*
* Output:
*   - Filtered dataset with updated response_id
*
*----------------------------------------------------------*

// Count respondents before filtering
qui unique response_id 
scalar number_respondents_before =  r(unique)

// Apply comprehension and attention check filters
drop if comprehension_check_1 != 1 & coop_channel == 0
drop if attention_check_1 != 1 & coop_channel == 0
drop if attention_check_2 != 1 & coop_channel == 0
drop if attention_check_3 != 1 & coop_channel == 0

// Count respondents after filtering
qui unique response_id 
scalar number_respondents_after =  r(unique)

// Report filtering statistics
qui scalar number_removed = number_respondents_before - number_respondents_after
di "Number of respondents removed: " number_removed 
di "Corresponding to " 100*(1-(number_respondents_after/number_respondents_before)) " % of respondents removed"

// Re-map response_id to be continuous
egen new_response_id = group(response_id)
drop response_id
order new_response_id, first
rename new_response_id response_id

end

data_preparation_CE
filter_online_respondent
cmset response_id panel_time_var_index alternative_index // Setting choice model data

save "$dataDir/Panel_ready", replace
global data "$dataDir/Panel_ready"
	
*-----------------------------*
* 3. Survey respondents' characteristics
*-----------------------------*
	
capture program drop generate_sumstats
program define generate_sumstats

*----------------------------------------------------------*
* Program: generate_sumstats
*
* This program constructs respondent-level socio-demographic indicators used for
* descriptive statistics and heterogeneity analysis.
*
* The script:
*  - Creates binary indicators for gender, age, education,
*    employment status, housing characteristics, and mobility
*  - Constructs household size and number of children
*  - Removes inconsistent or non-informative observations
*    (e.g. "Rather not say", implausible household sizes)
*
* Input: 
*   - Cleaned panel dataset of survey and CE responses
*
* Output:
*   - Dataset in memory augmented with socio-demographic
*     variables ready for analysis
*
*----------------------------------------------------------*

version 17
use "$data", clear

quietly{
			
		// Gender
		* Indicator for female respondent
		capture drop respondent_female
		gen respondent_female = 0 
		replace respondent_female = 1 if gender == 1
		
		// Age categories
		* Respondents aged 34 or below, and respondents older than 65
		capture drop age_le34
		gen age_le34 = 0
		replace age_le34 = 1 if age == 1 | age == 2 // 18–24 and 25-34
		
		capture drop age_gt65	
		gen age_gt65 = 0
		replace age_gt65 = 1 if age == 6 // >65
		
		// Household size
		* Construct total household size and remove inconsistent responses
		capture drop total_number_hh
		gen total_number_hh = household_number_infants + household_number_kids + household_number_adults + household_number_seniors
		label variable total_number_hh "Total household size (removed 'Rather not say' and nonsensical obs.)"
		replace total_number_hh = . if !missing(not_saying_number_infants) | !missing(not_saying_number_kids) | !missing(not_saying_number_adults) | !missing(not_saying_number_seniors)
			// Additional filters to remove nonsensical observations: 
			replace total_number_hh = . if household_number_adults == 0 & household_number_seniors == 0 
			replace total_number_hh = . if total_number_hh > 10 
		
		* Share of households with kids 
			* Number of kids 
			capture drop kids_number_hh
			gen kids_number_hh = household_number_infants + household_number_kids
			label variable kids_number_hh "Number of kids (< 18 yo) in the household (removed 'Rather not say' and nonsensical obs. for total_number_hh)"
			replace kids_number_hh = . if !missing(not_saying_number_infants) | !missing(not_saying_number_kids) 
				// Additional filters to remove nonsensical observations: 
				replace kids_number_hh = . if total_number_hh == . // Argument: if total_number_hh nonsensical => kids_number_hh nonsensical too. 
			
		// Higher education indicators
		* Binary indicators for respondent and partner
		capture drop higher_education_respondent 
		gen higher_education_respondent = 0
		replace higher_education_respondent = 1 if education > 2 
		replace higher_education_respondent = . if education == 6 //"Rather not say"
		
		capture drop higher_education_partner
		gen higher_education_partner = 0
		replace higher_education_partner = 1 if education_partner > 2
		replace higher_education_partner = . if education == 6 | education_partner == 7 //"Not applicable" or "Rather not say"
		
		// Employment status
		* Employment (part- or full-time) among respondents below retirement age (64 y.o.) and retirement indicator
			capture drop working_age
			gen working_age = 0
			replace working_age = 1 if age < 6 // "> 65" or "Rather not say"
			
			capture drop employed_leq64
			gen employed_leq64 = 0
			replace employed_leq64 = 1 if working_age == 1 & (employment_status == 1 | employment_status == 2) 
					
		* Share retired 
		capture drop is_retired 
		gen is_retired = 0 
		replace is_retired = 1 if employment_status == 6
	
		// Main mobility system
		* Indicator for households reporting using the car as main household transport mode and 
		* owning a fully electric vehicle as their sole car or among all cars they own. 
		    capture drop main_mobility_system_EV 
			gen main_mobility_system_EV = . 
			replace main_mobility_system_EV = is_there_electric_in_here if car_main_transport_mean // Fully electric vehicle reported as one of the main means of transport in the household
	
		// Housing characteristics
		* Dwelling type
		capture drop lives_semi_detached 
		gen lives_semi_detached = 0 
		replace lives_semi_detached = 1 if dwelling_category == 4 
		
		* Share lives in an appartment 
		capture drop lives_apt 
		gen lives_apt = 0 
		replace lives_apt = 1 if dwelling_category == 1 
				
		* Share home built after 2006
		capture drop lives_home_after2006
		gen lives_home_after2006 = 0 
		replace lives_home_after2006 = 1 if dwelling_year == 7
		
		* Share heats with gas 
		capture drop main_heating_system_gas 
		gen main_heating_system_gas = 0 
		replace main_heating_system_gas = 1 if heating_main_system == 5
		
	}
	
* In the text:

	capture drop country
	gen country = "" 
	replace country = "BEL" if coop_channel == 1
	replace country = "BEL" if !missing(Prolific_BE_survey)
	replace country = "FR" if prolific_country == 1 & country != "BEL" // résoudre ce truc de manière plus élégante 
	replace country = "LU" if prolific_country == 2
	replace country = "DE" if prolific_country == 3
	replace country = "NL" if prolific_country == 4
	encode country, gen(state)
	
	save "$data", replace

end

capture program drop generate_latex_sumstat_table
program define generate_latex_sumstat_table

*----------------------------------------------------------*
* Program: Constructs a Latex formatted Table with descriptive statistics
*
* This script:
*  - Removes duplicate respondents: panel --> cross-section (one observation per
*    response_id)
*  - Computes descriptive statistics for respondent,
*    household, dwelling, energy, and mobility characteristics
*  - Stores statistics in locals
*  - Writes a LaTeX table (Table 1 in the paper)
*
* Notes:
*  - Percentages are computed over non-missing or relevant observations
*  - National averages are reported in the paper
*
* Output:
*   - LaTeX file: $resultsDir/Table_Sum_stats.tex
*
*----------------------------------------------------------*

version 17

qui generate_sumstats
duplicates drop response_id, force // Cross-sectional data

	*--------------------------------------------------------*
    * STEP 1: Calculate all statistics and store in locals
    *--------------------------------------------------------*
	
    * Female respondents (%)
    quietly count if !missing(respondent_female)
    local n_female = r(N)
    quietly sum respondent_female if !missing(respondent_female)
    local pct_female = string(r(mean)*100, "%5.1f")
    
    * Age <= 34 (%)
    quietly count if !missing(age_le34)
    local n_age34 = r(N)
    quietly sum age_le34 if !missing(age_le34)
    local pct_age34 = string(r(mean)*100, "%5.1f")
    
    * Age > 65 (%)
    quietly count if !missing(age_gt65)
    local n_age65 = r(N)
    quietly sum age_gt65 if !missing(age_gt65)
    local pct_age65 = string(r(mean)*100, "%5.1f")
    
    * Higher education diploma (%)
    quietly count if !missing(higher_education_respondent)
    local n_edu = r(N)
    quietly sum higher_education_respondent if !missing(higher_education_respondent)
    local pct_edu = string(r(mean)*100, "%5.1f")
    
    * Employed (≤64), full- or part-time (%)
    quietly count if working_age == 1 & !missing(employed_leq64)
    local n_emp = r(N)
    quietly sum employed_leq64 if working_age == 1 & !missing(employed_leq64)
    local pct_emp = string(r(mean)*100, "%5.1f")
    
    * Retired (%)
    quietly count if !missing(is_retired)
    local n_ret = r(N)
    quietly sum is_retired if !missing(is_retired)
    local pct_ret = string(r(mean)*100, "%5.1f")
    
    * Mean household size
    quietly count if !missing(total_number_hh)
    local n_hhsize = r(N)
    quietly sum total_number_hh if !missing(total_number_hh)
    local mean_hhsize = string(r(mean), "%5.2f")
    
    * Household with kids (%)
    capture drop has_kids
    gen has_kids = (kids_number_hh > 0) if !missing(kids_number_hh)
    quietly count if !missing(has_kids)
    local n_kids = r(N)
    quietly sum has_kids if !missing(has_kids)
    local pct_kids = string(r(mean)*100, "%5.1f")
    
    * Household income quartiles (excluding "Rather not say")
    quietly count if household_income != 7 & !missing(household_income)
    local n_income = r(N)
    quietly sum household_income if household_income != 7, detail
    local q1_income = r(p25)
    local med_income = r(p50)
    local q3_income = r(p75)
    
	* Convert income categories to ranges
	if `q1_income' == 1 local q1_income_str "<\euro 2,000"
	if `q1_income' == 2 local q1_income_str "\euro 2,000-\euro 2,999"
	if `q1_income' == 3 local q1_income_str "\euro 3,000-\euro 3,999"
	if `q1_income' == 4 local q1_income_str "\euro 4,000-\euro 4,999"
	if `q1_income' == 5 local q1_income_str "\euro 5,000-\euro 5,999"
	if `q1_income' == 6 local q1_income_str ">\euro 6,000"

	if `med_income' == 1 local med_income_str "<\euro 2,000"
	if `med_income' == 2 local med_income_str "\euro 2,000-\euro 2,999"
	if `med_income' == 3 local med_income_str "\euro 3,000-\euro 3,999"
	if `med_income' == 4 local med_income_str "\euro 4,000-\euro 4,999"
	if `med_income' == 5 local med_income_str "\euro 5,000-\euro 5,999"
	if `med_income' == 6 local med_income_str ">\euro 6,000"

	if `q3_income' == 1 local q3_income_str "<\euro 2,000"
	if `q3_income' == 2 local q3_income_str "\euro 2,000-\euro 2,999"
	if `q3_income' == 3 local q3_income_str "\euro 3,000-\euro 3,999"
	if `q3_income' == 4 local q3_income_str "\euro 4,000-\euro 4,999"
	if `q3_income' == 5 local q3_income_str "\euro 5,000-\euro 5,999"
	if `q3_income' == 6 local q3_income_str ">\euro 6,000"
    
    * Homeowners (%) - excluding "Rather not say"
	capture drop is_homeowner
	gen is_homeowner = (dwelling_ownership == 1) if dwelling_ownership != 3 & !missing(dwelling_ownership)
	qui count if !missing(is_homeowner)
	local n_own = r(N)
	qui sum is_homeowner if !missing(is_homeowner)
	local pct_own = string(r(mean)*100, "%5.1f")	
	
    * Urban or suburban environment (%)
    capture drop urban_suburban
    gen urban_suburban = (dwelling_environment == 1 | dwelling_environment == 2) if !missing(dwelling_environment)
    quietly count if !missing(urban_suburban)
    local n_env = r(N)
    quietly sum urban_suburban if !missing(urban_suburban)
    local pct_env = string(r(mean)*100, "%5.1f")
    
    * Semi-detached house (%)
    quietly count if !missing(lives_semi_detached)
    local n_semi = r(N)
    quietly sum lives_semi_detached if !missing(lives_semi_detached)
    local pct_semi = string(r(mean)*100, "%5.1f")
    
    * Apartment (%)
    quietly count if !missing(lives_apt)
    local n_apt = r(N)
    quietly sum lives_apt if !missing(lives_apt)
    local pct_apt = string(r(mean)*100, "%5.1f")
    
    * Median dwelling size
    quietly count if !missing(dwelling_size)
    local n_size = r(N)
    quietly sum dwelling_size if !missing(dwelling_size), detail
    local med_size = r(p50)
    
	* Convert dwelling size to range
	if `med_size' == 1 local med_size_str "<50 m\$^2\$"
	if `med_size' == 2 local med_size_str "50-99 m\$^2\$"
	if `med_size' == 3 local med_size_str "100-149 m\$^2\$"
	if `med_size' == 4 local med_size_str "150-200 m\$^2\$"
	if `med_size' == 5 local med_size_str ">200 m\$^2\$"
    
    * Home built >= 2006 (%)
    quietly count if !missing(lives_home_after2006)
    local n_year = r(N)
    quietly sum lives_home_after2006 if !missing(lives_home_after2006)
    local pct_year = string(r(mean)*100, "%5.1f")
    
    * Household has solar PV (%)
    quietly count if !missing(own_solar_panels)
    local n_solar = r(N)
    quietly sum own_solar_panels if !missing(own_solar_panels)
    local pct_solar = string(r(mean)*100, "%5.1f")
    
    * Heat pump is primary heating system (%)
    capture drop has_heat_pump
    gen has_heat_pump = (heating_main_system == 1) if !missing(heating_main_system)
    quietly count if !missing(has_heat_pump)
    local n_hp = r(N)
    quietly sum has_heat_pump if !missing(has_heat_pump)
    local pct_hp = string(r(mean)*100, "%5.1f")
    
    * Natural gas is primary heating system (%)
    quietly count if !missing(main_heating_system_gas)
    local n_gas = r(N)
    quietly sum main_heating_system_gas if !missing(main_heating_system_gas)
    local pct_gas = string(r(mean)*100, "%5.1f")
    
    * Car is main transport mode (%)
    quietly count if !missing(car_main_transport_mean)
    local n_car = r(N)
    quietly sum car_main_transport_mean if !missing(car_main_transport_mean)
    local pct_car = string(r(mean)*100, "%5.1f")
    
    * Fully EV among car users (%)
    quietly count if car_main_transport_mean == 1 & !missing(main_mobility_system_EV)
    local n_ev = r(N)
    quietly sum main_mobility_system_EV if car_main_transport_mean == 1 & !missing(main_mobility_system_EV)
    local pct_ev = string(r(mean)*100, "%5.1f")
    
    * Home automation (%)
    quietly count if !missing(own_home_automation)
    local n_auto = r(N)
    quietly sum own_home_automation if !missing(own_home_automation)
    local pct_auto = string(r(mean)*100, "%5.1f")
    
	*--------------------------------------------------------*
    * STEP 2: Write LaTeX table to file
    *--------------------------------------------------------*
	
    local filename "$resultsDir/Table_1.tex"
    capture file close texfile
    file open texfile using "`filename'", write replace
    
    file write texfile "\begin{table}[h!]" _n
    file write texfile "\centering" _n
    file write texfile "\caption{Participants' characteristics}\label{Table_1_participants_characteristics}" _n
    file write texfile "\begin{threeparttable}" _n
    file write texfile "\begin{tabular}{lccc@{}c@{}}" _n
    file write texfile "\toprule" _n
    file write texfile "\multicolumn{1}{c}{} & \begin{tabular}[c]{@{}c@{}}Total\\ respondents\end{tabular} & \begin{tabular}[c]{@{}c@{}}Sample\\ statistics\end{tabular} & \multicolumn{2}{c}{\begin{tabular}[c]{@{}c@{}}National\\ average\end{tabular}} \\" _n
    file write texfile "\midrule" _n
    file write texfile "\textit{Respondent-specific characteristics} \\" _n
    file write texfile "\midrule" _n
    
    file write texfile "Female respondents (\%) & " (`n_female') " & " ("`pct_female'") "\% & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Age \$\leq\$ 34 (\%) & " (`n_age34') " & " ("`pct_age34'") "\% & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Age \$>\$ 65 (\%) & " (`n_age65') " & " ("`pct_age65'") "\% & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Higher education diploma (\%) & " (`n_edu') " & " ("`pct_edu'") "\% & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Employed (\$\leq\$ 64), full- or part-time (\%) & " (`n_emp') " & " ("`pct_emp'") "\% & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Retired (\%) & " (`n_ret') " & " ("`pct_ret'") "\% & \multicolumn{1}{c}{—} & \\" _n
    
    file write texfile "\midrule" _n
    file write texfile "\textit{Household characteristics} \\" _n
    file write texfile "\midrule" _n
    
    file write texfile "Mean household size (persons) & " (`n_hhsize') " & " ("`mean_hhsize'") " & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Household with children (\%) & " (`n_kids') " & " ("`pct_kids'") "\% & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Q1 household income category (net, monthly) & " (`n_income') " & " ("`q1_income_str'") " & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Median household income category (net, monthly) & " (`n_income') " & " ("`med_income_str'") " & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Q3 household income category (net, monthly) & " (`n_income') " & " ("`q3_income_str'") " & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Homeowners (\%) & " (`n_own') " & " ("`pct_own'") "\% & \multicolumn{1}{c}{—} & \\" _n
    
    file write texfile "\midrule" _n
    file write texfile "\textit{Dwelling and energy characteristics} \\" _n
    file write texfile "\midrule" _n
    
    file write texfile "Urban or suburban environment (\%) & " (`n_env') " & " ("`pct_env'") "\% & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Semi-detached house (\%) & " (`n_semi') " & " ("`pct_semi'") "\% & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Apartment (\%) & " (`n_apt') " & " ("`pct_apt'") "\% & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Median dwelling size (category) & " (`n_size') " & " ("`med_size_str'") " & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Home built \$\geq\$ 2006 (\%) & " (`n_year') " & " ("`pct_year'") "\% & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Household has solar PV (\%) & " (`n_solar') " & " ("`pct_solar'") "\% & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Household has home automation system (\%) & " (`n_auto') " & " ("`pct_auto'") "\% & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Heat pump is primary heating system (\%) & " (`n_hp') " & " ("`pct_hp'") "\% & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Natural gas is primary heating system (\%) & " (`n_gas') " & " ("`pct_gas'") "\% & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Car is main transport mode (\%) & " (`n_car') " & " ("`pct_car'") "\% & \multicolumn{1}{c}{—} & \\" _n
    file write texfile "Fully EV among car users (\%) & " (`n_ev') " & " ("`pct_ev'") "\% & \multicolumn{1}{c}{—} & \\" _n
    
    file write texfile "\bottomrule" _n
    file write texfile "\end{tabular}" _n
    file write texfile "\begin{tablenotes}" _n
    file write texfile "      \item \footnotesize NOTES" _n
    file write texfile "\end{tablenotes}" _n
    file write texfile "\end{threeparttable}" _n
    file write texfile "\end{table}" _n
    
    file close texfile

end

generate_latex_sumstat_table

* In the text:

tab country if coop_channel == 0

*-----------------------------*
* 4. Choice model estimation procedures
*-----------------------------*

// The following programs iterate over all utility specifications and
// choice model estimators considered. See Section 4 for more details. We run
// models separately for Cooperants, Online panel respondents ('_non_pooled'),
// and for both respondent groups pooled together ('pooled').
//
// For reproducibility, we explicitly provide starting values for the
// estimated coefficients. These values were obtained at convergence from 
// preliminary estimations using nrep(50), i.e. 50 Halton draws for simulated 
// maximum likelihood estimation.
//
// Note that running these programs may take a while (several days). Therefore, 
// the corresponding .ster estimation files are included in the directory. Also,
// small deviations from the reported estimates may occur due to the randomness
// of the Halton draws.

capture program drop estimation_procedures_non_pooled
program define estimation_procedures_non_pooled

version 17
use "$data", clear

******************** 1. Choice experiment on electric vehicles ********************

	********** Model 1: Range continuous, Frequency continuous, € incl., Timing categorical
		
		***** MNL: 
		
			sort response_id choice_situation_ev alternative_index
		
			cmset response_id panel_time_var_index alternative_index
			cmclogit choice_ev euro_ev $model1_ev if coop_channel == 1, vce(cluster response_id) nocons base(3) // LL = -5830.8327
			estimate store coop1_model1_ev_mnl 
			estimates save "$estimationDir\save_coop1_model1_ev_mnl.ster", replace 
			
			cmset response_id panel_time_var_index alternative_index
			cmclogit choice_ev euro_ev $model1_ev if coop_channel == 0, vce(cluster response_id) nocons base(3) // LL = -5309.9843
			estimate store coop0_model1_ev_mnl
			estimates save "$estimationDir\save_coop0_model1_ev_mnl.ster", replace 

		***** Mixlogit with independent coefficients: 
		
			matrix coop1_model1_ev_mix_in_50 = 0.073811, 0.0062866, 0.0139727, -0.00802, 0.301023, 0.1234515, -5.276231, -0.0114304, 0.0311689, -0.0517242, -0.3946779, 0.0113539, 7.834265 // LL =  -4626.8276 ; technique(bfgs 20 nr 2) nrep(50)
			matrix coop1_model1_ev_mix_fin = .072603, .0063495, .014228, .028507, .3644619, .1074625, -5.370622, -.0118299, .0314735, -.3225991, -.7631551, .0033785, 7.977183 // LL = -4613.5738 ; technique(bfgs 20 nr 2) nrep(2000) using coop1_model1_ev_mix_in_50 as starting values
			mixlogit choice_ev euro_ev if coop_channel == 1, group(_caseid) id(response_id) rand($model1_ev) cluster(response_id) technique(bfgs 20 nr 2) nrep(2000) from(coop1_model1_ev_mix_fin, copy)
			estimates store coop1_model1_ev_mix
			estimates save "$estimationDir\save_coop1_model1_ev_mix.ster", replace 

			matrix coop0_model1_ev_mix_in_50 = 0.0987348, 0.0086946, 0.0072093, -0.1637239, 0.0439573, -0.0110366, -1.53894, 0.0079521, 0.0460125, -0.2742768, 0.7100464, 0.0370986, 3.534675 // LL =  -4671.1707 ; technique(bfgs 20 nr 2) nrep(50)
!çcviiii			mixlogit choice_ev euro_ev if coop_channel == 0, group(_caseid) id(response_id) rand($model1_ev) cluster(response_id) technique(bfgs 20 nr 2) nrep(2000) from(coop0_model1_ev_mix_fin, copy)
			estimates store coop0_model1_ev_mix
			estimates save "$estimationDir\save_coop0_model1_ev_mix.ster", replace 

		***** Mixlogit with correlated coefficients: 
		
			matrix coop1_model1_ev_mix_corr_in_50 = 0.0756603, 0.0078535, 0.012523, 0.1880356, 0.5812157, 0.3514672, -5.076502, -0.0142775, 0.0190771, -0.3943606, -0.5143616, -0.4452553, -5.46158, 0.0303283, 0.2266626, 0.1386138, 0.3476101, 0.0931841, -0.8329736, -1.308585, -0.7397587, -4.248583, 0.0617274, 0.0014441, -5.325466, 0.0396234, -0.5261021, 3.627233 // LL = -4569.5207 ; technique(bfgs 20 nr 2) nrep(50)
			matrix coop1_model1_ev_mix_corr_fin = .0750077, .0080849, .0129993, .2274332, .6003893, .2769521, -5.339185,-.0157526, .0231029, -.1519811, -.2608058, -.044725, -5.313299, .0309904, .0200198, -.31573, .2760656, -.1142866, -.8303276,-1.37809, -.3786648, -4.145381, .3462542, .0461532, -5.39665,.1807703, -.5562329, 3.922081 // LL = -4539.8018 ; technique(bfgs 20 nr 2) nrep(2000) using coop1_model1_ev_mix_corr_in_50 as starting values
			mixlogit choice_ev euro_ev if coop_channel == 1, group(_caseid) id(response_id) rand($model1_ev) cluster(response_id) technique(bfgs 20 nr 2) corr nrep(2000) from(coop1_model1_ev_mix_corr_fin, copy)
			estimates store coop1_model1_ev_mix_corr
			estimates save "$estimationDir\save_coop1_model1_ev_mix_corr.ster", replace 

			matrix coop0_model1_ev_mix_corr_in_50 = 0.1017048, 0.0095941, 0.0065377, -0.1604939, 0.1361219, 0.068523, -1.458431, -0.0104897, 0.0143199, 0.1762631, -0.0059298, 0.0503652, -2.016182, 0.0468098, -0.1665235, -0.0966847, -0.0233232, -0.4302931, -0.0746055, -1.035485, -0.519021, -2.251937, 0.4398827, 0.0515685, -1.264696, 0.0177604, 2.480476, 1.450875 // LL = -4642.15 ; technique(bfgs 20 nr 2) nrep(50)
			matrix coop0_model1_ev_mix_corr_fin = .1010554, .0097423, .0065858, .0188214, .4118826, .2718166, -1.34383, -0.0114355, .0171832, .2394718, -0.1982874, .0323996, -2.160736, .048477, -0.0265597, -0.3361412, .1724904, -0.3097843, -0.6217792, -1.556502, -0.3073365, -0.6252338, -0.2164344, -0.0102734, -1.15083, .0370769, 2.886187, 2.017474 // LL = -4603.7285 ; technique(bfgs 20 nr 2) nrep(2000) using coop0_model1_ev_mix_corr_in_50 as starting values
			mixlogit choice_ev euro_ev if coop_channel == 0, group(_caseid) id(response_id) rand($model1_ev) cluster(response_id) technique(bfgs 20 nr 2) corr from(coop0_model1_ev_mix_corr_fin, copy) nrep(2000)
			estimates store coop0_model1_ev_mix_corr
			estimates save "$estimationDir\save_coop0_model1_ev_mix_corr.ster", replace 

	********** Model 2: Range categorical, Frequency categorical, € incl., Timing categorical
		
		***** MNL: 
		
			cmset response_id panel_time_var_index alternative_index
			cmclogit choice_ev euro_ev $model2_ev if coop_channel == 1, vce(cluster response_id) nocons base(3) // LL = -5741.5522 
			estimate store coop1_model2_ev_mnl
			estimates save "$estimationDir\save_coop1_model2_ev_mnl.ster", replace 

			cmset response_id panel_time_var_index alternative_index
			cmclogit choice_ev euro_ev $model2_ev if coop_channel == 0, vce(cluster response_id) nocons base(3) // LL = -5206.5362
			estimate store coop0_model2_ev_mnl 
			estimates save "$estimationDir\save_coop0_model2_ev_mnl.ster", replace 

		***** Mixlogit with independent coefficients: 
		
			matrix coop1_model2_ev_mix_in_50 = 0.0623495, 0.0880413, -0.1197301, -1.19254, 0.2871406, 0.6247828, 0.8146778, -0.0024798, 0.2912754, 0.1409225, -5.412561, 1.131708, -0.4570492, 1.688322, -0.7382875, -0.2917526, 1.027275, 0.1549143, -0.2130432, 0.0619639, 7.163347 // LL = -4567.8201 ; technique(bfgs 20 nr 2) nrep(50)
			matrix coop1_model2_ev_mix_fin = 0.0685996, 0.0552948, -0.1371326, -1.324745, 0.4644783, 0.7990165, 0.9317142, 0.0991997, 0.4634261, 0.1411646, -5.87177, 1.237073, -0.6778698, 1.915589, 0.3699868, -0.0017706, 1.329214, -0.012351, -0.7778639, 0.2485557, 7.747973 // LL = -4512.7657 ; technique(bfgs 20 nr 2) nrep(2000) using coop1_model2_ev_mix_in_50 as starting values
			mixlogit choice_ev euro_ev if coop_channel == 1, group(_caseid) id(response_id) rand($model2_ev) cluster(response_id) technique(bfgs 20 nr 2) nrep(2000) from(coop1_model2_ev_mix_fin, copy)
			estimates store coop1_model2_ev_mix
			estimates save "$estimationDir\save_coop1_model2_ev_mix.ster", replace 
			
			matrix coop0_model2_ev_mix_in_50 = 0.090671, -0.100983, -0.33766, -1.689512, 0.3552367, 0.6530216, 0.3697156, -0.1387499, 0.0509543, 0.0447119, -2.567908, 0.7322191, -0.6695752, 1.700979, 0.0621745, 0.6610733, 1.761239, 0.3304646, 0.4542581, 0.1510008, 3.54331 // LL = -4574.9544 ; technique(bfgs 20 nr 2) nrep(50)
			matrix coop0_model2_ev_mix_fin = 0.1019632, -0.0460023, -0.3322725, -1.902804, 0.3537967, 0.6902976, 0.5252838, 0.0074856, 0.3907185, 0.1776356, -2.60365, 0.9611995, -0.7635968, 1.951566, -0.0056206, 0.8298987, 2.310582, 0.0710664, 1.206901, 0.5677897, 3.753666 // LL = -4530.89 ; technique(bfgs 20 nr 2) nrep(2000) using coop0_model2_ev_mix_in_50 as starting values
			mixlogit choice_ev euro_ev if coop_channel == 0, group(_caseid) id(response_id) rand($model2_ev) cluster(response_id) technique(bfgs 20 nr 2) nrep(2000) from(coop0_model2_ev_mix_fin, copy)
			estimates store coop0_model2_ev_mix
			estimates save "$estimationDir\save_coop0_model2_ev_mix.ster", replace 

		***** Mixlogit with correlated coefficients:
		
			matrix coop1_model2_ev_mix_corr_in_50 = 0.0668564, 0.24775, -0.0973754, -1.632742, 0.5172792, 0.9615884, 1.250344, 0.2711611, 0.7771674, 0.4492742, -6.738327, 1.296166, 1.625189, 1.39511, 0.6984913, 1.371837, 2.160825, -0.2523533, -1.017732, 0.0108052, -4.431072, 1.592229, 3.110779, 0.1637075, 0.9369083, 0.5599619, -0.1270064, 0.3133662, -0.0745375, -2.171671, -0.1731627, 1.48759, 1.122928, -0.2852141, -0.4996694, 0.0081444, -0.0158534, -3.279888, -0.5226042, -0.4682373, -0.4631353, -0.0098026, -0.0462534, -0.5719807, -3.731037, 0.9756756, 1.24868, -0.2786194, 0.3837606, -0.3797924, 2.245991, 0.5728477, 1.537157, 1.485411, 0.9754771, 0.2118335, 0.6337933, 0.4752035, 0.0283981, -0.0925301, -0.1074479, 0.3610818, 2.748797, -0.3938242, 2.712586, 1.46546 // LL = -4357.6288 ; technique(bfgs 20 nr 2) nrep(50)
			matrix coop1_model2_ev_mix_corr_fin = 0.0853452, 0.3512157, -0.0115966, -1.949258, 0.8364059, 1.327146, 1.720777, 0.3143016, 0.9211418, 0.5803907, -7.997864, 2.320837, 1.83899, 1.363956, 1.302212, 1.400999, 2.046971, -0.2370337, -0.6421382, 0.057119, -2.89029, 2.600835, 3.388679, -0.0107727, 0.5388386, 1.260101, -0.0863512, 0.0120168, -0.1131596, -3.010824, 2.319983, 1.042444, 1.880659, 0.5817291, 0.1418059, 0.3099576, 0.2525338, -1.132805, 0.1884008, -0.3241135, -1.844843, -1.399534, -0.9210884, -1.045691, -2.594788, 1.539072, 1.310867, -1.366106, -1.119971, -1.097027, -1.007419, -0.274908, 1.072855, 1.452955, -0.058174, -2.143095, 0.1985241, -0.5125561, -0.4240637, -0.5709015, 0.6829658, -0.2055544, 6.678056, -0.6873266, 3.514349, 3.078502 // LL = -4367.0193 ; technique(bfgs 20 nr 2) nrep(2000) using coop1_model2_ev_mix_corr_in_50 as starting values
			mixlogit choice_ev euro_ev if coop_channel == 1, group(_caseid) id(response_id) rand($model2_ev) cluster(response_id) technique(bfgs 20 nr 2) corr nrep(2000) from(coop1_model2_ev_mix_corr_fin, copy)
			estimates store coop1_model2_ev_mix_corr
			estimates save "$estimationDir\save_coop1_model2_ev_mix_corr.ster", replace 

			matrix coop0_model2_ev_mix_corr_in_50 = 0.1034647, 0.0029027, -0.3218951, -1.939541, 0.5529829, 0.8974527, 0.5235857, 0.0776828, 0.5115638, 0.3355885, -2.703031, 0.7074983, -0.0767156, -0.5454877, 0.4020272, 0.7543853, 1.506081, 0.195374, 0.232726, 0.3563743, -1.319626, 0.9689817, 1.017425, 0.3135854, 0.116178, 0.4641183, -0.195805, -0.3205306, -0.0576207, -2.407695, 1.653464, 0.2124221, 0.5375013, 0.9810708, 0.6355037, 0.3008879, 0.516547, 0.3579962, 1.142375, 2.060923, 1.605246, 0.1321136, -0.4313889, -0.2116782, 0.0920049, 0.3400556, 0.0821352, 0.7167356, 1.409408, 0.2273547, 1.637927, 1.577678, -0.3791228, -0.6809677, -0.1547024, 1.537089, -0.1872389, 0.3202887, -0.5743961, -0.2989494, -0.3187622, -0.1188204, -0.8699362, 0.2565725, 0.159487, 0.3699408 // LL = -4420.6016 ; technique(bfgs 20 nr 2) nrep(50)
			matrix coop0_model2_ev_mix_corr_fin = 0.1152941, 0.1951416, -0.2112368, -2.164823, 0.6725375, 1.167585, 1.003772, 0.0087763, 0.4961572, 0.3536208, -2.57362, 1.103145, 0.9539395, 0.2501879, 0.984195, 1.939758, 2.531, 0.0400454, -0.6236802, 0.0948094, -0.9591697, 1.591491, 1.803973, -0.0092491, -0.0060349, 0.5299972, -0.4478634, -0.3454641, -0.3294543, -0.4533082, 2.073711, 0.550503, 0.5927876, 0.4968686, 0.927472, 0.6131482, 0.8714752, 0.1257755, 1.377944, 2.04918, 1.264966, 0.1785245, 0.4971707, -0.613093, 2.512319, 0.2112522, 2.016249, 0.331559, 0.4366967, 0.5154913, 1.217311, 0.7049632, -0.7012902, -1.538574, -0.0505772, 0.604415, 0.1482757, 0.0111314, 0.2993673, -0.1279806, -0.9938644, -0.4791923, -1.281412, 0.2890392, 2.189506, 1.527953 // LL = -4427.5637 ; technique(bfgs 20 nr 2) nrep(2000) using coop0_model2_ev_mix_corr_in_50 as starting values
			mixlogit choice_ev euro_ev if coop_channel == 0, group(_caseid) id(response_id) rand($model2_ev) cluster(response_id) technique(bfgs 20 nr 2) corr nrep(2000) from(coop0_model2_ev_mix_corr_fin, copy)
			estimates store coop0_model2_ev_mix_corr
			estimates save "$estimationDir\save_coop0_model2_ev_mix_corr.ster", replace 

	********** Model 3: Range categorical, frequency categorical, € incl., Timing categorical, continuous interaction €*Frequency 
	
		***** MNL: 
		
			cmset response_id panel_time_var_index alternative_index
			cmclogit choice_ev euro_ev $model3_ev if coop_channel == 1, vce(cluster response_id) nocons base(3) // LL = -5727.485 
			estimate store coop1_model3_ev_mnl
			estimates save "$estimationDir\save_coop1_model3_ev_mnl.ster", replace 

			cmset response_id panel_time_var_index alternative_index
			cmclogit choice_ev euro_ev $model3_ev if coop_channel == 0, vce(cluster response_id) nocons base(3) // LL = -5197.9224
			estimate store coop0_model3_ev_mnl
			estimates save "$estimationDir\save_coop0_model3_ev_mnl.ster", replace 
			
		***** Mixlogit with independent coefficients: 
		
			matrix coop1_model3_ev_mix_in_50 = 0.088834, -0.009554, -0.2235957, -1.322625, 0.4977236, 0.8617842, 1.530398, -0.0259075, 0.2583633, 0.1271674, -5.375152, -0.0012139, 0.9816255, 0.6728271, 1.701183, -0.6847686, -0.3277708, -0.8549071, 0.2213438, 0.1899851, 0.1182209, 7.113987, -0.0007231 // LL = -4554.2481 ; technique(bfgs 20 nr 2) nrep(50)
			matrix coop1_model3_ev_mix_fin = 0.0939973, -0.0407648, -0.2497645, -1.414621, 0.6559408, 1.005543, 1.522152, 0.1347788, 0.4702927, 0.1468719, -5.503606, -0.0010196, 1.109254, 0.653669, 1.879018, -0.3462475, 0.0142925, -0.6674509, 0.1416356, 0.8285265, 0.1806128, 7.628933, -0.0017185 // LL = -4497.7255 ; technique(bfgs 20 nr 2) nrep(2000) using coop1_model3_ev_mix_in_50 as starting values
			mixlogit choice_ev euro_ev if coop_channel == 1, group(_caseid) id(response_id) rand($model3_ev) cluster(response_id) technique(bfgs 20 nr 2) nrep(2000) from(coop1_model3_ev_mix_fin, copy)
			estimates store coop1_model3_ev_mix
			estimates save "$estimationDir\save_coop1_model3_ev_mix.ster", replace 

			matrix coop0_model3_ev_mix_in_50 = 0.1163231, -0.1689096, -0.4274963, -1.812122, 0.4973532, 0.8329914, 1.114278, -0.136187, 0.0388246, 0.0523032, -2.33531, -0.001242, 0.6370808, 0.7145093, 1.702667, 0.0166663, 0.6216852, -1.884738, 0.5040898, 0.5266682, 0.0027802, 3.437983, 0.0005759 // LL = -4573.1377 ; technique(bfgs 20 nr 2) nrep(50)
			matrix coop0_model3_ev_mix_fin = 0.1237683, -0.0980184, -0.4348423, -1.98419, 0.4942494, 0.8580994, 1.038053, 0.0377988, 0.3959097, 0.1870691, -2.36206, -0.000688, 0.8040285, 0.7168646, 1.902209, 0.1679871, 0.7590021, -1.527022, -0.0045451, 1.271046, 0.49486, 3.695776, 0.0032404 // LL = -4511.9623 ; technique(bfgs 20 nr 2) nrep(50) using coop0_model3_ev_mix_in_50 as starting values
			mixlogit choice_ev euro_ev if coop_channel == 0, group(_caseid) id(response_id) rand($model3_ev) cluster(response_id) technique(bfgs 20 nr 2) nrep(2000) from(coop0_model3_ev_mix_fin, copy)
			estimates store coop0_model3_ev_mix
			estimates save "$estimationDir\save_coop0_model3_ev_mix.ster", replace 

		***** Mixlogit with correlated coefficients: 
				
			matrix coop1_model3_ev_mix_corr_in_50 = 0.1057158, -0.0095675, -0.3811217, -1.62012, 0.7766761, 1.210771, 1.900045, 0.3169025, 0.7006434, 0.5313411, -5.860203, -0.001447, 0.5232436, 1.816885, 2.488143, 0.7607331, 1.112949, 0.9913609, -0.5033773, -0.5468619, -0.4475984, -4.899258, 0.0003185, 0.598339, 0.8748759, -0.578443, -0.0463718, 1.130319, 1.293203, 1.046268, 1.130834, 4.572081, -0.0006394, -1.309442, 0.8757056, 0.6480018, -0.1046012, 0.6904173, 0.3351742, 0.723714, -0.3495595, 0.0009254, 1.101387, 1.481439, 1.590594, -0.826524, -0.5396397, -0.3422103, -0.0526395, -0.0008486, -0.1003276, 0.980107, -0.2405439, 0.1673937, -0.0042269, -0.9667588, -0.0015094, -0.0195118, 0.243835, 0.4930378, -0.0388031, 0.8764747, 0.0003508, -0.5170103, -1.074564, -1.066877, -0.7064541, 0.0001431, -0.5921923, -0.0647477, -4.291237, -0.0008325, 0.1234495, -3.283697, 0.0012279, 1.76806, 0.0009361, 0.0007752 // LL = -4412.9636 ; technique(bfgs 20 nr 2) nrep(50)
			matrix coop1_model3_ev_mix_corr_fin = 0.1283739, 0.0382113, -0.3418929, -2.094757, 1.323963, 1.82692, 2.653311, 0.3624845, 0.9289289, 0.5387579, -7.281065, -0.0018302, 0.9242696, 2.99027, 3.38212, 1.103565, 1.627885, 1.897241, -0.1341396, -0.1364065, 0.0517916, -5.056942, 0.0003558, 0.5128897, 1.354253, -1.693921, -0.919692, 0.657708, 0.3197665, -0.1956608, -0.4998572, 3.678031, -0.0012554, -2.142675, -0.4487132, -0.8406392, -0.035175, 0.226268, -0.4643094, -0.3391999, -1.396352, 0.0006771, 0.6207661, 1.979395, 1.698495, -0.7127282, -0.8696139, -0.7039127, 0.0798302, 0.000284, 0.1250904, 0.9832824, 0.1539314, -0.7148544, 0.7535335, -1.370746, -0.0008704, 0.8201692, 1.931865, 1.748474, 0.98231, 0.5690868, -0.0005186, 0.4663032, 0.561257, -0.1680582, 0.1899001, 0.0002313, -0.8874368, -0.6803126, -4.473033, -0.0015234, 0.1539535, -3.774437, 0.0002674, 4.16898, 0.0009953, 0.000924 // LL = -4360.051 ; technique(bfgs 20 nr 2) nrep(2000) using coop1_model3_ev_mix_corr_in_50 as starting values
			mixlogit choice_ev euro_ev if coop_channel == 1, group(_caseid) id(response_id) rand($model3_ev) cluster(response_id) technique(bfgs 20 nr 2) corr nrep(2000) from(coop1_model3_ev_mix_corr_fin, copy)
			estimates store coop1_model3_ev_mix_corr
			estimates save "$estimationDir\save_coop1_model3_ev_mix_corr.ster", replace 

			matrix coop0_model3_ev_mix_corr_in_50 = 0.1379753, 0.0176829, -0.3357621, -2.15635, 0.9679811, 1.368567, 1.587248, 0.049243, 0.5078154, 0.3698575, -2.39173, -0.0012888, -0.308109, -1.104758, -1.012856, -1.52089, -2.415509, -2.320019, -0.2114996, -0.0634965, 0.0033751, -0.3753491, 0.0001197, -0.7946775, -2.292915, 0.4109334, 0.6465107, 0.4289984, -0.5088774, -0.3395378, -0.4165919, 0.6812469, -0.0006103, -0.840589, 0.4243317, 0.3157375, 0.3948903, -0.0548471, 0.310976, 0.4294558, -1.557357, -0.0000492, 0.4100927, 0.8073444, 2.163916, 0.2313561, -0.7398576, -0.2155386, 0.5408274, -0.0003327, -0.061235, -1.073194, -0.6322593, -1.880505, -0.4754502, -2.119022, 0.0014076, 0.1476934, -0.6142251, -0.479641, -0.0631299, 2.909208, 0.0007309, 0.4440576, 0.813395, 0.347236, 0.2868851, 0.0006409, -0.2932496, 0.2315664, -0.9115107, 0.0023772, 0.5988392, -0.0614807, 0.0008341, -1.030963, -0.0007373, 0.0006973 // LL = -4413.9802
			matrix coop0_model3_ev_mix_corr_fin = 0.1598484, 0.0169503, -0.3469707, -2.517022, 1.067399, 1.52634, 1.973671, 0.0477599, 0.559051, 0.4298867, -2.48053, -0.0016533, -1.156289, -1.94951, -1.036545, -0.1079127, -0.462893, -1.321073, -0.1900352, 0.1326521, -0.0358891, -0.820609, -0.0003958, -0.9031317, -2.854782, -0.5338186, -0.773152, -0.6877997, -0.4489255, 0.064383, -0.2296081, 0.4950418, -0.0001498, -0.8034971, 1.400142, 2.318053, 2.212695, -0.3452786, -1.290384, -0.5194142, -1.230272, 0.0005466, -1.564939, -1.473044, -0.4108856, -0.5232369, -1.669677, -0.1293304, -1.485632, 0.0000569, -0.964521, -2.930056, -0.5941249, -0.785658, -0.2997459, -2.65536, 0.0021104, -1.025739, -0.5746125, -0.5051601, 0.0614749, 2.46621, 0.0021967, 0.7103269, 0.7817337, 0.6375029, -0.9611595, 0.0005551, -0.4851952, -0.7003812, 1.371354, -0.0018932, 0.3905701, -0.1784111, 0.0005512, 0.8862765, 0.0021045, 0.0008445 // LL = -4403.1972
			mixlogit choice_ev euro_ev if coop_channel == 0, group(_caseid) id(response_id) rand($model3_ev) cluster(response_id) technique(bfgs 20 nr 2) corr nrep(2000) from(coop0_model3_ev_mix_corr_fin, copy)
			estimates store coop0_model3_ev_mix_corr
			estimates save "$estimationDir\save_coop0_model3_ev_mix_corr.ster", replace 
			
******************** 2. Choice experiment on heat pumps ********************

	********** Model 1: Temp. continuous, Frequency continuous, € incl., Timing categorical
	
		***** MNL: 
		
			cmset response_id panel_time_var_index alternative_index
			cmclogit choice_hp euro_hp $model1_hp if coop_channel == 1, vce(cluster response_id) nocons base(3) // LL = -5955.1794
			estimate store coop1_model1_hp_mnl
			estimates save "$estimationDir\save_coop1_model1_hp_mnl.ster", replace 

			cmset response_id panel_time_var_index alternative_index 
			cmclogit choice_hp euro_hp $model1_hp if coop_channel == 0, vce(cluster response_id) nocons base(3) // LL = -5397.3196  
			estimate store coop0_model1_hp_mnl
			estimates save "$estimationDir\save_coop0_model1_hp_mnl.ster", replace 
			
		***** Mixlogit with correlated coefficients: 

			matrix coop1_model1_hp_mix_in_50 = .3447892, .6739941, .0093358, -.6635685, 1.219699, .0111036, 10.10571, .1404511, .0248968, 1.151477, 1.501068, .8307109, 4.509318 // LL = -4767.7312
			matrix coop1_model1_hp_mix_fin = 0.3759036, 0.7586825, 0.0105815, -0.7322694, 1.342881, 0.0012478, 11.36221, 0.0141603, 0.0310279, 1.340412, 1.72105, 1.130654, 5.567997 // LL = -4727.8757
			mixlogit choice_hp euro_hp if coop_channel == 1, group(_caseid) id(response_id) rand($model1_hp) cluster(response_id) technique(bfgs 20 nr 2) nrep(2000) from(coop1_model1_hp_mix_fin, copy)
			estimates store coop1_model1_hp_mix
			estimates save "$estimationDir\save_coop1_model1_hp_mix.ster", replace 

			matrix coop0_model1_hp_mix_in_50 = .4118154, .5562677, .0088934, -.4924214, .4842253, .1286098, 7.948664, .0806469, .0412762, 1.091606, 1.177536, .4669242, 3.220237 // LL = -4704.6053 
			matrix coop0_model1_hp_mix_fin = 0.4373378, 0.5975541, 0.00884, -0.5057167, 0.5125587, 0.123755, 8.518084, 0.0136938, 0.0437725, 1.180515, 1.309351, 0.9634135, 3.649957 // LL = -4681.4386
			mixlogit choice_hp euro_hp if coop_channel == 0, group(_caseid) id(response_id) rand($model1_hp) cluster(response_id) technique(bfgs 20 nr 2) nrep(2000) from(coop0_model1_hp_mix_fin, copy) 
			estimates store coop0_model1_hp_mix
			estimates save "$estimationDir\save_coop0_model1_hp_mix.ster", replace 

		***** Mixlogit with correlated coefficients: 
			matrix coop1_model1_hp_mix_corr_in_50 = 0.3486072, 0.9797537, 0.0087017, -0.7763408, 1.472036, 0.0715468, 15.08929, -0.8019049, 0.0069652, 0.0232347, -0.5313792, 0.0892449, -18.2095, -0.0268878, 0.2407828, 0.257661, -0.0195134, 1.031251, -0.9094233, 0.6504262, 0.1222052, 2.876046, 1.412987, 0.4428219, -1.650728, 1.059171, -0.0776239, 2.214949 // LL = -4657.829
			matrix coop1_model1_hp_mix_corr_fin = 0.385618, 1.07339, 0.0099142, -0.8549827, 1.656267, 0.1335479, 16.35306, -0.9312074, 0.0072921, 0.0098629, -0.3965435, 0.0058184, -20.69238, -0.0341199, 0.2263546, 0.3486944, -0.0869123, 1.917734, -1.470519, 0.2040812, -0.0903048, 1.965043, 1.989445, 0.4530322, 0.4786901, 1.313926, -0.2648973, 4.273238  // LL = -4631.711
			mixlogit choice_hp euro_hp if coop_channel == 1, group(_caseid) id(response_id) rand($model1_hp) cluster(response_id) technique(bfgs 20 nr 2) corr nrep(2000) from(coop1_model1_hp_mix_corr_fin, copy) 
			estimates store coop1_model1_hp_mix_corr
			estimates save "$estimationDir\save_coop1_model1_hp_mix_corr.ster", replace 

			matrix coop0_model1_hp_mix_corr_in_50 = 0.4344686, 0.7047079, 0.0082489, -0.5138147, 0.6422893, 0.2461505, 10.30018, -0.714115, 0.0114712, -0.281239, -0.365116, -0.1564031, -14.60938, 0.0429924, -0.1509743, -0.1631548, -0.1579228, -0.6314642, -1.128089, -0.2591359, -0.1299899, 2.771903, -1.549749, -0.5640136, -0.581971, -1.046778, 0.5584541, 0.7098528 // LL =  -4609.4362
			matrix coop0_model1_hp_mix_corr_fin =  0.4957571, 0.8314358, 0.0097212, -0.582618, 0.7731524, 0.2986667, 12.39326, -0.9117707, 0.0097189, 0.1945147, -0.3754191, 0.2473123, -17.4874, 0.0533784, -0.070529, -0.2278468, -0.1386534, -1.254907, -2.01391, -0.8373288, -0.8453484, 0.1366073, -1.96054, -0.6449394, -0.9359847, -1.357276, -0.9726065, 3.601185 // LL = -4594.4199
			mixlogit choice_hp euro_hp if coop_channel == 0, group(_caseid) id(response_id) rand($model1_hp) cluster(response_id) technique(bfgs 20 nr 2) corr nrep(2000) from(coop0_model1_hp_mix_corr_fin, copy) 
			estimates store coop0_model1_hp_mix_corr
			estimates save "$estimationDir\save_coop0_model1_hp_mix_corr.ster", replace 

********** Model 2: Temp. categorical, Frequency categorical, € incl., Timing categorical
	
		***** MNL: 
		
			cmset response_id panel_time_var_index alternative_index
			cmclogit choice_hp euro_hp $model2_hp if coop_channel == 1, vce(cluster response_id) nocons base(3) // LL = -5935.2459
			estimate store coop1_model2_hp_mnl
			estimates save "$estimationDir\save_coop1_model2_hp_mnl.ster", replace 

			cmset response_id panel_time_var_index alternative_index
			cmclogit choice_hp euro_hp $model2_hp if coop_channel == 0, vce(cluster response_id) nocons base(3) // LL =  -5390.7597
			estimate store coop0_model2_hp_mnl
			estimates save "$estimationDir\save_coop0_model2_hp_mnl.ster", replace 
			
		***** Mixlogit with independent coefficients: 
		
			matrix coop1_model2_hp_mix_in_50 = 0.376899, -0.5419391, -1.305413, -2.235927, 0.3401253, 0.4565827, 0.4707758, -0.6526612, 1.388529, 0.007946, -2.472785, 1.065568, 0.9134876, -0.8274993, 0.1799367, -0.6949761, 0.8822643, -1.17466, 1.285144, 0.5081262, 5.064885  // LL = - -4757.2394
			matrix coop1_model2_hp_mix_fin = 0.5022884, -0.8078982, -1.859975, -3.186624, 0.4343162, 0.6281999, 0.6673077, -0.8542015, 1.86838, 0.0568521, -3.018375, 1.401875, 1.459516, -1.596185, -0.4336896, -1.211131, 1.880775, -1.783542, 2.112213, 1.394822, 6.488731 // LL = -4689.6111
			mixlogit choice_hp euro_hp if coop_channel == 1, group(_caseid) id(response_id) rand($model2_hp) cluster(response_id) technique(bfgs 20 nr 2) nrep(2000) from(coop1_model2_hp_mix_fin,  copy)
			estimates store coop1_model2_hp_mix
			estimates save "$estimationDir\save_coop1_model2_hp_mix.ster", replace 

			matrix coop0_model2_hp_mix_in_50 = 0.4306328, -0.4886798, -1.088468, -1.819131, 0.1163963, 0.2527926, 0.3289039, -0.3949407, 0.575382, 0.1763625, -2.41002, -0.7041002, -0.7459201, -1.024865, -0.1202131, -0.886492, 1.550729, -0.8118175, 1.03521, -0.6367605, 3.589827 // LL = -4729.9317
			matrix coop0_model2_hp_mix_fin = 0.5526755, -0.6515404, -1.500456, -2.460649, 0.0922493, 0.3092685, 0.4465486, -0.5569715, 0.6871187, 0.2070714, -2.930825, -0.4988169, -1.151877, -1.761815, -0.1600117, -1.291345, 2.310332, -1.515518, 1.590051, -1.345707, 4.124365  // LL = -4659.3802
			mixlogit choice_hp euro_hp if coop_channel == 0, group(_caseid) id(response_id) rand($model2_hp) cluster(response_id) technique(bfgs 20 nr 2) nrep(2000) from(coop0_model2_hp_mix_fin, copy)
			estimates store coop0_model2_hp_mix
			estimates save "$estimationDir\save_coop0_model2_hp_mix.ster", replace
			
		***** Mixlogit with correlated coefficients: 
		
			matrix coop1_model2_hp_mix_corr_in_50 = 0.4472102, -0.7634528, -1.974183, -3.351367, 0.7244899, 0.8727035, 0.6511739, -0.9026158, 2.036186, 0.1165074, -3.690694, 1.671568, 2.745843, 2.81848, -0.0193772, 0.1481909, 0.1911857, 0.257762, -0.5359516, 0.6482059, -1.551423, 0.8586312, 1.051972, 1.368954, 0.6102364, 0.9650521, 0.6049097, 0.4325102, -0.1561275, -1.931595, 0.2669679, 0.5557727, 0.8981576, 0.000127, -1.210159, 0.3811797, -0.7443327, -1.5103, 1.060667, 0.9970225, 0.5754014, 0.3790543, -1.959361, -0.9284069, -1.972713, -0.6544842, -0.663548, -0.2113845, -0.9209055, 0.2091785, -1.852694, -1.23121, 0.5613126, 0.4449594, -0.1613994, -0.1356718, -0.7177186, -0.3072716, 0.0469486, 1.59822, -0.7151852, -0.2180186, 1.913037, -0.3922948, 1.278529, 4.633082 // LL = -4549.914
			matrix coop1_model2_hp_mix_corr_fin = 0.5503174, -1.054835, -2.46813, -4.192738, 0.8838322, 1.07581, 0.8771467, -0.9654838, 2.474119, 0.1590404, -3.838537, 2.401627, 2.609028, 2.981603, 0.1305886, 0.5575674, 0.6538146, -0.175469, -0.9852985, 0.1735769, -1.451173, 2.450778, 2.225691, 0.8244202, 0.2934936, 0.2846828, 0.956827, 0.5774895, 0.6804207, 0.3994467, 0.9522761, 0.5341754, 0.3395801, 0.0006473, -0.6381294, -0.2038573, -1.407988, -2.944814, 1.644064, 1.621276, 2.173908, 0.7143911, -0.7869062, -0.6361068, 1.027296, -0.8900319, -0.4610592, 1.403431, -1.160996, 0.3418404, -2.531403, -1.25702, 0.542864, -0.3582146, -0.8156169, 2.334659, -0.8360942, -1.964701, -0.1355177, -0.5978464, -0.3607228, 0.0823146, 2.959032, -0.3124319, 0.99543, 5.077495 // LL = -4562.9232
			mixlogit choice_hp euro_hp if coop_channel == 1, group(_caseid) id(response_id) rand($model2_hp) cluster(response_id) technique(bfgs 20 nr 2) corr nrep(2000) from(coop1_model2_hp_mix_corr_fin, copy) 
			estimates store coop1_model2_hp_mix_corr
			estimates save "$estimationDir\save_coop1_model2_hp_mix_corr.ster", replace 

			matrix coop0_model2_hp_mix_corr_in_50 = 0.5219554, -0.6618899, -1.549726, -2.579385, 0.2149377, 0.3404365, 0.4353603, -0.5499337, 0.8542267, 0.3070554, -2.994303, 0.3769765, -0.362117, -0.2719455, -0.2767993, 0.1379055, -1.077573, -0.359747, -0.5090126, -1.240724, -2.12931, 1.346709, 2.120794, 0.0625063, 0.2455183, 0.1693815, 0.6694378, -0.2159495, 0.0811081, -0.8146768, 0.2904666, 0.2989476, 0.0077155, 0.3677744, -0.2456448, 1.078257, 0.8396, -0.8411805, -0.3019563, -0.4587631, -0.7014445, 0.3588413, -0.3633453, 0.870307, -0.9350807, 1.044955, 1.708931, 0.5185171, -0.0037619, -0.3790647, -0.5468153, -1.122265, 0.6806444, 1.201126, 0.4022126, 2.708486, -1.464515, -0.4424927, -0.8107355, 0.2762237, 0.7159818, 0.0820123, -0.180715, -0.3172336, 0.9356281, 2.284376 // LL = -4560.5032
			matrix coop0_model2_hp_mix_corr_fin = 0.6162923, -0.7365148, -1.719487, -2.902419, 0.3800628, 0.5073946, 0.568355, -0.5551374, 1.005097, 0.4476624, -3.364492, 1.310209, 2.289535, 2.69028, 0.8860103, 0.9956806, 1.610976, 0.3482367, -0.0428864, 0.3286753, 1.714414, 1.187111, 1.71428, -0.3344275, -0.867902, -0.926395, 1.308341, 0.7599474, 1.095802, -0.4693152, -0.6890711, 0.7941962, 0.6953, 0.9013388, 1.468975, 1.863481, 1.54272, 2.079981, 0.5461823, 1.670315, 0.6609983, 0.2003175, 0.0888212, -0.1129581, -2.040884, 0.6390211, 0.5523307, 1.098059, -0.3177633, -1.154422, -0.869125, -2.27935, 0.1410101, 0.4620474, -0.2761612, 1.764906, 0.7566457, -0.9694604, 0.4375767, 1.539351, 1.334644, -0.0450835, 2.223336, -0.166032, 0.2579038, 2.434984 // LL = -4548.3763
			mixlogit choice_hp euro_hp if coop_channel == 0, group(_caseid) id(response_id) rand($model2_hp) cluster(response_id) technique(bfgs 20 nr 2) corr nrep(2000) from(coop0_model2_hp_mix_corr_fin, copy) 
			estimates store coop0_model2_hp_mix_corr
			estimates save "$estimationDir\save_coop0_model2_hp_mix_corr.ster", replace

********** Model 3: Temp. categorical, frequency categorical, € incl., Timing categorical, continuous interaction €*Frequency 

		***** MNL: 
		
			cmset response_id panel_time_var_index alternative_index
			cmclogit choice_hp euro_hp $model3_hp if coop_channel == 1, vce(cluster response_id) nocons base(3) // LL = -5934.8551
			estimate store coop1_model3_hp_mnl
			estimates save "$estimationDir\save_coop1_model3_hp_mnl.ster", replace 

			cmset response_id panel_time_var_index alternative_index
			cmclogit choice_hp euro_hp $model3_hp if coop_channel == 0, vce(cluster response_id) nocons base(3) // LL = -5390.2538
			estimate store coop0_model3_hp_mnl
			estimates save "$estimationDir\save_coop0_model3_hp_mnl.ster", replace 

		***** Mixlogit with independent coefficients: 
				
			matrix coop1_model3_hp_mix_in_50 = 0.3770378, -0.5461686, -1.232003, -2.110215, 0.3414704, 0.4855671, 0.6549851, -0.5835933, 1.3434, 0.0369923, -2.434331, -0.0011497, 1.137279, 0.7899095, 0.5639795, -0.3372464, 0.3736305, -1.138809, 0.7474909, 1.28249, 0.3929503, 4.962944, 0.0023434 // LL = -4761.1986
			matrix coop1_model3_hp_mix_fin =  0.5644002, -0.8826514, -1.96764, -3.335517, 0.4786878, 0.7060682, 0.8601557, -0.8767622, 1.996608, 0.0508865, -2.9569, -0.0012125, 1.457269, 1.531694, 1.732366, -0.5170394, 1.189612, 0.8102627, 1.871341, 2.068647, 1.503556, 6.598319, 0.0132679 // LL =  -4683.8171
			mixlogit choice_hp euro_hp if coop_channel == 1, group(_caseid) id(response_id) rand($model3_hp) cluster(response_id) technique(bfgs 20 nr 2) nrep(2000) from(coop1_model3_hp_mix_fin, copy) 
			estimates store coop1_model3_hp_mix
			estimates save "$estimationDir\save_coop1_model3_hp_mix.ster", replace 

			matrix coop0_model3_hp_mix_in_50 = 0.2933585, -0.3181592, -0.9829932, -2.468409, 0.2843244, 0.0056321, 0.0587417, -0.0915875, 0.7711174, 0.6084697, -1.51865, 0.0029125, -1.062834, -0.7420567, 1.942374, 0.03496, 1.359096, 1.862603, -1.132877, -0.7639958, -0.6503247, 3.028374, 0.0021911 // LL = -4829.7828
			matrix coop0_model3_hp_mix_fin = 0.6086685, -0.7083425, -1.624352, -2.618826, 0.1092291, 0.3670035, 0.3273347, -0.5800522, 0.7920415, 0.2014191, -2.81597, 0.0016718, 0.4480402, -1.310579, 1.944274, 0.4670024, 1.239486, 0.3301012, -1.645434, -1.518477, -1.498109, 4.117612, 0.0189601 // LL = -4642.1422
			mixlogit choice_hp euro_hp if coop_channel == 0, group(_caseid) id(response_id) rand($model3_hp) cluster(response_id) technique(bfgs 20 nr 2) nrep(2000) from(coop0_model3_hp_mix_fin, copy)
			estimates store coop0_model3_hp_mix
			estimates save "$estimationDir\save_coop0_model3_hp_mix.ster", replace 

		***** Mixlogit with correlated coefficients: 
			matrix coop1_model3_hp_mix_corr_in_50 = 0.5433837, -0.9342137, -2.28158, -3.851692, 0.9326376, 1.026489, 0.8500353, -0.7219265, 2.39423, 0.3495369, -3.005462, -0.0006035, 1.685339, 3.176932, 3.612978, 0.440668, 0.3916074, 0.20357, 0.2675543, -0.4009224, 0.14599, -1.864938, 0.0044189, 0.5675684, 0.6164049, -0.7760709, -1.351492, -0.2572034, 0.8826477, 0.83468, 0.7833969, 3.594904, -0.0083826, -0.2284991, -0.3642379, 0.1190812, 1.63988, -0.571185, 0.1766846, 0.8607556, 0.2799373, -0.0106576, -0.5373038, 0.1073675, -0.6204923, 0.3295057, 0.5593988, 0.5153537, 0.9308729, -0.0014898, 0.1137077, 0.2925685, -0.6505673, 1.097955, -0.0347172, 1.638904, -0.0043413, 1.519015, 0.8285016, -0.8175991, 0.4798721, -1.796624, -0.0133048, 1.595815, 1.564401, 0.8645006, 1.379562, 0.0035354, 1.430995, 0.2836216, -1.790352, -0.0010956, 1.014292, 0.3595134, 0.0039862, 4.779984, 0.0048266, 0.0017378 // LL = -4529.8711
			matrix coop1_model3_hp_mix_corr_fin = 0.7332852, -1.28793, -3.0596, -5.011146, 0.9545831, 1.206238, 0.8440645, -0.9704395, 3.144482, 0.360663, -4.298546, 0.0004032, 2.307485, 4.18113, 3.869184, 0.9688232, 1.06873, -0.4433959, 0.3756973, -0.4255337, 0.252631, -2.475981, 0.00949, 1.695661, 1.978729, -0.7399854, -1.794249, -0.9429722, 0.7531015, 0.7342051, 0.5833156, 3.208338, 0.0022506, -1.680495, -0.0431534, -0.5966268, -0.892261, 0.7106931, 1.145197, 1.168768, 1.247227, 0.0060164, -1.405617, 0.1689622, 0.1584025, -0.8611632, 0.6485915, 0.9109979, 2.929308, -0.0078086, 0.5947751, 1.27101, -0.3417361, 0.5637098, -0.9411716, 2.825276, -0.0042486, 3.952939, 0.0776129, -1.540712, 0.2729672, -3.156723, -0.0327583, 2.03608, -0.1244781, 0.4357144, 2.490593, -0.001644, 2.222018, 0.3268538, -2.778138, -0.0029945, 1.305714, 0.3815884, 0.0095924, 3.92847, -0.0136943, 0.003113 // LL = -4548.4442
			mixlogit choice_hp euro_hp if coop_channel == 1, group(_caseid) id(response_id) rand($model3_hp) cluster(response_id) technique(bfgs 20 nr 2) corr nrep(2000) from(coop1_model3_hp_mix_corr_fin, copy) 
			estimates store coop1_model3_hp_mix_corr
			estimates save "$estimationDir\save_coop1_model3_hp_mix_corr.ster", replace 
			
			matrix coop0_model3_hp_mix_corr_in_50 =  0.5522378, -0.6929875, -1.628089, -2.623643, 0.0835769, 0.1454987, -0.011018, -0.583792, 0.8508213, 0.308048, -3.19899, 0.0036582, -0.4286853, -0.8963296, -0.8039732, -0.0792584, -0.1943561, 0.082667, -0.1048022, -0.3298404, 0.2880713, -0.2676176, -0.0162688, 1.58242, 2.173923, -0.1222226, -0.4805606, -0.3029952, 0.6332462, 0.1782399, 0.9854961, 0.282036, 0.0009769, -0.1460997, -0.19281, -0.5697358, 0.2291609, 0.473353, -0.2479338, 0.7364588, 1.42468, 0.0032598, 0.1354723, -0.8479815, -1.149946, 0.3405348, 1.349234, 1.264102, 3.190619, 0.0055588, 0.3438562, -0.1728153, 1.566969, 0.2349152, 0.8598891, 0.6075419, 0.0064059, -0.1404198, 0.9883814, -0.3197352, -0.1201621, -0.203993, -0.0009676, -0.6769371, -1.45257, -0.5859966, 1.027144, -0.0040884, 0.0256882, -0.1236076, -0.5695952, -0.00142, -0.9352182, 1.972269, -0.0091891, 1.481351, 0.0035975, -0.0018124 // LL = -4534.4413
			matrix coop0_model3_hp_mix_corr_fin =.7142085, -.8442141, -1.919418, -3.241293, .3999984, .5635884, .5401558, -.5749756, 1.229407, .5298027, -3.315453, .0012029, -1.750073, -2.773743, -2.391218, -.4802338, -.8041194, -.2463837, -.5416964, -.3059326, -.3107436, -2.125497, -.0038432, 1.102472, 2.652749, -.3301868, -.9057747, -.427281, .4342491, -.4413347, .4285527, -.8535951, .0025658, -.3633077, -1.169218, -1.826458, -1.328062, -.2310028, .3537347, .1646195, .6733273, -.0027558, .3253252, -.5631206, -.3277725, .8170829, 1.096608, 1.746814, 4.619005, .0022952, .1567279, .2436343, 2.158131, .6204911, 1.014204, -.1243861, -.0024529, .6870139, -.7406909, -1.433939, .1294646, -1.069802, -.0133046, -1.281455, -.3863658, -.4062411, .5753884, .0009116, 1.69601, 1.28049, -.7559542, -.0029251, -.8800336, 2.084257, -.0103594, -.0830355, .0131804, -.0007515 // LL = -4536.6584
			mixlogit choice_hp euro_hp if coop_channel == 0, group(_caseid) id(response_id) rand($model3_hp) cluster(response_id) technique(bfgs 20 nr 2) corr nrep(2000) from(coop0_model3_hp_mix_corr_fin, copy) 
			estimates store coop0_model3_hp_mix_corr
			estimates save "$estimationDir\save_coop0_model3_hp_mix_corr.ster", replace 	

end
	
capture program drop estimation_procedures_pooled
program define estimation_procedures_pooled

version 17
use "$data", clear

******************** 1. Choice experiment on electric vehicles ********************

	********** Model 1: Range continuous, Frequency continuous, € incl., Timing categorical
		
		***** MNL: 
		
			sort respondent_index choice_situation_ev alternative_index
		
			cmset response_id panel_time_var_index alternative_index
			cmclogit choice_ev euro_ev $model1_ev, vce(cluster response_id) nocons base(3) // LL = -11160.412 
			estimate store coop1_model1_ev_mnl 
			estimates save "$estimationDir\save_pool_model1_ev_mnl.ster", replace 

		***** Mixlogit with independent coefficients: 
		
			matrix pool_model1_ev_mix_in_50 = .0813736,.0071922,.0093333,.0015066,.3286546,.1161826,-2.824544,-.0088553,.0351686, -.2505036,.7576794,.1288239, 5.100355 // LL = -9370.5189 ; technique(bfgs 20 nr 2) nrep(50)
			matrix pool_model1_ev_mix_fin = .0854322,.0075007,.0104991,.0043746,.3265258,.1203174,-2.941432,-.0102285,.0385927,-.0197166,.9263842,-.0013797,5.250263 // LL = -9325.8616 ; technique(bfgs 20 nr 2) nrep(2000) using pool_model1_ev_mix_in_50 as starting values
			mixlogit choice_ev euro_ev, group(_caseid) id(response_id) rand($model1_ev) cluster(response_id) technique(bfgs 20 nr 2) nrep(2000) from(pool_model1_ev_mix_fin, copy)
			estimates store pool_model1_ev_mix
			estimates save "$estimationDir\save_pool_model1_ev_mix.ster", replace 

		***** Mixlogit with correlated coefficients: 
	
			matrix pool_model1_ev_mix_corr_in_50 = .0846234,.0084599,.0084308,.0698203,.4591971,.2398081,-2.611157,.0127305,-.0180433,-.0209207,.2178952,.0174068,2.714069,.0363923,-.0335253,-.3175073,.1642926,-.8782136,.6191631,1.328259,.331204,.3234543,.1202728,.0583637,4.970745,-.0569804,.7302875, -.0222456 // LL = -9237.51 ; technique(bfgs 20 nr 2) nrep(50)
			matrix pool_model1_ev_mix_corr_fin = .087325,.0088933,.0094967,.0803186,.4738926,.2526436,-2.878802,.0134986,-.0217482,-.0398849,.225795,-.0006179,3.750825,.0388477,.0025969,-.2486268,.2191871,-.343501,.6869505,1.464556,.3363195,.4652505,.1477763,.0020049,4.97213,.0045139,1.112333,-.2299401 // LL = -9214.2754 ; technique(bfgs 20 nr 2) nrep(2000) using pool_model1_ev_mix_corr_in_50 as starting values
			mixlogit choice_ev euro_ev, group(_caseid) id(response_id) rand($model1_ev) cluster(response_id) technique(bfgs 20 nr 2) corr nrep(2000) from(pool_model1_ev_mix_corr_fin, copy)
			estimates store pool_model1_ev_mix_corr
			estimates save "$estimationDir\save_pool_model1_ev_mix_corr.ster", replace 

	********** Model 2: Range categorical, Frequency categorical, € incl., Timing categorical
		
		***** MNL: 
		
			cmset response_id panel_time_var_index alternative_index
			cmclogit choice_ev euro_ev $model2_ev, vce(cluster response_id) nocons base(3) // LL = -10969.48
			estimate store pool_model2_ev_mnl
			estimates save "$estimationDir\save_pool_model2_ev_mnl.ster", replace 

		***** Mixlogit with independent coefficients: 
		
			matrix pool_model2_ev_mix_in_50 = .0741121,-.0070436,-.2154084,-1.421638,.3580727,.6735864,.5939801,.0585011,.3944151,.1261592,-3.601615, 1.056536,.4228922,1.641393,-.4826774,-.0118198,1.22702,-.0197914,-.6738118,.199531,4.833198 // LL = -9194.9797 ; technique(bfgs 20 nr 2) nrep(50)
			matrix pool_model2_ev_mix_fin =  .0844318,-.0108188,-.2409201,-1.592124,.4268445,.7481911,.7293942,.0589349,.4180933,.1461793,-3.807179,1.119128,.6563696,1.907987,-.3189383,.4456945,1.776139,-.0114032,-.986906,.3689669,5.280999 // LL = -9110.7059 ; technique(bfgs 20 nr 2) nrep(2000) using pool_model2_ev_mix_in_50 as starting values
			mixlogit choice_ev euro_ev, group(_caseid) id(response_id) rand($model2_ev) cluster(response_id) technique(bfgs 20 nr 2) nrep(2000) from(pool_model2_ev_mix_fin, copy)
			estimates store pool_model2_ev_mix
			estimates save "$estimationDir\save_pool_model2_ev_mix.ster", replace 
		
		***** Mixlogit with correlated coefficients:
		
			matrix pool_model2_ev_mix_corr_in_50 = .0777827,.1415061,-.0931861,-1.566634,.5598989,.888546,.8987042,.1542809,.5855037,.3457229,-3.649199,.7745269,.4520312,.65164,1.161801,1.717632,1.887418,.2778395,-.0174378,.3993928,-.278555,1.358341,1.649798,.3858587,.7105178,.9595055,-.1607507,-.0555255,-.1264322,-1.200099,1.60252,-.1937464,-.0390144,-.2255958,.4945203,.3578593,.2132922,-.6324883,-.6302608,-.3455774,.5064943,-.1722064,-.6304845,-.0028224,-.9736243,.5257657,.9333096,-.0040753,-.0471382,-.390903,1.505213,.6327902,.3299268,.764924,.4827448,.5082897,-.7370649,-.8485279,-.399154,-1.510682,.1773125,.0880355,2.460721,-.3681865,.8109617,3.183582 // LL = -8956.2888 ; technique(bfgs 20 nr 2) nrep(50)
			matrix pool_model2_ev_mix_corr_fin = .0985987, .2065375, -.1209948, -1.922317, .7068596, 1.14266, 1.244335, .1398773, .6595415, .4279208, -4.26936, 1.564538, 1.568605, 1.049389, .6893661, 1.047903, 1.995317, .0492512, -.5465059, .2258909, -1.456207, 1.791657, 2.371741, -.0500125, .2795217, .6921273, -.2266024, .0669749, -.2514787, -.576013, 1.988024, .5887165, .7669805, .2858194, .5572054, .3510184, .6603179, -.0209685, -1.508712, -2.230582, -1.199629, .1380416, -.4463716, .4215221, -.6764147, .8206034, 2.027826, -.2660163, -.9289859, -.0769317, .3711751, .9486638, 1.226415, 1.669144, .974892, 1.773265, -.6619557, -.2411948, .3291753, 1.455954, .2425219, -.2504378, 2.972197, -.1621887, 1.997264, 3.809447 // LL = -8887.7466 ; technique(bfgs 20 nr 2) nrep(2000) using pool_model2_ev_mix_corr_in_50 as starting values
			mixlogit choice_ev euro_ev, group(_caseid) id(response_id) rand($model2_ev) cluster(response_id) technique(bfgs 20 nr 2) corr nrep(2000) from(pool_model2_ev_mix_corr_fin, copy)
			estimates store pool_model2_ev_mix_corr
			estimates save "$estimationDir\save_pool_model2_ev_mix_corr.ster", replace 

	********** Model 3: Range categorical, frequency categorical, € incl., Timing categorical, continuous interaction €*Frequency 
	
		***** MNL: 
		
			cmset response_id panel_time_var_index alternative_index
			cmclogit choice_ev euro_ev $model3_ev, vce(cluster response_id) nocons base(3) // LL = -10946.485
			estimate store pool_model3_ev_mnl
			estimates save "$estimationDir\save_pool_model3_ev_mnl.ster", replace 

		***** Mixlogit with independent coefficients: 
		
			matrix pool_model3_ev_mix_in_50 =  .1000849, -.1184149, -.312963, -1.514011, .5602809, .8733639, 1.311944, .089623, .3952351, .1323486, -3.213847, -.0012314, -.9097191, .4376356, 1.683707, -.1630439, .0802186, 1.39498, .1548328, -.6184552, .0079196, -4.801427, .0000459 // LL = -9164.2136 ; technique(bfgs 20 nr 2) nrep(50)
			matrix pool_model3_ev_mix_fin = .1102599, -.0912967, -.351639, -1.696481, .6052849, .9568505, 1.357245, .0935717, .4286616, .1583828, -3.550428, -.0009984, -1.004987, .6678617, 1.905766, -.2536931, -.4237008, 1.178228, .116124, -1.058923, .3802621, -5.287935, .0022256 // LL = -9076.7027 ; technique(bfgs 20 nr 2) nrep(2000) using pool_model3_ev_mix_in_50 as starting values
			mixlogit choice_ev euro_ev, group(_caseid) id(response_id) rand($model3_ev) cluster(response_id) technique(bfgs 20 nr 2) nrep(2000) from(pool_model3_ev_mix_fin, copy)
			estimates store pool_model3_ev_mix
			estimates save "$estimationDir\save_pool_model3_ev_mix.ster", replace 

		***** Mixlogit with correlated coefficients: 
				
			matrix pool_model3_ev_mix_corr_in_50 = .1202162, .0789837, -.2583516, -1.83762, .9318996, 1.327119, 1.880371, .1960456, .5660274, .340735, -3.26516, -.0015499, -1.143967, -1.183765, -.3237905, -.3928843, -.5862835, -1.44411, .2356578, .5642704, .2097026, -1.209783, -.0001012, 1.321979, 2.643935, .6635267, 1.06024, .9141192, .2691283, .0756541, .133505, -.7350034, .0002015, -.1035943, .636712, 1.473343, 1.880539, .1966621, .2412826, -.1391882, .378812, -.0007334, 1.035062, 1.087274, -.3585254, -.6173543, -.2955172, -.1521974, -2.841926, .0012497, .0179045, .6686505, .1073286, -.7601299, .2167626, -3.256455, -.0001254, -.3222796, .7411811, .8645341, .1985478, -2.468584, .0004744, -.3599589, -.6527057, -.5644882, -1.226139, -.0016397, -.0938352, -.0936697, .0501442, -.0007105, .3453632, .510121, .0002634, .0331776, -.0000411, .0002765 // LL = -8882.7551  ; technique(bfgs 20 nr 2) nrep(50)
			matrix pool_model3_ev_mix_corr_fin = .1418145, .0159064, -.2781995, -2.210677, 1.151977, 1.598254, 2.272227, .2059197, .700287, .4608648, -4.098375, -.0018427, -1.271765, -2.142065, -1.437799, -.2943069, -.4212274, -1.257108, .0036446, .325932, .0023082, .6576175, -.0005783, 1.146934, 2.871645, .6975416, 1.501339, 1.00513, -.0360766, .1299671, -.0304542, -.2549309, .0000972, -1.162823, 1.048396, 1.717885, 1.215237, -.611313, -.3065012, -.5066633, .9340831, .0003149, 1.354681, .9062125, -.4904136, -.1595938, .08247, .2357016, -3.30451, .0013168, .849546, 2.66194, .4581384, -.3081818, .2048218, -1.559748, -.0010777, .162487, .5456825, .191663, -.2436761, -3.574414, -.0010497, -1.222115, -1.973148, -.7661679, -2.135564, -.0009761, -.3949278, -.1278674, 1.060836, .0003099, -.7848907, 1.450447, -.0003318, .6233261, -.0003519, -.0018341 // LL = -8859.81 ; technique(bfgs 20 nr 2) nrep(2000) using pool_model3_ev_mix_corr_in_50 as starting values
			mixlogit choice_ev euro_ev, group(_caseid) id(response_id) rand($model3_ev) cluster(response_id) technique(bfgs 20 nr 2) corr nrep(2000) from(pool_model3_ev_mix_corr_fin, copy)
			estimates store pool_model3_ev_mix_corr
			estimates save "$estimationDir\save_pool_model3_ev_mix_corr.ster", replace 


* HP: 

	********** Model 1: Range continuous, Frequency continuous, € incl., Timing categorical
		
		***** MNL: 
		
			sort respondent_index choice_situation_hp alternative_index
		
			cmset response_id panel_time_var_index alternative_index
			cmclogit choice_hp euro_hp $model1_hp, vce(cluster response_id) nocons base(3) // LL = -11447.303
			estimate store coop1_model1_hp_mnl 
			estimates save "$estimationDir\save_pool_model1_hp_mnl.ster", replace 

		***** Mixlogit with independent coefficients: 
		
			matrix pool_model1_hp_mix_in_50 = .3804765, .6264769, .0085743, -.5649492, .8601344, .0660209, 9.017346, -.0019601, .033499, 1.111046, 1.378814, .8016025, -4.486358 // LL = -9539.1298 ; technique(bfgs 20 nr 2) nrep(50)
			matrix pool_model1_hp_mix_fin = .4084693, .6730587, .0094209, -.6180606, .9064932, .0554132, 9.76992, .0348317, .037572, 1.274681, 1.567567, 1.036683, -4.628003 // LL = -9492.6914 ; technique(bfgs 20 nr 2) nrep(2000) using pool_model1_hp_mix_in_50 as starting values
			mixlogit choice_hp euro_hp, group(_caseid) id(response_id) rand($model1_hp) cluster(response_id) technique(bfgs 20 nr 2) nrep(2000) from(pool_model1_hp_mix_fin, copy)
			estimates store pool_model1_hp_mix
			estimates save "$estimationDir\save_pool_model1_hp_mix.ster", replace 

		***** Mixlogit with correlated coefficients: 
	
			matrix pool_model1_hp_mix_corr_in_50 = .3915301, .7931149, .0079246, -.5406797, 1.096698, .2149395, 11.89092, -.7918753, .0076313, .1004044, -.2929207, .00218, -15.74004, -.0354658, .2835504, .3520899, .2652593, 1.336251, -.8114588, -.4504582, .4986934, .6038602, 1.70402, .626792, 1.509044, -.2748422, 3.994163, -.0574689 // LL =  -9381.5048 ; technique(bfgs 20 nr 2) nrep(50)
			matrix pool_model1_hp_mix_corr_fin = .436246, .9295678, .0090227, -.7356633, 1.169684, .183243, 13.9771, -.9244901, .0075486, -.1040135, -.569368, -.1847265, -18.8408, -.0432606, .301305, .3734286, .2440731, 1.821257, -1.353736, .1918409, .3810483, 2.604844, 1.934277, .2627878, -.3530398, -.9957864, 3.037635, .6249539 // LL = -9319.5773 ; technique(bfgs 20 nr 2) nrep(2000) using pool_model1_hp_mix_corr_in_50 as starting values
			mixlogit choice_hp euro_hp, group(_caseid) id(response_id) rand($model1_hp) cluster(response_id) technique(bfgs 20 nr 2) corr nrep(2000) from(pool_model1_hp_mix_corr_fin, copy)
			estimates store pool_model1_hp_mix_corr
			estimates save "$estimationDir\save_pool_model1_hp_mix_corr.ster", replace 

	********** Model 2: Temp categorical, Frequency categorical, € incl., Timing categorical
		
		***** MNL: 
		
			cmset response_id panel_time_var_index alternative_index
			cmclogit choice_hp euro_hp $model2_hp, vce(cluster response_id) nocons base(3) // LL =  -11424.387
			estimate store pool_model2_hp_mnl
			estimates save "$estimationDir\save_pool_model2_hp_mnl.ster", replace 

		***** Mixlogit with independent coefficients: 
		
			matrix pool_model2_hp_mix_in_50 = .3986654, -.5138354, -1.217894, -2.032566, .2004964, .334687, .3966153, -.5228398, .9421625, .1207455, -2.540846, .5874441, 1.041214, 1.071452, .0266123, -.8195119, 1.220061, -1.075286, 1.319807, .1949733, 4.278287 // LL = -9567.7249 ; technique(bfgs 20 nr 2) nrep(50)
			matrix pool_model2_hp_mix_fin = .534588, -.7465096, -1.703557, -2.846128, .23266, .4369673, .54604, -.7137423, 1.234803, .1309818, -3.151196, .9450005, 1.352442, 1.754919, .0496785, -1.300855, 2.15208, -1.72289, 1.945081, 1.379543, 5.438514 // LL = -9430.9022 ; technique(bfgs 20 nr 2) nrep(2000) using pool_model2_hp_mix_in_50 as starting values
			mixlogit choice_hp euro_hp, group(_caseid) id(response_id) rand($model2_hp) cluster(response_id) technique(bfgs 20 nr 2) nrep(2000) from(pool_model2_hp_mix_fin, copy)
			estimates store pool_model2_hp_mix
			estimates save "$estimationDir\save_pool_model2_hp_mix.ster", replace 
		
		***** Mixlogit with correlated coefficients:
		
			matrix pool_model2_hp_mix_corr_in_50 = .4345491, -.677171, -1.648936, -2.624177, .467116, .5685859, .4926842, -.5494175, 1.26144, .1898405, -3.088112, 1.093065, 1.265296, 1.911729, .1901241, .4586777, .5217758, -.2508368, -.9637807, -.261639, -1.30957, 1.501983, 1.247947, .3830296, .176354, -.0490095, .899864, .8677772, .746932, -.9832405, .1900557, -.6208977, -.8461331, -1.036522, .4056409, -.9618689, .4152912, -.3945828, .4503529, .909863, 1.722671, .5970516, -.4222499, .3092183, -.9234995, -.4417723, .3515658, -.4785516, -.1168109, .3780933, -2.173671, -.0847979, -.2189417, .0318977, -.5451419, -2.234691, -.4763545, .232339, .2855857, .4162392, .9358543, .5238494, 1.003448, .2425443, 1.044424, 2.638941 // LL = -9265.3773 ; technique(bfgs 20 nr 2) nrep(50)
			matrix pool_model2_hp_mix_corr_fin = .5725261, -.8379072, -2.004504, -3.317852, .6744524, .7745852, .5928228, -.678551, 1.640787, .305229, -3.446846, 1.785179, 1.852998, 2.113819, .1009281, .5579224, .8395134, -.2978227, -.4406741, -.1644467, -1.166466, 2.08166, 2.342489, .4519885, .0891013, .2542665, .9211064, .3928119, .7357188, -.2392164, .8201714, -.549472, -.5869799, -.3281574, -.7137958, -1.975361, -.8662368, .6661499, 1.19105, 1.952461, 2.002208, .0005166, -.6172983, -.5629134, -.8806946, -.4328525, 1.291118, -.3656534, -.5794504, .3344051, -1.7573, -1.109163, -.58941, -.7059539, -.409992, -3.003755, -1.632355, .9324772, -.3239309, .6598384, .1645928, -1.170319, -.343289, .8894922, 1.744102, 3.857684  // LL = -9223.4663 ; technique(bfgs 20 nr 2) nrep(2000) using pool_model2_hp_mix_corr_in_50 as starting values
			mixlogit choice_hp euro_hp, group(_caseid) id(response_id) rand($model2_hp) cluster(response_id) technique(bfgs 20 nr 2) corr nrep(2000) from(pool_model2_hp_mix_corr_fin, copy)
			estimates store pool_model2_hp_mix_corr
			estimates save "$estimationDir\save_pool_model2_hp_mix_corr.ster", replace 

	********** Model 3: Temp categorical, frequency categorical, € incl., Timing categorical, continuous interaction €*Frequency 
	
		***** MNL: 
		
			cmset response_id panel_time_var_index alternative_index
			cmclogit choice_hp euro_hp $model3_hp, vce(cluster response_id) nocons base(3) // LL = -11423.508
			estimate store pool_model3_hp_mnl
			estimates save "$estimationDir\save_pool_model3_hp_mnl.ster", replace 

		***** Mixlogit with independent coefficients: 
		
			matrix pool_model3_hp_mix_in_50 = .4294627, -.5447905, -1.262123, -2.099328, .2650509, .3982106, .599996, -.5421003, .9452274, .0938835, -2.504619, -.0012624, -.6123674, -1.011031, 1.026896, .0259709, -.9002092, -1.441983, -1.040788, 1.363893, .2164473, 4.453162, .0011344 // LL = -9551.6185 ; technique(bfgs 20 nr 2) nrep(50)
			matrix pool_model3_hp_mix_fin = .5839827, -.7838423, -1.770101, -2.949315, .2586884, .5048389, .5736868, -.7227276, 1.319932, .1279357, -3.026715, .000053, -.8573665, -1.421052, 1.873188, -.5129642, -1.203248, .8633089, -1.770289, 1.859862, 1.453754, 5.419292, .0152735 // LL = -9416.815 ; technique(bfgs 20 nr 2) nrep(2000) using pool_model3_hp_mix_in_50 as starting values
			mixlogit choice_hp euro_hp, group(_caseid) id(response_id) rand($model3_hp) cluster(response_id) technique(bfgs 20 nr 2) nrep(2000) from(pool_model3_hp_mix_fin, copy)
			estimates store pool_model3_hp_mix
			estimates save "$estimationDir\save_pool_model3_hp_mix.ster", replace 

		***** Mixlogit with correlated coefficients: 
				
			matrix pool_model3_hp_mix_corr_in_50 = .4855145, -.6842842, -1.667582, -2.770982, .5559397, .6393297, .4972317, -.5562571, 1.363246, .2832346, -2.898163, .0000302, 1.117665, 1.759956, 2.393043, .1219158, .219381, .6495691, -.5983774, -.6390875, -.3316822, -1.237348, .0010123, 1.363317, .8987768, .0420179, .0608684, -.8552585, 1.17679, .9808859, .8314579, -.4243867, .0041758, .6028426, -.3423533, -.5004037, .4045524, .7375062, -1.052169, .1906734, -.5717578, -.0070145, .65434, .8372785, .1467766, .5104164, -.1578134, -.7424679, -1.067142, .0077499, -.2999884, .384241, .1767673, 1.031981, .6025804, 1.143799, -.0017296, -.2925082, .2413396, .0652318, -.4357239, 2.454558, -.0015925, .3034369, -.3572072, .507961, -.4047458, .0079067, .3744385, .2903748, 1.488725, -.0003955, .2176665, 2.865357, .0025099, 1.497928, .0019034, .0011701 // LL = -9235.8849 ; technique(bfgs 20 nr 2) nrep(50)
			matrix pool_model3_hp_mix_corr_fin = .669321, -.9237997, -2.235997, -3.731635, .7010486, .8525976, .6684004, -.7313994, 1.822625, .3696792, -3.504073, .0001441, 1.482615, 2.918107, 3.689131, .2133194, .2389728, -.3593832, .10338, -.5793213, -.3207539, -.6495552, .0061793, 1.43238, .5088167, .0907955, -.0168496, .2249652, 1.227312, 1.209636, 1.673587, .5302704, -.002122, .626653, -.8049964, -1.862883, -.1939405, .3587674, -.8814332, .4202621, -.2584756, -.0055698, 1.004363, .6858816, -.1957067, 1.190819, -.4710629, .4896292, -2.170368, .0088985, -.8051114, -1.785557, .0243681, 1.59237, .3527231, 2.169811, .0100299, -.7154076, 1.603314, .5851185, -.4601338, 2.499139, .00277, -.0085384, -.0741699, -.2267296, -1.457128, .0137066, -1.50374, -.5217644, 1.706002, .0000707, .8368002, 3.945152, .0033313, 1.000299, .0039055, .0094264 // LL = -9197.9717 ; technique(bfgs 20 nr 2) nrep(2000) using pool_model3_hp_mix_corr_in_50 as starting values
			mixlogit choice_hp euro_hp, group(_caseid) id(response_id) rand($model3_hp) cluster(response_id) technique(bfgs 20) corr nrep(2000) from(pool_model3_hp_mix_corr_fin, copy)
			estimates store pool_model3_hp_mix_corr
			estimates save "$estimationDir\save_pool_model3_hp_mix_corr.ster", replace 
end	

// Uncomment to re-run the programs:			
	// estimation_procedures_non_pooled		
	// estimation_procedures_pooled		
	
*-----------------------------*
* 5.1 Attitudes towards flexibility schemes
*-----------------------------*

***** 5.1.1 Willingness to enroll in a flexibility scheme
	
*** Figure 1: 

capture program drop willingness_to_enroll
program define willingness_to_enroll

*----------------------------------------------------------*
* Figure 1: Distribution of stated likelihood responses
* 
* Output:
*   - "$resultsDir/Figure_1.pdf" (note that the version presented
*      in the paper requires some manual editing for the labels)
*
* Notes: manual editing includes hiding the rectangle where the
*        xaxis would otherwise appear, changing legend color block
*        sizes to (x,y)=(35,15), changing the spacing between 
*        color block and text key to "medium", changing the 
*        key text appearance, and adding % to the bar texts. 
*----------------------------------------------------------*

version 17

use "$data", clear
duplicates drop response_id, force

graph hbar, ///
    over(statement_likelihood) ///
    stack asyvars percentage ///
    ytitle(" ") ///
    blabel(bar, pos(center) format(%3.0f) size(vhuge) color(black)) ///
    ylab(, notick labcolor(white) labsize(medlarge) glpattern(solid) glcolor(white) glwidth(vthin) ) ///
    legend(pos(6) cols(6) size(vhuge)) ///
    graphregion(margin(small)) ///
    xsize(5) ysize(1) yscale(lcolor(none)) ///
    bar(1, fintensity(100) fcolor(gray%90) lcolor(none) lwidth(thin)) ///
    bar(2, fintensity(100) fcolor(dimgray%90) lcolor(none) lwidth(thin)) ///
    bar(3, fintensity(100) fcolor(sandb%90) lcolor(none) lwidth(thin)) ///
    bar(4, fintensity(100) fcolor(gold%90) lcolor(none) lwidth(thin)) ///
    bar(5, fintensity(100) fcolor(dkorange%90) lcolor(none) lwidth(thin)) ///
    saving("$resultsDir/Figure_1.gph", replace)
	
// graph export "$resultsDir/Figure_1.gph", replace // Needed to manually edit labels
graph export "$resultsDir/Figure_1.pdf", replace

di "Percentage of enrollment in the text calculated from:"

tab statement_likelihood

end

willingness_to_enroll

capture program drop sociodemographics_coding
program define sociodemographics_coding

* --------------------------------------------------
* Sociodemographic recoding
* Recode income, education, and age into coarser categorical variables simpler
* to work with.
* --------------------------------------------------

version 17 

use "$data", clear

*** Total monthly net household income in three categories

	capture drop inc_cat3
	gen inc_cat3 = .
	replace inc_cat3 = 1 if inlist(household_income, 1, 2)    // <2000 and 2000-2999
	replace inc_cat3 = 2 if inlist(household_income, 3, 4)    // 3000-3999 and 4000-4999
	replace inc_cat3 = 3 if inlist(household_income, 5, 6)    // 5000-5999 and >6000
	replace inc_cat3 = 4 if household_income == 7             // Rather not say
	capture label drop inc3
	label define inc3 1 "Low (<3000€)" 2 "Mid (3000–4999€)" 3 "High (5000€+)" 4 "Rather not say"
	label values inc_cat3 inc3

*** Respondent's highest education attainment in three categories 

	capture drop edu3
	gen edu3 = .
	replace edu3 = 1 if inlist(education, 1, 2)   // Low: Elementary + Secondary
	replace edu3 = 2 if education == 3            // Bachelor
	replace edu3 = 3 if inlist(education, 4, 5)   // Postgraduate: Master + PhD
	replace edu3 = . if education == 6
	capture label drop edu3lbl
	label define edu3lbl 1 "Low education" 2 "Bachelor" 3 "Postgraduate"
	label values edu3 edu3lbl
	
*** Respondent's age in three categories: 
	
	capture drop age3
	gen age3 = .
	replace age3 = 1 if inlist(age, 1, 2)   // Young: 18–34
	replace age3 = 2 if inlist(age, 3, 4)   // Middle-aged: 35–54
	replace age3 = 3 if inlist(age, 5, 6)   // Older: 55+
	replace age3 = . if age == 7
	capture label drop age3lbl
	label define age3lbl 1 "Young (18–34)" 2 "Middle-aged (35–54)" 3 "Older (55+)"
	label values age3 age3lbl
	
end

capture program drop heterogeneity_enrolling
program define heterogeneity_enrolling

* --------------------------------------------------
* Sociodemographic correlations:
* Spearman rank correlations between enrollment
* likelihood and sociodemographic/technology variables.
* --------------------------------------------------

version 17

sociodemographics_coding

duplicates drop response_id, force

spearman statement_likelihood inc_cat3 if inc_cat3 != 4
spearman statement_likelihood edu3
spearman statement_likelihood age3
spearman statement_likelihood coop_channel 

spearman statement_likelihood is_there_electric_in_here

gen has_heat_pump = (heating_main_system == 1) if !missing(heating_main_system)
spearman statement_likelihood has_heat_pump

end

capture program drop summarize_enrollment_reasons
program define summarize_enrollment_reasons

*----------------------------------------------------------*
* Program: summarize_enrollment_reasons
*
* Identify and rank the top reasons to enroll and not to enroll in a 
* flexibility program. Results can be computed overall (pooled sample
* or by subgroup.
*
* Options:
*   - group(varname): compute results by group levels
*   - topn(integer) : number of top reasons reported (default = 3)
*
* Output:
*   - Console output: ranked mean importance and sample size
*
* Notes: 
*   - See the paper for full text for each decision factor
*----------------------------------------------------------*

version 17

syntax [, GRoup(varname) TOPn(integer 3)]

use "$data", clear
qui duplicates drop response_id, force

// Default: pooled analysis. If group is specified: analysis by subgroup

if "`group'" != "" {
	qui levelsof `group', local(groups)
}
else {
	local groups "all"
}

// For each group
foreach g of local groups {
   
	if "`g'" != "all" {
		local condition_base "if `group' == `g'"
		di "***** Sample: `group' = `g' "
	}
	else {
		local condition_base "if 1==1"
		di "***** Pooled sample"
	}
		
	* --------------------------------------------------
	* Reasons TO enroll
	* Here, we compute mean importance scores for each proposed decision factor, 
	* among respondents with high enrollment likelihood (statement_likelihood > 3).
	* Then, we rank reasons and display the top-N most cited motives.
	* --------------------------------------------------
	   
	di "--- Top `topn' reasons TO enroll ---"

	local reasons_pos environment independence stability compensation technologies comfort acquaintance

	// Store means with reason names
	tempname results
	matrix `results' = J(10, 2, .) // 10 is max, some cells are empty but not an issue
	local i = 1
	local reason_names ""

	foreach reason of local reasons_pos {
		qui sum reasons_why_`reason' `condition_base' & statement_likelihood > 3
			matrix `results'[`i', 1] = r(mean)
			matrix `results'[`i', 2] = r(N)
			local reason_names "`reason_names' `reason'" // We store names in a local since Stata does not allow text in matrices
														 // Creates a bijection element in matrix <-> reason name. More 'certain'
			local i = `i' + 1
	}

	local n_reasons = `i' - 1 							  // Total number of reasons

	// Mark all reasons as unused (0 = not yet displayed, 1 = already shown)
	forvalues i = 1/`n_reasons' {
		  local used_`i' = 0
	}

	// Find and display the top N reasons by descending mean score: 
	forvalues rank = 1/`=min(`topn', `n_reasons')' {
		  
		  local max_idx = .                               // Index of reason with highest score (not yet initialized)
				
		  // Search for the highest-scoring and unused (undisplayed) reason 
		  forvalues i = 1/`n_reasons' {                   
				if `used_`i'' == 0 {                      // Loop over all reasons not yet displayed
					if missing(`max_idx') | (`results'[`i',1] > `results'[`max_idx',1]) {
					  local max_idx = `i'                 // If max is missing or if the reason's score is higher than the current max then change the rank i
					}
			     }
		  }
				
		  // Now we have found the rank i: mark it as used and display: 
		  local used_`max_idx' = 1                         
		  local reason : word `max_idx' of `reason_names'  
		  di "  `rank'. `reason': " %5.3f `results'[`max_idx',1] " (N=" `results'[`max_idx', 2] ")"
	
	}
	
	* --------------------------------------------------
	* Reasons not TO enroll
	* Here, we compute mean importance scores for each proposed decision factor, 
	* among respondents with low enrollment likelihood (statement_likelihood < 3).
	* Then, we rank reasons and display the top-N most cited motives.
	* --------------------------------------------------
	   
	di "--- Top `topn' reasons NOT to enroll ---"	 
	
	local reasons_neg control comfort internet info damage too_low
	
	// Store means with reason names
	tempname results
	matrix `results' = J(10, 2, .) // 10 is max, some cells are empty but not an issue
	local i = 1
	local reason_names ""

	foreach reason of local reasons_neg {
		qui sum reasons_why_not_`reason' `condition_base' & statement_likelihood < 3
			matrix `results'[`i', 1] = r(mean)
			matrix `results'[`i', 2] = r(N)
			local reason_names "`reason_names' `reason'" // We store names in a local since Stata does not allow text in matrices
														 // Creates a bijection element in matrix <-> reason name. More 'certain'
			local i = `i' + 1
	}

	local n_reasons = `i' - 1 							  // Total number of reasons

	// Mark all reasons as unused (0 = not yet displayed, 1 = already shown)
	forvalues i = 1/`n_reasons' {
		  local used_`i' = 0
	}

	// Find and display the top N reasons by descending mean score: 
	forvalues rank = 1/`=min(`topn', `n_reasons')' {
		  
		  local max_idx = .                               // Index of reason with highest score (not yet initialized)
				
		  // Search for the highest-scoring and unused (undisplayed) reason 
		  forvalues i = 1/`n_reasons' {                   
				if `used_`i'' == 0 {                      // Loop over all reasons not yet displayed
					if missing(`max_idx') | (`results'[`i',1] > `results'[`max_idx',1]) {
					  local max_idx = `i'                 // If max is missing or if the reason's score is higher than the current max then change the rank i
					}
			     }
		  }
				
		  // Now we have found the rank i: mark it as used and display: 
		  local used_`max_idx' = 1                         
		  local reason : word `max_idx' of `reason_names'  
		  di "  `rank'. `reason': " %5.3f `results'[`max_idx',1] " (N=" `results'[`max_idx', 2] ")"  
		  
	}

}

end

* In the text:
heterogeneity_enrolling 

summarize_enrollment_reasons, top(7) 

***** 5.1.2 Transferring appliance control to a flexibility aggregator

capture program drop control_asset
program define control_asset

* --------------------------------------------------
* Program: control_asset
*
* This script analyzes respondents' readiness to cede some degree of control 
* over a flexibility program in three domains: (1) EV charging, (2) heating,
* and (3) white goods use.
*
* For each, the program generates stacked horizontal bar charts showing the 
* distribution of responses across the diffderent proposed levels of control
* ceding.
*
* White goods are pooled across proposed appliances (see the text for more
* details).
*
* Output:
*   - "$resultsDir/Figure_2.pdf": Combined panel with all three domains.
*
* Notes: manual editing of the .gph is needed to reproduce the exact 
*        Figure in the paper. It includes adding % to the bar texts, 
*        hiding blank regions where the xaxes would otherwise appear, 
*        and changing the "Outer" sizes of the first two region plots
*        to 70%.
* --------------------------------------------------

version 17

use "$data", clear
duplicates drop response_id, force

* (1) MOBILITY

tab degree_electric_mobility

graph hbar, ///
    over(degree_electric_mobility) ///
    stack asyvars percentage ///
    ytitle(" ") /// *     ytitle("Percentage of respondents", size(large)) ///
    blabel(bar, pos(center) format(%3.0f) size(medlarge) color(black)) yscale(lcolor(none))  ///
    ylab(, labcolor(white) labsize(medlarge) glpattern(solid) glcolor(gs3) glwidth(vthin))  /// *    ylab(, glpattern(solid) glcolor(gs3) glwidth(vthin)) ///
    legend(off) /// *    legend(pos(6) col(2) row(3) size(medlarge)) ///
    graphregion(margin(small)) ///
	l1title("{bf: EV charging}", color(gs2) orientation(vertical) size(medlarge)) ///
    xsize(6.5) ysize(1) ///
    bar(1, fintensity(100) fcolor(gray%90) lcolor(none) lwidth(thin)) ///
    bar(2, fintensity(100) fcolor(dimgray%90) lcolor(none) lwidth(thin)) ///
    bar(3, fintensity(100) fcolor(sandb%90) lcolor(none) lwidth(thin)) ///
    bar(4, fintensity(100) fcolor(gold%90) lcolor(none) lwidth(thin)) ///
    bar(5, fintensity(100) fcolor(dkorange%90) lcolor(none) lwidth(thin)) ///
    saving("$intermediateDir/g1_pool", replace)

* (2) HEATING

tab degree_control_heating

graph hbar, ///
    over(degree_control_heating) ///
    stack asyvars percentage ///
    ytitle(" ") /// *     ytitle("Percentage of respondents", size(large)) ///
    blabel(bar, pos(center) format(%3.0f) size(medlarge) color(black)) yscale(lcolor(none)) ///
    ylab(, labcolor(white) labsize(medlarge) glpattern(solid) glcolor(gs3) glwidth(vthin))  /// *    ylab(, glpattern(solid) glcolor(gs3) glwidth(vthin)) ///
    legend(off) /// *    legend(pos(6) col(2) row(3) size(medlarge)) ///
    graphregion(margin(small)) ///
	l1title("{bf: Heating}", color(gs2) orientation(vertical) size(medlarge)) ///
    xsize(6.5) ysize(1) ///
    bar(1, fintensity(100) fcolor(gray%90) lcolor(none) lwidth(thin)) ///
    bar(2, fintensity(100) fcolor(dimgray%90) lcolor(none) lwidth(thin)) ///
    bar(3, fintensity(100) fcolor(sandb%90) lcolor(none) lwidth(thin)) ///
    bar(4, fintensity(100) fcolor(gold%90) lcolor(none) lwidth(thin)) ///
    bar(5, fintensity(100) fcolor(dkorange%90) lcolor(none) lwidth(thin)) ///
    saving("$intermediateDir/g2_pool", replace)

* (3) WHITE GOODS
preserve

duplicates drop response_id, force

* Clean and prepare data
gen long __id = _n
keep __id degree_washing_machine degree_dishwasher degree_tumble_dryer degree_electric_oven

* Harmonize names for reshape
rename degree_washing_machine deg1
rename degree_dishwasher deg2
rename degree_tumble_dryer deg3
rename degree_electric_oven deg4

* Long format
reshape long deg, i(__id) j(appliance)
drop if missing(deg)

* Create category dummies
tab deg, generate(d)
forvalues k = 1/5 {
    capture confirm variable d`k'
    if _rc gen byte d`k' = 0
}

* Average shares across appliances
collapse (mean) d1 d2 d3 d4 d5

* Reshape to long for plotting
gen byte pooled = 1
reshape long d, i(pooled) j(level)
rename d share

* Plot
graph hbar share, ///
    over(level) ///
    stack asyvars percentage ///
    blabel(bar, pos(center) format(%3.0f) size(medlarge) color(black)) yscale(lcolor(none)) ///
    legend(off) ///
    graphregion(margin(small)) ///
	l1title("{bf: White goods}", color(gs2) orientation(vertical) size(medlarge)) ///
    ytitle("Percentage of respondents", size(large)) ///
    ylab(, labsize(medlarge) glpattern(solid) glcolor(gs3) glwidth(vthin)) ///
    xsize(6.5) ysize(1) ///
    bar(1, fintensity(100) fcolor(gray%90) lcolor(none) lwidth(thin)) ///
    bar(2, fintensity(100) fcolor(dimgray%90) lcolor(none) lwidth(thin)) ///
    bar(3, fintensity(100) fcolor(sandb%90) lcolor(none) lwidth(thin)) ///
    bar(4, fintensity(100) fcolor(gold%90) lcolor(none) lwidth(thin)) ///
    bar(5, fintensity(100) fcolor(dkorange%90) lcolor(none) lwidth(thin)) ///
    saving("$intermediateDir/g3_pool", replace)

restore

* Combine all three panels
graph combine "$intermediateDir/g1_pool.gph" "$intermediateDir/g2_pool.gph" "$intermediateDir/g3_pool.gph", cols(1) ///
    ycommon graphregion(margin(small))

// graph save "$resultsDir/Figure_2.pdf".gph, replace // Necessary for manual editing. 
graph export "$resultsDir/Figure_2.pdf", replace

end

control_asset

spearman statement_likelihood degree_electric_mobility
spearman statement_likelihood degree_control_heating

***** 5.1.3 Comfort preferences for heating and mobility 

*** Average daily driving distance over all household cars for households reporting
*   using the car as their main transport mode;

capture program drop average_daily_driving
program define average_daily_driving 

* --------------------------------------------------
* Program: average_daily_driving
*
* This script processes respondents' car usage data to compute the total
* daily driving distance across all household cars of households reporting
* using the car as their main transport mode. We do the following:
*   - Aggregate kilometers driven across all reported cars.
*   - Clean implausible values and missing codes.
*   - Plot a histogram of daily driving distance (truncated at 140 km).
*
* Output:
*   - "$resultsDir/Figure_3_left.pdf": Histogram of average daily driving distance.
* --------------------------------------------------

version 17

use "$data", clear
duplicates drop response_id, force

* Prepare the data
local vars car_main_how_many_km_only_1 ///
    car_main_how_many_km_car_1_most ///
    car_main_how_many_km_car_2_most ///
    car_main_how_many_km_Cars_1_most ///
    car_main_how_many_km_Cars_2_most

local i = 1
foreach v of local vars {
    capture drop c`i'
    gen c`i' = `v' // Standardized names
    local ++i
}

forvalues j = 1/5 {
    replace c`j' = . if c`j' == -99 | c`j' == -999
}

* Clean the total daily driving distance across all household cars
capture drop total_km_if
egen total_km_if = rowtotal(c1 c2 c3 c4 c5)
replace total_km_if = . if total_km_if > 500
keep if total_km_if > 0

* Histogram
twoway ///
    (histogram total_km_if if total_km_if <= 140, ///
        width(10) percent ///
        fcolor(navy%60) lcolor(navy%80)), ///
    xlabel(0(20)140) xtitle("Average daily driving distance (km)") ///
    ytitle("Percent") ///
    xsize(4.5) ysize(3) ///
    legend(off)

// graph save "$resultsDir/Figure_3_left.pdf".gph, replace
graph export "$resultsDir/Figure_3_left.pdf", replace

end

average_daily_driving

* Summary statistics
sum total_km_if, detail
di "Mean daily km: " r(mean)
di "Median daily km: " r(p50)
di "SD: " r(sd)

* Summary statistics if EV owners
sum total_km_if if is_there_electric_in_here, detail
di "Mean daily km: " r(mean)
di "Median daily km: " r(p50)
di "SD: " r(sd)

ttest total_km_if, by(is_there_electric_in_here) 

*** Min./Max. indoor temperatures for comfort in Winter.

capture program drop minmax_indoor_temp_winter
program define minmax_indoor_temp_winter

*----------------------------------------------------------*
* 
* Program: minmax_indoor_temp_winter
*
* Cleans and visualizes household indoor heating temperatures for comfort in 
* Winter. Replaces implausible or inconsistent values with missing (.), then
* plots histograms of minimum and maximum temperatures.
*
* Output:
*   - "$resultsDir/Figure_3_right.pdf": Overlapping histograms of 
*     winter min and max indoor temperatures (% of households)
*
* Notes:
*   - Minimum temperatures below 14°C are treated as implausible.
*   - Maximum temperatures below the minimum or below 18°C are treated as missing.
*----------------------------------------------------------*

version 17

use "$data", clear
duplicates drop response_id, force

* Clean data
replace heating_winter_min_temp = . if heating_winter_min_temp < 14
replace heating_winter_max_temp = . if heating_winter_max_temp < heating_winter_min_temp
replace heating_winter_max_temp = . if heating_winter_max_temp < 18

// Plot:

twoway ///
    (hist heating_winter_min_temp if inrange(heating_winter_min_temp, 14.5, 22), ///
        width(1) start(14.5) percent ///
        fcolor(blue%40) lcolor(blue%70)) ///
    (hist heating_winter_max_temp if inrange(heating_winter_max_temp, 14.5, 28), ///
        width(1) start(14.5) percent ///
        fcolor(red%40) lcolor(red%70)), ///
    legend(order(1 "Min" 2 "Max") position(2) ring(0)) ///
    xlabel(15(1)28, grid) ///
    xscale(range(15 28)) ///
    xtitle("Indoor comfort temperature in Winter (°C)") ///
    ytitle("Percent") ///
    xsize(4.5) ysize(3)

// graph save "$resultsDir/Figure_3_right.gph", replace
graph export "$resultsDir/Figure_3_right.pdf", replace

end

minmax_indoor_temp_winter

* Summary statistics
sum heating_winter_min_temp if inrange(heating_winter_min_temp, 14.5, 22), detail
di "Mean minimum temperature: " r(mean)
di "Median minimum temperature: " r(p50)
di "SD: " r(sd)

sum heating_winter_max_temp if inrange(heating_winter_max_temp, 14.5, 28), detail
di "Mean maximum temperature: " r(mean)
di "Median maximum temperature: " r(p50)
di "SD: " r(sd)

gen avg = (heating_winter_max_temp + heating_winter_min_temp)/2
sum avg, detail
di "Mean avg temperature: " r(mean)
di "Median avg temperature: " r(p50)
di "SD: " r(sd)

*-----------------------------*
* 5.2 Preferences for explicit flexibility contracts
*-----------------------------*	

***** 5.2.1 Descriptive choice results

capture program drop CE_overview
program define CE_overview

use "$data", clear

* Share of opting out: 

tab alternative_index if choice_ev == 1
tab alternative_index if choice_hp == 1

* Share of people who rejected all choice cards presented to them 

capture drop n_optout_*
bys response_id: egen n_optout_ev = total(choice_ev == 1 & alternative_index == 3)
bys response_id: egen n_optout_hp = total(choice_hp == 1 & alternative_index == 3)

tab n_optout_ev
tab n_optout_hp
	
* People who rejected across both 

capture drop always_optout
gen always_optout = (n_optout_ev == 4) & (n_optout_hp == 4)
tab always_optout

* WRP to likelihood to enroll 

duplicates drop response_id, force

spearman n_optout_ev statement_likelihood
spearman n_optout_hp statement_likelihood

* WRP to asset ownership

duplicates drop response_id, force

capture drop rel_optout*
gen rel_optout_hp = n_optout_hp/4
gen rel_optout_ev = n_optout_ev/4

capture drop has_ev
gen has_ev = is_there_electric_in_here == 1
capture drop has_hp 
gen has_hp = heating_main_system == 1

ttest rel_optout_ev, by(has_ev)
ttest rel_optout_hp, by(has_hp)
	
end

CE_overview

***** 5.2.2 Marginal WTA estimates for flexibility contracts

// Cf. discussion based on Appendix G: 
global pref_spec_pooled_EV   "$estimationDir/save_pool_model2_ev_mix_corr.ster"
global pref_spec_pooled_HP   "$estimationDir/save_pool_model2_hp_mix_corr.ster"

*** Table 3: 

// These programs generate the MWTA estimates in Table 3. The outputted .tex
// files are further reformatted in the paper. 
	
capture program drop Table_WTA
program define Table_WTA, rclass

*----------------------------------------------------------*
* 
* Program: WTA_table
*
* Compute marginal willingness-to-accept (MWTA) estimates for EV or HP choice
* experiment attributes, in the pooled sample. We use our preferred
* specification.
*
* Input:
*   - `ce' option passed as argument: "ev" or "hp"
*   - Pooled MIXL correlated model .ster files in $estimationDir
*
* Output:
*   - Console output: mean, SD, 95% CI for all attributes (matrix "T")
*   - LaTeX table: "$resultsDir/Table_3_`ce'.tex"
*----------------------------------------------------------*

version 17

syntax , ce(string)

// 1: Attributes and cost var
if ("`ce'"=="ev") {
	local numerators range_150 range_100 range_50 freq_ev_6 freq_ev_12 freq_ev_52 ///
							 timing_ev_Ev timing_ev_Ni timing_ev_AM asc
	local base_vars range_200 freq_ev_1 timing_ev_PM
	local cost euro_ev
}
else if ("`ce'"=="hp") {
	local numerators temp_18 temp_17 temp_16 freq_hp_6 freq_hp_12 freq_hp_52 ///
							 timing_hp_Ev timing_hp_Ni timing_hp_AM asc
	local base_vars temp_19 freq_hp_1 timing_hp_PM
	local cost euro_hp
}

// 2: Combine all variables
local all_vars `base_vars' `numerators'
local nvars : word count `all_vars'

matrix T = J(`nvars', 6, .)
local r = 1

// 3: Base levels: we set them to 0
foreach v of local base_vars {
	matrix T[`r',1] = 0
	matrix T[`r',2] = 0
	matrix T[`r',3] = 0
	matrix T[`r',4] = 0
	matrix T[`r',5] = 0
	matrix T[`r',6] = 0
	local ++r
}

// 4: Loop 1: Mean WTAs
estimates use "$estimationDir\save_pool_model2_`ce'_mix_corr.ster"
scalar cost_coef = abs(_b[`cost'])

local r = `=`: word count `base_vars'' + 1'

foreach v of local numerators {
	estimates use "$estimationDir\save_pool_model2_`ce'_mix_corr.ster"
	qui nlcom (_b[`v'] / -_b[`cost']), post
	
	matrix T[`r',1] = _b[_nl_1]
	matrix T[`r',2] = _b[_nl_1] - 1.96*_se[_nl_1]
	matrix T[`r',3] = _b[_nl_1] + 1.96*_se[_nl_1]
	
	local ++r
}

// 5: mixlogit, sd post 
estimates use "$estimationDir\save_pool_model2_`ce'_mix_corr.ster"
mixlcov, sd post

// 6: Loop 2: SD WTAs
local r = `=`: word count `base_vars'' + 1'

foreach v of local numerators {
	qui nlcom (_b[`v'] / cost_coef)
	
	matrix T[`r',4] = r(b)[1,1]
	matrix T[`r',5] = r(b)[1,1] - 1.96*sqrt(r(V)[1,1])
	matrix T[`r',6] = r(b)[1,1] + 1.96*sqrt(r(V)[1,1])
	
	local ++r
}

// 7: Label matrix
matrix colnames T = Mean LL UL SD SD_LL SD_UL
matrix rownames T = `all_vars'

di "WTA summary for `ce':"
matrix list T

// 8: Export
// estout matrix(T, fmt(%9.2f)) using "$resultsDir/Table_3_`ce'.tex", replace style(tex) title("WTA table for `ce'")
// estout matrix(T, fmt(%9.2f)) using "$resultsDir/Table_3_`ce'.txt", replace

// 9: LaTeX table
tempname fh
file open `fh' using "$resultsDir/Table_3_`ce'.tex", write replace

file write `fh' "\begin{tabular}{lcc}" _n
file write `fh' "\toprule" _n
file write `fh' "Parameter & Mean & SD \\\\" _n
file write `fh' "\midrule" _n

local i = 1
foreach v of local all_vars {
	  local vtex : subinstr local v "_" "_", all

	  local mf  : display %9.2f T[`i',1]
	  local lf  : display %9.2f T[`i',2]
	  local uf  : display %9.2f T[`i',3]
	  local sf  : display %9.2f T[`i',4]
	  local slf : display %9.2f T[`i',5]
	  local suf : display %9.2f T[`i',6]

	  // First row: variable name and values
	  file write `fh' "`vtex' & `mf' & `sf' \\\\" _n
	  // Second row: CIs
	  file write `fh' " & (`lf', `uf') & (`slf', `suf') \\\\" _n
	  
	  local ++i
}

file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular}" _n
file close `fh'

end

Table_WTA, ce(ev)
Table_WTA, ce(hp)

*** Figure 4:

capture program drop plot_marginal_WTA_range_ev_pool
program define plot_marginal_WTA_range_ev_pool

*----------------------------------------------------------*
* 
* Program: plot_marginal_WTA_range_ev_pool
*
* Compute and plot marginal WTA for EV range reductions. This program computes 
* willingness-to-accept (WTA) values for discrete EV remaining-range levels 
* using preferred specification for mixed logit estimates (Model 2), derives 
* 95% confidence intervals via Delta method, and compares them to a linear 
* specification from Model 1.
*
* Output:
*   - "$resultsDir/Figure4_left.pdf": Nonlinear vs. linear marginal WTA
*                                     by range level
*----------------------------------------------------------*

    clear
    set obs 4
    gen level = .
    gen WTA = .
    gen LL = .
    gen UL = .
    
    replace level = 50 in 1
    replace level = 100 in 2
    replace level = 150 in 3
    replace level = 200 in 4  // Base level
    
    * Calculate WTA for each level from pooled Model 2 (= preferred)
    estimates use "$pref_spec_pooled_EV"
    
    * Range 50
    nlcom (_b[range_50] / -_b[euro_ev]), post
    replace WTA = _b[_nl_1] in 1
    replace LL = _b[_nl_1] - 1.96*_se[_nl_1] in 1
    replace UL = _b[_nl_1] + 1.96*_se[_nl_1] in 1
    
    * Range 100
    estimates use "$pref_spec_pooled_EV"
    nlcom (_b[range_100] / -_b[euro_ev]), post
    replace WTA = _b[_nl_1] in 2
    replace LL = _b[_nl_1] - 1.96*_se[_nl_1] in 2
    replace UL = _b[_nl_1] + 1.96*_se[_nl_1] in 2
    
    * Range 150
    estimates use "$pref_spec_pooled_EV"
    nlcom (_b[range_150] / -_b[euro_ev]), post
    replace WTA = _b[_nl_1] in 3
    replace LL = _b[_nl_1] - 1.96*_se[_nl_1] in 3
    replace UL = _b[_nl_1] + 1.96*_se[_nl_1] in 3
    
    * Base level (200 km)
    replace WTA = 0 in 4
    replace LL = 0 in 4
    replace UL = 0 in 4
    
    * Linearity from Model 1
    estimates use "$estimationDir/save_pool_model1_ev_mix.ster"
    nlcom _b[range_ev], post
    local range_coef = r(table)[1,1]
    estimates use "$estimationDir/save_pool_model1_ev_mix.ster"
    nlcom _b[euro_ev], post
    local euro_coef = r(table)[1,1]
    
    gen wta_linearity = (`range_coef'/`euro_coef') * abs(200 - level)
        
    * Plot with linearity
    twoway ///
    (rcap UL LL level, lc(navy%60) lw(medthick)) ///
    (connected WTA level, mc(navy%60) msymbol(circle) msize(medium) lc(navy%60) lw(medthick)) ///
    (line wta_linearity level, lc(navy%40) lw(medthick) lp(dash)), ///
    xlabel(50 "50 km" 100 "100 km" 150 "150 km" 200 "200 km") ///
    ylabel(-5 0 5 10 15 20 25, angle(horizontal)) ///
    yline(0) ///
    legend(order(2 "Nonlinear (Model 2)" 3 "Linear (Model 1)") pos(6) row(1)) ///
    xtitle("EV remaining range during interventions (km)") ///
    ytitle("Marginal WTA per intervention (€)") xsize(4.5) ysize(3)
    graph export "$resultsDir/Figure_4_left.pdf", replace
    
end

capture program drop plot_marginal_WTA_temp_hp_pool
program define plot_marginal_WTA_temp_hp_pool

*----------------------------------------------------------*
* 
* Program: plot_marginal_WTA_temp_hp_pool
*
* Compute and plot marginal WTA for HP indoor temperature reductions. This 
* program computes willingness-to-accept (WTA) values for discrete HP indoor
* temperature levels using preferred specification for mixed logit estimates
* (Model 2), derives 95% confidence intervals via Delta method, and compares 
* them to a linear specification from Model 1.
*
* Output:
*   - "$resultsDir/Figure4_right.pdf": Nonlinear vs. linear marginal WTA
*                                      by range level
*----------------------------------------------------------*

    clear
    set obs 4
    gen level = .
    gen WTA = .
    gen LL = .
    gen UL = .
    
    replace level = 16 in 1
    replace level = 17 in 2
    replace level = 18 in 3
    replace level = 19 in 4  // Base level
    
    * Calculate WTA for each level from pooled Model 2 (= preferred)
    estimates use "$pref_spec_pooled_HP"
    
    * Temp 16
    nlcom (_b[temp_16] / -_b[euro_hp]), post
    replace WTA = _b[_nl_1] in 1
    replace LL = _b[_nl_1] - 1.96*_se[_nl_1] in 1
    replace UL = _b[_nl_1] + 1.96*_se[_nl_1] in 1
    
    * Temp 17
    estimates use "$pref_spec_pooled_HP"
    nlcom (_b[temp_17] / -_b[euro_hp]), post
    replace WTA = _b[_nl_1] in 2
    replace LL = _b[_nl_1] - 1.96*_se[_nl_1] in 2
    replace UL = _b[_nl_1] + 1.96*_se[_nl_1] in 2
    
    * Temp 18
    estimates use "$pref_spec_pooled_HP"
    nlcom (_b[temp_18] / -_b[euro_hp]), post
    replace WTA = _b[_nl_1] in 3
    replace LL = _b[_nl_1] - 1.96*_se[_nl_1] in 3
    replace UL = _b[_nl_1] + 1.96*_se[_nl_1] in 3
    
    * Base level (19°C)
    replace WTA = 0 in 4
    replace LL = 0 in 4
    replace UL = 0 in 4
    
    * Linearity from Model 1
    estimates use "$estimationDir/save_pool_model1_hp_mix.ster"
    nlcom _b[temp_hp], post
    local temp_coef = r(table)[1,1]
    estimates use "$estimationDir/save_pool_model1_hp_mix.ster"
    nlcom _b[euro_hp], post
    local euro_coef = r(table)[1,1]   
    
    gen wta_linearity = (`temp_coef'/`euro_coef') * abs(19 - level)
    
    * Plot with linearity
    twoway ///
    (rcap UL LL level, lc(navy%60) lw(medthick)) ///
    (connected WTA level, mc(navy%60) msymbol(circle) msize(medium) lc(navy%60) lw(medthick)) ///
    (line wta_linearity level, lc(navy%40) lw(medthick) lp(dash)), ///
    xlabel(16 "16 °C" 17 "17 °C" 18 "18 °C" 19 "19 °C") ///
    ylabel(0 2 4 6 8, angle(horizontal)) ///
    yline(0) ///
    legend(order(2 "Nonlinear (Model 2)" 3 "Linear (Model 1)") pos(6) row(1)) ///
    xtitle("HP indoor temperature limit during interventions") ///
    ytitle("Marginal WTA per intervention (€)") xsize(4.5) ysize(3)
    graph export "$resultsDir/Figure_4_right.pdf", replace
    
end

plot_marginal_WTA_range_ev_pool
plot_marginal_WTA_temp_hp_pool

*** Wald tests [text]:

di "Wald test: linearity of perception of remaining range for EV flexibility"
	estimates use "$pref_spec_pooled_EV"
	test (0 - range_150)/50 = (range_150 - range_100)/50 = (range_100 - range_50)/50

di "Wald test: linearity of perception of indoor temperature limit for HP flexibility"
	estimates use "$pref_spec_pooled_HP"
	test (0 - temp_18)/1 = (temp_18 - temp_17)/1 = (temp_17 - temp_16)/1

*** Implied marginal economic values for discomfort levels [text]:

* EV:
estimates use "$pref_spec_pooled_EV"
scalar euro_ev_scal = _b[euro_ev]
	* Between base 200 km and 150 km
	nlcom (-(_b[range_150] - 0)/euro_ev_scal) / 50
	* Between 150 km and 100 km
	nlcom (-(_b[range_100] - _b[range_150])/euro_ev_scal) / 50
	* Between 100 km and 50 km
	nlcom (-(_b[range_50] - _b[range_100])/euro_ev_scal) / 50
	
* HP:
estimates use "$pref_spec_pooled_HP"
scalar euro_hp_scal = _b[euro_hp]
	* Between 19°C (base) and 18°C
	nlcom (-(_b[temp_18] - 0)/euro_hp_scal) / 1 
	* Between 18°C and 17°C
	nlcom (-(_b[temp_17] - _b[temp_18])/euro_hp_scal) / 1
	* Between 17°C and 16°C
	nlcom (-(_b[temp_16] - _b[temp_17])/euro_hp_scal) / 1
	
	test  -_b[temp_18] = -(_b[temp_17] - _b[temp_18])
	test - _b[temp_18] = -(_b[temp_16] - _b[temp_17])
	test -(_b[temp_17] - _b[temp_18]) = -(_b[temp_16] - _b[temp_17])

***** 5.2.3 Heterogeneity in marginal WTA for large comfort impacts

capture program drop generate_tioli_design_EV
program define generate_tioli_design_EV

* -----------------------------------------------------------------------------
*
* Program: generate_tioli_design_EV
*
* This program creates the full factorial "take-it-or-leave-it" (TIOLI) choice 
* experiment design for EV flexibility. Per-intervention compensation levels
* are specified via elevels() (default: 3 5 10 20, like in the original choice 
* cards). The program generates all combinations of attributes: range, 
* frequency, timing, euro; it expands each profile to 2 alternatives (contract 
* and optout, hence the TIOLI); it creates an alternative-specific constant (ASC) 
* and dummy variables for categorical attributes. Finally, it assigns unique 
* choice situation IDs and alternative indices.
*
* Output:
*   - "$intermediateDir/full_design_EV_tioli.dta": ready-to-use dataset
*
* Example usage:
*   . create_full_design_EV             // uses default euro levels 3 5 10 20
*   . create_full_design_EV, elevels(1 2 3 5 7 10 25 30)
*
* -----------------------------------------------------------------------------

	// Step 0: euro parameter grid
	
		syntax , [ ELEVELS(numlist) ]      
		if ("`elevels'"=="") local elevels "3 5 10 20"
		local Ke : word count `elevels'

	// Step 1: get the full factorial design in this "take it or leave it" design (TIOLI)
		
		clear
		
		matrix levmat = (4, 4, 4, `Ke')   // range:4, freq:4, timing:4, euro:`Ke'
		genfact, levels(levmat)

		rename x1 range_ev 
		rename x2 freq_ev
		rename x3 timing_ev
		rename x4 euro_ev

		replace range_ev = 200 if range_ev == 1
		replace range_ev = 150 if range_ev == 2
		replace range_ev = 100 if range_ev == 3
		replace range_ev = 50 if range_ev == 4

		replace freq_ev = 1 if freq_ev == 1
		replace freq_ev = 6 if freq_ev == 2
		replace freq_ev = 12 if freq_ev == 3
		replace freq_ev = 52 if freq_ev == 4
 
		gen euro_ev_new = . // Need to use a temporary variable not to erase what was before
		local i = 1
		foreach v of numlist `elevels' {
			replace euro_ev_new = `v' if euro_ev == `i'
			local ++i
		}
		
		drop euro_ev
		rename euro_ev_new euro_ev

    // Step 2: generate an ID per profile (and per future case)
    
		gen choice_situation_ev = _n
		tempname Nprof
		qui count
		scalar `Nprof' = r(N)
		
    // Step 3: TIOLI design requires to expand to 2 alternatives (contract + optout)

		expand 2
		sort choice_situation_ev
		by choice_situation_ev: gen byte alternative_index = _n

		gen range_ev_o = range_ev
		gen freq_ev_o = freq_ev
		gen timing_ev_o = timing_ev
		gen euro_ev_o = euro_ev

		replace range_ev = 0 if alternative_index==2
		replace freq_ev = 0 if alternative_index==2
		replace timing_ev = 0 if alternative_index==2
		replace euro_ev = 0 if alternative_index==2
		gen byte asc = (alternative_index==2)

		order choice_situation_ev alternative_index range_ev freq_ev timing_ev euro_ev asc
		sort choice_situation_ev alternative_index

    // Step 4: dummyfication 

		capture drop freq_6
		capture drop freq_12
		capture drop freq_52 

		gen freq_ev_6 = (freq_ev == 6)
		gen freq_ev_12 = (freq_ev == 12)
		gen freq_ev_52 = (freq_ev == 52)

		capture drop range_50
		capture drop range_100
		capture drop range_150 

		gen range_50 = (range_ev == 50)
		gen range_100 = (range_ev == 100)
		gen range_150 = (range_ev == 150)		
		
		capture drop timing_Ev
		capture drop timing_Ni
		capture drop timing_AM
		
		gen timing_ev_Ev = (timing_ev == 1)
		gen timing_ev_Ni = (timing_ev == 2)
		gen timing_ev_AM = (timing_ev == 3)
    
    // Step 5: save
		
		save "$intermediateDir/full_design_EV_tioli", replace
end

capture program drop generate_tioli_design_HP
program define generate_tioli_design_HP

* -----------------------------------------------------------------------------
*
* Program: generate_tioli_design_HP
*
* This program creates the full factorial "take-it-or-leave-it" (TIOLI) choice 
* experiment design for HP flexibility. Per-intervention compensation levels
* are specified via elevels() (default: 1 2 3 4, like in the original choice 
* cards). The program generates all combinations of attributes: temperature, 
* frequency, timing, euro; it expands each profile to 2 alternatives (contract 
* and optout, hence the TIOLI); it creates an alternative-specific constant (ASC) 
* and dummy variables for categorical attributes. Finally, it assigns unique 
* choice situation IDs and alternative indices.
*
* Output:
*   - "$intermediateDir/full_design_HP_tioli.dta": ready-to-use dataset
*
* Example usage:
*   . create_full_design_HP             // uses default euro levels 1 2 3 4
*   . create_full_design_HP, elevels(1 2 3 4 5 6 7 8 9 10)
*
* -----------------------------------------------------------------------------

version 17

	// Step 0: euro parameter grid
		
		syntax , [ ELEVELS(numlist) ]      
		if ("`elevels'"=="") local elevels "1 2 3 4"
		local Ke : word count `elevels'

	// Step 1: get the full factorial design in this "take it or leave it" design (TIOLI)
		
		clear
		
		matrix levmat = (4, 4, 4, `Ke')   // temp:4, freq:4, timing:4, euro:`Ke'
		genfact, levels(levmat)

		rename x1 temp_hp
		rename x2 freq_hp
		rename x3 timing_hp
		rename x4 euro_hp

		replace temp_hp = 19 if temp_hp==1
		replace temp_hp = 18 if temp_hp==2
		replace temp_hp = 17 if temp_hp==3
		replace temp_hp = 16 if temp_hp==4

		replace freq_hp = 1  if freq_hp==1
		replace freq_hp = 6  if freq_hp==2
		replace freq_hp = 12 if freq_hp==3
		replace freq_hp = 52 if freq_hp==4

		gen euro_hp_new = . // Need to use a temporary variable to avoid erasing what was before
		local i = 1
		foreach v of numlist `elevels' {
			replace euro_hp_new = `v' if euro_hp == `i'
			local ++i
		}
		
		drop euro_hp
		rename euro_hp_new euro_hp
		
    // Step 2: generate an ID per profile (and per future case)
    
		gen choice_situation_hp = _n
		tempname Nprof
		qui count
		scalar `Nprof' = r(N)

    // Step 3: TIOLI design requires to expand to 2 alternatives (contract + optout)
	
		expand 2
		sort choice_situation_hp
		by choice_situation_hp: gen alternative_index = _n

		gen temp_hp_o = temp_hp
		gen freq_hp_o = freq_hp
		gen timing_hp_o = timing_hp
		gen euro_hp_o = euro_hp

		replace temp_hp = 0 if alternative_index==2
		replace freq_hp = 0 if alternative_index==2
		replace timing_hp = 0 if alternative_index==2
		replace euro_hp = 0 if alternative_index==2
		gen asc = (alternative_index==2)

		order choice_situation_hp alternative_index temp_hp freq_hp timing_hp euro_hp asc
		sort choice_situation_hp alternative_index

    // Step 4: dummyfication 
    
		capture drop freq_hp_6 
		capture drop freq_hp_12 
		capture drop freq_hp_52
		
		gen freq_hp_6 = (freq_hp==6)
		gen freq_hp_12 = (freq_hp==12)
		gen freq_hp_52 = (freq_hp==52)

		capture drop temp_18 
		capture drop temp_17 
		capture drop temp_16
		
		gen temp_18 = (temp_hp==18)
		gen temp_17 = (temp_hp==17)
		gen temp_16 = (temp_hp==16)

		capture drop timing_hp_Ev 
		capture drop timing_hp_Ni 
		capture drop timing_hp_AM
		
		gen timing_hp_Ev = (timing_hp==1)
		gen timing_hp_Ni = (timing_hp==2)
		gen timing_hp_AM = (timing_hp==3)

    // Step 5: save
		
		save "$intermediateDir/full_design_HP_tioli", replace

end

do "$root/Script_KR_Simulation_procedure.do"

*-----------------------------*
* 6.1 Acceptance of flexibility contracts
*-----------------------------*

capture program drop running_pool_designs_with_probas
program define running_pool_designs_with_probas

* -----------------------------------------------------------------------------
*
* Program: running_pool_designs_with_probas
*
* This program generates full TIOLI designs for EV and HP flexibility and compute 
* predicted probabilities from MIXL models (on pooled samples) for both a linear 
* (utility specification Model 1) and nonlinear (Model 2) set of preferences. 
*
* Notes:
*   - Assumes one choice per respondent (no panel / repeated choices).
*
* Output:
*   - "$intermediateDir/full_design_EV_tioli_with_probas.dta"
*   - "$intermediateDir/full_design_HP_tioli_with_probas.dta"
* -----------------------------------------------------------------------------

version 17

use "$data", clear

***** Choice experiment on EV flexibility: 

generate_tioli_design_EV

	// Assumption: one choice made per respondent (no panel)
	gen _caseid = choice_situation_ev
	gen response_id = choice_situation_ev

	// Running the model onto this dataset to get the probabilities

	estimates use "$estimationDir/save_pool_model2_ev_mix_corr.ster"
	mixlpred proba_pool, nrep(2000) burn(15)

	// Linear model 

	gen freq_ev_cont = freq_ev
	estimates use "$estimationDir/save_pool_model1_ev_mix_corr.ster"
	mixlpred proba_pool_lin, nrep(2000) burn(15)

save "$intermediateDir/full_design_EV_tioli_with_probas", replace

***** Choice experiment on HP flexibility: 

generate_tioli_design_HP

	// Assumption: one choice made per respondent (no panel)
	gen _caseid = choice_situation_hp
	gen response_id = choice_situation_hp

	// Running the model onto this dataset to get the probabilities
	   
	estimates use "$estimationDir/save_pool_model2_hp_mix_corr.ster"
	mixlpred proba_pool, nrep(2000) burn(15)

	// Linear model 

	gen freq_hp_cont = freq_hp
	estimates use "$estimationDir/save_pool_model1_hp_mix_corr.ster"
	mixlpred proba_pool_lin, nrep(2000) burn(15)

save "$intermediateDir/full_design_HP_tioli_with_probas", replace

end
                            
capture program drop contract_probabilities_TIOLI
program define contract_probabilities_TIOLI

* -----------------------------------------------------------------------------
*
* Program: contract_probabilities_TIOLI
*
* Computes and plots 'predicted' (in TIOLI) probabilities of contract acceptance
* for EV and HP flexibility choice experiments. It generates Figure 5. 
*
* Notes:
*   - Uses TIOLI designs (Take-It-Or-Leave-It): only one alternative per case
*     (no between-alternative competition).
*
* Output:
*   - "$resultsDir/Figure_5_left.pdf"  : EV flexibility
*   - "$resultsDir/Figure_5_right.pdf" : HP flexibility
* -----------------------------------------------------------------------------

version 17

running_pool_designs_with_probas

***** Choice experiment on EV flexibility: 

preserve
	use "$intermediateDir/full_design_EV_tioli_with_probas", clear
			 
	keep if alternative_index==1   // Contract only 

	// Overall averages by range (over all € levels)
	bys range_ev: egen mean_pool_all = mean(proba_pool)
	bys range_ev: egen mean_pool_all_lin = mean(proba_pool_lin)
	egen tag_range = tag(range_ev)

	// Averages by (range, euro) subgroups
	bys range_ev euro_ev: egen mean_pool_eu = mean(proba_pool)
	bys range_ev euro_ev: egen mean_pool_eu_lin = mean(proba_pool_lin)
	egen tag_pair = tag(range_ev euro_ev)

	sort range_ev euro_ev

	// Plot:
	twoway ///
		(line mean_pool_all range_ev if tag_range, lpattern(solid)  lwidth(medthick) lc(green)) ///
		(line mean_pool_eu  range_ev if tag_pair & euro_ev==3,  lpattern(dash_dot) lc(green%45)) ///
		(line mean_pool_eu  range_ev if tag_pair & euro_ev==20, lpattern(dash) lc(green%45)), ///
		ytitle("Mean predicted probability of contract acceptance") ///
		xtitle("Guaranteed EV range during an intervention (km)") ///
		legend(order(2 "€3" 1 "Overall" 3 "€20") ///
			   pos(6) cols(3) size(medsmall)) ///
		xlabel(50 100 150 200, grid) ylabel(0.5(0.05)0.9, grid) xsize(4.5) ysize(3)

	//graph save "$resultsDir/Figure_5_left", replace
	graph export "$resultsDir/Figure_5_left.pdf", replace
			 
restore

***** Choice experiment on HP flexibility: 

preserve
	use "$intermediateDir/full_design_HP_tioli_with_probas", clear
			 
	keep if alternative_index==1   // Contract only 

	// Overall averages by temp (over all € levels)
	bys temp_hp: egen mean_pool_all = mean(proba_pool)
	bys temp_hp: egen mean_pool_all_lin = mean(proba_pool_lin)
	egen tag_range = tag(temp_hp)

	// Averages by (range, euro) subgroups
	bys temp_hp euro_hp: egen mean_pool_eu = mean(proba_pool)
	bys temp_hp euro_hp: egen mean_pool_eu_lin = mean(proba_pool_lin)
	egen tag_pair = tag(temp_hp euro_hp)

	sort temp_hp euro_hp

	// Plot:
	twoway ///
		(line mean_pool_all temp_hp if tag_range, lpattern(solid)  lwidth(medthick) lc(green)) ///
		(line mean_pool_eu  temp_hp if tag_pair & euro_hp==1,  lpattern(dash_dot) lc(green%45)) ///
		(line mean_pool_eu  temp_hp if tag_pair & euro_hp==4, lpattern(dash) lc(green%45)), ///
		ytitle("Mean predicted probability of contract acceptance") ///
		xtitle("Guaranteed min. indoor temperature" "during an intervention (°C)") ///
		legend(order(2 "€1" 1 "Overall" 3 "€4") ///
			   pos(6) cols(3) size(medsmall)) ///
		xlabel(16 17 18 19, grid) ylabel(0.5(0.05)0.9, grid) xsize(4.5) ysize(3)

	//graph save "$resultsDir/Figure_5_right", replace
	graph export "$resultsDir/Figure_5_right.pdf", replace
	
restore

end

contract_probabilities_TIOLI

// The APE estimates presented in the paper are outputted in the console 
// from the execution of "Script_KR_Simulation_procedure.do" file. 

*-----------------------------*
* 6.2 Stylized grid benefits from flexibility contracts
*-----------------------------*

// These programs compute the economic and energy impacts of 16 explicit 
// flexibility contracts for EV and HP choice experiments. They use predicted 
// probabilities from the pooled MIXL correlated model. They generate Tables 5 
// (EV) and 6 (HP).
//
// Parameter values for the stylized analysis are defined inside each program 
// but can be manually changed. Examples for EV: 
//   local increment_number_ev = 1,000,000 EVs to start with (before enrollment)
//   local avg_power_EV_kW = 7.4 kW
//   local pi_cap_MW = 32,000 €/MW.year
//   local p_charging = 0.15
//   local p_below_R200 = 0.06
//   local p_below_R50 = 0.03
//   local delta = 0.5
//   local P_eff_R200 = `avg_power_EV_kW' * `p_charging' * (1 - `p_below_R200')
//   local P_eff_R50  = `avg_power_EV_kW' * `p_charging' * (1 - `p_below_R50')
// And for HP: 
//   local increment_number_hp = 1,000,000 HPs to start with (before enrollment)
//   local avg_power_HP_kW = 0.45 kW
//   local pi_cap_MW = 32,000 €/MW.year
//   local p_below_T19 = 0.42
//   local p_below_T16 = 0.07
//   local delta = 0.5
//   local P_eff_T19 = `avg_power_HP_kW' * (1 - `p_below_T19')
//   local P_eff_T16 = `avg_power_HP_kW' * (1 - `p_below_T16')
//
// See Section 6 and Appendix L for more details on how to interpret these.
//
// The programs compute for each bundle:
//   - Expected number of participants usign TIOLI enrollment probabilities.
//   - Compensation cost (€M/year)
//   - Effective power reduction (MW/event)
//   - Capacity value (€/year)
//   - Energy reduction (GWh)
//   - DAM load shifting value (€/year) using 2023 Belgium prices
//   - Net profit (capacity + load shifting – cost)
//
// Warning:
//   - Mean DAM prices (dam_pr_X_Y) are pasted manually from the console output of 
//     "Script_Cost_effectiveness_calc.do". They are not automatically fetched.
	
capture program drop Table_BotE_EV
program define Table_BotE_EV

* -----------------------------------------------------------------------------
*
* Program: Table_BotE_EV
*
* The program computes the impact (energy and financial from an aggregator's 
* viewpoint) of EV flexibility contracts (16 combinations) based on predicted 
* choice probabilities from the TIOLI design and based on assumptions outlined 
* in the paper and appendices 
*
* Notes:
*   - Calculates:
*       - Expected number of EVs participating per bundle
*       - Annual compensation costs (€M/year) [Aggregator]
*       - Effective power reduction (MW/event)
*       - Total capacity value (€/year) under a CRM
*       - Energy consumption reduction (GWh) 
*       - DAM load shifting value (€/year) using Belgian 2023 prices.
*         Values for dam_pr_8_X are pasted from results of 'Script_Cost_effectiveness_calc.do'.
*       - Net profit (capacity + load shifting – cost) [Aggregator]
*
* Outputs:
*  - "$resultsDir/Table_5.csv"
*  - "$resultsDir/Table_5.tex"
* -----------------------------------------------------------------------------

version 17

use "$intermediateDir/full_design_EV_tioli_with_probas", clear

// Parameters
local increment_number_ev = 1000000
local avg_power_EV_kW = 7.4
local pi_cap_MW = 32000
local p_charging = 0.15

local p_below_R200 = 0.06
local p_below_R50 = 0.03
local delta = 0.5

local P_eff_R200 = `avg_power_EV_kW' * `p_charging' * (1 - `p_below_R200')
local P_eff_R50 = `avg_power_EV_kW' * `p_charging' * (1 - `p_below_R50')

// Mean DAM prices for different frequencies (pasted from 'Script_Cost_effectiveness_calc.do' results)
scalar dam_pr_8_1 = .2367637
scalar dam_pr_8_6 = .2233287
scalar dam_pr_8_12 = .2133345
scalar dam_pr_8_52 = .1842119

// Define the 16 combinations
local range_vals "50 200"
local euro_vals "3 20"
local freq_vals "1 6 12 52"

// Step 1: Create bundles and calculate probabilities
local bundle_num = 0
foreach r of local range_vals {
	foreach e of local euro_vals {
		foreach f of local freq_vals {
			local ++bundle_num
		   
			capture drop bundle`bundle_num'
			gen bundle`bundle_num' = (range_ev == `r' & euro_ev == `e' & freq_ev == `f' & alternative_index != 2)
		   
			sum proba_pool if bundle`bundle_num', meanonly
			scalar p_b`bundle_num' = r(mean)
		   
			scalar r_b`bundle_num' = `r'
			scalar e_b`bundle_num' = `e'
			scalar f_b`bundle_num' = `f'
		}
	}
}

local total_bundles = `bundle_num'
di "Total bundles: `total_bundles'"

// Probability matrix
matrix EV = J(`total_bundles', 1, .)
forvalues b = 1/`total_bundles' {
	matrix EV[`b',1] = p_b`b'
}
matrix colnames EV = proba_pool

local rownames ""
forvalues b = 1/`total_bundles' {
	local rownames `"`rownames' "B`b'(R`=scalar(r_b`b')'E`=scalar(e_b`b')'F`=scalar(f_b`b')')""'
}
matrix rownames EV = `rownames'

matlist EV, format(%6.3f)

// Step 2: Amount in thousands of EVs [in 1000 EVs]
forvalues b = 1/`total_bundles' {
	scalar amt_b`b' = p_b`b' * (`increment_number_ev'/1000)
}

// Step 3: Annual compensation costs [in €M/year]
forvalues b = 1/`total_bundles' {
	scalar cost_b`b' = (amt_b`b' * 1000) * e_b`b' * f_b`b' / 10^6
}

// Step 4: Total effective power reduction [in MW/event]
forvalues b = 1/`total_bundles' {
	if r_b`b' == 50 {
		scalar mw_b`b' = (amt_b`b' * 1000) * `P_eff_R50' / 10^3
	}
	else {
		scalar mw_b`b' = (amt_b`b' * 1000) * `P_eff_R200' / 10^3
	}
}

// Step 5: Total capacity value [in €M/year]
forvalues b = 1/`total_bundles' {
	scalar cap_b`b' = mw_b`b' * `pi_cap_MW' / 10^6
}

// Step 6: Total effective energy consumption reduction
forvalues b = 1/`total_bundles' {
	if r_b`b' == 50 {
		scalar gwh_b`b' = (`P_eff_R50'/1000) * 8 * f_b`b' * (amt_b`b'*1000) / 10^3
	}
	else {
		scalar gwh_b`b' = (`P_eff_R200'/1000) * 8 * f_b`b' * (amt_b`b'*1000) / 10^3
	}
}

// Step 7: Total DAM load shifting value [in €M/year]
forvalues b = 1/`total_bundles' {
	if f_b`b' == 1 {
		scalar ls_b`b' = gwh_b`b' * (dam_pr_8_1 * 10^6) * (1 - `delta') / 10^6
	}
	else if f_b`b' == 6 {
		scalar ls_b`b' = gwh_b`b' * (dam_pr_8_6 * 10^6) * (1 - `delta') / 10^6
	}
	else if f_b`b' == 12 {
		scalar ls_b`b' = gwh_b`b' * (dam_pr_8_12 * 10^6) * (1 - `delta') / 10^6
	}
	else if f_b`b' == 52 {
		scalar ls_b`b' = gwh_b`b' * (dam_pr_8_52 * 10^6) * (1 - `delta') / 10^6
	}
}

// Create final table
preserve
	tempfile T
	postfile p int bundle int range_ev int euro_ev int freq_ev ///
		double amount double P_MW double E_per_call ///
		double V_cap double V_en double cost double net_profit ///
		using `T', replace

	forvalues b = 1/`total_bundles' {
		local E_per_call = (gwh_b`b' / f_b`b') * 10^3 // [MWh/call]
		local net_profit = cap_b`b' + ls_b`b' - cost_b`b'
	   
		post p ///
			(`b') (r_b`b') (e_b`b') (f_b`b') ///
			(amt_b`b') (mw_b`b') (`E_per_call') ///
			(cap_b`b') (ls_b`b') (cost_b`b') (`net_profit')
	}
	postclose p

	use `T', clear
   
	order bundle range_ev euro_ev freq_ev amount P_MW E_per_call V_cap V_en cost net_profit

	format amount P_MW V_cap V_en cost net_profit %12.1f
	format E_per_call %12.2f
   
	sort bundle
   
	list, noobs abbreviate(20) sep(4)
   
	//export delimited using "$resultsDir/Table_5.csv", replace
   
	file open texfile using "$resultsDir/Table_5.tex", write replace
	file write texfile "\begin{tabular}{rrrrrrrrrrr}" _n
	file write texfile "\hline" _n
	file write texfile "Range & Euro & Freq & Amount & P\_MW & E/Call & V\_cap & V\_en & Cost & Net Profit \\" _n
	file write texfile "\hline" _n
   
	forvalues i = 1/`=_N' {
		file write texfile (range_ev[`i']) " & " (euro_ev[`i']) " & " ///
			(freq_ev[`i']) " & " %9.1f (amount[`i']) " & " %9.1f (P_MW[`i']) " & " ///
			%9.2f (E_per_call[`i']) " & " %9.1f (V_cap[`i']) " & " ///
			%9.1f (V_en[`i']) " & " %9.1f (cost[`i']) " & " %9.1f (net_profit[`i']) " \\" _n
	}
   
	file write texfile "\hline" _n
	file write texfile "\end{tabular}" _n
	file close texfile
   
restore
   
end

capture program drop Table_BotE_HP
program define Table_BotE_HP

* -----------------------------------------------------------------------------
*
* Program: Table_BotE_HP
*
* The program computes the impact (energy and financial from an aggregator's 
* viewpoint) of HP flexibility contracts (16 combinations) based on predicted 
* choice probabilities from the TIOLI design and based on assumptions outlined 
* in the paper and appendices 
*
* Notes:
*   - Calculates:
*       - Expected number of HPs participating per bundle
*       - Annual compensation costs (€M/year) [Aggregator]
*       - Effective power reduction (MW/event)
*       - Total capacity value (€/year) under a CRM
*       - Energy consumption reduction (GWh) 
*       - DAM load shifting value (€/year) using Belgian 2023 prices.
*         Values for dam_pr_[4,14]_X are pasted from results of 'Script_Cost_effectiveness_calc.do'.
*       - Net profit (capacity + load shifting – cost) [Aggregator]
*
* Outputs:
*  - "$resultsDir/Table_6.csv"
*  - "$resultsDir/Table_6.tex"
* -----------------------------------------------------------------------------

use "$intermediateDir/full_design_HP_tioli_with_probas", clear

// Parameters
local increment_number_hp = 1000000
local avg_power_HP_kW = 0.45
local pi_cap_MW = 32000
local p_below_T19 = 0.42
local p_below_T16 = 0.07
local delta = 0.5

local P_eff_T19 = `avg_power_HP_kW' * (1 - `p_below_T19')
local P_eff_T16 = `avg_power_HP_kW' * (1 - `p_below_T16')

// Mean DAM prices for different frequencies
scalar dam_pr_4_1 = .2519925
scalar dam_pr_4_6 = .2422217
scalar dam_pr_4_12 = .2330069
scalar dam_pr_4_52 = .2039769

scalar dam_pr_14_1 = .2331421
scalar dam_pr_14_6 = .2161788
scalar dam_pr_14_12 = .2034048
scalar dam_pr_14_52 = .1695265

// Define the 16 combinations
local temp_vals "16 19"
local euro_vals "1 4"
local freq_vals "1 6 12 52"

// Step 1: Create bundles and calculate probabilities
local bundle_num = 0
foreach t of local temp_vals {
	foreach e of local euro_vals {
		foreach f of local freq_vals {
			local ++bundle_num
		   
			capture drop bundle`bundle_num'
			gen bundle`bundle_num' = (temp_hp == `t' & euro_hp == `e' & freq_hp == `f' & alternative_index != 2)
		   
			sum proba_pool if bundle`bundle_num', meanonly
			scalar p_b`bundle_num' = r(mean)
		   
			scalar t_b`bundle_num' = `t'
			scalar e_b`bundle_num' = `e'
			scalar f_b`bundle_num' = `f'
		}
	}
}

local total_bundles = `bundle_num'

// Probability matrix
matrix HP = J(`total_bundles', 1, .)
forvalues b = 1/`total_bundles' {
	matrix HP[`b',1] = p_b`b'
}
matrix colnames HP = proba_pool

local rownames ""
forvalues b = 1/`total_bundles' {
	local rownames `"`rownames' "B`b'(T`=scalar(t_b`b')'E`=scalar(e_b`b')'F`=scalar(f_b`b')')""'
}
matrix rownames HP = `rownames'

matlist HP, format(%6.3f)

// Step 2: Amount [in 1000 HPs]
forvalues b = 1/`total_bundles' {
	scalar amt_b`b' = p_b`b' * (`increment_number_hp'/1000)
}

// Step 3: Annual compensation costs [in €M/year]
forvalues b = 1/`total_bundles' {
	scalar cost_b`b' = (amt_b`b' * 1000) * (e_b`b') * f_b`b' / 10^6 
}

// Step 4: Total effective power reduction [in MW/event]
forvalues b = 1/`total_bundles' {
	if t_b`b' == 16 {
		scalar mw_b`b' = (amt_b`b' * 1000) * `P_eff_T16' / 10^3
	}
	else {
		scalar mw_b`b' = (amt_b`b' * 1000) * `P_eff_T19' / 10^3
	}
}

// Step 5: Total capacity value [in €M/year]
forvalues b = 1/`total_bundles' {
	scalar cap_b`b' = mw_b`b' * `pi_cap_MW' / 10^6
}

// Step 6: Total effective energy consumption reduction [in GWh/year]
forvalues b = 1/`total_bundles' {
	if t_b`b' == 16 {
		scalar gwh_b`b' = (`P_eff_T16'/1000) * 14 * f_b`b' * (amt_b`b'*1000) / 10^3
	}
	else {
		scalar gwh_b`b' = (`P_eff_T19'/1000) * 4 * f_b`b' * (amt_b`b'*1000) / 10^3
	}
}

// Step 7: Total DAM load shifting value [in €M/year]
forvalues b = 1/`total_bundles' {
	if t_b`b' == 16 {
		if f_b`b' == 1 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_14_1 * 10^6) * (1 - `delta') / 10^6
		}
		else if f_b`b' == 6 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_14_6 * 10^6) * (1 - `delta') / 10^6
		}
		else if f_b`b' == 12 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_14_12 * 10^6) * (1 - `delta') / 10^6
		}
		else if f_b`b' == 52 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_14_52 * 10^6) * (1 - `delta') / 10^6
		}
	}
	else {
		if f_b`b' == 1 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_4_1 * 10^6) * (1 - `delta') / 10^6
		}
		else if f_b`b' == 6 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_4_6 * 10^6) * (1 - `delta') / 10^6
		}
		else if f_b`b' == 12 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_4_12 * 10^6) * (1 - `delta') / 10^6
		}
		else if f_b`b' == 52 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_4_52 * 10^6) * (1 - `delta') / 10^6
		}
	}
}

// Create final table
preserve
	tempfile T
	postfile p int bundle int temp_hp int euro_hp int freq_hp ///
		double amount double P_MW double E_per_call ///
		double V_cap double V_en double cost double net_profit ///
		using `T', replace

	forvalues b = 1/`total_bundles' {
		local E_per_call = (gwh_b`b' / f_b`b') * 10^3 // [MWh/call]
		local net_profit = cap_b`b' + ls_b`b' - cost_b`b'
	   
		post p ///
			(`b') (t_b`b') (e_b`b') (f_b`b') ///
			(amt_b`b') (mw_b`b') (`E_per_call') ///
			(cap_b`b') (ls_b`b') (cost_b`b') (`net_profit')
	}
	postclose p

	use `T', clear
   
	order bundle temp_hp euro_hp freq_hp amount P_MW E_per_call V_cap V_en cost net_profit

	format amount P_MW V_cap V_en cost net_profit %12.1f
	format E_per_call %12.2f
   
	sort bundle
   
	list, noobs abbreviate(20) sep(4)
   
	//export delimited using "$resultsDir/Table_6.csv", replace
   
	file open texfile using "$resultsDir/Table_6.tex", write replace
	file write texfile "\begin{tabular}{rrrrrrrrrrr}" _n
	file write texfile "\hline" _n
	file write texfile "Temp & Euro & Freq & Amount & P\_MW & E/Call & V\_cap & V\_en & Cost & Net Profit \\" _n
	file write texfile "\hline" _n
   
	forvalues i = 1/`=_N' {
		file write texfile (temp_hp[`i']) " & " (euro_hp[`i']) " & " ///
			(freq_hp[`i']) " & " %9.1f (amount[`i']) " & " %9.1f (P_MW[`i']) " & " ///
			%9.2f (E_per_call[`i']) " & " %9.1f (V_cap[`i']) " & " ///
			%9.1f (V_en[`i']) " & " %9.1f (cost[`i']) " & " %9.1f (net_profit[`i']) " \\" _n
	}
   
	file write texfile "\hline" _n
	file write texfile "\end{tabular}" _n
	file close texfile
   
restore
   
end

Table_BotE_EV
Table_BotE_HP

*-----------------------------*
* 6.3 Cost-effectiveness of flexibility contracts 
*-----------------------------*

do "$root/Script_Cost_effectiveness_calc.do"

*-----------------------------*
* Appendices
*-----------------------------*

***** Appendix A: /

***** Appendix B: /

***** Appendix C: /

***** Appendix D: Diagnostic checks for individual-level parameters

capture program drop App_D_computation_rho_ratio
program define App_D_computation_rho_ratio, rclass

*----------------------------------------------------------*
* 
* Program: App_D_computation_rho_ratio
*
* This program computes the ratio between conditional and
* unconditional moments (mean and standard deviation) of a
* given preference parameter estimated in (pooled) mixed logit
* models with correlated random coefficients.
* => These ratios are proposed by (Sarrias, 2020) as diagnostic checks to assess
*    whether posterior/conditional/individual-level parameters are valid to use
*    (i.e., are a good approximation of the unconditional parameter distribution). 
*
* Inputs:
*   - CE(string)    : choice experiment (EV/HP)
*   - PARAM(string) : parameter name (for the unconditional estimate)
*
* The program does the following:
*   - Conditional moments are computed from the posterior/conditional/ind.-level
*     coefficients (pooled model; preferred utility specification and estimator)
*   - Unconditional moments are extracted from the model estimates (idem)
*   - Rho ratios are defined as:
*       rho_mean = mean_cond / mean_uncond
*       rho_sd   = sd_cond   / sd_uncond
*
* Output:
*   - Results are displayed in the console directly
*
* Reference: 
* Mauricio Sarrias, Individual-specific posterior distributions from Mixed Logit
* models: Properties, limitations and diagnostic checks, 
* Journal of Choice Modelling, Volume 36, 2020, 100224, 
* https://doi.org/10.1016/j.jocm.2020.100224.
*
*----------------------------------------------------------*

version 17
syntax , CE(string) PARAM(string)

// Derived names
local condvar = "beta_`ce'_`param'"
local model   = "$estimationDir/save_pool_model2_`ce'_mix_corr.ster"
	
// Conditional statistics 
preserve
	use "$data", clear
	estimates use "`model'"
	mixlbeta `param', saving("$intermediateDir/temp") replace nrep(2000) burn(15)
	use "$intermediateDir/temp", clear 
	rename `param' `condvar'
	qui sum `condvar' 
	local mean_cond = r(mean)
	local sd_cond   = r(sd)
restore

// Unconditional statistics
estimates use "`model'"
local mean_uncond = _b[`param']
qui mixlcov, sd post
local sd_uncond = _b[`param']

// Ratios
local rho_mean = `mean_cond'/`mean_uncond'
local rho_sd   = `sd_cond'/`sd_uncond'

di as text "==> ce=`ce'  param=`param'"
di as text "   mean: cond/uncond = " as res %9.6f `rho_mean' ///
   as text "   (cond=" %9.6f `mean_cond' ", uncond=" %9.6f `mean_uncond' ")"
di as text "   sd  : cond/uncond = " as res %9.6f `rho_sd'   ///
   as text "   (cond=" %9.6f `sd_cond'   ", uncond=" %9.6f `sd_uncond'   ")"
   
// Delete temp file 

erase "$intermediateDir/temp.dta"
	     
end

App_D_computation_rho_ratio, ce(ev) param(range_50)
App_D_computation_rho_ratio, ce(hp) param(temp_16)

***** Appendix E: /

***** Appendix F: Subsample robustness and descriptive comparisons

// We must repeat the definition of the program summarize_enrollment_reasons 
// because at this stage it got erased from memory. Exact same code as above.
use "$data", clear
capture program drop summarize_enrollment_reasons
program define summarize_enrollment_reasons

*----------------------------------------------------------*
* Program: summarize_enrollment_reasons
*
* Identify and rank the top reasons to enroll and not to enroll in a 
* flexibility program. Results can be computed overall (pooled sample
* or by subgroup.
*
* Options:
*   - group(varname): compute results by group levels
*   - topn(integer) : number of top reasons reported (default = 3)
*
* Output:
*   - Console output: ranked mean importance and sample size
*
* Notes: 
*   - See the paper for full text for each decision factor
*----------------------------------------------------------*

version 17

syntax [, GRoup(varname) TOPn(integer 3)]

use "$data", clear
qui duplicates drop response_id, force

// Default: pooled analysis. If group is specified: analysis by subgroup

if "`group'" != "" {
	qui levelsof `group', local(groups)
}
else {
	local groups "all"
}

// For each group
foreach g of local groups {
   
	if "`g'" != "all" {
		local condition_base "if `group' == `g'"
		di "***** Sample: `group' = `g' "
	}
	else {
		local condition_base "if 1==1"
		di "***** Pooled sample"
	}
		
	* --------------------------------------------------
	* Reasons TO enroll
	* Here, we compute mean importance scores for each proposed decision factor, 
	* among respondents with high enrollment likelihood (statement_likelihood > 3).
	* Then, we rank reasons and display the top-N most cited motives.
	* --------------------------------------------------
	   
	di "--- Top `topn' reasons TO enroll ---"

	local reasons_pos environment independence stability compensation technologies comfort acquaintance

	// Store means with reason names
	tempname results
	matrix `results' = J(10, 2, .) // 10 is max, some cells are empty but not an issue
	local i = 1
	local reason_names ""

	foreach reason of local reasons_pos {
		qui sum reasons_why_`reason' `condition_base' & statement_likelihood > 3
			matrix `results'[`i', 1] = r(mean)
			matrix `results'[`i', 2] = r(N)
			local reason_names "`reason_names' `reason'" // We store names in a local since Stata does not allow text in matrices
														 // Creates a bijection element in matrix <-> reason name. More 'certain'
			local i = `i' + 1
	}

	local n_reasons = `i' - 1 							  // Total number of reasons

	// Mark all reasons as unused (0 = not yet displayed, 1 = already shown)
	forvalues i = 1/`n_reasons' {
		  local used_`i' = 0
	}

	// Find and display the top N reasons by descending mean score: 
	forvalues rank = 1/`=min(`topn', `n_reasons')' {
		  
		  local max_idx = .                               // Index of reason with highest score (not yet initialized)
				
		  // Search for the highest-scoring and unused (undisplayed) reason 
		  forvalues i = 1/`n_reasons' {                   
				if `used_`i'' == 0 {                      // Loop over all reasons not yet displayed
					if missing(`max_idx') | (`results'[`i',1] > `results'[`max_idx',1]) {
					  local max_idx = `i'                 // If max is missing or if the reason's score is higher than the current max then change the rank i
					}
			     }
		  }
				
		  // Now we have found the rank i: mark it as used and display: 
		  local used_`max_idx' = 1                         
		  local reason : word `max_idx' of `reason_names'  
		  di "  `rank'. `reason': " %5.3f `results'[`max_idx',1] " (N=" `results'[`max_idx', 2] ")"
	
	}
	
	* --------------------------------------------------
	* Reasons not TO enroll
	* Here, we compute mean importance scores for each proposed decision factor, 
	* among respondents with low enrollment likelihood (statement_likelihood < 3).
	* Then, we rank reasons and display the top-N most cited motives.
	* --------------------------------------------------
	   
	di "--- Top `topn' reasons NOT to enroll ---"	 
	
	local reasons_neg control comfort internet info damage too_low
	
	// Store means with reason names
	tempname results
	matrix `results' = J(10, 2, .) // 10 is max, some cells are empty but not an issue
	local i = 1
	local reason_names ""

	foreach reason of local reasons_neg {
		qui sum reasons_why_not_`reason' `condition_base' & statement_likelihood < 3
			matrix `results'[`i', 1] = r(mean)
			matrix `results'[`i', 2] = r(N)
			local reason_names "`reason_names' `reason'" // We store names in a local since Stata does not allow text in matrices
														 // Creates a bijection element in matrix <-> reason name. More 'certain'
			local i = `i' + 1
	}

	local n_reasons = `i' - 1 							  // Total number of reasons

	// Mark all reasons as unused (0 = not yet displayed, 1 = already shown)
	forvalues i = 1/`n_reasons' {
		  local used_`i' = 0
	}

	// Find and display the top N reasons by descending mean score: 
	forvalues rank = 1/`=min(`topn', `n_reasons')' {
		  
		  local max_idx = .                               // Index of reason with highest score (not yet initialized)
				
		  // Search for the highest-scoring and unused (undisplayed) reason 
		  forvalues i = 1/`n_reasons' {                   
				if `used_`i'' == 0 {                      // Loop over all reasons not yet displayed
					if missing(`max_idx') | (`results'[`i',1] > `results'[`max_idx',1]) {
					  local max_idx = `i'                 // If max is missing or if the reason's score is higher than the current max then change the rank i
					}
			     }
		  }
				
		  // Now we have found the rank i: mark it as used and display: 
		  local used_`max_idx' = 1                         
		  local reason : word `max_idx' of `reason_names'  
		  di "  `rank'. `reason': " %5.3f `results'[`max_idx',1] " (N=" `results'[`max_idx', 2] ")"  
		  
	}

}

end

*** Data for Table 8: 
summarize_enrollment_reasons, top(7) group(coop_channel) // Columns 1 and 2
summarize_enrollment_reasons, top(7)                     // Column 3

*** Figure 11:

capture program drop willingness_to_enroll_group
program define willingness_to_enroll_group

*----------------------------------------------------------*
* Figure 11: Distribution of stated likelihood responses across subgroups
* 
* Output:
*   - "$resultsDir/App_F_Figure_11.pdf" (note that the version presented
*      in the paper requires some manual editing for the labels)
*
* Notes: 
*   - Percentages displayed are computed within each group. In other words, 
*     they sum to 100% across all levels but within a given group. 
*----------------------------------------------------------*

use "$data", clear
	
duplicates drop response_id, force 
		
preserve
	
	// Compute percentages within cooperant channel
	bysort coop_channel statement_likelihood: gen count = _N
	bysort coop_channel: egen total = count(statement_likelihood)
	gen pct = (count / total) * 100

	// Keep only one observation per combination (artificially creating what I need)
	bysort coop_channel statement_likelihood: keep if _n == 1

	// Plot
	graph bar pct, over(coop_channel) over(statement_likelihood) asyvars ///
		bar(1, color(orange%40)) bar(2, color(blue%40)) ///
		legend( label(1 "Online panel") label(2 "Cooperants") order(2 1) pos(6) col(2)) ///
		ytitle("Percentage within subsample") xsize(8) ysize(8) bargap(10) ylabel(0(5)60, grid) saving("$resultsDir/App_F_Figure_11.gph", replace)
		// And then manual edit in the graph editor to clean the labels. 
		
	graph export "$resultsDir/App_F_Figure_11.pdf", replace

restore

end

willingness_to_enroll_group

*** Figure 12:

capture program drop control_asset_group
program define control_asset_group

* --------------------------------------------------
* Program: control_asset_group
*
* This script analyzes respondents' readiness to cede some degree of control 
* over a flexibility program in three domains: (1) EV charging, (2) heating,
* and (3) white goods use --- and all this across cooperant subgroups. 
*
* For each, the program generates stacked horizontal bar charts showing the 
* distribution of responses across the diffderent proposed levels of control
* ceding.
*
* White goods are pooled across proposed appliances (see the text for more
* details).
*
* Output:
*   - "$resultsDir/App_F_Figure_11.pdf": Combined panel with all three domains
*										 and two cooperant subgroups.
* --------------------------------------------------

version 17

use "$data", clear
duplicates drop response_id, force

gen coop_channel_cat = coop_channel
label define coopcats 0 "OP" 1  "Coop.", replace
label values coop_channel_cat coopcats 

* (1) MOBILITY
graph hbar, /// 
	over(degree_electric_mobility) /// 
	over(coop_channel_cat, gap(35) label(labcolor(black) angle(vertical))) ///
	stack asyvars /// 
	percentage ///
	ytitle(" ") ///
	blabel(bar, pos(center) format(%3.0f) size(medlarge) color(black)) /// 
	ylab(, nolabel notick glpattern(solid) glcolor(gs3) glwidth(vthin)) ///
	legend(off) ///
	graphregion(margin(vsmall)) ///
	l1title("{bf: (1) Mobility}", color(gs2) orientation(vertical) size(medlarge)) ///
	xsize(6.5) ysize(4.5) /// 
	bar(1, fintensity(100) fcolor(gray%90) lcolor(none) lwidth(thin)) ///
	bar(2, fintensity(100) fcolor(dimgray%90) lcolor(none) lwidth(thin)) ///
	bar(3, fintensity(100) fcolor(sandb%90) lcolor(none) lwidth(thin)) ///
	bar(4, fintensity(100) fcolor(gold%90) lcolor(none) lwidth(thin)) ///
	bar(5, fintensity(100) fcolor(dkorange%90) lcolor(none) lwidth(thin)) ///
	fysize(50) ///
	saving("$intermediateDir/App_F_g1", replace) 
		
* (2) HEATING
graph hbar, /// 
		over(degree_control_heating) /// 
		over(coop_channel_cat, gap(35) label(labcolor(black) angle(vertical))) ///
		stack asyvars /// 
		percentage ///
		ytitle(" ") ///
		ylab(, nolabel notick glpattern(solid) glcolor(gs3) glwidth(vthin)) ///
		blabel(bar, pos(center) format(%3.0f) size(medlarge) color(black)) /// 
		legend(off) ///
		graphregion(margin(vsmall)) ///
		l1title("{bf: (2) Heating}", color(gs2) orientation(vertical) size(medlarge)) ///
		xsize(6.5) ysize(4.5) /// 
		bar(1, fintensity(100) fcolor(gray%90) lcolor(none) lwidth(thin)) ///
		bar(2, fintensity(100) fcolor(dimgray%90) lcolor(none) lwidth(thin)) ///
		bar(3, fintensity(100) fcolor(sandb%90) lcolor(none) lwidth(thin)) ///
		bar(4, fintensity(100) fcolor(gold%90) lcolor(none) lwidth(thin)) ///
		bar(5, fintensity(100) fcolor(dkorange%90) lcolor(none) lwidth(thin)) ///
		fysize(50) ///
		saving("$intermediateDir/App_F_g2", replace) 
		
* (3) WHITE GOODS
preserve

* Ensure we have a clean id and keep only what we need
gen long __id = _n
keep __id coop_channel* degree_washing_machine degree_dishwasher degree_tumble_dryer degree_electric_oven

* Harmonize names for reshape
rename degree_washing_machine deg1
rename degree_dishwasher deg2
rename degree_tumble_dryer deg3
rename degree_electric_oven deg4

* Long format: one row per (person x appliance)
reshape long deg, i(__id) j(appliance)

* Keep nonmissing answers only
drop if missing(deg)

* Summies for categories 1..5 (create missing ones as zeros)
tab deg, generate(d)
forvalues k = 1/5 {
	capture confirm variable d`k'
	if _rc {
		gen byte d`k' = 0 // If variables don't exist, generate them 
	} 
}

* Shares within each (coop × appliance)
collapse (mean) d1 d2 d3 d4 d5, by(coop_channel_cat appliance)

* Average across the 4 appliances (equal weight)
collapse (mean) d1 d2 d3 d4 d5, by(coop_channel_cat)

* Reshape into long so levels become a variable
reshape long d, i(coop_channel_cat) j(level)

* Rename
rename d share

* Plot stacked bars: coop_channel_cat × level
graph hbar share, ///
	over(level) ///
	over(coop_channel_cat, gap(35) label(labcolor(black) angle(vertical))) ///
	stack asyvars percentage ///
	blabel(bar, pos(center) format(%3.0f) size(medlarge) color(black)) ///
	legend(off) ///
	graphregion(margin(vsmall)) ///
	l1title("{bf: (3) White goods}", color(gs2) orientation(vertical) size(medlarge)) ///
	ytitle(" ") ///
	ylab(, glpattern(solid) glcolor(gs3) glwidth(vthin) labsize(large)) ///
	xsize(6.5) ysize(4.5) /// graph dimensions
	bar(1, fintensity(100) fcolor(gray%90) lcolor(none) lwidth(thin)) ///
	bar(2, fintensity(100) fcolor(dimgray%90) lcolor(none) lwidth(thin)) ///
	bar(3, fintensity(100) fcolor(sandb%90) lcolor(none) lwidth(thin)) ///
	bar(4, fintensity(100) fcolor(gold%90) lcolor(none) lwidth(thin)) ///
	bar(5, fintensity(100) fcolor(dkorange%90) lcolor(none) lwidth(thin)) ///
	fysize(59) ///
	saving("$intermediateDir/App_F_g3", replace) 

restore

* Combine all three panels
graph combine "$intermediateDir/App_F_g1.gph" "$intermediateDir/App_F_g2.gph" "$intermediateDir/App_F_g3.gph", cols(1) ///
    ycommon graphregion(margin(small))

// graph save "$resultsDir/App_F_Figure_12.pdf".gph, replace // Necessary for manual editing. 
graph export "$resultsDir/App_F_Figure_12.pdf", replace

		// Manually extract legend from:
		
		use "$data", clear
		
		duplicates drop response_id, force

		gen coop_channel_cat = coop_channel
		label define coopcats 0 "OP" 1  "Coop.", replace
		label values coop_channel_cat coopcats 

		graph hbar, /// 
		over(degree_electric_mobility) /// 
		over(coop_channel_cat, gap(35) label(labcolor(black) angle(vertical))) ///
		stack asyvars /// 
		percentage ///
		ytitle(" ") ///
		blabel(bar, pos(center) format(%3.0f) size(medlarge) color(black)) /// 
		ylab(, nolabel notick glpattern(solid) glcolor(gs3) glwidth(vthin)) ///
		legend(pos(6) col(2) row(3) size(medlarge)) ///
		graphregion(margin(vsmall)) ///
		l1title("{bf: (1) Mobility}", color(gs2) orientation(vertical) size(medlarge)) ///
		xsize(6.5) ysize(4.5) /// 
		bar(1, fintensity(100) fcolor(gray%90) lcolor(none) lwidth(thin)) ///
		bar(2, fintensity(100) fcolor(dimgray%90) lcolor(none) lwidth(thin)) ///
		bar(3, fintensity(100) fcolor(sandb%90) lcolor(none) lwidth(thin)) ///
		bar(4, fintensity(100) fcolor(gold%90) lcolor(none) lwidth(thin)) ///
		bar(5, fintensity(100) fcolor(dkorange%90) lcolor(none) lwidth(thin)) 
		
		// To extract overall sample sizes: 
		tab degree_control if coop_channel == 1
		tab degree_control if coop_channel == 0

end

control_asset_group

*** Figure 13:

capture program drop average_daily_driving_group
program define average_daily_driving_group 

* --------------------------------------------------
* Program: average_daily_driving_group
*
* This script processes respondents' car usage data to compute the total
* daily driving distance across all household cars of households reporting
* using the car as their main transport mode. We do the following:
*   - Aggregate kilometers driven across all reported cars.
*   - Clean implausible values and missing codes.
*   - Plot a histogram of daily driving distance (truncated at 140 km).
* And all this across the two cooperants/online panel groups, separately, and
* then we overlay the two plots. 
*
* Output:
*   - "$resultsDir/App_F_Figure_13.pdf": Histogram of average daily driving distance
*                                        across the two groups. 
* --------------------------------------------------

version 17

use "$data", clear
duplicates drop response_id, force

* Prepare the data
local vars car_main_how_many_km_only_1 ///
    car_main_how_many_km_car_1_most ///
    car_main_how_many_km_car_2_most ///
    car_main_how_many_km_Cars_1_most ///
    car_main_how_many_km_Cars_2_most

local i = 1
foreach v of local vars {
    capture drop c`i'
    gen c`i' = `v' // Standardized names
    local ++i
}

forvalues j = 1/5 {
    replace c`j' = . if c`j' == -99 | c`j' == -999
}

* Clean the total daily driving distance across all household cars
capture drop total_km_if
egen total_km_if = rowtotal(c1 c2 c3 c4 c5)
replace total_km_if = . if total_km_if > 500
keep if total_km_if > 0

* Histogram: 
twoway ///
    (histogram total_km_if if coop_channel==1 & total_km_if <=140, ///
        width(10) percent ///
        fcolor(blue%40) lcolor(blue)) ///
    (histogram total_km_if if coop_channel==0 & total_km_if <=140, ///
        width(10) percent ///
        fcolor(orange%40) lcolor(orange)), ///
    legend(order(1 "Cooperants" 2 "Online panel") pos(6) cols(2)) ///
    xlabel(0(20)140) xtitle("Average daily driving distance (km)") ///
    xsize(8) ysize(8.6)
	
// graph save "$resultsDir/App_F_Figure_13.pdf".gph, replace
graph export "$resultsDir/App_F_Figure_13.pdf", replace

end

average_daily_driving_group

*** Figure 14: 

capture program drop minmax_indoor_temp_winter_group
program define minmax_indoor_temp_winter_group

*----------------------------------------------------------*
* 
* Program: minmax_indoor_temp_winter_group
*
* Cleans and visualizes household indoor heating temperatures for comfort in 
* Winter. Replaces implausible or inconsistent values with missing (.), then
* plots histograms of minimum and maximum temperatures --- and all this across
* the two groups (cooperants/online panel respondents).
*
* Output:
*   - "$resultsDir/App_F_Figure_14_left.pdf" and
*     "$resultsDir/App_F_Figure_14_right.pdf": Overlapping histograms of 
*     winter min and max indoor temperatures (% of households) for cooperants
*     (left) and online panel respondents (right).
*
* Notes:
*   - Minimum temperatures below 14°C are treated as implausible.
*   - Maximum temperatures below the minimum or below 18°C are treated as missing.
*----------------------------------------------------------*

version 17

use "$data", clear
duplicates drop response_id, force

* Clean data
replace heating_winter_min_temp = . if heating_winter_min_temp < 14
replace heating_winter_max_temp = . if heating_winter_max_temp < heating_winter_min_temp
replace heating_winter_max_temp = . if heating_winter_max_temp < 18

// Plot:

* Cooperants: 

twoway ///
    (hist heating_winter_min_temp if coop_channel == 1 & inrange(heating_winter_min_temp, 14.5, 22), ///
        width(1) start(14.5) percent ///
        fcolor(blue%40) lcolor(blue%70)) ///
    (hist heating_winter_max_temp if  coop_channel == 1 & inrange(heating_winter_max_temp, 14.5, 28), ///
        width(1) start(14.5) percent ///
        fcolor(red%40) lcolor(red%70)), ///
    legend(order(1 "Min" 2 "Max") position(2) ring(0)) ///
    xlabel(15(1)28, grid) ///
    xscale(range(15 28)) ///
    xtitle("Indoor comfort temperature in Winter (°C)") ///
    ytitle("Percent") ylabel(0(5)30) ///
    xsize(8) ysize(8.6)
	
// graph save "$resultsDir/App_F_Figure_14_left.gph", replace
graph export "$resultsDir/App_F_Figure_14_left.pdf", replace

* Online panel respondents: 

twoway ///
    (hist heating_winter_min_temp if coop_channel == 0 & inrange(heating_winter_min_temp, 14.5, 22), ///
        width(1) start(14.5) percent ///
        fcolor(blue%40) lcolor(blue%70)) ///
    (hist heating_winter_max_temp if  coop_channel == 0 & inrange(heating_winter_max_temp, 14.5, 28), ///
        width(1) start(14.5) percent ///
        fcolor(red%40) lcolor(red%70)), ///
    legend(order(1 "Min" 2 "Max") position(2) ring(0)) ///
    xlabel(15(1)28, grid) ///
    xscale(range(15 28)) ///
    xtitle("Indoor comfort temperature in Winter (°C)") ///
    ytitle("Percent") ylabel(0(5)30) ///
    xsize(8) ysize(8.6)
	
// graph save "$resultsDir/App_F_Figure_14_right.gph", replace
graph export "$resultsDir/App_F_Figure_14_right.pdf", replace

end

minmax_indoor_temp_winter_group

***** Appendix G: Utility specification and choice-structure tests

capture program drop App_G_Table_9
program define App_G_Table_9

* -----------------------------------------------------------------------------
*
* Program: App_G_Table_9
*
* Collects log-likelihood, AIC, and BIC from choice models on pooled sample
* (CL, MIXL, MIXL with correlated random coefficients; all with preferred
* utility specification) for EV and HP choice experiments, and exports results 
* to a LaTeX table.
*
* Input: Stata estimation results (.ster) in "$estimationDir"
* Output: LaTeX file "$resultsDir/App_G_Table_9.tex"
* -----------------------------------------------------------------------------

version 17

    * Gather statistics...
    
    foreach choice in hp ev {
        foreach modeltype in mnl mix mix_corr {
            foreach m in 1 2 3 {
                
                * Load the model
                estimates use "$estimationDir/save_pool_model`m'_`choice'_`modeltype'.ster"
                
                * Extract LL, AIC, BIC
                estat ic
                
                local ll_`choice'_`modeltype'_`m' = string(r(S)[1,3], "%9.1f")
                local aic_`choice'_`modeltype'_`m' = string(r(S)[1,5], "%9.1f")
                local bic_`choice'_`modeltype'_`m' = string(r(S)[1,6], "%9.1f")
                
            }
        }
    }
    
    * ... and store them in a Latex Table.
    
    local filename "$resultsDir/App_G_Table_9.tex"
    capture file close texfile
    file open texfile using "`filename'", write replace
    
    * Header
    file write texfile "\begin{table}[ht]" _n
    file write texfile "\centering" _n
    file write texfile "\begin{threeparttable}" _n
    file write texfile "\caption{Model selection criteria for choice experiments (pooled sample)}\label{tab:model_selection}" _n
    file write texfile "\begin{tabular}{ccccc}" _n
    file write texfile "\toprule" _n
    file write texfile "\makecell{\textbf{Estimation}\\\textbf{method}} & \textbf{Model} & \textbf{LL} & \textbf{AIC} & \textbf{BIC} \\" _n
    file write texfile "\midrule" _n
    
    * PANEL A: HP
    file write texfile "\multicolumn{5}{l}{\textbf{Panel A:} Heat pump flexibility choice experiment} \\" _n
    file write texfile "\midrule" _n
    
    * MNL
    file write texfile "\multirow{3}{*}{CL} " _n
    file write texfile "& Model 1 & `ll_hp_mnl_1' & `aic_hp_mnl_1' & `bic_hp_mnl_1' \\" _n
    file write texfile "& Model 2 & `ll_hp_mnl_2' & `aic_hp_mnl_2' & `bic_hp_mnl_2' \\" _n
    file write texfile "& Model 3 & `ll_hp_mnl_3' & `aic_hp_mnl_3' & `bic_hp_mnl_3' \\" _n
    file write texfile "\midrule" _n
    
    * MIXL
    file write texfile "\multirow{3}{*}{MIXL} " _n
    file write texfile "& Model 1 & `ll_hp_mix_1' & `aic_hp_mix_1' & `bic_hp_mix_1' \\" _n
    file write texfile "& Model 2 & `ll_hp_mix_2' & `aic_hp_mix_2' & `bic_hp_mix_2' \\" _n
    file write texfile "& Model 3 & `ll_hp_mix_3' & `aic_hp_mix_3' & `bic_hp_mix_3' \\" _n
    file write texfile "\midrule" _n
    
    * MIXL correlated
    file write texfile "\multirow{3}{*}{\begin{tabular}[c]{@{}c@{}}MIXL\\(correlated)\end{tabular}} " _n
    file write texfile "& Model 1 & `ll_hp_mix_corr_1' & `aic_hp_mix_corr_1' & `bic_hp_mix_corr_1' \\" _n
    file write texfile "& Model 2 & `ll_hp_mix_corr_2' & `aic_hp_mix_corr_2' & `bic_hp_mix_corr_2' \\" _n
    file write texfile "& Model 3 & `ll_hp_mix_corr_3' & `aic_hp_mix_corr_3' & `bic_hp_mix_corr_3' \\" _n
    file write texfile "\midrule" _n
    
    * PANEL B: EV
    file write texfile "\multicolumn{5}{l}{\textbf{Panel B:} Electric vehicle flexibility choice experiment} \\" _n
    file write texfile "\midrule" _n
    
    * MNL
    file write texfile "\multirow{3}{*}{CL} " _n
    file write texfile "& Model 1 & `ll_ev_mnl_1' & `aic_ev_mnl_1' & `bic_ev_mnl_1' \\" _n
    file write texfile "& Model 2 & `ll_ev_mnl_2' & `aic_ev_mnl_2' & `bic_ev_mnl_2' \\" _n
    file write texfile "& Model 3 & `ll_ev_mnl_3' & `aic_ev_mnl_3' & `bic_ev_mnl_3' \\" _n
    file write texfile "\midrule" _n
    
    * MIXL
    file write texfile "\multirow{3}{*}{MIXL} " _n
    file write texfile "& Model 1 & `ll_ev_mix_1' & `aic_ev_mix_1' & `bic_ev_mix_1' \\" _n
    file write texfile "& Model 2 & `ll_ev_mix_2' & `aic_ev_mix_2' & `bic_ev_mix_2' \\" _n
    file write texfile "& Model 3 & `ll_ev_mix_3' & `aic_ev_mix_3' & `bic_ev_mix_3' \\" _n
    file write texfile "\midrule" _n
    
    * MIXL correlated
    file write texfile "\multirow{3}{*}{\begin{tabular}[c]{@{}c@{}}MIXL\\(correlated)\end{tabular}} " _n
    file write texfile "& Model 1 & `ll_ev_mix_corr_1' & `aic_ev_mix_corr_1' & `bic_ev_mix_corr_1' \\" _n
    file write texfile "& Model 2 & `ll_ev_mix_corr_2' & `aic_ev_mix_corr_2' & `bic_ev_mix_corr_2' \\" _n
    file write texfile "& Model 3 & `ll_ev_mix_corr_3' & `aic_ev_mix_corr_3' & `bic_ev_mix_corr_3' \\" _n
    
    * Footer
    file write texfile "\bottomrule" _n
    file write texfile "\end{tabular}" _n
    file write texfile "\begin{tablenotes}[flushleft]" _n
    file write texfile "\footnotesize" _n
    file write texfile "\item \textit{Notes:} [notes]." _n
    file write texfile "\end{tablenotes}" _n
    file write texfile "\end{threeparttable}" _n
    file write texfile "\end{table}" _n
    
    file close texfile
    
end

capture program drop App_G_Table_10
program define App_G_Table_10

* -----------------------------------------------------------------------------
*
* Program: App_G_Table_10
*
* Computes relative improvement in model fit (LL, AIC, BIC) of MIXL and MIXL
* correlated models compared to the baseline multinomial/conditional logit 
* (CL/MNL, both names are equivalent) for EV and HP choice experiments, and 
* exports results to a LaTeX table.
*
* Input: Stata estimation results (.ster) in "$estimationDir"
* Output: LaTeX file "$resultsDir/App_G_Table_10.tex"
* -----------------------------------------------------------------------------

version 17

    * Gather baseline's statistics...
    
    foreach choice in hp ev {
        foreach m in 1 2 3 {
            
            * Load the multinomial/conditional logit model's statistics as baseline
            estimates use "$estimationDir/save_pool_model`m'_`choice'_mnl.ster"
            estat ic
            
            local ll_`choice'_mnl_`m'_base = r(S)[1,3]
            local aic_`choice'_mnl_`m'_base = r(S)[1,5]
            local bic_`choice'_mnl_`m'_base = r(S)[1,6]
            
        }
    }
    
    * ... compute relative improvements...
    
    foreach choice in hp ev {
        foreach modeltype in mix mix_corr {
            foreach m in 1 2 3 {
                
                * Load the model
                estimates use "$estimationDir/save_pool_model`m'_`choice'_`modeltype'.ster"
                estat ic
                
                * Compute ratios of relative improvement wrp to baseline: 1 - (value / baseline_MNL)
                local ll_`choice'_`modeltype'_`m'_rel = 1 - (r(S)[1,3] / `ll_`choice'_mnl_`m'_base')
                local aic_`choice'_`modeltype'_`m'_rel = 1 - (r(S)[1,5] / `aic_`choice'_mnl_`m'_base')
                local bic_`choice'_`modeltype'_`m'_rel = 1 - (r(S)[1,6] / `bic_`choice'_mnl_`m'_base')
                
                * Formatting
                local ll_`choice'_`modeltype'_`m'_rel = string(`ll_`choice'_`modeltype'_`m'_rel' * 100, "%5.1f")
                local aic_`choice'_`modeltype'_`m'_rel = string(`aic_`choice'_`modeltype'_`m'_rel' * 100, "%5.1f")
                local bic_`choice'_`modeltype'_`m'_rel = string(`bic_`choice'_`modeltype'_`m'_rel' * 100, "%5.1f")
                
            }
        }
    }
    
    * ... and store them in a Latex table.
	
    local filename "$resultsDir/App_G_Table_10.tex"
    capture file close texfile
    file open texfile using "`filename'", write replace
    
    * Header
    file write texfile "\begin{table}[ht]" _n
    file write texfile "\centering" _n
    file write texfile "\begin{threeparttable}" _n
    file write texfile "\caption{Relative improvement in model fit compared to CL baseline (\%)}\label{tab:model_selection_relative}" _n
    file write texfile "\begin{tabular}{ccccc}" _n
    file write texfile "\toprule" _n
    file write texfile "\makecell{\textbf{Estimation}\\\textbf{method}} & \textbf{Model} & \textbf{LL (\%)} & \textbf{AIC (\%)} & \textbf{BIC (\%)} \\" _n
    file write texfile "\midrule" _n
    
    * PANEL A: HP
    
    file write texfile "\multicolumn{5}{l}{\textbf{Panel A:} Heat pump flexibility choice experiment} \\" _n
    file write texfile "\midrule" _n
    
    * MNL (baseline = 0)
    file write texfile "\multirow{3}{*}{\begin{tabular}[c]{@{}c@{}}CL\\(baseline)\end{tabular}}  " _n
    file write texfile "& Model 1 & — & — & — \\" _n
    file write texfile "& Model 2 & — & — & — \\" _n
    file write texfile "& Model 3 & — & — & — \\" _n
    file write texfile "\midrule" _n
    
    * MIXL
    file write texfile "\multirow{3}{*}{MIXL} " _n
    file write texfile "& Model 1 & `ll_hp_mix_1_rel' & `aic_hp_mix_1_rel' & `bic_hp_mix_1_rel' \\" _n
    file write texfile "& Model 2 & `ll_hp_mix_2_rel' & `aic_hp_mix_2_rel' & `bic_hp_mix_2_rel' \\" _n
    file write texfile "& Model 3 & `ll_hp_mix_3_rel' & `aic_hp_mix_3_rel' & `bic_hp_mix_3_rel' \\" _n
    file write texfile "\midrule" _n
    
    * MIXL correlated
    file write texfile "\multirow{3}{*}{\begin{tabular}[c]{@{}c@{}}MIXL\\(correlated)\end{tabular}} " _n
    file write texfile "& Model 1 & `ll_hp_mix_corr_1_rel' & `aic_hp_mix_corr_1_rel' & `bic_hp_mix_corr_1_rel' \\" _n
    file write texfile "& Model 2 & `ll_hp_mix_corr_2_rel' & `aic_hp_mix_corr_2_rel' & `bic_hp_mix_corr_2_rel' \\" _n
    file write texfile "& Model 3 & `ll_hp_mix_corr_3_rel' & `aic_hp_mix_corr_3_rel' & `bic_hp_mix_corr_3_rel' \\" _n
    file write texfile "\midrule" _n
    
    * PANEL B: EV

    file write texfile "\multicolumn{5}{l}{\textbf{Panel B:} Electric vehicle flexibility choice experiment} \\" _n
    file write texfile "\midrule" _n
    
    * MNL (baseline = 0)
    file write texfile "\multirow{3}{*}{\begin{tabular}[c]{@{}c@{}}CL\\(baseline)\end{tabular}}  " _n
    file write texfile "& Model 1 & — & — & — \\" _n
    file write texfile "& Model 2 & — & — & — \\" _n
    file write texfile "& Model 3 & — & — & — \\" _n
    file write texfile "\midrule" _n
    
    * MIXL
    file write texfile "\multirow{3}{*}{MIXL} " _n
    file write texfile "& Model 1 & `ll_ev_mix_1_rel' & `aic_ev_mix_1_rel' & `bic_ev_mix_1_rel' \\" _n
    file write texfile "& Model 2 & `ll_ev_mix_2_rel' & `aic_ev_mix_2_rel' & `bic_ev_mix_2_rel' \\" _n
    file write texfile "& Model 3 & `ll_ev_mix_3_rel' & `aic_ev_mix_3_rel' & `bic_ev_mix_3_rel' \\" _n
    file write texfile "\midrule" _n
    
    * MIXL correlated
    file write texfile "\multirow{3}{*}{\begin{tabular}[c]{@{}c@{}}MIXL\\(correlated)\end{tabular}} " _n
    file write texfile "& Model 1 & `ll_ev_mix_corr_1_rel' & `aic_ev_mix_corr_1_rel' & `bic_ev_mix_corr_1_rel' \\" _n
    file write texfile "& Model 2 & `ll_ev_mix_corr_2_rel' & `aic_ev_mix_corr_2_rel' & `bic_ev_mix_corr_2_rel' \\" _n
    file write texfile "& Model 3 & `ll_ev_mix_corr_3_rel' & `aic_ev_mix_corr_3_rel' & `bic_ev_mix_corr_3_rel' \\" _n
    
    * Footer
    file write texfile "\bottomrule" _n
    file write texfile "\end{tabular}" _n
    file write texfile "\begin{tablenotes}[flushleft]" _n
    file write texfile "\footnotesize" _n
    file write texfile "\item \textit{Notes:} [notes]" _n
    file write texfile "\end{tablenotes}" _n
    file write texfile "\end{threeparttable}" _n
    file write texfile "\end{table}" _n
    
    file close texfile
       
end

App_G_Table_9
App_G_Table_10

capture program drop model_comparisons
program define model_comparisons, rclass

* -----------------------------------------------------------------------------
*
* Program: model_comparisons
*
* Performs a likelihood-ratio (LR) test between two nested models cf Eq. (24) in 
* the paper. This assumes models tested are nested.
*
* Inputs:
*   - Two stored estimation results.
*
* Outputs (returned scalars):
*   - chi2 : LR test statistic
*   - df   : Degrees of freedom (number of restrictions to impose for nesting)
*   - crit : 95% chi-square critical value
*   - p    : p-value of the LR test
*
* -----------------------------------------------------------------------------

version 17

    syntax namelist(min=2 max=2)

    local est1 : word 1 of `namelist'
    local est2 : word 2 of `namelist'

    * Restore the first estimates
    qui estimates restore `est1'
    local ll1 = e(ll)
    local k1  = e(k)

    * Restore the second estimates
    qui estimates restore `est2'
    local ll2 = e(ll)
    local k2  = e(k)

    * Identify unrestricted vs restricted by number of parameters
    if `k1' > `k2' {
        local ll_unrestricted = `ll1'
        local k_unrestricted  = `k1'
        local ll_restricted   = `ll2'
        local k_restricted    = `k2'
    }
    else {
        local ll_unrestricted = `ll2'
        local k_unrestricted  = `k2'
        local ll_restricted   = `ll1'
        local k_restricted    = `k1'
    }

    * Compute LR statistic
    local lr_stat = 2 * (`ll_unrestricted' - `ll_restricted')

    * Degrees of freedom
    local df = `k_unrestricted' - `k_restricted'
             
    * Critical value at 95%
    local crit = invchi2(`df', 0.95)

    * p-value
    local pval = chi2tail(`df', `lr_stat')

    * Return results
    return scalar chi2 = `lr_stat'
    return scalar df = `df'
    return scalar crit = `crit'
    return scalar p = `pval'
end

capture program drop App_G_Table_model_comparison
program define App_G_Table_model_comparison
    
* -----------------------------------------------------------------------------
*
* Program: App_G_Table_model_comparison
*
* Computes likelihood-ratio (LR) tests between two NESTED models (m1 vs m2) 
* for each choice experiment, each estimator type (CL / MIXL / MIXL correlated),
* and each sample group. 
*
* Notes:
*   - Degrees of freedom are the same across groups for the same model comparison,
*     so the program reuses a single df value when reporting tables.
*
* Inputs:
*   - Two stored estimation results in "$estimationDir".
*
* Outputs:
*   - LaTeX table "$resultsDir/App_G_Table_Model`m1'_vs_Model`m2'.tex"
*     reporting LR statistics, degrees of freedom, and p-value
* -----------------------------------------------------------------------------
	
version 17
	
	args m1 m2

    * STEP 1: Load models and compute LR statistics
    
    foreach choice in hp ev {
        foreach modeltype in mnl mix mix_corr {
            
            * Cooperants (coop1)
            estimates use "$estimationDir/save_coop1_model`m1'_`choice'_`modeltype'.ster"
            estimates store temp_coop1_m`m1'_`choice'_`modeltype'
            estimates use "$estimationDir/save_coop1_model`m2'_`choice'_`modeltype'.ster"
            estimates store temp_coop1_m`m2'_`choice'_`modeltype'
            
            model_comparisons temp_coop1_m`m1'_`choice'_`modeltype' temp_coop1_m`m2'_`choice'_`modeltype'
            scalar lr_coop1_`choice'_`modeltype' = r(chi2)
            scalar df_coop1_`choice'_`modeltype' = r(df)
            scalar pval_coop1_`choice'_`modeltype' = r(p)
            
            * Online panel (coop0)
            estimates use "$estimationDir/save_coop0_model`m1'_`choice'_`modeltype'.ster"
            estimates store temp_coop0_m`m1'_`choice'_`modeltype'
            estimates use "$estimationDir/save_coop0_model`m2'_`choice'_`modeltype'.ster"
            estimates store temp_coop0_m`m2'_`choice'_`modeltype'
            
            model_comparisons temp_coop0_m`m1'_`choice'_`modeltype' temp_coop0_m`m2'_`choice'_`modeltype'
            scalar lr_coop0_`choice'_`modeltype' = r(chi2)
            scalar df_coop0_`choice'_`modeltype' = r(df)
            scalar pval_coop0_`choice'_`modeltype' = r(p)
            
            * Pooled
            estimates use "$estimationDir/save_pool_model`m1'_`choice'_`modeltype'.ster"
            estimates store temp_pool_m`m1'_`choice'_`modeltype'
            estimates use "$estimationDir/save_pool_model`m2'_`choice'_`modeltype'.ster"
            estimates store temp_pool_m`m2'_`choice'_`modeltype'
            
            model_comparisons temp_pool_m`m1'_`choice'_`modeltype' temp_pool_m`m2'_`choice'_`modeltype'
            scalar lr_pool_`choice'_`modeltype' = r(chi2)
            scalar df_pool_`choice'_`modeltype' = r(df)
            scalar pval_pool_`choice'_`modeltype' = r(p)
            
        }
    }
    
    * STEP 2: Write LaTeX table
    
    local filename "$resultsDir/App_G_Table_Model`m1'_vs_Model`m2'.tex"
    capture file close texfile
    file open texfile using "`filename'", write replace
    
    * Header
    file write texfile "\begin{table}[ht]" _n
    file write texfile "\centering" _n
    file write texfile "\begin{adjustbox}{width=\textwidth}" _n
    file write texfile "\begin{threeparttable}" _n
    file write texfile "\caption{Likelihood ratio tests: Model `m1' vs Model `m2'}\label{tab:lr_m`m1'_m`m2'}" _n
    file write texfile "\begin{tabular}{ccccccccc}" _n
    file write texfile "\toprule" _n
    file write texfile "\multirow{2}{*}{\textbf{Estimator}} & \multirow{2}{*}{\textbf{df}} & \multicolumn{2}{c}{\textit{Cooperants}} & \multicolumn{2}{c}{\textit{Online panel}} & \multicolumn{2}{c}{\textit{Pooled}} \\" _n
    file write texfile "\cmidrule(lr){3-4} \cmidrule(lr){5-6} \cmidrule(lr){7-8}" _n
    file write texfile " & & LR stat & \$p\$-value & LR stat & \$p\$-value & LR stat & \$p\$-value \\" _n
    file write texfile "\midrule" _n
    
    * PANEL A: Heat Pump
    file write texfile "\multicolumn{8}{l}{\textbf{Panel A:} Heat pump flexibility} \\" _n
    file write texfile "\midrule" _n
    
    foreach modeltype in mnl mix mix_corr {
        
        * Format model type name
        if "`modeltype'" == "mnl" local mtype "CL"
        else if "`modeltype'" == "mix" local mtype "MIXL"
        else local mtype "MIXL (corr.)"
        
        * df across groups (same value)
        local df = string(df_coop1_hp_`modeltype', "%3.0f")
		        
        * Cooperants
        local lr_c1 = string(lr_coop1_hp_`modeltype', "%9.2f")
        local pv_c1 = pval_coop1_hp_`modeltype'
        if `pv_c1' < 0.001 local pv_c1_str "$<$0.001"
        else local pv_c1_str = string(`pv_c1', "%9.3f")
        
        * Online panel
        local lr_c0 = string(lr_coop0_hp_`modeltype', "%9.2f")
        local pv_c0 = pval_coop0_hp_`modeltype'
        if `pv_c0' < 0.001 local pv_c0_str "$<$0.001"
        else local pv_c0_str = string(`pv_c0', "%9.3f")
        
        * Pooled
        local lr_p = string(lr_pool_hp_`modeltype', "%9.2f")
        local pv_p = pval_pool_hp_`modeltype'
        if `pv_p' < 0.001 local pv_p_str "$<$0.001"
        else local pv_p_str = string(`pv_p', "%9.3f")
        
        * Write row
        file write texfile "`mtype' & `df' & `lr_c1' & `pv_c1_str' & `lr_c0' & `pv_c0_str' & `lr_p' & `pv_p_str' \\" _n
    }
    
    file write texfile "\midrule" _n
    
    * PANEL B: Electric Vehicle
    file write texfile "\multicolumn{8}{l}{\textbf{Panel B:} Electric vehicle flexibility} \\" _n
    file write texfile "\midrule" _n
    
    foreach modeltype in mnl mix mix_corr {
        
        * Format model type name
        if "`modeltype'" == "mnl" local mtype "CL"
        else if "`modeltype'" == "mix" local mtype "MIXL"
        else local mtype "MIXL (corr.)"
        
        * df across groups (same value)
        local df = string(df_coop1_hp_`modeltype', "%3.0f")
        
        * Cooperants
        local lr_c1 = string(lr_coop1_ev_`modeltype', "%9.2f")
        local pv_c1 = pval_coop1_ev_`modeltype'
        if `pv_c1' < 0.001 local pv_c1_str "$<$0.001"
        else local pv_c1_str = string(`pv_c1', "%9.3f")
        
        * Online panel
        local lr_c0 = string(lr_coop0_ev_`modeltype', "%9.2f")
        local pv_c0 = pval_coop0_ev_`modeltype'
        if `pv_c0' < 0.001 local pv_c0_str "$<$0.001"
        else local pv_c0_str = string(`pv_c0', "%9.3f")
        
        * Pooled
        local lr_p = string(lr_pool_ev_`modeltype', "%9.2f")
        local pv_p = pval_pool_ev_`modeltype'
        if `pv_p' < 0.001 local pv_p_str "$<$0.001"
        else local pv_p_str = string(`pv_p', "%9.3f")
        
        * Write row
        file write texfile "`mtype' & `df' & `lr_c1' & `pv_c1_str' & `lr_c0' & `pv_c0_str' & `lr_p' & `pv_p_str' \\" _n
    }
    
    * Footer
    file write texfile "\bottomrule" _n
    file write texfile "\end{tabular}" _n
    file write texfile "\begin{tablenotes}[flushleft]" _n
    file write texfile "\footnotesize" _n
    file write texfile "\item \textit{Notes:} [notes]" _n
    file write texfile "\end{tablenotes}" _n
    file write texfile "\end{threeparttable}" _n
    file write texfile "\end{adjustbox}" _n
    file write texfile "\end{table}" _n
    
    file close texfile
	        
end

App_G_Table_model_comparison 1 2 // Table 12
App_G_Table_model_comparison 2 3 // Table 13

capture program drop Table_model2corrVS2mix
program define Table_model2corrVS2mix

* -----------------------------------------------------------------------------
*
* Program: Table_model2corrVS2mix
*
* Computes likelihood-ratio (LR) tests between MIXL correlated vs MIXL independent 
* (Model 2) for each choice experiment and subsample. Utility specification is
* given by Model 2. 
*
* Notes:
*   - Degrees of freedom are the same across groups for a given comparison, 
*     so the program reuses a single df per experiment.
*
* Inputs:
*   - Two stored estimation results in "$estimationDir".
*
* Output:
*   - LaTeX table "$resultsDir/App_G_Table_Mixcorr_vs_Mix.tex"
* -----------------------------------------------------------------------------

version 17

    * STEP 1: Compute LR tests for all groups
    
    foreach choice in hp ev {
        
        * Cooperants
        estimates use "$estimationDir/save_coop1_model2_`choice'_mix_corr.ster"
        estimates store temp_coop1_corr_`choice'
        estimates use "$estimationDir/save_coop1_model2_`choice'_mix.ster"
        estimates store temp_coop1_mix_`choice'
        
        model_comparisons temp_coop1_corr_`choice' temp_coop1_mix_`choice'
        scalar lr_coop1_`choice' = r(chi2)
        scalar df_coop1_`choice' = r(df)
        scalar pval_coop1_`choice' = r(p)
        
        * Online panel
        estimates use "$estimationDir/save_coop0_model2_`choice'_mix_corr.ster"
        estimates store temp_coop0_corr_`choice'
        estimates use "$estimationDir/save_coop0_model2_`choice'_mix.ster"
        estimates store temp_coop0_mix_`choice'
        
        model_comparisons temp_coop0_corr_`choice' temp_coop0_mix_`choice'
        scalar lr_coop0_`choice' = r(chi2)
        scalar df_coop0_`choice' = r(df)
        scalar pval_coop0_`choice' = r(p)
        
        * Pooled
        estimates use "$estimationDir/save_pool_model2_`choice'_mix_corr.ster"
        estimates store temp_pool_corr_`choice'
        estimates use "$estimationDir/save_pool_model2_`choice'_mix.ster"
        estimates store temp_pool_mix_`choice'
        
        model_comparisons temp_pool_corr_`choice' temp_pool_mix_`choice'
        scalar lr_pool_`choice' = r(chi2)
        scalar df_pool_`choice' = r(df)
        scalar pval_pool_`choice' = r(p)
        
	}
    
    * STEP 2: Write LaTeX table
    
    local filename "$resultsDir/App_G_Table_Mixcorr_vs_Mix.tex"
    capture file close texfile
    file open texfile using "`filename'", write replace
    
    * Header
    file write texfile "\begin{table}[ht]" _n
    file write texfile "\centering" _n
    file write texfile "\begin{threeparttable}" _n
    file write texfile "\caption{Likelihood ratio tests: MIXL correlated vs independent (Model 2) (utility specification given by Model 2)}\label{tab:lr_mixcorr_mix}" _n
    file write texfile "\begin{tabular}{lcccccccc}" _n
    file write texfile "\toprule" _n
    file write texfile "\multirow{2}{*}{\textbf{Experiment}} & \multirow{2}{*}{\textbf{df}} & \multicolumn{2}{c}{\textit{Cooperants}} & \multicolumn{2}{c}{\textit{Online panel}} & \multicolumn{2}{c}{\textit{Pooled}} \\" _n
    file write texfile "\cmidrule(lr){3-4} \cmidrule(lr){5-6} \cmidrule(lr){7-8}" _n
    file write texfile " & & LR stat & \$p\$-value & LR stat & \$p\$-value & LR stat & \$p\$-value \\" _n
    file write texfile "\midrule" _n
    
    * HP row
    local df_hp = string(df_coop1_hp, "%3.0f")
    
    local lr_c1_hp = string(lr_coop1_hp, "%9.2f")
    local pv_c1_hp = pval_coop1_hp
    if `pv_c1_hp' < 0.001 local pv_c1_hp_str "$<$0.001"
    else local pv_c1_hp_str = string(`pv_c1_hp', "%9.3f")
    
    local lr_c0_hp = string(lr_coop0_hp, "%9.2f")
    local pv_c0_hp = pval_coop0_hp
    if `pv_c0_hp' < 0.001 local pv_c0_hp_str "$<$0.001"
    else local pv_c0_hp_str = string(`pv_c0_hp', "%9.3f")
    
    local lr_p_hp = string(lr_pool_hp, "%9.2f")
    local pv_p_hp = pval_pool_hp
    if `pv_p_hp' < 0.001 local pv_p_hp_str "$<$0.001"
    else local pv_p_hp_str = string(`pv_p_hp', "%9.3f")
    
    file write texfile "Heat pump & `df_hp' & `lr_c1_hp' & `pv_c1_hp_str' & `lr_c0_hp' & `pv_c0_hp_str' & `lr_p_hp' & `pv_p_hp_str' \\" _n
    
    * EV row
    local df_ev = string(df_coop1_ev, "%3.0f")
    
    local lr_c1_ev = string(lr_coop1_ev, "%9.2f")
    local pv_c1_ev = pval_coop1_ev
    if `pv_c1_ev' < 0.001 local pv_c1_ev_str "$<$0.001"
    else local pv_c1_ev_str = string(`pv_c1_ev', "%9.3f")
    
    local lr_c0_ev = string(lr_coop0_ev, "%9.2f")
    local pv_c0_ev = pval_coop0_ev
    if `pv_c0_ev' < 0.001 local pv_c0_ev_str "$<$0.001"
    else local pv_c0_ev_str = string(`pv_c0_ev', "%9.3f")
    
    local lr_p_ev = string(lr_pool_ev, "%9.2f")
    local pv_p_ev = pval_pool_ev
    if `pv_p_ev' < 0.001 local pv_p_ev_str "$<$0.001"
    else local pv_p_ev_str = string(`pv_p_ev', "%9.3f")
    
    file write texfile "Electric vehicle & `df_ev' & `lr_c1_ev' & `pv_c1_ev_str' & `lr_c0_ev' & `pv_c0_ev_str' & `lr_p_ev' & `pv_p_ev_str' \\" _n
    
    * Footer
    file write texfile "\bottomrule" _n
    file write texfile "\end{tabular}" _n
    file write texfile "\begin{tablenotes}[flushleft]" _n
    file write texfile "\footnotesize" _n
    file write texfile "\item \textit{Notes:} [notes]." _n
    file write texfile "\end{tablenotes}" _n
    file write texfile "\end{threeparttable}" _n
    file write texfile "\end{table}" _n
    
    file close texfile
        
end

Table_model2corrVS2mix	         // Table 14
	
***** Appendix H: Full choice-model outputs

*** Model results in the preference space

capture program drop estimation_results
program define estimation_results

* -----------------------------------------------------------------------------
*
* Program: estimation_results
*
* Computes model fit statistics and estimated coefficients for preferred 
* specification for both choice experiments and all samples, in the preference
* space. 
*
* Steps for each experiment & sample:
*   1) Restore estimation results of preferred specifications (.ster)
*   2) Display log-likelihood, number of parameters (from mixlcov)
*   3) Compute multinomial/conditional logit as baseline (cmclogit)
*   4) Compute McFadden's pseudo R²: 1 - (LL_model / LL_baseline)
*
* Output:
*   - Log-likelihoods, number of parameters, and McFadden's R² are displayed
*     in the Stata console and can be manually used to fill Tables 15 and 16 in 
*     the paper.
* -----------------------------------------------------------------------------

version 17

***** Choice experiment on EV flexibility: 

	estimates use "$estimationDir/save_coop1_model2_ev_mix_corr"
	estimates replay 
	estat ic 
	local ll_fin = e(ll)
	mixlcov, sd
	di "Number of parameters = `e(k)'"
	use "$data", clear
	cmset response_id panel_time_var_index alternative_index // Setting choice model data
	qui cmclogit choice_ev asc if coop_channel == 1, vce(cluster response_id) nocons base(3) 
	qui estat ic 
	local ll_0 = e(ll)
	local rho = 1 - (`ll_fin'/`ll_0')
	di "McFadden's pseudo R2 = `rho' " 

	estimates use "$estimationDir/save_coop0_model2_ev_mix_corr"
	estimates replay 
	estat ic 
	local ll_fin = e(ll)
	mixlcov, sd
	di "Number of parameters = `e(k)'"
	use "$data", clear
	cmset response_id panel_time_var_index alternative_index // Setting choice model data
	qui cmclogit choice_ev asc if coop_channel == 0, vce(cluster response_id) nocons base(3) 
	qui estat ic 
	local ll_0 = e(ll)
	local rho = 1 - (`ll_fin'/`ll_0')
	di "McFadden's pseudo R2 = `rho' " 
	
	estimates use "$estimationDir/save_pool_model2_ev_mix_corr"
	estimates replay 
	estat ic 
	local ll_fin = e(ll)
	mixlcov, sd
	di "Number of parameters = `e(k)'"
	use "$data", clear
	cmset response_id panel_time_var_index alternative_index // Setting choice model data
	qui cmclogit choice_ev asc, vce(cluster response_id) nocons base(3) 
	qui estat ic 
	local ll_0 = e(ll)
	local rho = 1 - (`ll_fin'/`ll_0')
	di "McFadden's pseudo R2 = `rho' " 

***** Choice experiment on HP flexibility: 

	estimates use "$estimationDir/save_coop1_model2_hp_mix_corr"
	estimates replay 
	estat ic 
	local ll_fin = e(ll)
	mixlcov, sd
	di "Number of parameters = `e(k)'"
	use "$data", clear
	cmset response_id panel_time_var_index alternative_index // Setting choice model data
	qui cmclogit choice_hp asc if coop_channel == 1, vce(cluster response_id) nocons base(3) 
	qui estat ic 
	local ll_0 = e(ll)
	local rho = 1 - (`ll_fin'/`ll_0')
	di "McFadden's pseudo R2 = `rho' " 

	estimates use "$estimationDir/save_coop0_model2_hp_mix_corr"
	estimates replay 
	estat ic 
	local ll_fin = e(ll)
	mixlcov, sd
	di "Number of parameters = `e(k)'"
	use "$data", clear
	cmset response_id panel_time_var_index alternative_index // Setting choice model data
	qui cmclogit choice_hp asc if coop_channel == 0, vce(cluster response_id) nocons base(3) 
	qui estat ic 
	local ll_0 = e(ll)
	local rho = 1 - (`ll_fin'/`ll_0')
	di "McFadden's pseudo R2 = `rho' " 
	
	estimates use "$estimationDir/save_pool_model2_hp_mix_corr"
	estimates replay 
	estat ic 
	local ll_fin = e(ll)
	mixlcov, sd
	di "Number of parameters = `e(k)'"
	use "$data", clear
	cmset response_id panel_time_var_index alternative_index // Setting choice model data
	qui cmclogit choice_hp asc, vce(cluster response_id) nocons base(3) 
	qui estat ic 
	local ll_0 = e(ll)
	local rho = 1 - (`ll_fin'/`ll_0')
	di "McFadden's pseudo R2 = `rho' " 
	
end

estimation_results

*** Correlations between preferences

// These plots are generated using the .ado file provided with the replication
// materials. To run the corresponding programs, please install mixlcorr.ado
// and place it in Stata's ado/plus/m directory.
// The figures are produced as .gph files. Manual editing of plot notes,
// legends, and axis labels is required to obtain the final versions
// reported in the paper.

* EV: Figures 15--17
estimates use "$estimationDir/save_coop1_model2_ev_mix_corr.ster"
mixlcorr $model2_ev, plot name("$resultsDir/App_H2_Figure_15") sig(0.05)

estimates use "$estimationDir/save_coop0_model2_ev_mix_corr.ster"
mixlcorr $model2_ev, plot name("$resultsDir/App_H2_Figure_16") sig(0.05)

estimates use "$estimationDir/save_pool_model2_ev_mix_corr.ster"
mixlcorr $model2_ev, plot name("$resultsDir/App_H2_Figure_17") sig(0.05)

* HP: Figures 18--20
estimates use "$estimationDir/save_coop1_model2_hp_mix_corr.ster"
mixlcorr $model2_hp, plot name("$resultsDir/App_H2_Figure_18") sig(0.05)

estimates use "$estimationDir/save_coop0_model2_hp_mix_corr.ster"
mixlcorr $model2_hp, plot name("$resultsDir/App_H2_Figure_19") sig(0.05)

estimates use "$estimationDir/save_pool_model2_hp_mix_corr.ster"
mixlcorr $model2_hp, plot name("$resultsDir/App_H2_Figure_20") sig(0.05)

*** Marginal WTA estimates by samples 

capture program drop App_H_plot_MWTA_range_ev_samples
program define App_H_plot_MWTA_range_ev_samples

*----------------------------------------------------------*
* 
* Program: App_H_plot_MWTA_range_ev_samples
*
* Compute and plot marginal WTA for EV range reductions for Cooperants and 
* Online panel respondents. This program computes willingness-to-accept (WTA) 
* values for discrete EV remaining-range levels using preferred specification 
* for mixed logit estimates (Model 2), derives 95% confidence intervals via 
* Delta method.
*
* Output:
*   - "$resultsDir/App_H3_Figure_21_left.pdf": Nonlinear vs. linear marginal WTA
*                                              by range level and by samples
*----------------------------------------------------------*

    clear
    set obs 12  // 4 levels × 3 groups
    gen level = .
    gen WTA = .
    gen LL = .
    gen UL = .
    gen group = .
    
    * Create structure: 3 groups × 4 levels
    local row = 1
    foreach g in 1 0 2 {  // 1=coop1, 0=coop0
        foreach lev in 50 100 150 200 {
            replace level = `lev' in `row'
            replace group = `g' in `row'
            local ++row
        }
    }
    
    * Calculate WTA for each group and level
    foreach g in 1 0 {
        
        if `g' == 1 local suffix "coop1"
        else if `g' == 0 local suffix "coop0"
        
        * Range 50
        estimates use "$estimationDir/save_`suffix'_model2_ev_mix_corr.ster"
        nlcom (_b[range_50] / -_b[euro_ev]), post
        quietly replace WTA = _b[_nl_1] if group == `g' & level == 50
        quietly replace LL = _b[_nl_1] - 1.96*_se[_nl_1] if group == `g' & level == 50
        quietly replace UL = _b[_nl_1] + 1.96*_se[_nl_1] if group == `g' & level == 50
        
        * Range 100
        estimates use "$estimationDir/save_`suffix'_model2_ev_mix_corr.ster"
        nlcom (_b[range_100] / -_b[euro_ev]), post
        quietly replace WTA = _b[_nl_1] if group == `g' & level == 100
        quietly replace LL = _b[_nl_1] - 1.96*_se[_nl_1] if group == `g' & level == 100
        quietly replace UL = _b[_nl_1] + 1.96*_se[_nl_1] if group == `g' & level == 100
        
        * Range 150
        estimates use "$estimationDir/save_`suffix'_model2_ev_mix_corr.ster"
        nlcom (_b[range_150] / -_b[euro_ev]), post
        quietly replace WTA = _b[_nl_1] if group == `g' & level == 150
        quietly replace LL = _b[_nl_1] - 1.96*_se[_nl_1] if group == `g' & level == 150
        quietly replace UL = _b[_nl_1] + 1.96*_se[_nl_1] if group == `g' & level == 150
        
        * Base level (200 km)
        quietly replace WTA = 0 if group == `g' & level == 200
        quietly replace LL = 0 if group == `g' & level == 200
        quietly replace UL = 0 if group == `g' & level == 200
    }
    
    * Plot (cooperants vs online panel)
    twoway ///
    (rcap UL LL level if group==1, lc(blue%60) lw(medthick)) ///
    (connected WTA level if group==1, mc(blue%60) msymbol(circle) msize(medium) lc(blue%60) lw(medthick)) ///
    (rcap UL LL level if group==0, lc(orange%60) lw(medthick)) ///
    (connected WTA level if group==0, mc(orange%60) msymbol(circle) msize(medium) lc(orange%60) lw(medthick)), ///
    legend(order(2 "Cooperants" 4 "Online panel") pos(6) row(1)) ///
    xlabel(50 "50 km" 100 "100 km" 150 "150 km" 200 "200 km") ///
    ylabel(-10 -5 0 5 10 15 20 25 30, angle(horizontal)) ///
    yline(0) ///
    xtitle("EV remaining range during interventions (km)") ///
    ytitle("Marginal WTA (€)") xsize(7) ysize(8)
    graph export "$resultsDir/App_H3_Figure_21_left.pdf", replace
    
end

capture program drop App_H_plot_MWTA_temp_hp_samples
program define App_H_plot_MWTA_temp_hp_samples

*----------------------------------------------------------*
* 
* Program: App_H_plot_MWTA_temp_hp_samples
*
* Compute and plot marginal WTA for HP indoor temperature reductions for 
* Cooperants and Online panel respondents. This program computes willingness-
* to-accept (WTA) values for discrete HP indoor temperature levels using 
* preferred specification for mixed logit estimates (Model 2), derives 95% 
* confidence intervals via Delta method.
*
* Output:
*   - "$resultsDir/App_H3_Figure_21_right.pdf": Nonlinear vs. linear marginal WTA
*                                               by range level and by samples
*----------------------------------------------------------*

    clear
    set obs 12  // 4 levels × 3 groups
    gen level = .
    gen WTA = .
    gen LL = .
    gen UL = .
    gen group = .
    
    * Create structure
    local row = 1
    foreach g in 1 0 {
        foreach lev in 16 17 18 19 {
            replace level = `lev' in `row'
            replace group = `g' in `row'
            local ++row
        }
    }
    
    * Calculate WTA for each group and level
    foreach g in 1 0 {
        
        if `g' == 1 local suffix "coop1"
        else if `g' == 0 local suffix "coop0"
        
        * Temp 16
        estimates use "$estimationDir/save_`suffix'_model2_hp_mix_corr.ster"
        nlcom (_b[temp_16] / -_b[euro_hp]), post
        quietly replace WTA = _b[_nl_1] if group == `g' & level == 16
        quietly replace LL = _b[_nl_1] - 1.96*_se[_nl_1] if group == `g' & level == 16
        quietly replace UL = _b[_nl_1] + 1.96*_se[_nl_1] if group == `g' & level == 16
        
        * Temp 17
        estimates use "$estimationDir/save_`suffix'_model2_hp_mix_corr.ster"
        nlcom (_b[temp_17] / -_b[euro_hp]), post
        quietly replace WTA = _b[_nl_1] if group == `g' & level == 17
        quietly replace LL = _b[_nl_1] - 1.96*_se[_nl_1] if group == `g' & level == 17
        quietly replace UL = _b[_nl_1] + 1.96*_se[_nl_1] if group == `g' & level == 17
        
        * Temp 18
        estimates use "$estimationDir/save_`suffix'_model2_hp_mix_corr.ster"
        nlcom (_b[temp_18] / -_b[euro_hp]), post
        quietly replace WTA = _b[_nl_1] if group == `g' & level == 18
        quietly replace LL = _b[_nl_1] - 1.96*_se[_nl_1] if group == `g' & level == 18
        quietly replace UL = _b[_nl_1] + 1.96*_se[_nl_1] if group == `g' & level == 18
        
        * Base level (19°C)
        quietly replace WTA = 0 if group == `g' & level == 19
        quietly replace LL = 0 if group == `g' & level == 19
        quietly replace UL = 0 if group == `g' & level == 19
    }
    
    * Plot 
    twoway ///
    (rcap UL LL level if group==1, lc(blue%60) lw(medthick)) ///
    (connected WTA level if group==1, mc(blue%60) msymbol(circle) msize(medium) lc(blue%60) lw(medthick)) ///
    (rcap UL LL level if group==0, lc(orange%60) lw(medthick)) ///
    (connected WTA level if group==0, mc(orange%60) msymbol(circle) msize(medium) lc(orange%60) lw(medthick)), ///
    legend(order(2 "Cooperants" 4 "Online panel") pos(6) row(1)) ///
    xlabel(16 "16 °C" 17 "17 °C" 18 "18 °C" 19 "19 °C") ///
    ylabel(0 2 4 6 8 10, angle(horizontal)) ///
    yline(0) ///
    xtitle("HP indoor temperature limit during interventions") ///
    ytitle("Marginal WTA (€)") xsize(7) ysize(8)
    graph export "$resultsDir/App_H3_Figure_21_right.pdf", replace
    
end

capture program drop App_H_plot_MWTA_freq_ev_samples
program define App_H_plot_MWTA_freq_ev_samples

*----------------------------------------------------------*
* 
* Program: App_H_plot_MWTA_freq_ev_samples
*
* Compute and plot marginal WTA for EV intervention frequency for Cooperants and 
* Online panel respondents. This program computes willingness-to-accept (WTA) 
* values for discrete EV intervention frequency levels using preferred 
* specification for mixed logit estimates (Model 2), derives 95% confidence 
* intervals via Delta method.
*
* Output:
*   - "$resultsDir/App_H3_Figure_22_left.pdf": Nonlinear vs. linear marginal WTA
*                                              by frequency level and by samples
*----------------------------------------------------------*

    clear
    set obs 12  // 4 levels × 3 groups
    gen level = .
    gen WTA = .
    gen LL = .
    gen UL = .
    gen group = .
    
    * Create structure
    local row = 1
    foreach g in 1 0 {
        foreach lev in 1 6 12 52 {
            replace level = `lev' in `row'
            replace group = `g' in `row'
            local ++row
        }
    }
    
    * Base level first (1 intervention/year)
    quietly replace WTA = 0 if level == 1
    quietly replace LL = 0 if level == 1
    quietly replace UL = 0 if level == 1
    
    * Calculate WTA for each group and level
    foreach g in 1 0 {
        
        if `g' == 1 local suffix "coop1"
        else if `g' == 0 local suffix "coop0"
        
        * Freq 6
        estimates use "$estimationDir/save_`suffix'_model2_ev_mix_corr.ster"
        nlcom (_b[freq_ev_6] / -_b[euro_ev]), post
        quietly replace WTA = _b[_nl_1] if group == `g' & level == 6
        quietly replace LL = _b[_nl_1] - 1.96*_se[_nl_1] if group == `g' & level == 6
        quietly replace UL = _b[_nl_1] + 1.96*_se[_nl_1] if group == `g' & level == 6
        
        * Freq 12
        estimates use "$estimationDir/save_`suffix'_model2_ev_mix_corr.ster"
        nlcom (_b[freq_ev_12] / -_b[euro_ev]), post
        quietly replace WTA = _b[_nl_1] if group == `g' & level == 12
        quietly replace LL = _b[_nl_1] - 1.96*_se[_nl_1] if group == `g' & level == 12
        quietly replace UL = _b[_nl_1] + 1.96*_se[_nl_1] if group == `g' & level == 12
        
        * Freq 52
        estimates use "$estimationDir/save_`suffix'_model2_ev_mix_corr.ster"
        nlcom (_b[freq_ev_52] / -_b[euro_ev]), post
        quietly replace WTA = _b[_nl_1] if group == `g' & level == 52
        quietly replace LL = _b[_nl_1] - 1.96*_se[_nl_1] if group == `g' & level == 52
        quietly replace UL = _b[_nl_1] + 1.96*_se[_nl_1] if group == `g' & level == 52
    }
    
    * Plot 
    twoway ///
    (rcap UL LL level if group==1, lc(blue%60) lw(medthick)) ///
    (connected WTA level if group==1, mc(blue%60) msymbol(circle) msize(medium) lc(blue%60) lw(medthick)) ///
    (rcap UL LL level if group==0, lc(orange%60) lw(medthick)) ///
    (connected WTA level if group==0, mc(orange%60) msymbol(circle) msize(medium) lc(orange%60) lw(medthick)), ///
    legend(order(2 "Cooperants" 4 "Online panel") pos(6) row(1)) ///
    xlabel(1 6 12 52) ///
    ylabel(-30 -25 -20 -15 -10 -5 0, angle(horizontal)) ///
    yline(0) ///
    xtitle("Yearly frequency of interventions on an EV") ///
    ytitle("Marginal WTA (€)") xsize(7) ysize(8)
    graph export "$resultsDir/App_H3_Figure_22_left.pdf", replace
    
end

capture program drop App_H_plot_MWTA_freq_hp_samples
program define App_H_plot_MWTA_freq_hp_samples

*----------------------------------------------------------*
* 
* Program: App_H_plot_MWTA_freq_hp_samples
*
* Compute and plot marginal WTA for HP intervention frequency for Cooperants and 
* Online panel respondents. This program computes willingness-to-accept (WTA) 
* values for discrete HP intervention frequency levels using preferred 
* specification for mixed logit estimates (Model 2), derives 95% confidence 
* intervals via Delta method.
*
* Output:
*   - "$resultsDir/App_H3_Figure_22_right.pdf": Nonlinear vs. linear marginal WTA
*                                               by frequency level and by samples
*----------------------------------------------------------*

    clear
    set obs 12  // 4 levels × 3 groups
    gen level = .
    gen WTA = .
    gen LL = .
    gen UL = .
    gen group = .
    
    * Create structure
    local row = 1
    foreach g in 1 0 {
        foreach lev in 1 6 12 52 {
            replace level = `lev' in `row'
            replace group = `g' in `row'
            local ++row
        }
    }
    
    * Base level first
    quietly replace WTA = 0 if level == 1
    quietly replace LL = 0 if level == 1
    quietly replace UL = 0 if level == 1
    
    * Calculate WTA for each group and level
    foreach g in 1 0 {
        
        if `g' == 1 local suffix "coop1"
        else if `g' == 0 local suffix "coop0"
        else local suffix "pool"
        
        * Freq 6
        estimates use "$estimationDir/save_`suffix'_model2_hp_mix_corr.ster"
        nlcom (_b[freq_hp_6] / -_b[euro_hp]), post
        quietly replace WTA = _b[_nl_1] if group == `g' & level == 6
        quietly replace LL = _b[_nl_1] - 1.96*_se[_nl_1] if group == `g' & level == 6
        quietly replace UL = _b[_nl_1] + 1.96*_se[_nl_1] if group == `g' & level == 6
        
        * Freq 12
        estimates use "$estimationDir/save_`suffix'_model2_hp_mix_corr.ster"
        nlcom (_b[freq_hp_12] / -_b[euro_hp]), post
        quietly replace WTA = _b[_nl_1] if group == `g' & level == 12
        quietly replace LL = _b[_nl_1] - 1.96*_se[_nl_1] if group == `g' & level == 12
        quietly replace UL = _b[_nl_1] + 1.96*_se[_nl_1] if group == `g' & level == 12
        
        * Freq 52
        estimates use "$estimationDir/save_`suffix'_model2_hp_mix_corr.ster"
        nlcom (_b[freq_hp_52] / -_b[euro_hp]), post
        quietly replace WTA = _b[_nl_1] if group == `g' & level == 52
        quietly replace LL = _b[_nl_1] - 1.96*_se[_nl_1] if group == `g' & level == 52
        quietly replace UL = _b[_nl_1] + 1.96*_se[_nl_1] if group == `g' & level == 52
    }
    
    * Plot
    twoway ///
    (rcap UL LL level if group==1, lc(blue%60) lw(medthick)) ///
    (connected WTA level if group==1, mc(blue%60) msymbol(circle) msize(medium) lc(blue%60) lw(medthick)) ///
    (rcap UL LL level if group==0, lc(orange%60) lw(medthick)) ///
    (connected WTA level if group==0, mc(orange%60) msymbol(circle) msize(medium) lc(orange%60) lw(medthick)), ///
    legend(order(2 "Cooperants" 4 "Online panel") pos(6) row(1)) ///
    xlabel(1 6 12 52) ///
    ylabel(-3 -2.5 -2 -1.5 -1 -0.5 0, angle(horizontal)) ///
    yline(0) ///
    xtitle("Yearly frequency of interventions on a HP") ///
    ytitle("Marginal WTA (€)") xsize(7) ysize(8)
    graph export "$resultsDir/App_H3_Figure_22_right.pdf", replace
    
end

* Figure 21:
App_H_plot_MWTA_range_ev_samples 
App_H_plot_MWTA_temp_hp_samples

* Figure 22:
App_H_plot_MWTA_freq_ev_samples
App_H_plot_MWTA_freq_hp_samples

capture program drop Table_WTA_subgroup
program define Table_WTA_subgroup, rclass

*----------------------------------------------------------*
* 
* Program: Table_WTA_subgroup
*
* Compute marginal willingness-to-accept (MWTA) estimates for EV or HP choice
* experiment attributes, in a given subsample. We use our preferred
* specification.
*
* Input:
*   - `ce' option passed as argument: "ev" or "hp"
*   - `coop' option passed as argument: "1" (cooperants) or "0" (online panel)
*   - Pooled MIXL correlated model .ster files in $estimationDir
*
* Output:
*   - Console output: mean, SD, 95% CI for all attributes (matrix "T")
*   - LaTeX table: "$resultsDir/App_H3_Table_`ce'_[coop,online].tex"
*----------------------------------------------------------*

syntax , ce(string) coop(integer)

// 1: Attributes and cost var
if ("`ce'"=="ev") {
	local numerators range_150 range_100 range_50 freq_ev_6 freq_ev_12 freq_ev_52 ///
							 timing_ev_Ev timing_ev_Ni timing_ev_AM asc
	local base_vars range_200 freq_ev_1 timing_ev_PM
	local cost euro_ev
}
else if ("`ce'"=="hp") {
	local numerators temp_18 temp_17 temp_16 freq_hp_6 freq_hp_12 freq_hp_52 ///
							 timing_hp_Ev timing_hp_Ni timing_hp_AM asc
	local base_vars temp_19 freq_hp_1 timing_hp_PM
	local cost euro_hp
}

// 2: Combine all variables
local all_vars `base_vars' `numerators'
local nvars : word count `all_vars'

matrix T = J(`nvars', 6, .)
local r = 1

// 3: Base levels are set to 0
foreach v of local base_vars {
	matrix T[`r',1] = 0
	matrix T[`r',2] = 0
	matrix T[`r',3] = 0
	matrix T[`r',4] = 0
	matrix T[`r',5] = 0
	matrix T[`r',6] = 0
	local ++r
}

// 4: Loop 1: Mean WTAs

if (`coop' == 1) {
	estimates use "$estimationDir\save_coop1_model2_`ce'_mix_corr.ster"
}
else {
	estimates use "$estimationDir\save_coop0_model2_`ce'_mix_corr.ster"
}

scalar cost_coef = abs(_b[`cost'])

local r = `=`: word count `base_vars'' + 1'

foreach v of local numerators {
	if (`coop' == 1) {
		  estimates use "$estimationDir\save_coop1_model2_`ce'_mix_corr.ster"
	}
	else {
		  estimates use "$estimationDir\save_coop0_model2_`ce'_mix_corr.ster"
	}
	
	qui nlcom (_b[`v'] / -_b[`cost']), post
   
	matrix T[`r',1] = _b[_nl_1]
	matrix T[`r',2] = _b[_nl_1] - 1.96*_se[_nl_1]
	matrix T[`r',3] = _b[_nl_1] + 1.96*_se[_nl_1]
   
	local ++r
}

// 5: mixlogit, sd post 

if (`coop' == 1) {
	estimates use "$estimationDir\save_coop1_model2_`ce'_mix_corr.ster"
}
else {
	estimates use "$estimationDir\save_coop0_model2_`ce'_mix_corr.ster"
}

mixlcov, sd post

// 6: Loop 2: SD WTAs
local r = `=`: word count `base_vars'' + 1'

foreach v of local numerators {
	qui nlcom (_b[`v'] / cost_coef)
   
	matrix T[`r',4] = r(b)[1,1]
	matrix T[`r',5] = r(b)[1,1] - 1.96*sqrt(r(V)[1,1])
	matrix T[`r',6] = r(b)[1,1] + 1.96*sqrt(r(V)[1,1])
   
	local ++r
}

// 7: Label matrix
matrix colnames T = Mean LL UL SD SD_LL SD_UL
matrix rownames T = `all_vars'

di "WTA summary for `ce' (coop=`coop')"
matrix list T

// 8: Determine suffix for output files
if (`coop' == 1) {
	local suffix "coop"
}
else {
	local suffix "online"
}

// 9: Export
// estout matrix(T, fmt(%9.2f)) using "$resultsDir/....tex", replace style(tex) title("WTA table for `ce' (`suffix')")
// estout matrix(T, fmt(%9.2f)) using "$resultsDir/....tex", replace

// 10: LaTeX table
tempname fh
file open `fh' using "$resultsDir/App_H3_Table_`ce'_`suffix'.tex", write replace

file write `fh' "\begin{tabular}{lcc}" _n
file write `fh' "\toprule" _n
file write `fh' "Parameter & Mean & SD \\\\" _n
file write `fh' "\midrule" _n

local i = 1
foreach v of local all_vars {
	local vtex : subinstr local v "_" "_", all

	local mf  : display %9.2f T[`i',1]
	local lf  : display %9.2f T[`i',2]
	local uf  : display %9.2f T[`i',3]
	local sf  : display %9.2f T[`i',4]
	local slf : display %9.2f T[`i',5]
	local suf : display %9.2f T[`i',6]

	// First row: variable name and values
	file write `fh' "`vtex' & `mf' & `sf' \\\\" _n
	// Second row: CIs
	file write `fh' " & (`lf', `uf') & (`slf', `suf') \\\\" _n
	
	local ++i
}

file write `fh' "\bottomrule" _n
file write `fh' "\end{tabular}" _n
file close `fh'

end

* Table 16: 
Table_WTA_subgroup, ce(ev) coop(1) 
Table_WTA_subgroup, ce(ev) coop(0)

* Table 17:
Table_WTA_subgroup, ce(hp) coop(1) 
Table_WTA_subgroup, ce(hp) coop(0)

***** Appendix I: Nonlinear MWTA for intervention frequency 

capture program drop App_I_plot_MWTA_freq_ev
program define App_I_plot_MWTA_freq_ev

*----------------------------------------------------------*
* 
* Program: App_I_plot_MWTA_freq_ev
*
* Compute and plot marginal WTA for EV intervention frequency for the pooled
* sample. This program computes willingness-to-accept (WTA) values for discrete
* EV intervention frequency levels using preferred specification for mixed logit
* estimates (Model 2), derives 95% confidence intervals via Delta method.
*
* Output:
*   - "$resultsDir/App_I_Figure_23_left.pdf": Nonlinear vs. linear marginal WTA
*                                             by frequency level.
*----------------------------------------------------------*

    clear
    set obs 4
    gen level = .
    gen WTA = .
    gen LL = .
    gen UL = .
    
    replace level = 1 in 1   // Base level
    replace level = 6 in 2
    replace level = 12 in 3
    replace level = 52 in 4
    
    * Base level (1 intervention/year)
    replace WTA = 0 in 1
    replace LL = 0 in 1
    replace UL = 0 in 1
    
    * Calculate WTA for each level from pooled Model 2
    estimates use "$pref_spec_pooled_EV"
    
    * Freq 6
    nlcom (_b[freq_ev_6] / -_b[euro_ev]), post
    replace WTA = _b[_nl_1] in 2
    replace LL = _b[_nl_1] - 1.96*_se[_nl_1] in 2
    replace UL = _b[_nl_1] + 1.96*_se[_nl_1] in 2
    
    * Freq 12
    estimates use "$pref_spec_pooled_EV"
    nlcom (_b[freq_ev_12] / -_b[euro_ev]), post
    replace WTA = _b[_nl_1] in 3
    replace LL = _b[_nl_1] - 1.96*_se[_nl_1] in 3
    replace UL = _b[_nl_1] + 1.96*_se[_nl_1] in 3
    
    * Freq 52
    estimates use "$pref_spec_pooled_EV"
    nlcom (_b[freq_ev_52] / -_b[euro_ev]), post
    replace WTA = _b[_nl_1] in 4
    replace LL = _b[_nl_1] - 1.96*_se[_nl_1] in 4
    replace UL = _b[_nl_1] + 1.96*_se[_nl_1] in 4
    
    * Plot:
    twoway ///
    (rcap UL LL level, lc(navy%60) lw(medthick)) ///
    (connected WTA level, mc(navy%60) msymbol(circle) msize(medium) lc(navy%60) lw(medthick)), ///
    xlabel(1 6 12 52) ///
    ylabel(-20 -15 -10 -5 0, angle(horizontal)) ///
    yline(0) ///
    xtitle("Yearly frequency of interventions on an EV") ///
    ytitle("Marginal WTA (€)") xsize(7) ysize(8) legend(off)
    graph export "$resultsDir/App_I_Figure_23_left.pdf", replace

end

capture program drop App_I_plot_MWTA_freq_hp
program define App_I_plot_MWTA_freq_hp

*----------------------------------------------------------*
* 
* Program: App_I_plot_MWTA_freq_hp
*
* Compute and plot marginal WTA for HP intervention frequency for the pooled
* sample. This program computes willingness-to-accept (WTA) values for discrete
* HP intervention frequency levels using preferred specification for mixed logit
* estimates (Model 2), derives 95% confidence intervals via Delta method.
*
* Output:
*   - "$resultsDir/App_I_Figure_23_right.pdf": Nonlinear vs. linear marginal WTA
*                                              by frequency level.
*----------------------------------------------------------*

    clear
    set obs 4
    gen level = .
    gen WTA = .
    gen LL = .
    gen UL = .
    
    replace level = 1 in 1   // Base level
    replace level = 6 in 2
    replace level = 12 in 3
    replace level = 52 in 4
    
    * Base level (1 intervention/year)
    replace WTA = 0 in 1
    replace LL = 0 in 1
    replace UL = 0 in 1
    
    * Calculate WTA for each level from pooled Model 2
    estimates use "$pref_spec_pooled_HP"
    
    * Freq 6
    nlcom (_b[freq_hp_6] / -_b[euro_hp]), post
    replace WTA = _b[_nl_1] in 2
    replace LL = _b[_nl_1] - 1.96*_se[_nl_1] in 2
    replace UL = _b[_nl_1] + 1.96*_se[_nl_1] in 2
    
    * Freq 12
    estimates use "$pref_spec_pooled_HP"
    nlcom (_b[freq_hp_12] / -_b[euro_hp]), post
    replace WTA = _b[_nl_1] in 3
    replace LL = _b[_nl_1] - 1.96*_se[_nl_1] in 3
    replace UL = _b[_nl_1] + 1.96*_se[_nl_1] in 3
    
    * Freq 52
    estimates use "$pref_spec_pooled_HP"
    nlcom (_b[freq_hp_52] / -_b[euro_hp]), post
    replace WTA = _b[_nl_1] in 4
    replace LL = _b[_nl_1] - 1.96*_se[_nl_1] in 4
    replace UL = _b[_nl_1] + 1.96*_se[_nl_1] in 4
    
    * Plot 
    twoway ///
    (rcap UL LL level, lc(navy%60) lw(medthick)) ///
    (connected WTA level, mc(navy%60) msymbol(circle) msize(medium) lc(navy%60) lw(medthick)), ///
    xlabel(1 6 12 52) ///
    ylabel(-2 -1.5 -1 -0.5 0, angle(horizontal)) ///
    yline(0) ///
    xtitle("Yearly frequency of interventions on a HP") ///
    ytitle("Marginal WTA (€)") xsize(7) ysize(8) legend(off)
    graph export "$resultsDir/App_I_Figure_23_right.pdf", replace
  
end

* Figure 23:
App_I_plot_MWTA_freq_ev
App_I_plot_MWTA_freq_hp

***** Appendix J: [See above]

***** Appendix K: Correlations between preferences EV-HP choice experiments

capture program drop merge_posterior_betas
program define merge_posterior_betas

* -----------------------------------------------------------------------------
*
* Program: merge_posterior_betas
*
* The program computes individual-level posterior means of random coefficients
* (using Arne Risa Hole's mixlbeta) from Model 2 with correlated random
* parameters, and merge them back with the survey and CE responses.
*
* For each CE (EV, HP) and sample (coop = 1, coop = 0, pooled) the program:
*   1) Loads the corresponding Model 2 estimation results (.ster)
*   2) Recovers individual-specific coefficients using mixlbeta
*   3) Renames coefficients with prefixes
*   4) Merges them back to the main dataset by response_id
*
* Main output:
*   - "$intermediateDir/data_with_betas.dta": contains all posterior betas and 
*                                             is overwritten after each step.
* -----------------------------------------------------------------------------

version 17
use                    "$data", clear
save                   "$intermediateDir/data_with_betas", replace
use                    "$intermediateDir/data_with_betas", clear

global data_with_betas "$intermediateDir/data_with_betas"

***** Choice experiment on EV flexibility: 

	// Cooperant respondents: 

		use "$data_with_betas", clear
		estimates use "$estimationDir/save_coop1_model2_ev_mix_corr.ster"
		mixlbeta euro_ev $model2_ev if coop_channel == 1, saving("$intermediateDir/coop1_model2_ev_mix_corr_b") replace nrep(2000) burn(15)
		use "$intermediateDir/coop1_model2_ev_mix_corr_b", clear 
		foreach var of varlist _all {
			if "`var'" != "response_id"{
				rename `var' beta_coop1_ev_`var'
				}
		}
		merge 1:m response_id using "$data_with_betas", nogen
		sort response_id choice_situation_ev alternative_index
		save "$data_with_betas", replace

	// Online panel respondents: 

		use "$data_with_betas", clear
		estimates use "$estimationDir/save_coop0_model2_ev_mix_corr.ster"
		mixlbeta euro_ev $model2_ev if coop_channel == 0, saving("$intermediateDir/coop0_model2_ev_mix_corr_b") replace nrep(2000) burn(15)
		use "$intermediateDir/coop0_model2_ev_mix_corr_b", clear 
		foreach var of varlist _all {
			if "`var'" != "response_id"{
				rename `var' beta_coop0_ev_`var'
				}
		}
		merge 1:m response_id using "$data_with_betas", nogen
		sort response_id choice_situation_ev alternative_index
		save "$data_with_betas", replace

	// Pooled sample: 	
	
		use "$data_with_betas", clear
		estimates use "$estimationDir/save_pool_model2_ev_mix_corr.ster"
		mixlbeta euro_ev $model2_ev, saving("$intermediateDir/pool_model2_ev_mix_corr_b") replace nrep(2000) burn(15)
		use "$intermediateDir/pool_model2_ev_mix_corr_b", clear 
		foreach var of varlist _all {
			if "`var'" != "response_id"{
				rename `var' beta_pool_ev_`var'
				}
		}
		merge 1:m response_id using "$data_with_betas", nogen
		sort response_id choice_situation_ev alternative_index
		save "$data_with_betas", replace
		
***** Choice experiment on HP flexibility: 

	// Cooperant respondents: 

		use "$data_with_betas", clear
		estimates use "$estimationDir/save_coop1_model2_hp_mix_corr.ster"
		mixlbeta euro_hp $model2_hp if coop_channel == 1, saving("$intermediateDir/coop1_model2_hp_mix_corr_b") replace nrep(2000) burn(15)
		use "$intermediateDir/coop1_model2_hp_mix_corr_b", clear 
		foreach var of varlist _all {
			if "`var'" != "response_id"{
				rename `var' beta_coop1_hp_`var'
				}
		}
		merge 1:m response_id using "$data_with_betas", nogen
		sort response_id choice_situation_hp alternative_index
		save "$data_with_betas", replace

	// Online panel respondents: 

		use "$data_with_betas", clear
		estimates use "$estimationDir/save_coop0_model2_hp_mix_corr.ster"
		mixlbeta euro_hp $model2_hp if coop_channel == 0, saving("$intermediateDir/coop0_model2_hp_mix_corr_b") replace nrep(2000) burn(15)
		use "$intermediateDir/coop0_model2_hp_mix_corr_b", clear 
		foreach var of varlist _all {
			if "`var'" != "response_id"{
				rename `var' beta_coop0_hp_`var'
				}
		}
		merge 1:m response_id using "$data_with_betas", nogen
		sort response_id choice_situation_hp alternative_index
		save "$data_with_betas", replace

	// Pooled sample: 	
	
		use "$data_with_betas", clear
		estimates use "$estimationDir/save_pool_model2_hp_mix_corr.ster"
		mixlbeta euro_hp $model2_hp, saving("$intermediateDir/pool_model2_hp_mix_corr_b") replace nrep(2000) burn(15)
		use "$intermediateDir/pool_model2_hp_mix_corr_b", clear 
		foreach var of varlist _all {
			if "`var'" != "response_id"{
				rename `var' beta_pool_hp_`var'
				}
		}
		merge 1:m response_id using "$data_with_betas", nogen
		sort response_id choice_situation_hp alternative_index
		save "$data_with_betas", replace
		
***** Erase the rest:

erase "$intermediateDir/coop1_model2_ev_mix_corr_b.dta"		
erase "$intermediateDir/coop0_model2_ev_mix_corr_b.dta"		
erase "$intermediateDir/pool_model2_ev_mix_corr_b.dta"		

erase "$intermediateDir/coop1_model2_hp_mix_corr_b.dta"		
erase "$intermediateDir/coop0_model2_hp_mix_corr_b.dta"		
erase "$intermediateDir/pool_model2_hp_mix_corr_b.dta"	

end

capture program drop App_K_correlation_across_CE
program define App_K_correlation_across_CE

* -----------------------------------------------------------------------------
*
* Program: merge_posterior_correlations
*
* Computes pairwise correlations and p-values between equivalent posterior
* random coefficients (EV vs HP choice experiments) from Model 2, stores in a
* matrix, displays results, and exports to LaTeX.
*
* Input: "$data_with_betas", a file with survey responses and individual betas.
* Output: Matrix 'corr_table' and LaTeX file "$resultsDir/App_K_Table_19.tex"
* ---------------------------------------------------------------------*

version 17

merge_posterior_betas
use "$data_with_betas", clear

// Define pairs of 'equivalent' preferences we want to compute the correlations in 
local pairs "beta_pool_ev_euro_ev beta_pool_hp_euro_hp beta_pool_ev_range_150 beta_pool_hp_temp_18 beta_pool_ev_range_100 beta_pool_hp_temp_17 beta_pool_ev_range_50 beta_pool_hp_temp_16 beta_pool_ev_freq_ev_6 beta_pool_hp_freq_hp_6 beta_pool_ev_freq_ev_12 beta_pool_hp_freq_hp_12 beta_pool_ev_freq_ev_52 beta_pool_hp_freq_hp_52 beta_pool_ev_timing_ev_Ev beta_pool_hp_timing_hp_Ev beta_pool_ev_timing_ev_Ni beta_pool_hp_timing_hp_Ni beta_pool_ev_timing_ev_AM beta_pool_hp_timing_hp_AM beta_pool_ev_asc beta_pool_hp_asc"

	// Store pairs in matrices
	local npairs = `: word count `pairs'' / 2
	matrix corr_table = J(`npairs', 2, .)

// Compute correlations
local row = 1
forvalues i = 1(2)`: word count `pairs'' {
    local var1 : word `i' of `pairs'
    local var2 : word `=`i'+1' of `pairs'
    
    pwcorr `var1' `var2', sig star(0.05)
    scalar rho = r(rho)
    scalar n = r(N)
    
    matrix corr_table[`row', 1] = rho
    scalar pval = r(sig)[2,1]
    matrix corr_table[`row', 2] = pval
	
	local short1 = substr("`var1'",14,.)
	local short2 = substr("`var2'",14,.)
    
    local rownames "`rownames' `short1',`short2'"
    local ++row
}

// Rename the matrix columns/rows
matrix colnames corr_table = Correlation p_value
matrix rownames corr_table = `rownames'

// Display
di "Pairwise correlations:"
matrix list corr_table, format(%9.3f)

// Export LaTeX
esttab matrix(corr_table, fmt(%9.3f)) using "$resultsDir/App_K_Table_19.tex", replace

end

* Table 19:
App_K_correlation_across_CE

***** Appendix L: 

** Choice experiment on EV flexibility: 

capture program drop Table_BotE_EV_reduced_av
program define Table_BotE_EV_reduced_av

* -----------------------------------------------------------------------------
*
* Program: Table_BotE_EV_reduced_av
*
* The program computes the impact (energy and financial from an aggregator's 
* viewpoint) of EV flexibility contracts (16 combinations) based on predicted 
* choice probabilities from the TIOLI design and based on assumptions outlined 
* in the paper and appendices
*
* REDUCED AVAILABILITY SCENARIO ASSUMPTIONS: 
* p_charging    -> 0.12
* p_below_R200  -> 0.072
* p_below_R50   -> 0.036
*
* Notes:
*   - Calculates:
*       - Expected number of EVs participating per bundle
*       - Annual compensation costs (€M/year) [Aggregator]
*       - Effective power reduction (MW/event)
*       - Total capacity value (€/year) under a CRM
*       - Energy consumption reduction (GWh) 
*       - DAM load shifting value (€/year) using Belgian 2023 prices.
*         Values for dam_pr_8_X are pasted from results of 'Script 6.3.do'.
*       - Net profit (capacity + load shifting – cost) [Aggregator]
*
* Outputs:
*  - "$resultsDir/Table_21.csv"
*  - "$resultsDir/Table_21.tex"
* -----------------------------------------------------------------------------

version 17

use "$intermediateDir/full_design_EV_tioli_with_probas", clear

// Parameters
local increment_number_ev = 1000000
local avg_power_EV_kW = 7.4
local pi_cap_MW = 32000
local p_charging = 0.12

local p_below_R200 = 0.072
local p_below_R50 = 0.036
local delta = 0.5

local P_eff_R200 = `avg_power_EV_kW' * `p_charging' * (1 - `p_below_R200')
local P_eff_R50 = `avg_power_EV_kW' * `p_charging' * (1 - `p_below_R50')

// Mean DAM prices for different frequencies (pasted from 'Script 6.3.do' results)
scalar dam_pr_8_1 = .2367637
scalar dam_pr_8_6 = .2233287
scalar dam_pr_8_12 = .2133345
scalar dam_pr_8_52 = .1842119

// Define the 16 combinations
local range_vals "50 200"
local euro_vals "3 20"
local freq_vals "1 6 12 52"

// Step 1: Create bundles and calculate probabilities
local bundle_num = 0
foreach r of local range_vals {
	foreach e of local euro_vals {
		foreach f of local freq_vals {
			local ++bundle_num
		   
			capture drop bundle`bundle_num'
			gen bundle`bundle_num' = (range_ev == `r' & euro_ev == `e' & freq_ev == `f' & alternative_index != 2)
		   
			sum proba_pool if bundle`bundle_num', meanonly
			scalar p_b`bundle_num' = r(mean)
		   
			scalar r_b`bundle_num' = `r'
			scalar e_b`bundle_num' = `e'
			scalar f_b`bundle_num' = `f'
		}
	}
}

local total_bundles = `bundle_num'
di "Total bundles: `total_bundles'"

// Probability matrix
matrix EV = J(`total_bundles', 1, .)
forvalues b = 1/`total_bundles' {
	matrix EV[`b',1] = p_b`b'
}
matrix colnames EV = proba_pool

local rownames ""
forvalues b = 1/`total_bundles' {
	local rownames `"`rownames' "B`b'(R`=scalar(r_b`b')'E`=scalar(e_b`b')'F`=scalar(f_b`b')')""'
}
matrix rownames EV = `rownames'

matlist EV, format(%6.3f)

// Step 2: Amount in thousands of EVs [in 1000 EVs]
forvalues b = 1/`total_bundles' {
	scalar amt_b`b' = p_b`b' * (`increment_number_ev'/1000)
}

// Step 3: Annual compensation costs [in €M/year]
forvalues b = 1/`total_bundles' {
	scalar cost_b`b' = (amt_b`b' * 1000) * e_b`b' * f_b`b' / 10^6
}

// Step 4: Total effective power reduction [in MW/event]
forvalues b = 1/`total_bundles' {
	if r_b`b' == 50 {
		scalar mw_b`b' = (amt_b`b' * 1000) * `P_eff_R50' / 10^3
	}
	else {
		scalar mw_b`b' = (amt_b`b' * 1000) * `P_eff_R200' / 10^3
	}
}

// Step 5: Total capacity value [in €M/year]
forvalues b = 1/`total_bundles' {
	scalar cap_b`b' = mw_b`b' * `pi_cap_MW' / 10^6
}

// Step 6: Total effective energy consumption reduction
forvalues b = 1/`total_bundles' {
	if r_b`b' == 50 {
		scalar gwh_b`b' = (`P_eff_R50'/1000) * 8 * f_b`b' * (amt_b`b'*1000) / 10^3
	}
	else {
		scalar gwh_b`b' = (`P_eff_R200'/1000) * 8 * f_b`b' * (amt_b`b'*1000) / 10^3
	}
}

// Step 7: Total DAM load shifting value [in €M/year]
forvalues b = 1/`total_bundles' {
	if f_b`b' == 1 {
		scalar ls_b`b' = gwh_b`b' * (dam_pr_8_1 * 10^6) * (1 - `delta') / 10^6
	}
	else if f_b`b' == 6 {
		scalar ls_b`b' = gwh_b`b' * (dam_pr_8_6 * 10^6) * (1 - `delta') / 10^6
	}
	else if f_b`b' == 12 {
		scalar ls_b`b' = gwh_b`b' * (dam_pr_8_12 * 10^6) * (1 - `delta') / 10^6
	}
	else if f_b`b' == 52 {
		scalar ls_b`b' = gwh_b`b' * (dam_pr_8_52 * 10^6) * (1 - `delta') / 10^6
	}
}

// Create final table
preserve
	tempfile T
	postfile p int bundle int range_ev int euro_ev int freq_ev ///
		double amount double P_MW double E_per_call ///
		double V_cap double V_en double cost double net_profit ///
		using `T', replace

	forvalues b = 1/`total_bundles' {
		local E_per_call = (gwh_b`b' / f_b`b') * 10^3 // [MWh/call]
		local net_profit = cap_b`b' + ls_b`b' - cost_b`b'
	   
		post p ///
			(`b') (r_b`b') (e_b`b') (f_b`b') ///
			(amt_b`b') (mw_b`b') (`E_per_call') ///
			(cap_b`b') (ls_b`b') (cost_b`b') (`net_profit')
	}
	postclose p

	use `T', clear
   
	order bundle range_ev euro_ev freq_ev amount P_MW E_per_call V_cap V_en cost net_profit

	format amount P_MW V_cap V_en cost net_profit %12.1f
	format E_per_call %12.2f
   
	sort bundle
   
	list, noobs abbreviate(20) sep(4)
   
	//export delimited using "$resultsDir/Table_21.csv", replace
   
	file open texfile using "$resultsDir/Table_21.tex", write replace
	file write texfile "\begin{tabular}{rrrrrrrrrrr}" _n
	file write texfile "\hline" _n
	file write texfile "Range & Euro & Freq & Amount & P\_MW & E/Call & V\_cap & V\_en & Cost & Net Profit \\" _n
	file write texfile "\hline" _n
   
	forvalues i = 1/`=_N' {
		file write texfile (range_ev[`i']) " & " (euro_ev[`i']) " & " ///
			(freq_ev[`i']) " & " %9.1f (amount[`i']) " & " %9.1f (P_MW[`i']) " & " ///
			%9.2f (E_per_call[`i']) " & " %9.1f (V_cap[`i']) " & " ///
			%9.1f (V_en[`i']) " & " %9.1f (cost[`i']) " & " %9.1f (net_profit[`i']) " \\" _n
	}
   
	file write texfile "\hline" _n
	file write texfile "\end{tabular}" _n
	file close texfile
   
restore
   
end

capture program drop Table_BotE_EV_reduced_mon
program define Table_BotE_EV_reduced_mon

* -----------------------------------------------------------------------------
*
* Program: Table_BotE_EV_reduced_mon
*
* The program computes the impact (energy and financial from an aggregator's 
* viewpoint) of EV flexibility contracts (16 combinations) based on predicted 
* choice probabilities from the TIOLI design and based on assumptions outlined 
* in the paper and appendices
*
* REDUCED MONETIZATION SCENARIO ASSUMPTIONS: 
* delta      -> 0.60
* pi_cap_MW  -> 25,600 €/MW.year
*
* Notes:
*   - Calculates:
*       - Expected number of EVs participating per bundle
*       - Annual compensation costs (€M/year) [Aggregator]
*       - Effective power reduction (MW/event)
*       - Total capacity value (€/year) under a CRM
*       - Energy consumption reduction (GWh) 
*       - DAM load shifting value (€/year) using Belgian 2023 prices.
*         Values for dam_pr_8_X are pasted from results of 'Script 6.3.do'.
*       - Net profit (capacity + load shifting – cost) [Aggregator]
*
* Outputs:
*  - "$resultsDir/Table_22.csv"
*  - "$resultsDir/Table_22.tex"
* -----------------------------------------------------------------------------

version 17

use "$intermediateDir/full_design_EV_tioli_with_probas", clear

// Parameters
local increment_number_ev = 1000000
local avg_power_EV_kW = 7.4
local pi_cap_MW = 25600
local p_charging = 0.15

local p_below_R200 = 0.06
local p_below_R50 = 0.03
local delta = 0.6

local P_eff_R200 = `avg_power_EV_kW' * `p_charging' * (1 - `p_below_R200')
local P_eff_R50 = `avg_power_EV_kW' * `p_charging' * (1 - `p_below_R50')

// Mean DAM prices for different frequencies (pasted from 'Script 6.3.do' results)
scalar dam_pr_8_1 = .2367637
scalar dam_pr_8_6 = .2233287
scalar dam_pr_8_12 = .2133345
scalar dam_pr_8_52 = .1842119

// Define the 16 combinations
local range_vals "50 200"
local euro_vals "3 20"
local freq_vals "1 6 12 52"

// Step 1: Create bundles and calculate probabilities
local bundle_num = 0
foreach r of local range_vals {
	foreach e of local euro_vals {
		foreach f of local freq_vals {
			local ++bundle_num
		   
			capture drop bundle`bundle_num'
			gen bundle`bundle_num' = (range_ev == `r' & euro_ev == `e' & freq_ev == `f' & alternative_index != 2)
		   
			sum proba_pool if bundle`bundle_num', meanonly
			scalar p_b`bundle_num' = r(mean)
		   
			scalar r_b`bundle_num' = `r'
			scalar e_b`bundle_num' = `e'
			scalar f_b`bundle_num' = `f'
		}
	}
}

local total_bundles = `bundle_num'
di "Total bundles: `total_bundles'"

// Probability matrix
matrix EV = J(`total_bundles', 1, .)
forvalues b = 1/`total_bundles' {
	matrix EV[`b',1] = p_b`b'
}
matrix colnames EV = proba_pool

local rownames ""
forvalues b = 1/`total_bundles' {
	local rownames `"`rownames' "B`b'(R`=scalar(r_b`b')'E`=scalar(e_b`b')'F`=scalar(f_b`b')')""'
}
matrix rownames EV = `rownames'

matlist EV, format(%6.3f)

// Step 2: Amount in thousands of EVs [in 1000 EVs]
forvalues b = 1/`total_bundles' {
	scalar amt_b`b' = p_b`b' * (`increment_number_ev'/1000)
}

// Step 3: Annual compensation costs [in €M/year]
forvalues b = 1/`total_bundles' {
	scalar cost_b`b' = (amt_b`b' * 1000) * e_b`b' * f_b`b' / 10^6
}

// Step 4: Total effective power reduction [in MW/event]
forvalues b = 1/`total_bundles' {
	if r_b`b' == 50 {
		scalar mw_b`b' = (amt_b`b' * 1000) * `P_eff_R50' / 10^3
	}
	else {
		scalar mw_b`b' = (amt_b`b' * 1000) * `P_eff_R200' / 10^3
	}
}

// Step 5: Total capacity value [in €M/year]
forvalues b = 1/`total_bundles' {
	scalar cap_b`b' = mw_b`b' * `pi_cap_MW' / 10^6
}

// Step 6: Total effective energy consumption reduction
forvalues b = 1/`total_bundles' {
	if r_b`b' == 50 {
		scalar gwh_b`b' = (`P_eff_R50'/1000) * 8 * f_b`b' * (amt_b`b'*1000) / 10^3
	}
	else {
		scalar gwh_b`b' = (`P_eff_R200'/1000) * 8 * f_b`b' * (amt_b`b'*1000) / 10^3
	}
}

// Step 7: Total DAM load shifting value [in €M/year]
forvalues b = 1/`total_bundles' {
	if f_b`b' == 1 {
		scalar ls_b`b' = gwh_b`b' * (dam_pr_8_1 * 10^6) * (1 - `delta') / 10^6
	}
	else if f_b`b' == 6 {
		scalar ls_b`b' = gwh_b`b' * (dam_pr_8_6 * 10^6) * (1 - `delta') / 10^6
	}
	else if f_b`b' == 12 {
		scalar ls_b`b' = gwh_b`b' * (dam_pr_8_12 * 10^6) * (1 - `delta') / 10^6
	}
	else if f_b`b' == 52 {
		scalar ls_b`b' = gwh_b`b' * (dam_pr_8_52 * 10^6) * (1 - `delta') / 10^6
	}
}

// Create final table
preserve
	tempfile T
	postfile p int bundle int range_ev int euro_ev int freq_ev ///
		double amount double P_MW double E_per_call ///
		double V_cap double V_en double cost double net_profit ///
		using `T', replace

	forvalues b = 1/`total_bundles' {
		local E_per_call = (gwh_b`b' / f_b`b') * 10^3 // [MWh/call]
		local net_profit = cap_b`b' + ls_b`b' - cost_b`b'
	   
		post p ///
			(`b') (r_b`b') (e_b`b') (f_b`b') ///
			(amt_b`b') (mw_b`b') (`E_per_call') ///
			(cap_b`b') (ls_b`b') (cost_b`b') (`net_profit')
	}
	postclose p

	use `T', clear
   
	order bundle range_ev euro_ev freq_ev amount P_MW E_per_call V_cap V_en cost net_profit

	format amount P_MW V_cap V_en cost net_profit %12.1f
	format E_per_call %12.2f
   
	sort bundle
   
	list, noobs abbreviate(20) sep(4)
   
	//export delimited using "$resultsDir/Table_22.csv", replace
   
	file open texfile using "$resultsDir/Table_22.tex", write replace
	file write texfile "\begin{tabular}{rrrrrrrrrrr}" _n
	file write texfile "\hline" _n
	file write texfile "Range & Euro & Freq & Amount & P\_MW & E/Call & V\_cap & V\_en & Cost & Net Profit \\" _n
	file write texfile "\hline" _n
   
	forvalues i = 1/`=_N' {
		file write texfile (range_ev[`i']) " & " (euro_ev[`i']) " & " ///
			(freq_ev[`i']) " & " %9.1f (amount[`i']) " & " %9.1f (P_MW[`i']) " & " ///
			%9.2f (E_per_call[`i']) " & " %9.1f (V_cap[`i']) " & " ///
			%9.1f (V_en[`i']) " & " %9.1f (cost[`i']) " & " %9.1f (net_profit[`i']) " \\" _n
	}
   
	file write texfile "\hline" _n
	file write texfile "\end{tabular}" _n
	file close texfile
   
restore
   
end

** Choice experiment on HP flexibility: 

capture program drop Table_BotE_HP_reduced_av
program define Table_BotE_HP_reduced_av

* -----------------------------------------------------------------------------
*
* Program: Table_BotE_HP_reduced_av
*
* The program computes the impact (energy and financial from an aggregator's 
* viewpoint) of HP flexibility contracts (16 combinations) based on predicted 
* choice probabilities from the TIOLI design and based on assumptions outlined 
* in the paper and appendices 
*
* REDUCED AVAILABILITY SCENARIO ASSUMPTIONS: 
* p_below_T19   -> 0.504
* p_below_T16   -> 0.084
*
*
* Notes:
*   - Calculates:
*       - Expected number of HPs participating per bundle
*       - Annual compensation costs (€M/year) [Aggregator]
*       - Effective power reduction (MW/event)
*       - Total capacity value (€/year) under a CRM
*       - Energy consumption reduction (GWh) 
*       - DAM load shifting value (€/year) using Belgian 2023 prices.
*         Values for dam_pr_[4,14]_X are pasted from results of 'Script 6.3.do'.
*       - Net profit (capacity + load shifting – cost) [Aggregator]
*
* Outputs:
*  - "$resultsDir/Table_23.csv"
*  - "$resultsDir/Table_23.tex"
* -----------------------------------------------------------------------------

use "$intermediateDir/full_design_HP_tioli_with_probas", clear

// Parameters
local increment_number_hp = 1000000
local avg_power_HP_kW = 0.45
local pi_cap_MW = 32000
local p_below_T19 = 0.504
local p_below_T16 = 0.084
local delta = 0.5

local P_eff_T19 = `avg_power_HP_kW' * (1 - `p_below_T19')
local P_eff_T16 = `avg_power_HP_kW' * (1 - `p_below_T16')

// Mean DAM prices for different frequencies
scalar dam_pr_4_1 = .2519925
scalar dam_pr_4_6 = .2422217
scalar dam_pr_4_12 = .2330069
scalar dam_pr_4_52 = .2039769

scalar dam_pr_14_1 = .2331421
scalar dam_pr_14_6 = .2161788
scalar dam_pr_14_12 = .2034048
scalar dam_pr_14_52 = .1695265

// Define the 16 combinations
local temp_vals "16 19"
local euro_vals "1 4"
local freq_vals "1 6 12 52"

// Step 1: Create bundles and calculate probabilities
local bundle_num = 0
foreach t of local temp_vals {
	foreach e of local euro_vals {
		foreach f of local freq_vals {
			local ++bundle_num
		   
			capture drop bundle`bundle_num'
			gen bundle`bundle_num' = (temp_hp == `t' & euro_hp == `e' & freq_hp == `f' & alternative_index != 2)
		   
			sum proba_pool if bundle`bundle_num', meanonly
			scalar p_b`bundle_num' = r(mean)
		   
			scalar t_b`bundle_num' = `t'
			scalar e_b`bundle_num' = `e'
			scalar f_b`bundle_num' = `f'
		}
	}
}

local total_bundles = `bundle_num'

// Probability matrix
matrix HP = J(`total_bundles', 1, .)
forvalues b = 1/`total_bundles' {
	matrix HP[`b',1] = p_b`b'
}
matrix colnames HP = proba_pool

local rownames ""
forvalues b = 1/`total_bundles' {
	local rownames `"`rownames' "B`b'(T`=scalar(t_b`b')'E`=scalar(e_b`b')'F`=scalar(f_b`b')')""'
}
matrix rownames HP = `rownames'

matlist HP, format(%6.3f)

// Step 2: Amount [in 1000 HPs]
forvalues b = 1/`total_bundles' {
	scalar amt_b`b' = p_b`b' * (`increment_number_hp'/1000)
}

// Step 3: Annual compensation costs [in €M/year]
forvalues b = 1/`total_bundles' {
	scalar cost_b`b' = (amt_b`b' * 1000) * (e_b`b') * f_b`b' / 10^6 
}

// Step 4: Total effective power reduction [in MW/event]
forvalues b = 1/`total_bundles' {
	if t_b`b' == 16 {
		scalar mw_b`b' = (amt_b`b' * 1000) * `P_eff_T16' / 10^3
	}
	else {
		scalar mw_b`b' = (amt_b`b' * 1000) * `P_eff_T19' / 10^3
	}
}

// Step 5: Total capacity value [in €M/year]
forvalues b = 1/`total_bundles' {
	scalar cap_b`b' = mw_b`b' * `pi_cap_MW' / 10^6
}

// Step 6: Total effective energy consumption reduction [in GWh/year]
forvalues b = 1/`total_bundles' {
	if t_b`b' == 16 {
		scalar gwh_b`b' = (`P_eff_T16'/1000) * 14 * f_b`b' * (amt_b`b'*1000) / 10^3
	}
	else {
		scalar gwh_b`b' = (`P_eff_T19'/1000) * 4 * f_b`b' * (amt_b`b'*1000) / 10^3
	}
}

// Step 7: Total DAM load shifting value [in €M/year]
forvalues b = 1/`total_bundles' {
	if t_b`b' == 16 {
		if f_b`b' == 1 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_14_1 * 10^6) * (1 - `delta') / 10^6
		}
		else if f_b`b' == 6 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_14_6 * 10^6) * (1 - `delta') / 10^6
		}
		else if f_b`b' == 12 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_14_12 * 10^6) * (1 - `delta') / 10^6
		}
		else if f_b`b' == 52 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_14_52 * 10^6) * (1 - `delta') / 10^6
		}
	}
	else {
		if f_b`b' == 1 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_4_1 * 10^6) * (1 - `delta') / 10^6
		}
		else if f_b`b' == 6 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_4_6 * 10^6) * (1 - `delta') / 10^6
		}
		else if f_b`b' == 12 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_4_12 * 10^6) * (1 - `delta') / 10^6
		}
		else if f_b`b' == 52 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_4_52 * 10^6) * (1 - `delta') / 10^6
		}
	}
}

// Create final table
preserve
	tempfile T
	postfile p int bundle int temp_hp int euro_hp int freq_hp ///
		double amount double P_MW double E_per_call ///
		double V_cap double V_en double cost double net_profit ///
		using `T', replace

	forvalues b = 1/`total_bundles' {
		local E_per_call = (gwh_b`b' / f_b`b') * 10^3 // [MWh/call]
		local net_profit = cap_b`b' + ls_b`b' - cost_b`b'
	   
		post p ///
			(`b') (t_b`b') (e_b`b') (f_b`b') ///
			(amt_b`b') (mw_b`b') (`E_per_call') ///
			(cap_b`b') (ls_b`b') (cost_b`b') (`net_profit')
	}
	postclose p

	use `T', clear
   
	order bundle temp_hp euro_hp freq_hp amount P_MW E_per_call V_cap V_en cost net_profit

	format amount P_MW V_cap V_en cost net_profit %12.1f
	format E_per_call %12.2f
   
	sort bundle
   
	list, noobs abbreviate(20) sep(4)
   
	//export delimited using "$resultsDir/Table_23.csv", replace
   
	file open texfile using "$resultsDir/Table_23.tex", write replace
	file write texfile "\begin{tabular}{rrrrrrrrrrr}" _n
	file write texfile "\hline" _n
	file write texfile "Temp & Euro & Freq & Amount & P\_MW & E/Call & V\_cap & V\_en & Cost & Net Profit \\" _n
	file write texfile "\hline" _n
   
	forvalues i = 1/`=_N' {
		file write texfile (temp_hp[`i']) " & " (euro_hp[`i']) " & " ///
			(freq_hp[`i']) " & " %9.1f (amount[`i']) " & " %9.1f (P_MW[`i']) " & " ///
			%9.2f (E_per_call[`i']) " & " %9.1f (V_cap[`i']) " & " ///
			%9.1f (V_en[`i']) " & " %9.1f (cost[`i']) " & " %9.1f (net_profit[`i']) " \\" _n
	}
   
	file write texfile "\hline" _n
	file write texfile "\end{tabular}" _n
	file close texfile
   
restore
   
end

capture program drop Table_BotE_HP_reduced_mon
program define Table_BotE_HP_reduced_mon

* -----------------------------------------------------------------------------
*
* Program: Table_BotE_HP_reduced_mon
*
* The program computes the impact (energy and financial from an aggregator's 
* viewpoint) of HP flexibility contracts (16 combinations) based on predicted 
* choice probabilities from the TIOLI design and based on assumptions outlined 
* in the paper and appendices 
*
* REDUCED MONETIZATION SCENARIO ASSUMPTIONS: 
* delta      -> 0.60
* pi_cap_MW  -> 25,600 €/MW.year
*
* Notes:
*   - Calculates:
*       - Expected number of HPs participating per bundle
*       - Annual compensation costs (€M/year) [Aggregator]
*       - Effective power reduction (MW/event)
*       - Total capacity value (€/year) under a CRM
*       - Energy consumption reduction (GWh) 
*       - DAM load shifting value (€/year) using Belgian 2023 prices.
*         Values for dam_pr_[4,14]_X are pasted from results of 'Script 6.3.do'.
*       - Net profit (capacity + load shifting – cost) [Aggregator]
*
* Outputs:
*  - "$resultsDir/Table_24.csv"
*  - "$resultsDir/Table_24.tex"
* -----------------------------------------------------------------------------

use "$intermediateDir/full_design_HP_tioli_with_probas", clear

// Parameters
local increment_number_hp = 1000000
local avg_power_HP_kW = 0.45
local pi_cap_MW = 25600
local p_below_T19 = 0.42
local p_below_T16 = 0.07
local delta = 0.6

local P_eff_T19 = `avg_power_HP_kW' * (1 - `p_below_T19')
local P_eff_T16 = `avg_power_HP_kW' * (1 - `p_below_T16')

// Mean DAM prices for different frequencies
scalar dam_pr_4_1 = .2519925
scalar dam_pr_4_6 = .2422217
scalar dam_pr_4_12 = .2330069
scalar dam_pr_4_52 = .2039769

scalar dam_pr_14_1 = .2331421
scalar dam_pr_14_6 = .2161788
scalar dam_pr_14_12 = .2034048
scalar dam_pr_14_52 = .1695265

// Define the 16 combinations
local temp_vals "16 19"
local euro_vals "1 4"
local freq_vals "1 6 12 52"

// Step 1: Create bundles and calculate probabilities
local bundle_num = 0
foreach t of local temp_vals {
	foreach e of local euro_vals {
		foreach f of local freq_vals {
			local ++bundle_num
		   
			capture drop bundle`bundle_num'
			gen bundle`bundle_num' = (temp_hp == `t' & euro_hp == `e' & freq_hp == `f' & alternative_index != 2)
		   
			sum proba_pool if bundle`bundle_num', meanonly
			scalar p_b`bundle_num' = r(mean)
		   
			scalar t_b`bundle_num' = `t'
			scalar e_b`bundle_num' = `e'
			scalar f_b`bundle_num' = `f'
		}
	}
}

local total_bundles = `bundle_num'

// Probability matrix
matrix HP = J(`total_bundles', 1, .)
forvalues b = 1/`total_bundles' {
	matrix HP[`b',1] = p_b`b'
}
matrix colnames HP = proba_pool

local rownames ""
forvalues b = 1/`total_bundles' {
	local rownames `"`rownames' "B`b'(T`=scalar(t_b`b')'E`=scalar(e_b`b')'F`=scalar(f_b`b')')""'
}
matrix rownames HP = `rownames'

matlist HP, format(%6.3f)

// Step 2: Amount [in 1000 HPs]
forvalues b = 1/`total_bundles' {
	scalar amt_b`b' = p_b`b' * (`increment_number_hp'/1000)
}

// Step 3: Annual compensation costs [in €M/year]
forvalues b = 1/`total_bundles' {
	scalar cost_b`b' = (amt_b`b' * 1000) * (e_b`b') * f_b`b' / 10^6 
}

// Step 4: Total effective power reduction [in MW/event]
forvalues b = 1/`total_bundles' {
	if t_b`b' == 16 {
		scalar mw_b`b' = (amt_b`b' * 1000) * `P_eff_T16' / 10^3
	}
	else {
		scalar mw_b`b' = (amt_b`b' * 1000) * `P_eff_T19' / 10^3
	}
}

// Step 5: Total capacity value [in €M/year]
forvalues b = 1/`total_bundles' {
	scalar cap_b`b' = mw_b`b' * `pi_cap_MW' / 10^6
}

// Step 6: Total effective energy consumption reduction [in GWh/year]
forvalues b = 1/`total_bundles' {
	if t_b`b' == 16 {
		scalar gwh_b`b' = (`P_eff_T16'/1000) * 14 * f_b`b' * (amt_b`b'*1000) / 10^3
	}
	else {
		scalar gwh_b`b' = (`P_eff_T19'/1000) * 4 * f_b`b' * (amt_b`b'*1000) / 10^3
	}
}

// Step 7: Total DAM load shifting value [in €M/year]
forvalues b = 1/`total_bundles' {
	if t_b`b' == 16 {
		if f_b`b' == 1 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_14_1 * 10^6) * (1 - `delta') / 10^6
		}
		else if f_b`b' == 6 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_14_6 * 10^6) * (1 - `delta') / 10^6
		}
		else if f_b`b' == 12 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_14_12 * 10^6) * (1 - `delta') / 10^6
		}
		else if f_b`b' == 52 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_14_52 * 10^6) * (1 - `delta') / 10^6
		}
	}
	else {
		if f_b`b' == 1 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_4_1 * 10^6) * (1 - `delta') / 10^6
		}
		else if f_b`b' == 6 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_4_6 * 10^6) * (1 - `delta') / 10^6
		}
		else if f_b`b' == 12 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_4_12 * 10^6) * (1 - `delta') / 10^6
		}
		else if f_b`b' == 52 {
			scalar ls_b`b' = gwh_b`b' * (dam_pr_4_52 * 10^6) * (1 - `delta') / 10^6
		}
	}
}

// Create final table
preserve
	tempfile T
	postfile p int bundle int temp_hp int euro_hp int freq_hp ///
		double amount double P_MW double E_per_call ///
		double V_cap double V_en double cost double net_profit ///
		using `T', replace

	forvalues b = 1/`total_bundles' {
		local E_per_call = (gwh_b`b' / f_b`b') * 10^3 // [MWh/call]
		local net_profit = cap_b`b' + ls_b`b' - cost_b`b'
	   
		post p ///
			(`b') (t_b`b') (e_b`b') (f_b`b') ///
			(amt_b`b') (mw_b`b') (`E_per_call') ///
			(cap_b`b') (ls_b`b') (cost_b`b') (`net_profit')
	}
	postclose p

	use `T', clear
   
	order bundle temp_hp euro_hp freq_hp amount P_MW E_per_call V_cap V_en cost net_profit

	format amount P_MW V_cap V_en cost net_profit %12.1f
	format E_per_call %12.2f
   
	sort bundle
   
	list, noobs abbreviate(20) sep(4)
   
	//export delimited using "$resultsDir/Table_24.csv", replace
   
	file open texfile using "$resultsDir/Table_24.tex", write replace
	file write texfile "\begin{tabular}{rrrrrrrrrrr}" _n
	file write texfile "\hline" _n
	file write texfile "Temp & Euro & Freq & Amount & P\_MW & E/Call & V\_cap & V\_en & Cost & Net Profit \\" _n
	file write texfile "\hline" _n
   
	forvalues i = 1/`=_N' {
		file write texfile (temp_hp[`i']) " & " (euro_hp[`i']) " & " ///
			(freq_hp[`i']) " & " %9.1f (amount[`i']) " & " %9.1f (P_MW[`i']) " & " ///
			%9.2f (E_per_call[`i']) " & " %9.1f (V_cap[`i']) " & " ///
			%9.1f (V_en[`i']) " & " %9.1f (cost[`i']) " & " %9.1f (net_profit[`i']) " \\" _n
	}
   
	file write texfile "\hline" _n
	file write texfile "\end{tabular}" _n
	file close texfile
   
restore
   
end

* Tables 21 and 22
Table_BotE_EV_reduced_av
Table_BotE_EV_reduced_mon

* Tables 23 and 24
Table_BotE_HP_reduced_av
Table_BotE_HP_reduced_mon