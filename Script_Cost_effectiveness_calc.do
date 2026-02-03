/********************************************************************
 Paper title   : Survey evidence on cost-effective residential flexibility contracts
                 for electric vehicles and heat pumps 
 Paper authors : Baptiste Rigaux (*), Sam Hamels, Marten Ovaere
 Affiliation   : Department of Economics, Ghent University (Belgium)
 Contact       : (*) baptiste.rigaux@ugent.be
 Date          : 2026 Feb 3rd
 
 ! THIS SCRIPT MUST BE CALLED FROM Main.do !

 Description : Script_Cost_effectiveness_calc
 This script performs the calculations for Section 6.3 in the back-of-the-
 envelope section. It generates Figure 6. 

 Input :
 - root/Data/DAM_2023.csv : a CSV file with 2023 hourly day-ahead market 
                            electricity prices in Belgium. 
							Source: Transparency Platform. 

 Outputs are stored in: root/Results/ ... 
 Intermediate files are stored in: root/Intermediate/Script 3/ ...
 Console outputs are used in the text of the paper. 

********************************************************************/

*-----------------------------*
* 0. Preamble
*-----------------------------*

version 17
clear all
set more off

*-----------------------------*
* 1. Paths
*-----------------------------*

* Root (replace that with your directory)
global root "C:/..." 

* Relative paths
global dataDir          "$root/Data"
global resultsDir       "$root/Results"
global sp_intermediateDir  "$root/Intermediate/Script section 6.3"

*-----------------------------*
* 2. Cleaning DAM price data
*-----------------------------*

capture program drop data_preparation
program define data_preparation

*----------------------------------------------------------*
* Program: data_preparation 
*
* This program cleans the DAM price data. 
*
* Inputs:
* - a CSV with 2023 hourly day-ahead market electricity prices for Belgium. 
*	Source: Transparency Platform. 
*
* Output:
*  - a cleaned Stata .dta file DAM_2023 with prices in €EUR/kWh.
*
*----------------------------------------------------------*

clear all 

import delimited "$dataDir/DAM_2023.csv", varnames(1) 

drop bznbe currency
rename mtucetcest time_temp

rename dayaheadpriceeurmwh DAM_price
	label variable DAM_price "Day-ahead prices, per kWh"
	replace DAM_price = DAM_price / 1000 // Prices per kWh
		
split time_temp, parse("-") 
	drop time_temp time_temp2	
	rename time_temp1 time_temp
		
gen double time = clock(time_temp, "DMYhm")
	drop time_temp
	format time %tcDDmonCCYY_HH:MM:SS

order time DAM_price

save "$sp_intermediateDir/DAM_2023", replace

end

*-----------------------------*
* 3. Identifying most lucrative windows for flexibility events
*-----------------------------*

capture program drop window_ranking
program define window_ranking

