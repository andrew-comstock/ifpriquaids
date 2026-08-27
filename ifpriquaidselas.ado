*! version 1.0.0  25aug2026
*! ifpriquaidselas -- observation-level elasticities after -ifpriquaids-
*!
*! Generates, for every observation in e(sample):
*!   cw#        latent (SY expected) budget shares
*!   em_#       conditional expenditure elasticities
*!   epm_#_#    conditional Marshallian (uncompensated) price elasticities
*!   eph_#_#    conditional Hicksian (compensated) price elasticities
*!
*! Optional outlier cleaning by IQR or SD.  Flexible in the number of goods.

program ifpriquaidselas, rclass
	version 14.0

	if "`e(cmd2)'" != "ifpriquaids" {
		di as err "last estimates were not produced by ifpriquaids"
		exit 301
	}

	syntax [if] [in] [,                                                  ///
		PREfix(name)                                                     ///
		PRICEGroup(varname)                                              ///
		IQRclean(real -1)                                                ///
		SDclean(real -1)                                                 ///
		LEGacy                                                           ///
		REPLACE                                                          ///
		noSUMmary ]

	local p `prefix'

	/* ---------------- cleaning options -------------------------------- */
	if `iqrclean' != -1 & `sdclean' != -1 {
		di as err "specify only one of iqrclean() and sdclean()"
		exit 198
	}
	local cleanmethod ""
	local cleanfactor .
	if `iqrclean' != -1 {
		if `iqrclean' <= 0 {
			di as err "iqrclean() must be positive"
			exit 198
		}
		local cleanmethod "iqr"
		local cleanfactor `iqrclean'
	}
	if `sdclean' != -1 {
		if `sdclean' <= 0 {
			di as err "sdclean() must be positive"
			exit 198
		}
		local cleanmethod "sd"
		local cleanfactor `sdclean'
	}

	/* ---------------- recover the model from e() ---------------------- */
	local n     = e(ngoods)
	local k     = e(ndemos)
	local shares       "`e(shares)'"
	local cdfvars      "`e(cdfvars)'"
	local pdfvars      "`e(pdfvars)'"
	local demographics "`e(demographics)'"
	local anot         "`e(anot)'"
	local quad = ("`e(quadratic)'" == "yes")

	tempname A B G L D DP
	matrix `A'  = e(alpha)
	matrix `B'  = e(beta)
	matrix `G'  = e(gamma)
	matrix `DP' = e(deltapdf)
	if `quad'  matrix `L' = e(lambda)
	if `k' > 0 matrix `D' = e(delta)

	/* ---------------- sample ------------------------------------------ */
	marksample touse, novarlist
	quietly replace `touse' = 0 if !e(sample)
	quietly count if `touse'
	if r(N) == 0 {
		di as err "no observations"
		exit 2000
	}
	local nobs = r(N)

	/* ---------------- log prices / log expenditure -------------------- *
	 * If the model was fitted with prices()/expenditure() in levels, the
	 * logs lived in tempvars that are long gone; rebuild them here.
	 * ------------------------------------------------------------------ */
	local plevels "`e(prices)'"
	local lnprices ""
	if "`plevels'" != "" {
		foreach v of local plevels {
			tempvar lv
			quietly gen double `lv' = ln(`v') if `touse'
			local lnprices `lnprices' `lv'
		}
	}
	else	local lnprices "`e(lnprices)'"

	local mlevel "`e(expenditure)'"
	if "`mlevel'" != "" {
		tempvar lm
		quietly gen double `lm' = ln(`mlevel') if `touse'
		local lnexp `lm'
	}
	else	local lnexp "`e(lnexpenditure)'"

	/* ---------------- names of the variables to create ---------------- */
	local newvars ""
	forvalues i = 1/`n' {
		local newvars `newvars' `p'cw`i' `p'em_`i'
		forvalues j = 1/`n' {
			local newvars `newvars' `p'epm_`i'_`j' `p'eph_`i'_`j'
		}
	}
	if "`replace'" != "" {
		foreach v of local newvars {
			capture drop `v'
		}
	}
	foreach v of local newvars {
		capture confirm new variable `v'
		if _rc {
			di as err "`v' already exists; use replace, or prefix()"
			exit 110
		}
	}

	quietly {

	/* ================================================================== *
	 * Price aggregators
	 *   lnA = a0 + sum_i a_i lnp_i + .5 sum_i sum_j g_ij lnp_i lnp_j
	 *   bp  = b(p) = exp( sum_i b_i lnp_i )
	 * ================================================================== */
	tempvar lnA bp
	local xb "`anot'"
	forvalues i = 1/`n' {
		local pi : word `i' of `lnprices'
		local xb "`xb' + `A'[1,`i']*`pi'"
	}
	forvalues i = 1/`n' {
		local pi : word `i' of `lnprices'
		local xb "`xb' + 0.5*`G'[`i',`i']*`pi'*`pi'"
		local i1 = `i' + 1
		forvalues j = `i1'/`n' {
			local pj : word `j' of `lnprices'
			local xb "`xb' + `G'[`i',`j']*`pi'*`pj'"
		}
	}
	gen double `lnA' = `xb' if `touse'

	local xb "0"
	forvalues i = 1/`n' {
		local pi : word `i' of `lnprices'
		local xb "`xb' + `B'[1,`i']*`pi'"
	}
	gen double `bp' = exp(`xb') if `touse'

	tempvar lnmA
	gen double `lnmA' = `lnexp' - `lnA' if `touse'

	/* ================================================================== *
	 * Latent (SY expected) budget shares
	 *   cw_i = Phi_i * w*_i + deltapdf_i * phi_i
	 * ================================================================== */
	forvalues i = 1/`n' {
		local cdfi : word `i' of `cdfvars'
		local pdfi : word `i' of `pdfvars'

		local rhs "`A'[1,`i']"
		forvalues j = 1/`n' {
			local pj : word `j' of `lnprices'
			local rhs "`rhs' + `G'[`i',`j']*`pj'"
		}
		local rhs "`rhs' + `B'[1,`i']*`lnmA'"
		if `quad' {
			local rhs "`rhs' + `L'[1,`i']*(`lnmA'^2)/`bp'"
		}
		forvalues t = 1/`k' {
			local zt : word `t' of `demographics'
			local rhs "`rhs' + `D'[`i',`t']*`zt'"
		}
		gen double `p'cw`i' = `cdfi'*(`rhs') + `DP'[1,`i']*`pdfi' if `touse'
	}

	/* ================================================================== *
	 * Derivatives
	 *   mu_i = d w*_i / d lnm            (UNSCALED by Phi)
	 *   y_i  = d cw_i / d lnm  = Phi_i * mu_i
	 * ================================================================== */
	forvalues i = 1/`n' {
		local cdfi : word `i' of `cdfvars'
		tempvar mu`i' y`i'
		if `quad' {
			gen double `mu`i'' =                                     ///
			    `B'[1,`i'] + 2*`L'[1,`i']*`lnmA'/`bp' if `touse'
		}
		else {
			gen double `mu`i'' = `B'[1,`i'] if `touse'
		}
		gen double `y`i'' = `cdfi'*`mu`i'' if `touse'
	}

	/* d ln a(p) / d ln p_j = a_j + sum_k g_jk ln p_k
	 * pricegroup() replaces the household's own log prices with within-
	 * group means, reproducing the -bysort area: egen mean- of the
	 * reference do-file.  If prices are already constant within the group
	 * the two coincide. */
	local LNP "`lnprices'"
	if "`pricegroup'" != "" {
		local LNP ""
		forvalues k2 = 1/`n' {
			local pk : word `k2' of `lnprices'
			tempvar mk
			bysort `touse' `pricegroup' : egen double `mk' = ///
			    mean(cond(`touse', `pk', .))
			local LNP `LNP' `mk'
		}
	}
	forvalues j = 1/`n' {
		tempvar dA`j'
		local rhs "`A'[1,`j']"
		forvalues k2 = 1/`n' {
			local pk : word `k2' of `LNP'
			local rhs "`rhs' + `G'[`j',`k2']*`pk'"
		}
		gen double `dA`j'' = `rhs' if `touse'
	}

	/* ================================================================== *
	 * Elasticities
	 * ================================================================== */

	* expenditure: e_i = (d cw_i/d lnm)/cw_i + 1
	forvalues i = 1/`n' {
		gen double `p'em_`i' = `y`i''/`p'cw`i' + 1 if `touse'
	}

	* Marshallian: e^m_ij = (d cw_i/d lnp_j)/cw_i - kronecker(i,j)
	*
	* The chain rule puts the UNSCALED mu_i against dA_j; -legacy- uses the
	* Phi-scaled y_i there instead, as the reference do-file does.
	forvalues i = 1/`n' {
		local cdfi : word `i' of `cdfvars'
		local MU "`mu`i''"
		if "`legacy'" != "" local MU "`y`i''"
		forvalues j = 1/`n' {
			local dwdp "`G'[`i',`j'] - `MU'*`dA`j''"
			if `quad' {
				local dwdp                                       ///
				"`dwdp' - `L'[1,`i']*`B'[1,`j']*(`lnmA'^2)/`bp'"
			}
			gen double `p'epm_`i'_`j' =                              ///
			    `cdfi'*(`dwdp')/`p'cw`i' if `touse'
		}
		replace `p'epm_`i'_`i' = `p'epm_`i'_`i' - 1 if `touse'
	}

	* Hicksian, by the Slutsky equation: e^h_ij = e^m_ij + e_i * w_j
	* -legacy- reproduces the reference's  e^m_ij - e_i * w_i  instead.
	forvalues i = 1/`n' {
		forvalues j = 1/`n' {
			if "`legacy'" != "" {
				gen double `p'eph_`i'_`j' =                      ///
				    `p'epm_`i'_`j' - `p'em_`i'*`p'cw`i' if `touse'
			}
			else {
				gen double `p'eph_`i'_`j' =                      ///
				    `p'epm_`i'_`j' + `p'em_`i'*`p'cw`j' if `touse'
			}
		}
	}

	} // quietly

	/* ================================================================== *
	 * Labels
	 * ================================================================== */
	forvalues i = 1/`n' {
		local si : word `i' of `shares'
		label variable `p'cw`i'   "latent budget share, `si'"
		label variable `p'em_`i'  "expenditure elasticity, `si'"
		forvalues j = 1/`n' {
			local sj : word `j' of `shares'
			label variable `p'epm_`i'_`j' "Marshallian `si' wrt p(`sj')"
			label variable `p'eph_`i'_`j' "Hicksian `si' wrt p(`sj')"
		}
	}

	/* ================================================================== *
	 * Optional outlier cleaning of the elasticities (never of cw)
	 * ================================================================== */
	local ncleaned = 0
	if "`cleanmethod'" != "" {
		local elasvars ""
		forvalues i = 1/`n' {
			local elasvars `elasvars' `p'em_`i'
			forvalues j = 1/`n' {
				local elasvars `elasvars' `p'epm_`i'_`j' `p'eph_`i'_`j'
			}
		}
		foreach v of local elasvars {
			_ifpriclean `v' if `touse',                              ///
			    method(`cleanmethod') factor(`cleanfactor')
			local ncleaned = `ncleaned' + r(ndropped)
		}
	}

	/* ================================================================== *
	 * Summary matrices in r()
	 * ================================================================== */
	local wexp ""
	if "`e(wexp)'" != "" local wexp "[aw`e(wexp)']"

	tempname emMed emMean epmMed epmMean ephMed ephMean
	matrix `emMed'   = J(1, `n', .)
	matrix `emMean'  = J(1, `n', .)
	matrix `epmMed'  = J(`n', `n', .)
	matrix `epmMean' = J(`n', `n', .)
	matrix `ephMed'  = J(`n', `n', .)
	matrix `ephMean' = J(`n', `n', .)

	forvalues i = 1/`n' {
		Summ `p'em_`i' `touse' "`wexp'"
		matrix `emMed'[1,`i']  = r(med)
		matrix `emMean'[1,`i'] = r(mean)
		forvalues j = 1/`n' {
			Summ `p'epm_`i'_`j' `touse' "`wexp'"
			matrix `epmMed'[`i',`j']  = r(med)
			matrix `epmMean'[`i',`j'] = r(mean)
			Summ `p'eph_`i'_`j' `touse' "`wexp'"
			matrix `ephMed'[`i',`j']  = r(med)
			matrix `ephMean'[`i',`j'] = r(mean)
		}
	}
	matrix colnames `emMed'   = `shares'
	matrix colnames `emMean'  = `shares'
	foreach m in `epmMed' `epmMean' `ephMed' `ephMean' {
		matrix rownames `m' = `shares'
		matrix colnames `m' = `shares'
	}

	/* ================================================================== *
	 * Report
	 * ================================================================== */
	if "`summary'" != "nosummary" {
		di ""
		di as txt "Conditional elasticities after ifpriquaids"    ///
		   " (`n' goods, " as res `nobs' as txt " obs)"
		if "`legacy'" != "" {
			di as txt "  {bf:legacy} formulas in use - see help file"
		}
		if "`cleanmethod'" == "iqr" {
			di as txt "  cleaned: " as res `cleanfactor'          ///
			   as txt " x IQR, " as res `ncleaned'                ///
			   as txt " values set to missing"
		}
		if "`cleanmethod'" == "sd" {
			di as txt "  cleaned: " as res `cleanfactor'          ///
			   as txt " x SD, "  as res `ncleaned'                ///
			   as txt " values set to missing"
		}
		di ""
		di as txt "{hline 58}"
		di as txt %-16s "good" %13s "expenditure" %13s "own Marsh."   ///
		   %13s "own Hicks."
		di as txt "{hline 58}"
		forvalues i = 1/`n' {
			local si : word `i' of `shares'
			di as txt %-16s abbrev("`si'",15)                     ///
			   as res %13.4f `emMed'[1,`i']                       ///
			          %13.4f `epmMed'[`i',`i']                    ///
			          %13.4f `ephMed'[`i',`i']
		}
		di as txt "{hline 58}"
		di as txt "medians over the estimation sample"
	}

	return matrix em_median   = `emMed'
	return matrix em_mean     = `emMean'
	return matrix epm_median  = `epmMed'
	return matrix epm_mean    = `epmMean'
	return matrix eph_median  = `ephMed'
	return matrix eph_mean    = `ephMean'
	return scalar ngoods      = `n'
	return scalar N           = `nobs'
	return scalar ncleaned    = `ncleaned'
	return local  cleanmethod "`cleanmethod'"
	return local  prefix      "`p'"
end


/* ====================================================================== *
 * Weighted mean and median of one variable over the sample
 * ====================================================================== */

program Summ, rclass
	version 14.0
	args var touse wexp

	quietly {
		summarize `var' `wexp' if `touse'
		local m = r(mean)
		local nn = r(N)
		if `nn' > 0 {
			_pctile `var' `wexp' if `touse', p(50)
			local md = r(r1)
		}
		else	local md = .
	}
	return scalar mean = `m'
	return scalar med  = `md'
	return scalar N    = `nn'
end
