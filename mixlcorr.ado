*! mixlcorr 03Feb2026
*! author: Baptiste Rigaux, Faculty of Economics and Business Administration, Ghent University
*! Heavily based on/adapted from 'mixlcov.ado' 03Jun2015; author: Arne Risa Hole

/*
------------------------------------------------------------------------------
mixlcorr: Computes correlation matrix (and SEs, p-values) of random coefficients
from `mixlogit` or `mixlogitwtp` *with correlated attributes* after estimating 
via Cholesky decomposition.

Outputs:
- r(corr_val)             : matrix of correlations between random coefficients
- r(corr_val_sig) : same matrix but sets to 0 all correlations with p > sig level
- r(corr_se)              : matrix of standard errors of correlations
- r(corr_pval)            : matrix of p-values of correlations

Options:
- plot          : if specified, automatically generates two heatplots:
                    1) correlation matrix
                    2) only significant correlations (others set to 0)
- name(string)  : File path (relative or absolute) and filename prefix for saved
                  plots. Default is "heatmap_corrmatrix". 
                  Example: name("results/corr_preferences")
- sig(real)     : significance level (default 0.05) to zero out non-significant correlations
                  for matrix r(corr_val_sig) and in the second plot.

IMPORTANT:
- Requires the user-written package `heatplot`. 
  Install it via: 
      . ssc install heatplot

Example usage:
. mixlogit choice x1 x2 x3, corr group(gid) id(id) rand(x1 x2 x3)
. mixlcorr x1 x2 x3, plot name("figures/corr_preferences") sig(0.10)
------------------------------------------------------------------------------
*/

program define mixlcorr, rclass
    version 17
    // Required: varlist with names of variables assumed random
    syntax varlist [, plot name(string) sig(real 0.05)]

    * ---------------------------------------------------------
    * Save krnd and variable names BEFORE mixlcov wipes e()
    * ---------------------------------------------------------
    // Count and tokenize only variables in rand()
    local randvars `varlist'
    local krnd : word count `randvars'
    tokenize `randvars'

    * ---------------------------------------------------------
    * Run mixlcov to get v11, v21, ..., vnn
    * ---------------------------------------------------------
    mixlcov, post

    * ---------------------------------------------------------
    * Build nlcom expressions for correlations
    * ---------------------------------------------------------
    local corrnlcom
    forvalues i = 1/`krnd' {
        if `i' < `krnd' {
            local next = `i' + 1
            forvalues j = `next'/`krnd' {
                local corrnlcom `corrnlcom' (corr`j'`i': _b[v`j'`i'] / sqrt(_b[v`i'`i']*_b[v`j'`j']))
            }
        }
    }

    * ---------------------------------------------------------
    * Compute correlations using nlcom and get results in r(b)
    * ---------------------------------------------------------
    if "`corrnlcom'" != "" {
        nlcom `corrnlcom'
    }

    * ---------------------------------------------------------
    * Initialize matrices for estimates, SE, p-values
    * ---------------------------------------------------------
    local nrows = `krnd'
    matrix corr_val = J(`nrows', `nrows', 1)
    matrix corr_se = J(`nrows', `nrows', 0)
    matrix corr_pval = J(`nrows', `nrows', 1)

    * ---------------------------------------------------------
    * Fill matrices from r(table)
    * ---------------------------------------------------------
    local c = 1
    forvalues i = 1/`krnd' {
        if `i' < `krnd' {
            local next = `i' + 1
            forvalues j = `next'/`krnd' {
                local est = r(b)[1,`c']
                local se  = r(table)[2,`c']
                local pval= r(table)[4,`c']

                matrix corr_val[`i', `j'] = `est'
                matrix corr_val[`j', `i'] = `est'
                matrix corr_se[`i', `j'] = `se'
                matrix corr_se[`j', `i'] = `se'
                matrix corr_pval[`i', `j'] = `pval'
                matrix corr_pval[`j', `i'] = `pval'

                local ++c
            }
        }
    }

    * ---------------------------------------------------------
    * Attach variable names as row and col names on all matrices
    * ---------------------------------------------------------
    local rownames
    local colnames
    forvalues i = 1/`krnd' {
        local rownames `rownames' ``i''
        local colnames `colnames' ``i''
    }

    matrix rownames corr_val = `rownames'
    matrix colnames corr_val = `colnames'
    matrix rownames corr_se = `rownames'
    matrix colnames corr_se = `colnames'
    matrix rownames corr_pval = `rownames'
    matrix colnames corr_pval = `colnames'

    * ---------------------------------------------------------
    * Build matrix with only significant correlations (keep diagonal)
    * ---------------------------------------------------------
    matrix corr_val_sig = corr_val
    forvalues i = 1/`nrows' {
        forvalues j = 1/`nrows' {
            if `i' == `j' {
                matrix corr_val_sig[`i',`j'] = 1
            }
            else if corr_pval[`i',`j'] > `sig' {
                matrix corr_val_sig[`i',`j'] = .
            }
        }
    }
    matrix rownames corr_val_sig = `rownames'
    matrix colnames corr_val_sig = `colnames'

    * ---------------------------------------------------------
    * Build xlabel and ylabel options dynamically for heatplot
    * ---------------------------------------------------------
    local xlabelopts
    local ylabelopts
    forvalues i = 1/`krnd' {
        local xlabelopts `xlabelopts' `i' "``i''"
        local ylabelopts `ylabelopts' `i' "``i''"
    }

    * ---------------------------------------------------------
    * Only produce plots if user requested option 'plot'
    * ---------------------------------------------------------
    if "`plot'" != "" {
        * Check if heatplot is installed
        capture which heatplot
        if _rc {
            di as error "The option 'plot' requires the package heatplot. Install it with: ssc install heatplot"
            exit 198
        }

	local plotname "heatmap_corrmatrix"
	if "`name'" != "" local plotname "`name'"

	local plotfile "`plotname'.gph"

        * Plot with all correlations
        heatplot corr_val, ///
            values(format(%9.2f) size(vsmall)) ///
            color(hcl diverging, h(120 260) l(50) intensity(.6)) ///
            upper cuts(-1.1(.2)1.1) ///
            note("Correlation matrix from mixlcorr2 (sig < `sig')") ///
            xlabel(`xlabelopts', angle(45) labsize(small)) ///
            ylabel(`ylabelopts', labsize(small)) ///
            xsize(11) ysize(9) ///
	    saving("`plotfile'", replace)

        * Plot with only significant correlations
        local plotname_signifonly "`plotname'_signifonly"
        local plotfile_signifonly "`plotname_signifonly'.gph"

        heatplot corr_val_sig, ///
            values(format(%9.2f) size(vsmall)) ///
            color(hcl diverging, h(120 260) l(50) intensity(.6)) ///
            upper cuts(-1.1(.2)1.1) ///
            note("Only correlations significant at `=round(`sig'*100,0)'% level shown; others set to 0") ///
            xlabel(`xlabelopts', angle(45) labsize(small)) ///
            ylabel(`ylabelopts', labsize(small)) ///
            xsize(11) ysize(9) ///
            saving("`plotfile_signifonly'", replace)
    }

    * ---------------------------------------------------------
    * Return all matrices
    * ---------------------------------------------------------
    return matrix corr_val = corr_val
    return matrix corr_val_sig = corr_val_sig
    return matrix corr_se = corr_se
    return matrix corr_pval = corr_pval

end