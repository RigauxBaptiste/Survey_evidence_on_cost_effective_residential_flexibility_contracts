/*******************************************************************************
 Paper title   : Survey evidence on cost-effective residential flexibility 
                 contracts for electric vehicles and heat pumps 
 Paper authors : Baptiste Rigaux (*), Sam Hamels, Marten Ovaere
 Affiliation   : Department of Economics, Ghent University (Belgium)
 Contact       : (*) baptiste.rigaux@ugent.be
 Date          : 2026 Feb 3rd

! THIS SCRIPT MUST BE CALLED FROM Main.do !
 
Description: Script_KR_Simulation_procedure 

This script performs the elements of the analysis that require a Krinsky-Robb
'simulation' procedure. Specifically, it generates 1,000 .ster estimation
files [*] where coefficients are randomly drawn from their asymptotic normal
distribution at model convergence. These random draws are then used to:

- Perform the heterogeneity analysis for the marginal WTA of large comfort
  impacts (Section 5.2.3) and assess how uncertainty in model parameters
  propagates into uncertainty in MWTA regression estimates.
- Estimate average partial effects (APEs) discussed in Section 6.1 and assess
  how parameter uncertainty propagates into uncertainty in APEs.

This program does not take any explicit input; it must be run within the main
script. In other words, it reuses the framework (globals, data setup) of the
main script.

Outputs are stored in: root/Results/...
Intermediate files are stored in: root/Intermediate/...

[*] Generated .ster files have been pasted in
    root/Intermediate/Simulation to allow reproducibility of results. Note that
    re-running the bootstrap generation may take several days and, due to
    randomness, may produce (negligible) differences if another seed is used.	
		
Console outputs are used directly in the text of the paper.

We reuse the same Krinsky-Robb replications for the .ster files each time.

*******************************************************************************/

log using "$intermediateDir/log_KR_sim.log", replace

// Simulation parameters: 

set seed 42
global nreps 1000

global simulationDir "$intermediateDir/Estimation files Krinsky-Robb simulation"

***********************************************
***********************************************
*											  *
*                     EVs                     *
*											  *
***********************************************
***********************************************

// A: Generate replications of models .ster

capture program drop generate_simulation_ster_EV
program define generate_simulation_ster_EV

*------------------------------------------------------------------------------*
* Program: generate_simulation_ster_EV
*
* Generate Krinsky–Robb simulation draws for the pooled EV mixed logit model 
* (preferred specification). In other words: random draws of estimated parameters
* mean preferences and full covariance matrix around their asymptotic normal
* distribution.
*
* Input:
*   - $data                       : estimation dataset
*   - $pref_spec_pooled_EV        : baseline .ster estimation file
*   - $nreps                      : number of replications
*
* Output:
*   - Replicated .ster files saved in $simulationDir
*------------------------------------------------------------------------------*
	
	use "$data", clear

	estimates use "$pref_spec_pooled_EV"

	matrix b = e(b)
	matrix V = e(V)
	local  k = colsof(b)

	* Generate s random normal draws around the parameters at convergence for EV
	* choice exp (pooled model 2, mixed logit correlated)
	
	forvalues i = 1/$nreps {
		di "Iteration `i'/$nreps"
		preserve
		clear
		drawnorm z1-z`k', n(1) means(b) cov(V)
		mkmat z1-z`k', matrix(bdraw)
		restore
	 
		qui mixlogit choice_ev euro_ev, group(_caseid) id(response_id) ///
		rand($model2_ev) technique(bfgs) corr nrep(1) from(bdraw, copy) ///
		iterate(0) // No need to iterate, just need the '.ster' file framework

		estimates save "$simulationDir/save_pool_model2_ev_mix_corr_`i'.ster", replace

	}

end

// Uncomment to re-run the programs:			
// generate_simulation_ster_EV

// B: Design and probabilities

	* Create the TIOLI design 

generate_tioli_design_EV
use "$intermediateDir/full_design_EV_tioli.dta", clear
qui gen _caseid = choice_situation_ev 
qui gen response_id = choice_situation_ev
save "$intermediateDir/EV_TIOLI_design_simxprobas.dta", replace

global EV_TIOLI_design_simxprobas "$intermediateDir/EV_TIOLI_design_simxprobas.dta"

	* Bootstrapped probabilities

capture program drop gen_simulation_proba_EV
program define gen_simulation_proba_EV

*------------------------------------------------------------------------------*
* Program: gen_simulation_proba_EV
*
* Generate replicated acceptance probabilities for the EV TIOLI design using
* replicated model estimates. TIOLI: take-it-or-leave-it (only one contract
* vs. optout, i.e. no between-alternative competition).
*
* Input:
*   - $data
*   - $pref_spec_pooled_EV
*   - $EV_TIOLI_design_simxprobas : TIOLI design dataset
*   - Replicated .ster files in $simulationDir
*   - $nreps
*
* Output:
*   - Updated $EV_TIOLI_design_simxprobas dataset with baseline and replicated 
*     predicted probabilities
*------------------------------------------------------------------------------*

use "$data", clear