*----------------------------------------------------------*
* Program: window_ranking
*
* This program identifies the highest-value non-overlapping
* rolling windows of day-ahead market (DAM) electricity prices.
* In other words, this program identifies when to dispatch interventions, 
* according to the rules in the BotE section in the paper. 
*
* The program:
*  - Filters hourly DAM price data by selected months
*  - Computes forward rolling means over a specified window size
*  - Ranks rolling windows by average price
*  - Selects the top F non-overlapping windows
*
* Inputs:
*   - Prepared DAM price dataset (via data_preparation)
*   - WINDOW : size of the rolling window (in hours)
*   - F      : number of top non-overlapping windows to select
*   - MONTHS : list of months of year to include (1–12)
*
* Output:
*   - Dataset including rolling mean prices and a 'validated'
*     rank for the selected top windows, i.e. when to send interventions.
*
*----------------------------------------------------------*

    version 17
	
    syntax , WINDOW(integer) F(integer) MONTHS(numlist)
	
    qui data_preparation
	
    // Keep only requested months in the command 
    tempvar _keep
    gen `_keep' = 0
    foreach m of numlist `months' {
        replace `_keep' = 1 if month(dofc(time)) == `m'
    }
    keep if `_keep' == 1
	
// Setting data as time series (required for using command "rolling") 
gen index = _n
tsset index // Observation index as time variable 

save "$sp_intermediateDir/data_tsset", replace
use "$sp_intermediateDir/data_tsset", clear

// Computing (forward) rolling means in windows of f hours (i.e. f observations) 
rolling mean_dam_price_win`window'_`f' = r(mean), window(`window'): sum DAM_price
rename start index 
drop end

merge 1:1 index using "$sp_intermediateDir/data_tsset", nogen

// Algorithm to select the f highest-value, non-overlapping windows 
// Iteratively select the top F rolling windows while enforcing non-overlapping constraints.


gsort -mean_dam_price

gen validated_rank_win`window'_`f' = . 

forvalues i = 1(1)`f'{
	// At each iteration i:
	//  - The i-th highest remaining window is validated and assigned rank i
	replace validated_rank_win`window'_`f' = `i' in `i'
	//  - All other observations whose time interval overlaps with the selected window
	//    (i.e. closer than WINDOW hours) are removed from the candidate set
	drop if validated_rank_win`window'_`f'!= `i' & abs(time-time[`i']) < msofhours(`window')
} 

replace mean_dam_price_win`window'_`f' = . if missing(validated_rank_win`window'_`f')

end

// For HPs: we assume interventions are dispatched during heating season months. 
// We take 4 h (T_threshold = 19°C) or 14 h (T_threshold = 16°C) interventions.
window_ranking, window(4) f(52) months(1 2 3 4 10 11 12)
save "$sp_intermediateDir/ranking_win4_52", replace

window_ranking, window(14) f(52) months(1 2 3 4 10 11 12)
save "$sp_intermediateDir/ranking_win14_52", replace

// For EVs: interventions are dispatched all year long and last 8 hours. 
window_ranking, window(8) f(52) months(1 2 3 4 5 6 7 8 9 10 11 12)
save "$sp_intermediateDir/ranking_win8_52", replace

// We merge datasets 

use "$sp_intermediateDir/DAM_2023", clear
gen index = _n 

merge 1:1 index using "$sp_intermediateDir/ranking_win4_52", nogen
merge 1:1 index using "$sp_intermediateDir/ranking_win14_52", nogen
merge 1:1 index using "$sp_intermediateDir/ranking_win8_52", nogen

save "$sp_intermediateDir/intervention_starts", replace

*-----------------------------*
* 4. Extract discrete values of Pi_en(f_j, t_j) (used in the text)
*-----------------------------*

use "$sp_intermediateDir/intervention_starts", clear

qui sum mean_dam_price_win4_52 if !missing(mean_dam_price_win4_52)
scalar Pi_en_win4_52 = r(mean)
di "Interventions on HP (T = 19 °C): Pi_en(52 events/year, 4 hour) = €/kWh " round(scalar(Pi_en_win4_52),0.001)

	capture drop rank_mean_dam_price_win4_52	
	qui egen rank_mean_dam_price_win4_52 = rank(mean_dam_price_win4_52)
	
	qui sum mean_dam_price_win4_52 if rank_mean_dam_price_win4_52 == 52
	qui scalar Pi_en_win4_1 = r(mean)
	di "Interventions on HP (T = 19 °C): Pi_en(1 event/year, 4 hour) = €/kWh " round(scalar(Pi_en_win4_1),0.001)	
	
	qui sum mean_dam_price_win4_52 if rank_mean_dam_price_win4_52 > 52-6
	qui scalar Pi_en_win4_6 = r(mean)
	di "Interventions on HP (T = 19 °C): Pi_en(6 events/year, 4 hour) = €/kWh " round(scalar(Pi_en_win4_6),0.001)	
	
	qui sum mean_dam_price_win4_52 if rank_mean_dam_price_win4_52 > 52-12
	qui scalar Pi_en_win4_12 = r(mean)
	di "Interventions on HP (T = 19 °C): Pi_en(12 events/year, 4 hour) = €/kWh " round(scalar(Pi_en_win4_12),0.001)	
	
qui sum mean_dam_price_win14_52 if !missing(mean_dam_price_win14_52)
scalar Pi_en_win14_52 = r(mean)
di "Interventions on HP (T = 16 °C): Pi_en(52 events/year, 14 hour) = €/kWh " round(scalar(Pi_en_win14_52),0.001)

	capture drop rank_mean_dam_price_win14_52	
	qui egen rank_mean_dam_price_win14_52 = rank(mean_dam_price_win14_52)
	
	qui sum mean_dam_price_win14_52 if rank_mean_dam_price_win14_52 == 52
	qui scalar Pi_en_win14_1 = r(mean)
	di "Interventions on HP (T = 16 °C): Pi_en(1 event/year, 14 hour) = €/kWh " round(scalar(Pi_en_win14_1),0.001)	
	
	qui sum mean_dam_price_win14_52 if rank_mean_dam_price_win14_52 > 52-6
	qui scalar Pi_en_win14_6 = r(mean)
	di "Interventions on HP (T = 16 °C): Pi_en(6 events/year, 14 hour) = €/kWh " round(scalar(Pi_en_win14_6),0.001)
	
	qui sum mean_dam_price_win14_52 if rank_mean_dam_price_win14_52 > 52-12
	qui scalar Pi_en_win14_12 = r(mean)
	di "Interventions on HP (T = 16 °C): Pi_en(12 events/year, 14 hour) = €/kWh " round(scalar(Pi_en_win14_12),0.001)

qui sum mean_dam_price_win8_52 if !missing(mean_dam_price_win8_52)
scalar Pi_en_win8_52 = r(mean)
di "Interventions on EV: Pi_en(52 events/year, 8 hour) = €/kWh " round(scalar(Pi_en_win8_52),0.001)

	capture drop rank_mean_dam_price_win8_52	
	qui egen rank_mean_dam_price_win8_52 = rank(mean_dam_price_win8_52)
	
	qui sum mean_dam_price_win8_52 if rank_mean_dam_price_win8_52 == 52
	qui scalar Pi_en_win8_1 = r(mean)
	di "Interventions on EV: Pi_en(1 event/year, 8 hour) = €/kWh " round(scalar(Pi_en_win8_1),0.001)
	
	qui sum mean_dam_price_win8_52 if rank_mean_dam_price_win8_52 > 52-6
	qui scalar Pi_en_win8_6 = r(mean)
	di "Interventions on EV: Pi_en(6 events/year, 8 hour) = €/kWh " round(scalar(Pi_en_win8_6),0.001)
	
	qui sum mean_dam_price_win8_52 if rank_mean_dam_price_win8_52 > 52-12
	qui scalar Pi_en_win8_12 = r(mean)
	di "Interventions on EV: Pi_en(12 events/year, 8 hour) = €/kWh " round(scalar(Pi_en_win8_12),0.001)

*-----------------------------*
* 5. Systematically extract values of Pi_en(f_j, t_j) (used for other functions)
*-----------------------------*
	
capture program drop compute_pi_en_by_f
program define compute_pi_en_by_f

*----------------------------------------------------------*
* Program: compute_pi_en_by_f
*
* This program computes the average DAM electricity price Pi_en 
* across the f non overlapping windows of highest average price within a
* year. In other words, the average DAM price during f most lucrative windows
* to dispatch an intervention. 
*
* For a given rolling window length (= intervention duration, in hours), it:
*  - Loads ranked rolling window DAM prices (cf. previous functions)
*  - Ranks interventions by mean DAM price
*  - Computes Pi_en(f) as the average DAM price over the
*    top f highest-priced windows (= interventions)
*
* Inputs:
*   - WINDOW : intervention duration = rolling window length (in hours)
*   - MAXF   : maximum number of interventions considered
*
* Output:
*   - Stata dataset pi_en_win{WINDOW}_by_f containing:
*       * f     : number of selected events
*       * pi_en : corresponding average DAM price (€/kWh)
*
*----------------------------------------------------------*

	version 17

    syntax , WINDOW(integer) MAXF(integer)
    
    // Load the pre-ranked dataset of interventions for the specified window and MAXF
    use "$sp_intermediateDir/ranking_win`window'_`maxf'", clear
    
    // Create rank variable
    capture drop rank_mean_dam_price_win`window'_`maxf'
    egen rank_mean_dam_price_win`window'_`maxf' = rank(mean_dam_price_win`window'_`maxf')
    
    // Create a temporary dataset to store Pi_en values for each f
    tempfile temp_pi_en
    postfile pi_en_results int f double pi_en using `temp_pi_en', replace
    
    forvalues i = 1/`maxf' {
        // Compute the mean DAM price of the top i interventions:
        quietly sum mean_dam_price_win`window'_`maxf' if rank_mean_dam_price_win`window'_`maxf' > `maxf' - `i'
		// Post the number of interventions (i) and the mean price to the temp dataset
        post pi_en_results (`i') (r(mean))
    }
    
    postclose pi_en_results
    
    use `temp_pi_en', clear
    save "$sp_intermediateDir/pi_en_win`window'_by_f", replace
    
end

// For EVs: 
compute_pi_en_by_f, window(8) maxf(52)   

// For HPs: 
	// 19 °C threshold interventions: 
	compute_pi_en_by_f, window(4) maxf(52)
	
	// 16 °C threshold interventions: 
	compute_pi_en_by_f, window(14) maxf(52)  

*-----------------------------*
* 6. Compute/plot breakeven per-intervention compensation (Eq. 13)
*-----------------------------*

capture program drop breakeven_mj
program define breakeven_mj

*----------------------------------------------------------*
* Program: breakeven_mj_dynamic
*
* Computes the breakeven per-intervention compensation (m_j) in Eq. 13
* using the electricity price indicator Pi_en as a function
* of the number of selected events (f).
*
* The formula used:
*   m_j(f) =  pi_en(f) * (1 - delta) * e_call + (1/f) * (pi_cap * p_call - c_fix)
*
* Inputs:
*   - pi_cap       : capacity price (€/kW)
*   - pi_en_dataset: dataset containing pi_en(f) for each f
*   - p_call       : effective power reduction per unit and intervention (kW)
*   - e_call       : effective energy reduction per unit and intervention (kWh)
*   - c_fix        : yearly fixed cost per unit (€/year)
*   - delta        : derating factor [0,1] to capture the share of curtailed
*					 energy that is rescheduled and the lower prices at which it
*					 is then consumed.L
*
* Outputs: an unsaved dataset with: 
*   - Variable mj : breakeven per-intervention compensation for each f
*   - Observations: f = 1..52 events/year
*
*----------------------------------------------------------*

	version 17 
	
    syntax , pi_cap(real) pi_en_dataset(string) p_call(real) e_call(real) c_fix(real) delta(real)
    
    // Create dataset with intervention frequency
    clear
    set obs 52
    gen f = _n
    
    // Merge Pi_en dataset containing pi_en(f)
    merge 1:1 f using "$sp_intermediateDir/`pi_en_dataset'", nogen keep(master match)
    
    // Compute m_j: 
    gen mj = pi_en * (1 - `delta') * `e_call' + (1/f)*(`pi_cap'*`p_call' - `c_fix')
    
end

capture program drop proceed_breakeven_EV
program define proceed_breakeven_EV

*----------------------------------------------------------*
* Program: proceed_breakeven_EV
*
* Computes and plots breakeven compensation curves for
* electric vehicle (EV) flexibility interventions.
*
* The program:
*  - Calls the breakeven_mj program for EV interventions
*  - Considers alternative fixed-cost assumptions
*  - Merges all results into a single dataset
*  - Generates a figure of breakeven compensation
*    as a function of intervention frequency (f)
*
* Output:
*   - Dataset: root/Intermediate/breakeven_mj_ev_all.dta
*   - Figure : root/Results/Figure_6_left.pdf
*
* Note: 
* Since we observe little difference in effective energy and power reduction per 
* EV and per call across the two ranges considered, we generate results for
* range thresholds of 50 and 200 km. 
*
*----------------------------------------------------------*

// Averaging over range thresholds (negligible difference between the two ranges)

local p_call_200km = 1.04
local p_call_50km = 1.08

local e_call_200km = 8 * `p_call_200km'
local e_call_50km = 8 * `p_call_50km'

local avg_p_call = 0.5 * (`p_call_200km' +  `p_call_50km') 
local avg_e_call = 0.5 * (`e_call_200km' + `e_call_50km') 

// No fixed costs: 

breakeven_mj, pi_cap(32) pi_en_dataset("pi_en_win8_by_f") ///
    p_call(`avg_p_call') e_call(`avg_e_call') c_fix(0) delta(0.5)
save "$sp_intermediateDir/breakeven_mj_ev_cfix0", replace

// 20€/year and HP fixed costs:
	
breakeven_mj, pi_cap(32) pi_en_dataset("pi_en_win8_by_f") ///
    p_call(`avg_p_call') e_call(`avg_e_call') c_fix(20) delta(0.5)
save "$sp_intermediateDir/breakeven_mj_ev_cfix20", replace	

// Merging all files together in a single dataset to draw figures: 

	use "$sp_intermediateDir/breakeven_mj_ev_cfix0", clear
	rename mj mj_ev_cfix0
	save "$sp_intermediateDir/breakeven_mj_ev_cfix0", replace

	use "$sp_intermediateDir/breakeven_mj_ev_cfix20", clear
	rename mj mj_ev_cfix20
	save "$sp_intermediateDir/breakeven_mj_ev_cfix20", replace

	merge 1:1 f using "$sp_intermediateDir/breakeven_mj_ev_cfix0", nogen
	
// Plot: 

local mtilde = ustrunescape("\u006D\u0303") 
graph twoway ///
    line mj_ev_cfix0  f, lcolor(green%65) lwidth(medthick)  || ///
	line mj_ev_cfix20  f, lcolor(green%45) lwidth(medthick) lp(dash) ///
    xsize(4.5) ysize(3) ///
    xtitle("Frequency f of interventions in a year") ///
    ytitle("Breakeven compensation per intervention `mtilde'{sub:j} (€)") ///
    ylabel(0(4)36) xlabel(1 6 12 18 24 30 36 42 48 52) ///
    legend(order(1 "c{sub:fix}=€0" 2 "c{sub:fix}=€20/year") pos(6) cols(2) size(medsmall)) ///
    yline(0) ymtick(0(4)36, grid) /// 
    text(34 47 "EV", place(c) box fcolor(gs12) lcolor(gs12) margin(1 1 1 1))
	graph export "$resultsDir/Figure_6_left.pdf", replace
	
end

capture program drop proceed_breakeven_HP
program define proceed_breakeven_HP

*----------------------------------------------------------*
* Program: proceed_breakeven_HP
*
* Computes and plots breakeven compensation curves for
* heat pump (HP) flexibility interventions.
*
* The program:
*  - Calls the breakeven_mj program for different HP
*    intervention thresholds (16°C and 19°C) yielding different durations
*  - Considers alternative fixed-cost assumptions
*  - Merges all results into a single dataset
*  - Generates a figure of breakeven compensation
*    as a function of intervention frequency (f)
*
* Output:
*   - Dataset: root/Intermediate/breakeven_mj_hp_all.dta
*   - Figure : root/Results/Figure_6_right.pdf
*
*----------------------------------------------------------*

// 16 °C threshold interventions: 
	
		// No fixed costs
breakeven_mj, pi_cap(32) pi_en_dataset("pi_en_win14_by_f") ///
    p_call(0.42) e_call(5.88) c_fix(0) delta(0.5)
save "$sp_intermediateDir/breakeven_mj_hp_16_deg_cfix0", replace

		// 10€/year and HP fixed costs
breakeven_mj, pi_cap(32) pi_en_dataset("pi_en_win14_by_f") ///
    p_call(0.42) e_call(5.88) c_fix(10) delta(0.5)
save "$sp_intermediateDir/breakeven_mj_hp_16_deg_cfix10", replace

// 19 °C threshold interventions: 
	
		// No fixed costs
breakeven_mj, pi_cap(32) pi_en_dataset("pi_en_win4_by_f") ///
    p_call(0.26) e_call(0.936) c_fix(0) delta(0.5)
save "$sp_intermediateDir/breakeven_mj_hp_19_deg_cfix0", replace

		// 10€/year and HP fixed costs
breakeven_mj, pi_cap(32) pi_en_dataset("pi_en_win4_by_f") ///
    p_call(0.26) e_call(0.936) c_fix(10) delta(0.5)
save "$sp_intermediateDir/breakeven_mj_hp_19_deg_cfix10", replace

// Merging all files together in a single dataset to draw figures: 

	use "$sp_intermediateDir/breakeven_mj_hp_16_deg_cfix0", clear
	rename mj mj_16_cfix0
	save "$sp_intermediateDir/breakeven_mj_hp_16_deg_cfix0", replace

	use "$sp_intermediateDir/breakeven_mj_hp_16_deg_cfix10", clear
	rename mj mj_16_cfix10
	save "$sp_intermediateDir/breakeven_mj_hp_16_deg_cfix10", replace

	use "$sp_intermediateDir/breakeven_mj_hp_19_deg_cfix0", clear
	rename mj mj_19_cfix0
	save "$sp_intermediateDir/breakeven_mj_hp_19_deg_cfix0", replace

	use "$sp_intermediateDir/breakeven_mj_hp_19_deg_cfix10", clear
	rename mj mj_19_cfix10
	save "$sp_intermediateDir/breakeven_mj_hp_19_deg_cfix10", replace

	merge 1:1 f using "$sp_intermediateDir/breakeven_mj_hp_19_deg_cfix0", nogen
	merge 1:1 f using "$sp_intermediateDir/breakeven_mj_hp_16_deg_cfix10", nogen
	merge 1:1 f using "$sp_intermediateDir/breakeven_mj_hp_16_deg_cfix0", nogen

	save "$sp_intermediateDir/breakeven_mj_hp_all", replace
	
// Plot: 

local mtilde = ustrunescape("\u006D\u0303") 
graph twoway ///
    line mj_16_cfix0  f, lcolor(green%65) lwidth(medthick)  || ///
	line mj_19_cfix0  f, lcolor(purple%65) lwidth(medthick)  || ///
	line mj_16_cfix10  f, lcolor(green%45) lwidth(medthick)  lp(dash) || ///
	line mj_19_cfix10  f, lcolor(purple%45) lwidth(medthick) lp(dash)   ///
    xsize(4.5) ysize(3) ///
    xtitle("Frequency f of interventions in a year") ///
    ytitle("Breakeven compensation per intervention `mtilde'{sub:j} (€)") ///
    ylabel(-2(2)14) xlabel(1 6 12 18 24 30 36 42 48 52) ///
    legend(order(1 "16 °C, c{sub:fix}=€0" 2 "19 °C, c{sub:fix}=€0" 3 "16 °C, c{sub:fix}=€10/year" 4 "19 °C, c{sub:fix}=€10/year" ) pos(6) cols(2) size(medsmall)) ///
    yline(0) ymtick(-2(1)14, grid) ///
    text(13.5 47 "HP", place(c) box fcolor(gs12) lcolor(gs12) margin(1 1 1 1))
	graph export "$resultsDir/Figure_6_right.pdf", replace

end
	
proceed_breakeven_EV
proceed_breakeven_HP
