*! version 1.0.0  25aug2026
*! ifpriwl -- Working-Leser all-food model, stage 1 of the ifpriquaids pipeline
*!
*!   foodshare = a + beta_p*ln(avg food price) + beta_m*ln(total expenditure)
*!               + covariates
*!
*! Observation-level elasticities:
*!   EM =  1 + beta_m / foodshare      expenditure elasticity, all food
*!   EP = -1 + beta_p / foodshare      price elasticity, all food
*!
*! Built from 03_WL.do; its four validity checks are retained.

program ifpriwl, eclass
	version 14.0

	syntax varname(numeric) [if] [in]                                    ///
		[aweight fweight pweight iweight]                                ///
		, LNEXPenditure(varname numeric)                                 ///
		  LNPrice(varname numeric)                                       ///
		[ COVariates(varlist numeric fv)                                 ///
		  PREfix(name)                                                   ///
		  REPLACE                                                        ///
		  IQRclean(real -1)                                              ///
		  SDclean(real -1)                                               ///
		  EMBounds(numlist min=2 max=2 ascending)                        ///
		  EPBounds(numlist min=2 max=2 ascending)                        ///
		  noCHECK                                                        ///
		  noSUMmary                                                      ///
		  * ]

	local foshare `varlist'
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

	/* ---------------- plausibility bounds ----------------------------- *
	 * Defaults are the bounds hard-coded in 03_WL.do.
	 * ------------------------------------------------------------------ */
	if "`embounds'" == "" local embounds ".2 2"
	if "`epbounds'" == "" local epbounds "-2 -.2"
	local emlo : word 1 of `embounds'
	local emhi : word 2 of `embounds'
	local eplo : word 1 of `epbounds'
	local ephi : word 2 of `epbounds'

	/* ---------------- output names ------------------------------------ */
	local newvars "`p'EM `p'EP"
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

	/* ---------------- sample ------------------------------------------ */
	marksample touse
	local wgt ""
	if "`weight'" != "" local wgt "[`weight'`exp']"

	/* ================================================================== *
	 * Working-Leser regression
	 *
	 * The estimation sample is taken from the fit itself rather than
	 * built with markout, so that factor-variable covariates and any
	 * collinear-drop behaviour are handled by -regress-.
	 * ================================================================== */
	regress `foshare' `lnprice' `lnexpenditure' `covariates'             ///
	    if `touse' `wgt', `options'

	quietly replace `touse' = e(sample)
	local nobs = e(N)
	if `nobs' == 0 error 2000

	/* ================================================================== *
	 * Validity of the two coefficients we need
	 *
	 * 03_WL.do wrote each coefficient into a variable and checked that no
	 * observation was missing.  Since _b[] is a scalar that is exactly a
	 * test of whether the coefficient itself is missing, done directly
	 * here.  The collinearity test below is an addition: a regressor
	 * dropped for collinearity returns _b = 0 with _se = 0, which would
	 * silently produce EM = 1 or EP = -1 rather than a missing value.
	 * ================================================================== */
	if missing(_b[`lnexpenditure']) {
		di as error "Expenditure coefficient from WL contains a missing value"
		exit 498
	}
	if missing(_b[`lnprice']) {
		di as error "Price coefficient from WL contains a missing value"
		exit 498
	}
	local bnames : colnames e(b)
	local omitm = 0
	local omitp = 0
	foreach nm of local bnames {
		if "`nm'" == "o.`lnexpenditure'" local omitm = 1
		if "`nm'" == "o.`lnprice'"       local omitp = 1
	}
	if `omitm' {
		di as error "Expenditure coefficient from WL was dropped "        ///
		            "(collinear with another regressor)"
		exit 498
	}
	if `omitp' {
		di as error "Price coefficient from WL was dropped "              ///
		            "(collinear with another regressor)"
		exit 498
	}

	tempname bm bp
	scalar `bm' = _b[`lnexpenditure']
	scalar `bp' = _b[`lnprice']

	/* ================================================================== *
	 * Elasticities
	 * ================================================================== */
	quietly {
		gen double `p'EM =  1 + `bm'/`foshare' if `touse'
		gen double `p'EP = -1 + `bp'/`foshare' if `touse'
	}
	label variable `p'EM "Expenditure elasticity, all food"
	label variable `p'EP "Price elasticity, all food"

	/* ================================================================== *
	 * Plausibility of the result
	 *
	 * Unweighted medians, matching 03_WL.do, and computed BEFORE any
	 * cleaning so the check sees the model's own output.
	 * ================================================================== */
	quietly summarize `p'EM if `touse', detail
	local emMedRaw = r(p50)
	quietly summarize `p'EP if `touse', detail
	local epMedRaw = r(p50)

	if "`check'" != "nocheck" {
		if `emMedRaw' < `emlo' | `emMedRaw' > `emhi' {
			di as error "All food exp. elast is outside acceptable "  ///
			            "bounds: < `emlo' or > `emhi'"
			exit 498
		}
		if `epMedRaw' < `eplo' | `epMedRaw' > `ephi' {
			di as error "All food price elast is outside acceptable " ///
			            "bounds: < `eplo' or > `ephi'"
			exit 498
		}
	}

	/* ================================================================== *
	 * Optional outlier cleaning
	 * ================================================================== */
	local ncleaned = 0
	if "`cleanmethod'" != "" {
		foreach v of local newvars {
			_ifpriclean `v' if `touse',                               ///
			    method(`cleanmethod') factor(`cleanfactor')
			local ncleaned = `ncleaned' + r(ndropped)
		}
	}

	/* ================================================================== *
	 * Summaries
	 * ================================================================== */
	quietly summarize `p'EM if `touse', detail
	local emMed = r(p50)
	local emMean = r(mean)
	quietly summarize `p'EP if `touse', detail
	local epMed = r(p50)
	local epMean = r(mean)

	local emMedW = .
	local epMedW = .
	local emMeanW = .
	local epMeanW = .
	if "`weight'" != "" {
		quietly summarize `p'EM [aw`exp'] if `touse'
		local emMeanW = r(mean)
		quietly _pctile `p'EM [aw`exp'] if `touse', p(50)
		local emMedW = r(r1)
		quietly summarize `p'EP [aw`exp'] if `touse'
		local epMeanW = r(mean)
		quietly _pctile `p'EP [aw`exp'] if `touse', p(50)
		local epMedW = r(r1)
	}

	/* ================================================================== *
	 * Report
	 * ================================================================== */
	if "`summary'" != "nosummary" {
		di ""
		di as txt "Working-Leser model, all food"
		di as txt "  food share      : " as res "`foshare'"
		di as txt "  log expenditure : " as res %-16s "`lnexpenditure'"  ///
		   as txt "beta = " as res %9.6f `bm'
		di as txt "  log price       : " as res %-16s "`lnprice'"        ///
		   as txt "beta = " as res %9.6f `bp'
		if "`covariates'" != "" {
			di as txt "  covariates      : " as res "`covariates'"
		}
		di as txt "  observations    : " as res `nobs'
		if "`cleanmethod'" != "" {
			di as txt "  cleaned         : " as res `cleanfactor'     ///
			   as txt " x " as res upper("`cleanmethod'")             ///
			   as txt ", " as res `ncleaned'                          ///
			   as txt " values set to missing"
		}
		di ""
		di as txt "{hline 52}"
		if "`weight'" == "" {
			di as txt %-22s "" %14s "median" %14s "mean"
			di as txt "{hline 52}"
			di as txt %-22s "EM (expenditure)"                        ///
			   as res %14.4f `emMed' %14.4f `emMean'
			di as txt %-22s "EP (price)"                              ///
			   as res %14.4f `epMed' %14.4f `epMean'
		}
		else {
			di as txt %-22s "" %11s "median" %11s "mean"              ///
			   %14s "wtd median"
			di as txt "{hline 52}"
			di as txt %-22s "EM (expenditure)"                        ///
			   as res %11.4f `emMed' %11.4f `emMean' %14.4f `emMedW'
			di as txt %-22s "EP (price)"                              ///
			   as res %11.4f `epMed' %11.4f `epMean' %14.4f `epMedW'
		}
		di as txt "{hline 52}"
		if "`check'" == "nocheck" {
			di as txt "plausibility checks skipped (nocheck)"
		}
	}

	/* ================================================================== *
	 * e() additions
	 *
	 * e(cmd) is left as "regress" so the usual regress postestimation
	 * still works; e(cmd2) identifies this wrapper, matching the
	 * convention used by ifpriquaids.
	 * ================================================================== */
	ereturn local cmd2          "ifpriwl"
	ereturn local title2        "Working-Leser model, all food"
	ereturn local foodshare     "`foshare'"
	ereturn local lnexpenditure "`lnexpenditure'"
	ereturn local lnprice       "`lnprice'"
	ereturn local covariates    "`covariates'"
	ereturn local emvar         "`p'EM"
	ereturn local epvar         "`p'EP"
	ereturn local cleanmethod   "`cleanmethod'"
	ereturn local prefix        "`p'"

	ereturn scalar beta_exp    = `bm'
	ereturn scalar beta_price  = `bp'
	ereturn scalar EM_median   = `emMed'
	ereturn scalar EM_mean     = `emMean'
	ereturn scalar EP_median   = `epMed'
	ereturn scalar EP_mean     = `epMean'
	ereturn scalar EM_median_w = `emMedW'
	ereturn scalar EM_mean_w   = `emMeanW'
	ereturn scalar EP_median_w = `epMedW'
	ereturn scalar EP_mean_w   = `epMeanW'
	ereturn scalar ncleaned    = `ncleaned'
end