estimates use "$pref_spec_pooled_EV"

matrix b = e(b)
matrix V = e(V)

local  k = colsof(b)

* Generate nreps times the contract acceptance probabilities in TIOLI 

forvalues s = 0/$nreps {
	if `s' == 0 {
		generate_tioli_design_EV
		use "$EV_TIOLI_design_simxprobas", clear
		estimates use "$pref_spec_pooled_EV"
		capture drop proba_validated_model
		mixlpred proba_validated_model, nrep(2000) burn(15)
		qui save "$EV_TIOLI_design_simxprobas", replace
		continue
	}
		
	di "Iteration `s'/$nreps"
	
	use "$EV_TIOLI_design_simxprobas", clear
	
	estimates use "$simulationDir/save_pool_model2_ev_mix_corr_`s'.ster"
	capture drop proba_`s'
	mixlpred proba_`s', nrep(2000) burn(15)

	qui save "$EV_TIOLI_design_simxprobas", replace
	
}

end

// Uncomment to re-run the programs:			
// gen_simulation_proba_EV

	* APEs and CIs
	
capture program drop compute_APE_simulation_EV
program define compute_APE_simulation_EV

*------------------------------------------------------------------------------*
* Program: compute_APE_simulation_EV
*
* Compute simulated distributions of Average Partial Effects (APE) of a €1 
* increase in per-intervention compensation on EV contract acceptance
* probabilities.
*
* Input:
*   - $EV_TIOLI_design_simxprobas : TIOLI design with replicated probabilities
*   - Replicated .ster files in $simulationDir
*   - $nreps
*
* Output:
*   - Console output: mean APE and 95% CI
*   - Dataset: $intermediateDir/APE_simulation_results.dta
*------------------------------------------------------------------------------*

// Base TIOLI design: 

	use "$intermediateDir/EV_TIOLI_design_simxprobas.dta", clear
	tempfile design_base
	save `design_base'

// File to store all the APEs for each iteration 

	clear
	set obs $nreps
	gen simulation_rep = _n
	gen ape_pp = .
	tempfile ape_results
	save `ape_results'
	
// Replications of APEs of increasing compensation by €1 

