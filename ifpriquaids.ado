*! version 1.1.0  24aug2026
*! ifpriquaids -- Censored QUAIDS via the Shonkwiler-Yen two-step method
*!
*! Homogeneity and symmetry are imposed by construction; adding-up is
*! relaxed (all n share equations are estimated, all alphas/betas/lambdas
*! are free).  The first-stage probit is NOT run by this command: the
*! standard-normal cdf and pdf evaluated at the first-stage index are
*! supplied by the user through cdf() and pdf().
*!
*! Requires the companion evaluator nlsurifpriquaids.ado.

program ifpriquaids, eclass
	version 14.0

	if replay() {
		if "`e(cmd2)'" != "ifpriquaids" error 301
		Replay `0'
		exit
	}

	Estimate `0'
	ereturn local cmdline "ifpriquaids `0'"
end


/* ====================================================================== *
 * Estimation
 * ====================================================================== */

program Estimate, eclass
	version 14.0

	syntax varlist(numeric min=2) [if] [in]                          ///
		[aweight fweight pweight iweight]                            ///
		, CDF(varlist numeric)                                       ///
		  PDF(varlist numeric)                                       ///
		[ LNPRices(varlist numeric)                                  ///
		  PRices(varlist numeric)                                    ///
		  LNEXPenditure(varname numeric)                             ///
		  EXPenditure(varname numeric)                               ///
		  DEMOgraphics(varlist numeric)                              ///
		  ANOT(string)                                               ///
		  noQUADratic                                                ///
		  ADDingup                                                   ///
		  NOSYcorrection(varlist numeric)                             ///
		  INITial(name)                                              ///
		  Level(cilevel)                                             ///
		  COEFVars                                                   ///
		  PREfix(name)                                               ///
		  * ]

	local shares `varlist'
	local n : word count `shares'

	/* ---------------- prices ------------------------------------------ */
	if ("`lnprices'" != "") + ("`prices'" != "") != 1 {
		di as err "specify one, and only one, of lnprices() or prices()"
		exit 198
	}
	if "`prices'" != "" {
		local np : word count `prices'
		if `np' != `n' {
			di as err "prices(): `np' variables specified; " ///
			          "`n' required (one per share)"
			exit 198
		}
	}
	else {
		local np : word count `lnprices'
		if `np' != `n' {
			di as err "lnprices(): `np' variables specified; " ///
			          "`n' required (one per share)"
			exit 198
		}
	}

	/* ---------------- expenditure ------------------------------------- */
	if ("`lnexpenditure'" != "") + ("`expenditure'" != "") != 1 {
		di as err "specify one, and only one, of " ///
		          "lnexpenditure() or expenditure()"
		exit 198
	}

	/* ---------------- cdf / pdf --------------------------------------- */
	local ncdf : word count `cdf'
	local npdf : word count `pdf'
	if `ncdf' != `n' {
		di as err "cdf(): `ncdf' variables specified; " ///
		          "`n' required (one per share)"
		exit 198
	}
	if `npdf' != `n' {
		di as err "pdf(): `npdf' variables specified; " ///
		          "`n' required (one per share)"
		exit 198
	}

	local k : word count `demographics'

	/* ---------------- nosycorrection() -------------------------------- *
	 * Goods whose Shonkwiler-Yen term is to be omitted outright, rather
	 * than estimated and left for nlsur to report as "(constrained)".
	 * Map the share names the user gave to their positions in `shares'.
	 * ------------------------------------------------------------------ */
	local nosyindex ""
	foreach v of local nosycorrection {
		local p : list posof "`v'" in shares
		if !`p' {
			di as err "nosycorrection(): `v' is not one of the share " ///
			          "variables"
			exit 198
		}
		local nosyindex `nosyindex' `p'
	}
	local nosyindex : list uniq nosyindex
	local nosyindex : list sort nosyindex
	* Omitting the correction for every good is legitimate: it is exactly
	* the right specification when no good is censored, and reduces the
	* model to an uncensored QUAIDS.  No guard here.
	local nnosy : word count `nosyindex'

	/* ---------------- a0 ---------------------------------------------- */
	if "`anot'" == "" local anot 0
	local anotvar ""
	capture confirm variable `anot'
	if !_rc {
		local anotvar `anot'
	}
	else {
		capture confirm number `anot'
		if _rc {
			di as err "anot(): must be a number or a variable name"
			exit 198
		}
	}

	/* ---------------- sample ------------------------------------------ */
	marksample touse
	markout `touse' `shares' `lnprices' `prices' `lnexpenditure'         ///
	                `expenditure' `cdf' `pdf' `demographics' `anotvar'
	qui count if `touse'
	if r(N) == 0 error 2000
	local nobs = r(N)

	/* ---------------- build logs if levels were supplied -------------- */
	if "`prices'" != "" {
		local lnprices ""
		foreach v of local prices {
			tempvar lv
			qui gen double `lv' = ln(`v') if `touse'
			local lnprices `lnprices' `lv'
		}
	}
	if "`expenditure'" != "" {
		tempvar lnexp
		qui gen double `lnexp' = ln(`expenditure') if `touse'
		local lnexpenditure `lnexp'
	}

	/* ---------------- parameter list ----------------------------------- *
	 * ORDER MATTERS: nlsurifpriquaids unpacks `at' in exactly this order.
	 * -------------------------------------------------------------------*/
	local nm1 = `n' - 1

	/* ------------------------------------------------------------------ *
	 * addingup: impose the adding-up restrictions on the LATENT system,
	 *     sum_i alpha_i = 1,  sum_i beta_i = 0,  sum_i lambda_i = 0,
	 *     sum_i delta_it = 0,
	 * by dropping the n-th parameter of each block and deriving it.
	 *
	 * The gamma block needs nothing: adding-up wants column sums of gamma
	 * to be zero, and symmetry plus the homogeneity already imposed give
	 * that for free, since sum_i g_ij = sum_i g_ji = row sum j = 0.
	 *
	 * deltapdf is unrestricted: it has no counterpart in the latent
	 * system, and the fitted shares do not sum to one in any case.
	 * ------------------------------------------------------------------ */
	local nfree = `n'
	if "`addingup'" != "" local nfree = `nm1'

	local params ""
	forvalues i = 1/`nfree' {
		local params `params' a`i'
	}
	forvalues i = 1/`nm1' {
		forvalues j = `i'/`nm1' {
			local params `params' g`i'_`j'
		}
	}
	forvalues i = 1/`nfree' {
		local params `params' b`i'
	}
	if "`quadratic'" != "noquadratic" {
		forvalues i = 1/`nfree' {
			local params `params' l`i'
		}
	}
	forvalues t = 1/`k' {
		forvalues i = 1/`nfree' {
			local params `params' d`i'_`t'
		}
	}
	forvalues i = 1/`n' {
		local omit : list posof "`i'" in nosyindex
		if !`omit' local params `params' dp`i'
	}
	local nparam : word count `params'

	/* ------------------------------------------------------------------ *
	 * A good consumed by every household is normally handled by setting
	 * cdf = 1 and pdf = 0, which correctly collapses its equation to the
	 * uncensored QUAIDS form.  Its SY coefficient then multiplies an
	 * identically-zero variable and is exactly unidentified; nlsur reports
	 * it as "(constrained)".  Say so up front instead of letting it pass
	 * unremarked in a 180-row coefficient table.
	 * ------------------------------------------------------------------ */
	local degen ""
	local nunc = 0
	forvalues i = 1/`n' {
		local pv : word `i' of `pdf'
		local cv : word `i' of `cdf'
		quietly summarize `pv' if `touse', meanonly
		local pzero = (r(min) == 0 & r(max) == 0)
		quietly summarize `cv' if `touse', meanonly
		local cone  = (r(min) == 1 & r(max) == 1)
		if `pzero' & `cone' local ++nunc
		local omit : list posof "`i'" in nosyindex
		if !`omit' & `pzero' {
			local sv : word `i' of `shares'
			local degen "`degen' `sv'"
		}
	}

	/* ------------------------------------------------------------------ *
	 * With adding-up imposed the latent shares sum to one.  If in addition
	 * every good is uncensored (cdf = 1 and pdf = 0 throughout) the fitted
	 * shares sum to one exactly, the n residuals sum to zero, and the error
	 * covariance matrix is singular - which is precisely why uncensored
	 * implementations drop an equation.  Refuse rather than let nlsur fail
	 * obscurely.
	 * ------------------------------------------------------------------ */
	if "`addingup'" != "" & `nunc' == `n' {
		di as err "addingup: every good is uncensored (cdf = 1, pdf = 0),"
		di as err "so the fitted shares would sum to one exactly and the"
		di as err "error covariance matrix would be singular."
		di as err "Fit n-1 equations with an uncensored command instead, " ///
		          "or drop addingup."
		exit 498
	}
	if "`degen'" != "" {
		di as txt "note: pdf is identically zero for:`degen'"
		di as txt "      the Shonkwiler-Yen coefficient is not identified " ///
		          "for these goods and will"
		di as txt "      be reported as constrained to 0; to drop it from " ///
		          "the model outright, use"
		di as txt "      nosycorrection(`degen')"
	}

	* Warn if a good named in nosycorrection() does have a live pdf: that
	* is a substantive restriction, not a bookkeeping convenience.
	local forced ""
	foreach idx of local nosyindex {
		local pv : word `idx' of `pdf'
		quietly summarize `pv' if `touse', meanonly
		if !(r(min) == 0 & r(max) == 0) {
			local sv : word `idx' of `shares'
			local forced "`forced' `sv'"
		}
	}
	if "`forced'" != "" {
		di as txt "note: nosycorrection() imposes deltapdf = 0 for:`forced'"
		di as txt "      whose pdf is not identically zero; this is a " ///
		          "testable restriction"
	}

	/* ---------------- optional pieces of the nlsur call ---------------- */
	local demoopt ""
	if `k' > 0 local demoopt "demographics(`demographics')"
	local nosyopt ""
	if `nnosy' > 0 local nosyopt "nosyindex(`nosyindex')"
	local initopt ""
	if "`initial'" != "" local initopt "initial(`initial')"
	local wgt ""
	if "`weight'" != "" local wgt "[`weight'`exp']"

	/* ---------------- estimate ----------------------------------------- *
	 * The evaluator caches the right-hand-side data in Mata for speed.
	 * Clear it either side of the fit so the cache can only ever live for
	 * the duration of this estimation, and a later -predict- rebuilds it
	 * rather than being served data that may since have changed.
	 * -capture- because the Mata is compiled when the evaluator ado is
	 * first loaded, which may not have happened yet.
	 * ------------------------------------------------------------------ */
	capture mata: ifq_clear()

	nlsur ifpriquaids @ `shares' if `touse' `wgt' ,                     ///
		lnprices(`lnprices') lnexpenditure(`lnexpenditure')             ///
		cdfvars(`cdf') pdfvars(`pdf') anot(`anot')                      ///
		`demoopt' `quadratic' `nosyopt' `addingup'                      ///
		parameters(`params') nequations(`n')                            ///
		`initopt' level(`level') `options'

	capture mata: ifq_clear()

	/* ================================================================== *
	 * Unpack e(b) into named matrices (same order as `params')
	 * ================================================================== */

	tempname bb alpha beta lambda gamma delta dpdf
	matrix `bb' = e(b)

	/* ------------------------------------------------------------------ *
	 * The matrices below are unpacked by POSITION, which is only valid if
	 * e(b) holds exactly the parameters we asked for, in order.  Constrained
	 * parameters are retained by nlsur as zeros, so this normally holds -
	 * but verify rather than silently return misaligned coefficients.
	 * ------------------------------------------------------------------ */
	local eqnames : coleq `bb'
	if `: word count `eqnames'' != `nparam' {
		di as err "ifpriquaids: nlsur returned "                         ///
		   `: word count `eqnames'' " parameters, `nparam' expected"
		di as err "the e() parameter matrices cannot be built reliably"
		exit 498
	}
	if "`eqnames'" != "`params'" {
		di as err "ifpriquaids: nlsur returned the parameters in an "    ///
		          "unexpected order"
		di as err "the e() parameter matrices cannot be built reliably"
		exit 498
	}

	local pos = 0

	tempname acc
	matrix `alpha' = J(1, `n', 0)
	scalar `acc' = 0
	forvalues i = 1/`nfree' {
		local ++pos
		matrix `alpha'[1, `i'] = `bb'[1, `pos']
		scalar `acc' = `acc' + `bb'[1, `pos']
	}
	if "`addingup'" != "" matrix `alpha'[1, `n'] = 1 - `acc'

	matrix `gamma' = J(`n', `n', 0)
	forvalues i = 1/`nm1' {
		forvalues j = `i'/`nm1' {
			local ++pos
			matrix `gamma'[`i', `j'] = `bb'[1, `pos']
			matrix `gamma'[`j', `i'] = `bb'[1, `pos']
		}
	}
	tempname s
	forvalues i = 1/`nm1' {
		scalar `s' = 0
		forvalues j = 1/`nm1' {
			scalar `s' = `s' + `gamma'[`i', `j']
		}
		matrix `gamma'[`i', `n'] = -`s'
		matrix `gamma'[`n', `i'] = -`s'
	}
	scalar `s' = 0
	forvalues j = 1/`nm1' {
		scalar `s' = `s' + `gamma'[`n', `j']
	}
	matrix `gamma'[`n', `n'] = -`s'

	matrix `beta' = J(1, `n', 0)
	scalar `acc' = 0
	forvalues i = 1/`nfree' {
		local ++pos
		matrix `beta'[1, `i'] = `bb'[1, `pos']
		scalar `acc' = `acc' + `bb'[1, `pos']
	}
	if "`addingup'" != "" matrix `beta'[1, `n'] = -`acc'

	if "`quadratic'" != "noquadratic" {
		matrix `lambda' = J(1, `n', 0)
		scalar `acc' = 0
		forvalues i = 1/`nfree' {
			local ++pos
			matrix `lambda'[1, `i'] = `bb'[1, `pos']
			scalar `acc' = `acc' + `bb'[1, `pos']
		}
		if "`addingup'" != "" matrix `lambda'[1, `n'] = -`acc'
	}

	if `k' > 0 {
		matrix `delta' = J(`n', `k', 0)
		forvalues t = 1/`k' {
			scalar `acc' = 0
			forvalues i = 1/`nfree' {
				local ++pos
				matrix `delta'[`i', `t'] = `bb'[1, `pos']
				scalar `acc' = `acc' + `bb'[1, `pos']
			}
			if "`addingup'" != "" matrix `delta'[`n', `t'] = -`acc'
		}
	}

	* Omitted goods keep a 0 here: the parameter does not exist.
	matrix `dpdf' = J(1, `n', 0)
	forvalues i = 1/`n' {
		local omit : list posof "`i'" in nosyindex
		if !`omit' {
			local ++pos
			matrix `dpdf'[1, `i'] = `bb'[1, `pos']
		}
	}

	* row/column names
	matrix colnames `alpha' = `shares'
	matrix rownames `alpha' = alpha
	matrix colnames `beta'  = `shares'
	matrix rownames `beta'  = beta
	matrix colnames `gamma' = `shares'
	matrix rownames `gamma' = `shares'
	matrix colnames `dpdf'  = `shares'
	matrix rownames `dpdf'  = deltapdf
	if "`quadratic'" != "noquadratic" {
		matrix colnames `lambda' = `shares'
		matrix rownames `lambda' = lambda
	}
	if `k' > 0 {
		matrix rownames `delta' = `shares'
		matrix colnames `delta' = `demographics'
	}

	/* ================================================================== *
	 * Optional: constant variables holding the point estimates, so that
	 * do-files written around the old 15-good script keep working.
	 * ================================================================== */
	if "`coefvars'" != "" {
		local lamopt ""
		if "`quadratic'" != "noquadratic" local lamopt "lambda(`lambda')"
		local delopt ""
		if `k' > 0 local delopt "delta(`delta')"
		local preopt ""
		if "`prefix'" != "" local preopt "prefix(`prefix')"

		Coefvars, n(`n') k(`k') `preopt'                             ///
			alpha(`alpha') gamma(`gamma') beta(`beta')               ///
			dpdf(`dpdf') `lamopt' `delopt' `quadratic'
	}

	/* ================================================================== *
	 * e() returns
	 * ================================================================== */
	* e(cmd) is deliberately left as "nlsur" so that the standard
	* nlsur postestimation tools (replay, predict, test, nlcom, estimates)
	* keep working unchanged.  e(cmd2) identifies the wrapper.
	ereturn local cmd2     "ifpriquaids"
	ereturn local title2   "Censored QUAIDS (Shonkwiler-Yen two-step)"
	ereturn local shares   "`shares'"
	* When levels were supplied the logs live in tempvars that do not
	* survive the command, so report the variables the user actually named.
	if "`prices'" != "" {
		ereturn local prices   "`prices'"
		ereturn local lnprices "(logs taken internally)"
	}
	else	ereturn local lnprices "`lnprices'"
	if "`expenditure'" != "" {
		ereturn local expenditure   "`expenditure'"
		ereturn local lnexpenditure "(log taken internally)"
	}
	else	ereturn local lnexpenditure "`lnexpenditure'"
	ereturn local cdfvars  "`cdf'"
	ereturn local pdfvars  "`pdf'"
	ereturn local demographics "`demographics'"
	ereturn local anot     "`anot'"
	ereturn local quadratic = cond("`quadratic'"=="noquadratic","no","yes")
	ereturn local addingup = cond("`addingup'"!="", "imposed", "relaxed")
	ereturn local homogeneity "imposed"
	ereturn local symmetry "imposed"
	ereturn local nosycorrection "`nosycorrection'"
	ereturn local nosyindex      "`nosyindex'"

	ereturn scalar ngoods  = `n'
	ereturn scalar ndemos  = `k'
	ereturn scalar nparam  = `nparam'
	ereturn scalar nnosy   = `nnosy'

	ereturn matrix alpha    = `alpha'
	ereturn matrix beta     = `beta'
	ereturn matrix gamma    = `gamma'
	ereturn matrix deltapdf = `dpdf'
	if "`quadratic'" != "noquadratic" ereturn matrix lambda = `lambda'
	if `k' > 0                        ereturn matrix delta  = `delta'

	Note
end


/* ====================================================================== *
 * One-line reminder of what is (and is not) imposed
 * ====================================================================== */

program Note
	version 14.0
	di as txt "Censored QUAIDS (Shonkwiler-Yen): " as res e(ngoods)     ///
	   as txt " goods, " as res e(ndemos) as txt " demographic(s);"     ///
	   _n "  homogeneity and symmetry imposed, adding-up "              ///
	   as res "`e(addingup)'" as txt "."
	if "`e(addingup)'" == "imposed" {
		di as txt "  (adding-up holds for the latent shares; fitted " ///
		          "shares still need not sum to 1)"
	}
	if "`e(nosycorrection)'" != "" {
		di as txt "  SY correction omitted for: " as res "`e(nosycorrection)'"
	}
end


/* ====================================================================== *
 * Generate constant variables holding the point estimates
 * ====================================================================== */

program Coefvars
	version 14.0
	syntax , n(integer) k(integer)                                       ///
		alpha(name) gamma(name) beta(name) dpdf(name)                    ///
		[ PREfix(name) lambda(name) delta(name) noQUADratic ]

	local p `prefix'
	local nm1 = `n' - 1

	* refuse to clobber
	local newvars ""
	forvalues i = 1/`n' {
		local newvars `newvars' `p'a`i' `p'b`i' `p'dp`i'
		if "`quadratic'" != "noquadratic" local newvars `newvars' `p'l`i'
		forvalues j = 1/`n' {
			local newvars `newvars' `p'g`i'_`j'
		}
		forvalues t = 1/`k' {
			local newvars `newvars' `p'd`i'_`t'
		}
	}
	foreach v of local newvars {
		capture confirm new variable `v'
		if _rc {
			di as err "coefvars: variable `v' already exists"
			exit 110
		}
	}

	quietly {
		forvalues i = 1/`n' {
			gen double `p'a`i'  = `alpha'[1, `i']
			gen double `p'b`i'  = `beta'[1, `i']
			gen double `p'dp`i' = `dpdf'[1, `i']
			if "`quadratic'" != "noquadratic" {
				gen double `p'l`i' = `lambda'[1, `i']
			}
			forvalues j = 1/`n' {
				gen double `p'g`i'_`j' = `gamma'[`i', `j']
			}
			forvalues t = 1/`k' {
				gen double `p'd`i'_`t' = `delta'[`i', `t']
			}
		}
	}
	if "`p'" == ""  di as txt "(coefficient variables created)"
	else            di as txt "(coefficient variables created with prefix `p')"
end


/* ====================================================================== *
 * Replay
 * ====================================================================== */

program Replay
	version 14.0
	nlsur `0'
	Note
end
