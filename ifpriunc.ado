*! version 1.0.0  26aug2026
*! ifpriunc -- unconditional elasticities by multi-stage budgeting
*!
*! Combines the conditional elasticities of one demand system with the
*! UNCONDITIONAL elasticities of the group it is nested in, giving
*! unconditional elasticities for the goods of that system:
*!
*!   expenditure : E_i  = Eparent * em_i
*!   price       : U_ij = epm_ij + em_i * share_j * (1 + EPparent)
*!   own price   : U_ii
*!
*! One call handles one stage transition.  Chain calls for more stages:
*! the outputs of one call are the parent inputs of the next, so any
*! number of stages is supported and only the branches that actually have
*! a sub-system need be run.
*!
*! Built from 05_elast_construct_clean.do; see -legacy- for the one
*! formula that differs.

program ifpriunc, rclass
	version 14.0

	syntax [if] [in] ,                                                   ///
		PARENTEM(string)                                                 ///
		PARENTEP(string)                                                 ///
		[ NGoods(integer 0)                                              ///
		  EM(name)                                                       ///
		  SHare(name)                                                    ///
		  EPM(name)                                                      ///
		  EPH(name)                                                      ///
		  GENerate(name)                                                 ///
		  NAMes(string)                                                  ///
		  IQRclean(real -1)                                              ///
		  SDclean(real -1)                                               ///
		  LEGacy                                                         ///
		  REPLACE                                                        ///
		  noSUMmary ]

	/* ---------------- input stubs, defaulting to the package's ------- *
	 * ifpriquaidselas writes em_1..em_n, cw1..cwn, epm_i_j, eph_i_j.
	 * ------------------------------------------------------------------ */
	if "`em'"    == "" local em    "em_"
	if "`share'" == "" local share "cw"
	if "`epm'"   == "" local epm   "epm_"
	if "`eph'"   == "" local eph   "eph_"
	local g `generate'

	/* ---------------- number of goods --------------------------------- */
	if `ngoods' == 0 {
		if "`e(cmd2)'" == "ifpriquaids" local ngoods = e(ngoods)
		else if "`e(cmd2)'" == "ifpriquaidselas" local ngoods = e(ngoods)
	}
	if `ngoods' == 0 {
		di as err "ngoods() required (no ifpriquaids estimates in memory)"
		exit 198
	}
	local n = `ngoods'

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

	/* ---------------- parent inputs: number or variable --------------- */
	foreach p in parentem parentep {
		local v "``p''"
		capture confirm variable `v'
		if _rc {
			capture confirm number `v'
			if _rc {
				di as err "`p'(): must be a number or a variable name"
				exit 198
			}
		}
	}

	/* ---------------- inputs must exist ------------------------------- *
	 * Checked one at a time rather than accumulated into a macro first:
	 * with a large ngoods() the accumulated list is n + n^2 names and
	 * overflows before the useful error can be given.
	 * ------------------------------------------------------------------ */
	local hint "check ngoods(), em(), share() and epm()"
	if "`legacy'" != "" local hint "check ngoods(), em(), share(), epm() and eph()"
	forvalues i = 1/`n' {
		foreach v in `em'`i' `share'`i' {
			capture confirm numeric variable `v'
			if _rc {
				di as err "`v' not found - `hint'"
				exit 111
			}
		}
		forvalues j = 1/`n' {
			capture confirm numeric variable `epm'`i'_`j'
			if _rc {
				di as err "`epm'`i'_`j' not found - `hint'"
				exit 111
			}
			if "`legacy'" != "" {
				capture confirm numeric variable `eph'`i'_`j'
				if _rc {
					di as err "`eph'`i'_`j' not found - `hint'"
					exit 111
				}
			}
		}
	}

	/* ---------------- names for labelling ----------------------------- */
	local nnames : word count `names'
	if `nnames' > 0 & `nnames' != `n' {
		di as err "names(): `nnames' given, `n' required"
		exit 198
	}

	/* ---------------- output names ------------------------------------ *
	 * Default naming follows 05_elast_construct_clean.do: em#, ep#_#,
	 * eop#.  Note the contrast with the CONDITIONAL em_#, epm_#_# - the
	 * underscore is the only thing distinguishing them, so generate() is
	 * worth using when both are in play.
	 * ------------------------------------------------------------------ */
	local newvars ""
	forvalues i = 1/`n' {
		local newvars `newvars' `g'em`i' `g'eop`i'
		forvalues j = 1/`n' {
			local newvars `newvars' `g'ep`i'_`j'
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
			di as err "`v' already exists; use replace, or generate()"
			exit 110
		}
	}

	/* ---------------- sample ------------------------------------------ */
	marksample touse, novarlist
	quietly count if `touse'
	if r(N) == 0 error 2000
	local nobs = r(N)

	/* ================================================================== *
	 * Unconditional elasticities
	 *
	 *   dln m_G / dln p_j = share_j * (1 + EPparent)
	 * so the chain rule through this stage gives, in MARSHALLIAN form,
	 *   U_ij = epm_ij + em_i * share_j * (1 + EPparent)
	 * The equivalent Hicksian form is
	 *   U_ij = eph_ij + em_i * share_j * EPparent
	 * -legacy- reproduces 05_elast_construct_clean.do, which pairs the
	 * Hicksian input with the Marshallian multiplier.
	 * ================================================================== */
	quietly {
		forvalues i = 1/`n' {
			gen double `g'em`i' = (`parentem') * `em'`i' if `touse'
			forvalues j = 1/`n' {
				if "`legacy'" != "" {
					gen double `g'ep`i'_`j' = `eph'`i'_`j'          ///
					    + `em'`i' * `share'`j' * (1 + (`parentep')) ///
					    if `touse'
				}
				else {
					gen double `g'ep`i'_`j' = `epm'`i'_`j'          ///
					    + `em'`i' * `share'`j' * (1 + (`parentep')) ///
					    if `touse'
				}
			}
			gen double `g'eop`i' = `g'ep`i'_`i' if `touse'
		}
	}

	/* ---------------- labels ------------------------------------------ */
	forvalues i = 1/`n' {
		local ni "good `i'"
		if `nnames' > 0 local ni : word `i' of `names'
		label variable `g'em`i'  "expenditure elasticity (unc.), `ni'"
		label variable `g'eop`i' "own-price elasticity (unc.), `ni'"
		forvalues j = 1/`n' {
			local nj "good `j'"
			if `nnames' > 0 local nj : word `j' of `names'
			label variable `g'ep`i'_`j' ///
			    "Marshallian price elast (unc.), `ni' wrt price of `nj'"
		}
	}

	/* ---------------- optional cleaning ------------------------------- */
	local ncleaned = 0
	if "`cleanmethod'" != "" {
		foreach v of local newvars {
			_ifpriclean `v' if `touse',                               ///
			    method(`cleanmethod') factor(`cleanfactor')
			local ncleaned = `ncleaned' + r(ndropped)
		}
	}

	/* ---------------- summaries --------------------------------------- */
	tempname emMed epMed
	matrix `emMed' = J(1, `n', .)
	matrix `epMed' = J(1, `n', .)
	forvalues i = 1/`n' {
		quietly summarize `g'em`i' if `touse', detail
		matrix `emMed'[1, `i'] = r(p50)
		quietly summarize `g'eop`i' if `touse', detail
		matrix `epMed'[1, `i'] = r(p50)
	}
	if `nnames' > 0 {
		matrix colnames `emMed' = `names'
		matrix colnames `epMed' = `names'
	}

	/* ---------------- report ------------------------------------------ */
	if "`summary'" != "nosummary" {
		di ""
		di as txt "Unconditional elasticities by multi-stage budgeting"  ///
		   " (" as res `n' as txt " goods, " as res `nobs' as txt " obs)"
		di as txt "  parent expenditure elasticity : " as res "`parentem'"
		di as txt "  parent own-price elasticity   : " as res "`parentep'"
		if "`legacy'" != "" {
			di as txt "  {bf:legacy} formula in use - see help file"
		}
		if "`cleanmethod'" != "" {
			di as txt "  cleaned: " as res `cleanfactor' as txt " x "  ///
			   as res upper("`cleanmethod'") as txt ", " as res       ///
			   `ncleaned' as txt " values set to missing"
		}
		di ""
		di as txt "{hline 56}"
		di as txt %-22s "good" %16s "expenditure" %16s "own price"
		di as txt "{hline 56}"
		forvalues i = 1/`n' {
			local ni "`i'"
			if `nnames' > 0 local ni : word `i' of `names'
			di as txt %-22s abbrev("`ni'", 21)                     ///
			   as res %16.4f `emMed'[1,`i'] %16.4f `epMed'[1,`i']
		}
		di as txt "{hline 56}"
		di as txt "medians; both unconditional"
	}

	return matrix em_median  = `emMed'
	return matrix eop_median = `epMed'
	return scalar ngoods     = `n'
	return scalar N          = `nobs'
	return scalar ncleaned   = `ncleaned'
	return local  generate   "`g'"
	return local  emvars     "`g'em"
	return local  epvars     "`g'ep"
	return local  eopvars    "`g'eop"
end