forvalues s = 1/$nreps {
    di "Simulation for APE of increasing compensation by €1/inter. `s'/$nreps"
    
    * Load replicated estimation files 
    estimates use "$simulationDir/save_pool_model2_ev_mix_corr_`s'.ster"
    
    * Baseline: €k/intervention 
    use `design_base', clear
    qui mixlpred proba_baseline, nrep(2000) burn(15)
    qui sum proba_baseline if alternative_index == 1
    local proba_before = r(mean)
    
    * --> €k+1/intervention 
    use `design_base', clear
    qui replace euro_ev = euro_ev + 1 if alternative_index == 1
    qui mixlpred proba_after, nrep(2000) burn(15)
    qui sum proba_after if alternative_index == 1
    local proba_after = r(mean)
    
    * APE in pp
    local ape_s_pp = 100*(`proba_after' - `proba_before')
    use `ape_results', clear
    qui replace ape = `ape_s_pp' if simulation_rep == `s'
    qui save `ape_results', replace
}


// Calculating the CI 

use `ape_results', clear

sum ape_pp, d
egen sim_mean = mean(ape_pp)
_pctile ape_pp, p(2.5 97.5)

display "Average Partial Effect (APE)"
display "Mean APE: " %6.4f sim_mean[1]
display "95% CI: [" %6.4f r(r1) ", " %6.4f r(r2) "]"

save "$intermediateDir/APE_EV_simulation_results.dta", replace

end

compute_APE_simulation_EV

// C: Conditional parameters and replicated WTA regressions

	* Generate replicated (= simulated) individual level parameters

capture program drop gen_indiv_betas_simulation_EV
program define gen_indiv_betas_simulation_EV

*------------------------------------------------------------------------------*
* Program: gen_indiv_betas_simulation_EV
*
* Simulate individual-level random coefficients for the EV mixed logit model 
* using Krinsky–Robb estimates. Note: "individual-level" = "conditional" =
* = "posterior" (see Appendix C.4)
*
* Input:
*   - $data                         : survey dataset
*   - Replicated .ster files in $simulationDir
*   - $model2_ev                    : list of random coefficients
*   - $nreps                        : number of simulation replications
*
* Output:
*   - Individual-level beta datasets saved in $simulationDir/Individual betas/
*------------------------------------------------------------------------------*

* Generate S times the individual level parameters
forvalues s = 1/$nreps {
	di "Iteration `s'/$nreps"
	
	use "$data", clear
	
	estimates use "$simulationDir/save_pool_model2_ev_mix_corr_`s'.ster"
	mixlbeta euro_ev $model2_ev, ///
	  saving("$simulationDir/Individual betas/pool_model2_ev_mix_corr_beta_`s'.dta") ///
	  replace nrep(2000) burn(15)
    use "$simulationDir/Individual betas/pool_model2_ev_mix_corr_beta_`s'.dta", clear
	foreach var of varlist _all {
		if "`var'" != "response_id"{
			rename `var' beta_ev_`var'
			}
	}
	merge 1:m response_id using "$data", nogen
	sort response_id choice_situation_ev alternative_index
	
	duplicates drop response_id, force
	
    save "$simulationDir/Individual betas/pool_model2_ev_mix_corr_survey_beta_`s'.dta", replace
}

end

gen_indiv_betas_simulation_EV

	* Prepare regression variables 
	
capture program drop dep_variables_preparation_ev 
program define dep_variables_preparation_ev

*------------------------------------------------------------------------------*
* Program: dep_variables_preparation_ev
*
* Description:
*   Prepares additional dependent and control variables for EV analysis.
*   Includes:
*     - Household car ownership and total daily driving distance
*     - Dwelling characteristics (size, ownership)
*     - Respondent sociodemographics categorized for regression 
*       (income, education, employment, age)
*     - Country of residence coded as categorical variable
*
* Notes:
*   - Continuous variables are truncated or recoded to handle extreme or missing values.
*   - Categorical variables are harmonized into levels for clean regressions.
*------------------------------------------------------------------------------*

// EV: how many cars do households that report using car as main transport means have? 

capture drop cars_main_number
gen cars_main_number = .
replace cars_main_number = 0 if car_main_transport_mean_how_many == -99
replace cars_main_number = 1 if car_main_transport_mean_how_many == 1
replace cars_main_number = 2 if car_main_transport_mean_how_many == 2
replace cars_main_number = 3 if car_main_transport_mean_how_many == 3
// Category 3 aggregates households with three or more cars. ///
// This group represents a small share of the sample (≈5%).

// EV: average distance travelled by car everyday 

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
// Upper bound to exclude extreme values likely driven by reporting errors.
// Although distances are aggregated across multiple vehicles, 
// 500 km corresponds approximately to the 97.9th percentile of the distribution.

* has_ev: Need to replace main_mobility_system_EV in order to identify across the 
* entire population, not only across people with cars. 

capture drop has_ev
gen has_ev = is_there_electric_in_here == 1
				
// Dwelling characteristics 

capture drop dwelling_leq_100
gen dwelling_leq_100 = 0
replace dwelling_leq_100  = 1 if dwelling_size >= 3

capture drop dwelling_homeowner
gen dwelling_homeowner = 0
replace dwelling_homeowner = 1 if dwelling_ownership == 1

// Respondent sociodemographics, used as control 
	
	*** Total monthly net household income in three categories

	capture drop inc_cat3
	gen inc_cat3 = .
	replace inc_cat3 = 1 if inlist(household_income, 1, 2)    // <2000 and 2000-2999
	replace inc_cat3 = 2 if inlist(household_income, 3, 4)    // 3000-3999 and 4000-4999
	replace inc_cat3 = 3 if inlist(household_income, 5, 6)    // 5000-5999 and >6000
	replace inc_cat3 = 4 if household_income == 7             // Rather not say
	capture label drop inc3
	label define inc3 1 "Lower (<3000€)" 2 "Mid (3000–4999€)" 3 "High (5000€+)" 4 "Rather not say"
	label values inc_cat3 inc3		
		
	*** Respondent's highest education attainment in three categories 

	capture drop edu3
	gen edu3 = .
	replace edu3 = 1 if inlist(education, 1, 2)   // Non-tertiary: Elementary + Secondary
	replace edu3 = 2 if education == 3            // Bachelor
	replace edu3 = 3 if inlist(education, 4, 5)   // Postgraduate: Master + PhD
	replace edu3 = . if education == 6
	capture label drop edu3lbl
	label define edu3lbl 1 "Non-tertiary education" 2 "Bachelor" 3 "Postgraduate"
	label values edu3 edu3lbl

	*** Employment status : categorical variable with 4 categories

	capture drop emp4
	gen emp4 = .
	// Employment status level coding: 
	// 1: Working full time, 
	// 2: Working part-time
	// 3: Unemployed and job seeker,
	// 4: Stay-at-home, 
	// 5: Student,
	// 6: Retired, 
	// 7: Unable to work, 
	// 8: Other, 
	// 9: Rather not say.	
	replace emp4 = 1 if inlist(employment_status, 1, 2) 
	replace emp4 = 2 if inlist(employment_status, 3, 4, 7, 8, 9) //
	replace emp4 = 3 if employment_status == 5
	replace emp4 = 4 if employment_status == 6
	capture label drop emp4lbl
	label define emp4lbl 1 "Working" 2 "Not working (non-retired)" 3 "Student" 4 "Retired"
	label values emp4 emp4lbl

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

	* Run regressions nreps times
	
capture program drop run_WTA_reg_simulation_EV	
program define run_WTA_reg_simulation_EV

*------------------------------------------------------------------------------*
* Program: run_WTA_reg_simulation_EV
*
* Purpose: Perform WTA regression simulations for EV MWTA for largest discomfort
*          during interventions using pre-simulated individual-level betas.
*
* Functionality:
*   - Iterates over S simulation replications of individual betas
*   - Computes MWTA per individual and intervention for Range 50 (€ per unit)
*   - Prepares covariates (driving habits, attitudinal, sociodemographics, controls)
*   - Runs linear regressions for each replication
*   - Stores coefficients and robust SEs in a postfile for later aggregation
*
* Input: 
*   - Individual betas: "$simulationDir/Individual betas/pool_model2_ev_mix_corr_survey_beta_*.dta"
*   - Prepared covariates: dep_variables_preparation_ev
*
* Output:
*   - Postfile: "$intermediateDir/Simulation_EV_reg_results": model name, variable, coef, SE, replication
*------------------------------------------------------------------------------*

// Define covariates 

	global driving_habits has_ev i.degree_electric_mobility cars_main_number total_km_if  
	global attitudinal energy_saving_metric_mean knowledge_metric_mean ecofriendliness_metric_mean
	global sociodemographics coop_channel kids_number_hh i.inc_cat3 dwelling_homeowner i.dwelling_environment i.dwelling_category i.state
	global controls_respondent ib1.age3 respondent_female i.emp4 ib(1).edu3
	
// Create and open a post file to store regression results

capture postclose simrep 
postfile simrep str20 model str40 varname b se rep using "$intermediateDir/Simulation_EV_reg_results", replace

	// Step 1: 
	
	use "$data", clear
	estimates use "$pref_spec_pooled_EV"
	mixlbeta euro_ev $model2_ev, ///
	  saving("$intermediateDir/pool_model2_ev_mix_corr_beta.dta") ///
	  replace nrep(2000) burn(15)
    use "$intermediateDir/pool_model2_ev_mix_corr_beta.dta", clear
	foreach var of varlist _all {
		if "`var'" != "response_id"{
			rename `var' beta_ev_`var'
			}
	}
	merge 1:m response_id using "$data", nogen
	sort response_id choice_situation_ev alternative_index
	
	duplicates drop response_id, force
		
	capture drop wta_range_50
	gen wta_range_50 = -beta_ev_range_50/beta_ev_euro_ev
		
	qui dep_variables_preparation_ev
		
	reg wta_range_50 $driving_habits $attitudinal $sociodemographics $controls_respondent, vce(robust)
	
	estat vif

	// Simulation loop: 
	
	forvalues s = 1/$nreps {
		
		di "Iteration of WTA regression replication: `s'/$nreps"
	    use "$simulationDir/Individual betas/pool_model2_ev_mix_corr_survey_beta_`s'.dta", clear 
		
		// Calculate individual WTAs

			capture drop wta_range_50
			gen wta_range_50 = -beta_ev_range_50/beta_ev_euro_ev
		
		// Prepare variables 
		
			qui dep_variables_preparation_ev
			
		// Regression WTA Range 50
		
			qui reg wta_range_50 $driving_habits $attitudinal $sociodemographics $controls_respondent, vce(robust)

			matrix b1 = e(b)          
			matrix se1 = vecdiag(e(V))

			local vars : colnames b1
			local nvars = colsof(b1)

			forvalues j = 1/`nvars' {
				local varname = word("`vars'", `j')
				local coef    = b1[1,`j']
				local stderr  = sqrt(se1[1,`j'])
				post simrep ("y_range_50") ("`varname'") (`coef') (`stderr') (`s')
			}

	}
	
	postclose simrep 

end

capture program drop get_CI_WTA_reg_simulation_EV
program define get_CI_WTA_reg_simulation_EV

*------------------------------------------------------------------------------*
* Program: get_CI_WTA_reg_simulation_EV
*
* Purpose:
*   Compute confidence intervals and empirical p-values from WTA regression replications.
*   Percentiles used for Krinsky-Robb 95% CI.
*
* Input:
*   - "$intermediateDir/Simulation_EV_reg_results.dta" for each replication
*
* Output:
*   - "$resultsDir/Table4_App_J_Table_19_Data_EV.dta"
*     Mean coefficient, 95% CI, empirical p-value, significance flags for stars
*
*------------------------------------------------------------------------------*

use "$intermediateDir/Simulation_EV_reg_results", clear

// Percentiles: 

bysort model varname: egen ci_low_b = pctile(b), p(2.5)
bysort model varname: egen ci_high_b = pctile(b), p(97.5)

// Simulated P-values H0 coeff == 0

bysort model varname: egen n_total = count(b)
bysort model varname: egen n_pos  = total(b > 0)
bysort model varname: egen n_neg = total( b < 0)

gen prop_pos = n_pos / n_total
gen prop_neg = n_neg / n_total

gen pval_bootstrap = 2*min(prop_pos, prop_neg)

// Collapse 

collapse (mean) boot_mean_b = b ///
         ci_low_b ci_high_b pval_bootstrap, ///
         by(model varname)
		 
// Significativeness

gen sig_05 = (pval_bootstrap < 0.05)
gen sig_01 = (pval_bootstrap < 0.01)

save "$resultsDir/Table4_App_J_Table_19_Data_EV.dta", replace

li model varname boot_mean_b ci_low_b ci_high_b pval_bootstrap sig_05 sig_01, clean

end

	* Wrapper: do the regressions 

capture program drop run_full_WTA_analysis_EV 
program define run_full_WTA_analysis_EV

*------------------------------------------------------------------------------*
* Program: run_full_WTA_analysis_EV
*
* Purpose:
*   Wrapper program to run full WTA analysis:
*     1) Run regressions on all simulated betas
*     2) Compute CI and p-values over all replications
*
* Input:
*   - Simulation betas in "$simulationDir/Individual betas"
*   - Covariates and globals defined in main script
*   - Number of replications: $nreps
*
* Output:
*   1) "$intermediateDir/Simulation_EV_reg_results.dta"
*      Regression coefficients per replication
*   2) "$resultsDir/Table4_App_J_Table_19_Data_EV.dta"
*      Summary statistics (mean, 95% CI, empirical p-values)
*
*------------------------------------------------------------------------------*

// 1: regression:

run_WTA_reg_simulation_EV

// 2: IC an p-values: 

get_CI_WTA_reg_simulation_EV

end

run_full_WTA_analysis_EV	
		
***********************************************
***********************************************
*											  *
*                     HPs                     *
*											  *
***********************************************
***********************************************

// A: Generate replications of models .ster

capture program drop generate_simulation_ster_HP
program define generate_simulation_ster_HP

*------------------------------------------------------------------------------*
* Program: generate_simulation_ster_HP
*
* Generate Krinsky–Robb simulation draws for the pooled HP mixed logit model 
* (preferred specification). In other words: random draws of estimated parameters
* mean preferences and full covariance matrix around their asymptotic normal
* distribution.
*
* Input:
*   - $data                       : estimation dataset
*   - $pref_spec_pooled_HP        : baseline .ster estimation file
*   - $nreps                      : number of replications
*
* Output:
*   - Replicated .ster files saved in $simulationDir
*------------------------------------------------------------------------------*
	
	use "$data", clear

	estimates use "$pref_spec_pooled_HP"

	matrix b = e(b)
	matrix V = e(V)
	local  k = colsof(b)

	* Generate s random normal draws around the parameters at convergence for HP
	* choice exp (pooled model 2, mixed logit correlated)
	
	forvalues i = 1/$nreps {
		di "Iteration `i'/$nreps"
		preserve
		clear
		drawnorm z1-z`k', n(1) means(b) cov(V)
		mkmat z1-z`k', matrix(bdraw)
		restore
	 
		qui mixlogit choice_hp euro_hp, group(_caseid) id(response_id) ///
		rand($model2_hp) technique(bfgs) corr nrep(1) from(bdraw, copy) iterate(0)
        // No need to iterate, just need the '.ster' file framework

		estimates save "$simulationDir/save_pool_model2_hp_mix_corr_`i'.ster", replace

	}

end

// Uncomment to re-run the programs:			
// generate_simulation_ster_HP

// B: Design and probabilities

	* Create the TIOLI design 

generate_tioli_design_HP
use "$intermediateDir/full_design_HP_tioli.dta", clear
qui gen _caseid = choice_situation_hp
qui gen response_id = choice_situation_hp
save "$intermediateDir/HP_TIOLI_design_simxprobas.dta", replace

global HP_TIOLI_design_simxprobas "$intermediateDir/HP_TIOLI_design_simxprobas.dta"

	* Bootstrapped probabilities

capture program drop gen_simulation_proba_HP
program define gen_simulation_proba_HP

*------------------------------------------------------------------------------*
* Program: gen_simulation_proba_HP
*
* Generate replicated acceptance probabilities for the HP TIOLI design using
* replicated model estimates. TIOLI: take-it-or-leave-it (only one contract
* vs. optout, i.e. no between-alternative competition).
*
* Input:
*   - $data
*   - $pref_spec_pooled_HP
*   - $HP_TIOLI_design_simxprobas : TIOLI design dataset
*   - Replicated .ster files in $simulationDir
*   - $nreps
*
* Output:
*   - Updated $HP_TIOLI_design_simxprobas dataset with baseline and replicated 
*     predicted probabilities
*------------------------------------------------------------------------------*

use "$data", clear

estimates use "$pref_spec_pooled_HP"

matrix b = e(b)
matrix V = e(V)

local  k = colsof(b)

* Generate nreps times the contract acceptance probabilities in TIOLI 

forvalues s = 0/$nreps {
	if `s' == 0 {
		generate_tioli_design_HP
		use "$HP_TIOLI_design_simxprobas", clear
		estimates use "$pref_spec_pooled_HP"
		capture drop proba_validated_model
		mixlpred proba_validated_model, nrep(2000) burn(15)
		qui save "$HP_TIOLI_design_simxprobas", replace
		continue
	}
		
	di "Iteration `s'/$nreps"
	
	use "$HP_TIOLI_design_simxprobas", clear
	
	estimates use "$simulationDir/save_pool_model2_hp_mix_corr_`s'.ster"
	capture drop proba_`s'
	mixlpred proba_`s', nrep(2000) burn(15)

	qui save "$HP_TIOLI_design_simxprobas", replace
	
}

end

// Uncomment to run the program:
// gen_simulation_proba_HP

	* APEs and CIs
	
capture program drop compute_APE_simulation_HP
program define compute_APE_simulation_HP

*------------------------------------------------------------------------------*
* Program: compute_APE_simulation_HP
*
* Compute simulated distributions of Average Partial Effects (APE) of a €1 
* increase in per-intervention compensation on EV contract acceptance
* probabilities.
*
* Input:
*   - $HP_TIOLI_design_simxprobas : TIOLI design with replicated probabilities
*   - Replicated .ster files in $simulationDir
*   - $nreps
*
* Output:
*   - Console output: mean APE and 95% CI
*   - Dataset: $intermediateDir/APE_simulation_results.dta
*------------------------------------------------------------------------------*

// Base TIOLI design: 

	use "$intermediateDir/HP_TIOLI_design_simxprobas.dta", clear
	tempfile design_base
	save `design_base'

// File to store all the APEs for each iteration 

	clear
	set obs $nreps
	gen simulation_rep = _n
	gen ape_pp = .
	tempfile ape_results
	save `ape_results'
	
// Replications of APEs of increasing compensation by €1 

forvalues s = 1/$nreps {
    di "Simulation for APE of increasing compensation by €1/inter. `s'/$nreps"
    
    * Load replicated estimation files 
    estimates use "$simulationDir/save_pool_model2_hp_mix_corr_`s'.ster"
    
    * Baseline: €k/intervention 
    use `design_base', clear
    qui mixlpred proba_baseline, nrep(2000) burn(15)
    qui sum proba_baseline if alternative_index == 1
    local proba_before = r(mean)
    
    * --> €k+1/intervention 
    use `design_base', clear
    qui replace euro_hp = euro_hp + 1 if alternative_index == 1
    qui mixlpred proba_after, nrep(2000) burn(15)
    qui sum proba_after if alternative_index == 1
    local proba_after = r(mean)
    
    * APE in pp
    local ape_s_pp = 100*(`proba_after' - `proba_before')
    use `ape_results', clear
    qui replace ape = `ape_s_pp' if simulation_rep == `s'
    qui save `ape_results', replace
}


// Calculating the CI 

use `ape_results', clear

sum ape_pp, d
egen sim_mean = mean(ape_pp)
_pctile ape_pp, p(2.5 97.5)

display "Average Partial Effect (APE)"
display "Mean APE: " %6.4f sim_mean[1]
display "95% CI: [" %6.4f r(r1) ", " %6.4f r(r2) "]"

save "$intermediateDir/APE_HP_simulation_results.dta", replace

end

compute_APE_simulation_HP

// C: Conditional parameters and replicated WTA regressions

	* Generate replicated (= simulated) individual level parameters

capture program drop gen_indiv_betas_simulation_HP
program define gen_indiv_betas_simulation_HP

*------------------------------------------------------------------------------*
* Program: gen_indiv_betas_simulation_HP
*
* Simulate individual-level random coefficients for the HP mixed logit model 
* using Krinsky–Robb estimates. Note: "individual-level" = "conditional" =
* = "posterior" (see Appendix C.4)
*
* Input:
*   - $data                         : survey dataset
*   - Replicated .ster files in $simulationDir
*   - $model2_hp                    : list of random coefficients
*   - $nreps                        : number of simulation replications
*
* Output:
*   - Individual-level beta datasets saved in $simulationDir/Individual betas/
*------------------------------------------------------------------------------*

* Generate S times the individual level parameters
forvalues s = 1/$nreps {
	di "Iteration `s'/$nreps"
	
	use "$data", clear
	
	estimates use "$simulationDir/save_pool_model2_hp_mix_corr_`s'.ster"
	mixlbeta euro_hp $model2_hp, ///
	  saving("$simulationDir/Individual betas/pool_model2_hp_mix_corr_beta_`s'.dta") ///
	  replace nrep(2000) burn(15)
    use "$simulationDir/Individual betas/pool_model2_hp_mix_corr_beta_`s'.dta", clear
	foreach var of varlist _all {
		if "`var'" != "response_id"{
			rename `var' beta_hp_`var'
			}
	}
	merge 1:m response_id using "$data", nogen
	sort response_id choice_situation_ev alternative_index
	
	duplicates drop response_id, force
	
    save "$simulationDir/Individual betas/pool_model2_hp_mix_corr_survey_beta_`s'.dta", replace
}

end

gen_indiv_betas_simulation_HP

	* Prepare regression variables 
	
capture program drop dep_variables_preparation_hp 
program define dep_variables_preparation_hp

*------------------------------------------------------------------------------*
* Program: dep_variables_preparation_hp
*
* Description:
*   Prepares additional dependent and control variables for HP analysis.
*   Includes:
*     - Household temperature preferences and HP ownership
*     - Dwelling characteristics (size, ownership)
*     - Respondent sociodemographics categorized for regression 
*       (income, education, employment, age)
*     - Country of residence coded as categorical variable
*
* Notes:
*   - Continuous variables are truncated or recoded to handle extreme or missing values.
*   - Categorical variables are harmonized into levels for clean regressions.
*------------------------------------------------------------------------------*

// HP: 

	* What is your indoor temeperature preferred value for comfort in Winter? 
	* Similarly as in program 'minmax_indoor_temp_winter' (main script): 
	*   - Minimum temperatures below 14°C are treated as implausible.
	*   - Maximum temperatures below the minimum or below 18°C are treated as missing.
	replace heating_winter_min_temp = . if heating_winter_min_temp < 14
	replace heating_winter_max_temp = . if heating_winter_max_temp < heating_winter_min_temp
	replace heating_winter_max_temp = . if heating_winter_max_temp < 18

	* Is main heating system a HP? (Similarly as in program 'generate_sumstats' main script:)

	capture drop has_heat_pump
	gen has_heat_pump = (heating_main_system == 1) if !missing(heating_main_system)

// Dwelling characteristics 

capture drop dwelling_leq_100
gen dwelling_leq_100 = 0
replace dwelling_leq_100  = 1 if dwelling_size >= 3

capture drop dwelling_homeowner
gen dwelling_homeowner = 0
replace dwelling_homeowner = 1 if dwelling_ownership == 1

// Respondent sociodemographics, used as control 
	
	*** Total monthly net household income in three categories

	capture drop inc_cat3
	gen inc_cat3 = .
	replace inc_cat3 = 1 if inlist(household_income, 1, 2)    // <2000 and 2000-2999
	replace inc_cat3 = 2 if inlist(household_income, 3, 4)    // 3000-3999 and 4000-4999
	replace inc_cat3 = 3 if inlist(household_income, 5, 6)    // 5000-5999 and >6000
	replace inc_cat3 = 4 if household_income == 7             // Rather not say
	capture label drop inc3
	label define inc3 1 "Lower (<3000€)" 2 "Mid (3000–4999€)" 3 "High (5000€+)" 4 "Rather not say"
	label values inc_cat3 inc3		
		
	*** Respondent's highest education attainment in three categories 

	capture drop edu3
	gen edu3 = .
	replace edu3 = 1 if inlist(education, 1, 2)   // Non-tertiary: Elementary + Secondary
	replace edu3 = 2 if education == 3            // Bachelor
	replace edu3 = 3 if inlist(education, 4, 5)   // Postgraduate: Master + PhD
	replace edu3 = . if education == 6
	capture label drop edu3lbl
	label define edu3lbl 1 "Non-tertiary education" 2 "Bachelor" 3 "Postgraduate"
	label values edu3 edu3lbl

	*** Employment status : categorical variable with 4 categories

	capture drop emp4
	gen emp4 = .
	// Employment status level coding: 
	// 1: Working full time, 
	// 2: Working part-time
	// 3: Unemployed and job seeker,
	// 4: Stay-at-home, 
	// 5: Student,
	// 6: Retired, 
	// 7: Unable to work, 
	// 8: Other, 
	// 9: Rather not say.	
	replace emp4 = 1 if inlist(employment_status, 1, 2) 
	replace emp4 = 2 if inlist(employment_status, 3, 4, 7, 8, 9) //
	replace emp4 = 3 if employment_status == 5
	replace emp4 = 4 if employment_status == 6
	capture label drop emp4lbl
	label define emp4lbl 1 "Working" 2 "Not working (non-retired)" 3 "Student" 4 "Retired"
	label values emp4 emp4lbl

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

	* Run regressions nreps times
	
capture program drop run_WTA_reg_simulation_HP	
program define run_WTA_reg_simulation_HP

*------------------------------------------------------------------------------*
* Program: run_WTA_reg_simulation_HP
*
* Purpose: Perform WTA regression simulations for HP MWTA for largest discomfort
*          during interventions using pre-simulated individual-level betas.
*
* Functionality:
*   - Iterates over S simulation replications of individual betas
*   - Computes MWTA per individual and intervention for Temp 16 (€ per unit)
*   - Prepares covariates (driving habits, attitudinal, sociodemographics, controls)
*   - Runs linear regressions for each replication
*   - Stores coefficients and robust SEs in a postfile for later aggregation
*
* Input: 
*   - Individual betas: "$simulationDir/Individual betas/pool_model2_hp_mix_corr_survey_beta_*.dta"
*   - Prepared covariates: dep_variables_preparation_hp
*
* Output:
*   - Postfile: "$intermediateDir/Simulation_HP_reg_results": model name, variable, coef, SE, replication
*------------------------------------------------------------------------------*

// Define covariates 

	global heating_habits heating_winter_min_temp has_heat_pump i.degree_control_heating i.dwelling_leq_100  
	global attitudinal energy_saving_metric_mean knowledge_metric_mean ecofriendliness_metric_mean
	global sociodemographics coop_channel kids_number_hh i.inc_cat3 dwelling_homeowner i.dwelling_environment i.dwelling_category i.state
	global controls_respondent ib1.age3 respondent_female i.emp4 ib(1).edu3
	
// Create and open a post file to store regression results

capture postclose simrep 
postfile simrep str20 model str40 varname b se rep using "$intermediateDir/Simulation_HP_reg_results", replace

	// Step 1: 
	
	use "$data", clear
	estimates use "$pref_spec_pooled_HP"
	mixlbeta euro_hp $model2_hp, ///
	  saving("$intermediateDir/pool_model2_hp_mix_corr_beta.dta") ///
	  replace nrep(2000) burn(15)
    use "$intermediateDir/pool_model2_hp_mix_corr_beta.dta", clear
	foreach var of varlist _all {
		if "`var'" != "response_id"{
			rename `var' beta_hp_`var'
			}
	}
	merge 1:m response_id using "$data", nogen
	sort response_id choice_situation_hp alternative_index
	
	duplicates drop response_id, force	
	
	capture drop wta_temp_16
	gen wta_temp_16 = -beta_hp_temp_16/beta_hp_euro_hp	
		
	qui dep_variables_preparation_hp
		
	reg wta_temp_16 $heating_habits $attitudinal $sociodemographics $controls_respondent, vce(robust)
	
	estat vif

	// Simulation loop: 
	
	forvalues s = 1/$nreps {
		
		di "Iteration of WTA regression replication: `s'/$nreps"
	    use "$simulationDir/Individual betas/pool_model2_hp_mix_corr_survey_beta_`s'.dta", clear 
		
		// Calculate individual WTAs

			capture drop wta_temp_16
			gen wta_temp_16 = -beta_hp_temp_16/beta_hp_euro_hp	
		
		// Prepare variables 
		
			qui dep_variables_preparation_hp

		// Regression WTA Range 50
		
			qui reg wta_temp_16 $heating_habits $attitudinal $sociodemographics $controls_respondent, vce(robust)

			matrix b1 = e(b)          
			matrix se1 = vecdiag(e(V))

			local vars : colnames b1
			local nvars = colsof(b1)

			forvalues j = 1/`nvars' {
				local varname = word("`vars'", `j')
				local coef    = b1[1,`j']
				local stderr  = sqrt(se1[1,`j'])
				post simrep ("y_temp_16") ("`varname'") (`coef') (`stderr') (`s')
			}

	}
	
	postclose simrep 

end

capture program drop get_CI_WTA_reg_simulation_HP
program define get_CI_WTA_reg_simulation_HP

*------------------------------------------------------------------------------*
* Program: get_CI_WTA_reg_simulation_HP
*
* Purpose:
*   Compute confidence intervals and empirical p-values from WTA regression replications.
*   Percentiles used for Krinsky-Robb 95% CI.
*
* Input:
*   - "$intermediateDir/Simulation_HP_reg_results.dta" for each replication
*
* Output:
*   - "$resultsDir/Table4_App_J_Table_19_Data_HP.dta"
*     Mean coefficient, 95% CI, empirical p-value, significance flags for stars
*
*------------------------------------------------------------------------------*

use "$intermediateDir/Simulation_HP_reg_results", clear

// Percentiles: 

bysort model varname: egen ci_low_b = pctile(b), p(2.5)
bysort model varname: egen ci_high_b = pctile(b), p(97.5)

// Simulated P-values H0 coeff == 0

bysort model varname: egen n_total = count(b)
bysort model varname: egen n_pos  = total(b > 0)
bysort model varname: egen n_neg = total( b < 0)

gen prop_pos = n_pos / n_total
gen prop_neg = n_neg / n_total

gen pval_bootstrap = 2*min(prop_pos, prop_neg)

// Collapse 

collapse (mean) boot_mean_b = b ///
         ci_low_b ci_high_b pval_bootstrap, ///
         by(model varname)
		 
// Significativeness

gen sig_05 = (pval_bootstrap < 0.05)
gen sig_01 = (pval_bootstrap < 0.01)

save "$resultsDir/Table4_App_J_Table_19_Data_HP.dta", replace

li model varname boot_mean_b ci_low_b ci_high_b pval_bootstrap sig_05 sig_01, clean

end

	* Wrapper: do the regressions 

capture program drop run_full_WTA_analysis_HP 
program define run_full_WTA_analysis_HP

*------------------------------------------------------------------------------*
* Program: run_full_WTA_analysis_HP
*
* Purpose:
*   Wrapper program to run full WTA analysis:
*     1) Run regressions on all simulated betas
*     2) Compute CI and p-values over all replications
*
* Input:
*   - Simulation betas in "$simulationDir/Individual betas"
*   - Covariates and globals defined in main script
*   - Number of replications: $nreps
*
* Output:
*   1) "$intermediateDir/Simulation_HP_reg_results.dta"
*      Regression coefficients per replication
*   2) "$resultsDir/Table4_App_J_Table_19_Data_HP.dta"
*      Summary statistics (mean, 95% CI, empirical p-values)
*
*------------------------------------------------------------------------------*

// 1: regression:

run_WTA_reg_simulation_HP

// 2: IC an p-values: 

get_CI_WTA_reg_simulation_HP

end

run_full_WTA_analysis_HP	