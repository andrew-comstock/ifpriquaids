*! version 1.0.0  25aug2026
*! ifpriprobit -- first-stage probits for the censored QUAIDS pipeline
*!
*! One probit per good of the censoring dummy on log total expenditure and
*! covariates, producing the standard normal cdf and pdf at the fitted index
*! for -ifpriquaids-.
*!
*! Handles the practical problem that a covariate which predicts
*! participation perfectly makes Stata drop observations, which leaves holes
*! in cdf/pdf and breaks the demand system downstream.  See -autodrop-.
*!
*! Built from 03_probit.do; its missing-value checks are retained.

program ifpriprobit, eclass
	version 14.0

	syntax varlist(min=1 numeric) [if] [in]                              ///
		[pweight fweight iweight]                                        ///
		, LNEXPenditure(varname numeric)                                 ///
		[ COVariates(string)                                             ///
		  COVDrop(string)                                                ///
		  EXclude(numlist integer >=1 sort)                              ///
		  NOCONStant(numlist integer >=1 sort)                           ///
		  noAUTODrop                                                     ///
		  MAXDrop(integer 20)                                            ///
		  PREfix(name)                                                   ///
		  GENIndex(name)                                                 ///
		  REPLACE                                                        ///
		  noSUMmary                                                      ///
		  * ]

	local dvars `varlist'
	local n : word count `dvars'
	local p `prefix'

	/* ---------------- validate good numbers --------------------------- */
	foreach g of local exclude {
		if `g' > `n' {
			di as err "exclude(): `g' exceeds the number of goods (`n')"
			exit 198
		}
	}
	foreach g of local noconstant {
		if `g' > `n' {
			di as err "noconstant(): `g' exceeds the number of goods (`n')"
			exit 198
		}
	}

	/* ---------------- covariates -------------------------------------- *
	 * Expand up front so that factor-variable LEVELS can be dropped
	 * individually: a level that predicts perfectly is removed on its own,
	 * exactly as one would do by hand.
	 * ------------------------------------------------------------------ */
	local basecov ""
	local covbase ""
	if `"`covariates'"' != "" {
		fvexpand `covariates'
		local basecov `r(varlist)'
		fvrevar `covariates', list
		local covbase `r(varlist)'
	}

	/* ---------------- covdrop(): per-good manual removals -------------- *
	 * Syntax:  covdrop(13: zone_2 ; 7: hhsex urban)
	 * ------------------------------------------------------------------ */
	forvalues i = 1/`n' {
		local mandrop`i' ""
	}
	if `"`covdrop'"' != "" {
		local spec `"`covdrop'"'
		while `"`spec'"' != "" {
			gettoken chunk spec : spec, parse(";")
			if `"`chunk'"' == ";" continue
			gettoken gnum rest : chunk, parse(":")
			local gnum = trim("`gnum'")
			gettoken colon rest : rest, parse(":")
			if "`colon'" != ":" {
				di as err "covdrop(): expected "                  ///
				          "'good: varlist', found `chunk'"
				exit 198
			}
			capture confirm integer number `gnum'
			if _rc | `gnum' < 1 | `gnum' > `n' {
				di as err "covdrop(): `gnum' is not a good number "  ///
				          "between 1 and `n'"
				exit 198
			}
			local mandrop`gnum' `"`rest'"'
		}
	}

	/* ---------------- output names ------------------------------------ *
	 * Checked after the options above, so that a bad option reports its
	 * own error rather than "variable already exists".
	 * ------------------------------------------------------------------ */
	local newvars ""
	forvalues i = 1/`n' {
		local newvars `newvars' `p'cdf`i' `p'pdf`i'
		if "`genindex'" != "" local newvars `newvars' `genindex'`i'
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

	/* ---------------- sample ------------------------------------------ *
	 * One common sample across every good, so the cdf/pdf columns handed
	 * to ifpriquaids are complete for the same households.
	 * ------------------------------------------------------------------ */
	marksample touse
	markout `touse' `dvars' `lnexpenditure' `covbase'
	quietly count if `touse'
	if r(N) == 0 error 2000
	local nobs = r(N)

	local wgt ""
	if "`weight'" != "" local wgt "[`weight'`exp']"

	/* ================================================================== *
	 * One probit per good
	 * ================================================================== */
	local allterms ""
	local anydrop = 0

	forvalues i = 1/`n' {
		local dv : word `i' of `dvars'
		local isexcl : list posof "`i'" in exclude
		local isnoc  : list posof "`i'" in noconstant

		local drop`i' ""
		local nused`i' = 0
		local pbar`i'  = .

		if `isexcl' {
			tempvar xbv`i'
			local excl`i' = 1
			continue
		}
		local excl`i' = 0

		* covariates for this good: base minus any manual removals
		local covs "`basecov'"
		local mdrop`i' ""
		if `"`mandrop`i''"' != "" {
			fvexpand `mandrop`i''
			local md `r(varlist)'
			* record only what was actually present to remove
			local mdrop`i' : list md & covs
			local covs : list covs - md
		}

		local nocopt ""
		if `isnoc' local nocopt "noconstant"

		tempvar xb
		local iter = 0
		while 1 {
			local ++iter

			capture noisily quietly probit `dv' `lnexpenditure' `covs'   ///
			    if `touse' `wgt', `nocopt' `options'
			if _rc {
				di as err "probit failed for `dv' (good `i'), rc = " _rc
				exit _rc
			}

			capture drop `xb'
			quietly predict double `xb' if `touse', xb
			quietly count if `touse' & `xb' >= .
			local nmiss = r(N)

			if `nmiss' == 0 continue, break

			* Observations were lost.  Identify the culprit from WHICH
			* observations were dropped, not from Stata's omission markers.
			*
			* Marker-based detection does not work here.  A BASE factor
			* level that predicts perfectly is still reported as "1b.zone",
			* with no "o" anywhere in the name - indistinguishable from an
			* ordinary base level - so the one case that matters is exactly
			* the one that is invisible.  Meanwhile "6o.zone" may be a
			* merely collinear term that cost no observations at all and
			* must be left alone.
			*
			* Stata drops precisely the observations for which the
			* offending term is non-zero, so the culprit is the term whose
			* support within the sample coincides with the set of dropped
			* observations.
			tempvar lost
			capture drop `lost'
			quietly gen byte `lost' = `touse' & `xb' >= .

			* A term is responsible when EVERY observation for which it is
			* non-zero was dropped.  Testing it per term rather than against
			* the whole dropped set matters: several levels can predict
			* perfectly at once, in which case no single one accounts for
			* all the dropped observations.  A merely collinear term fails
			* this test - none of its observations are lost - so it is
			* correctly left alone.
			local pick ""
			foreach t of local covs {
				* turn a term into an indicator expression:
				* "2.zone", "1b.zone", "1bno.zone" -> (zone == k)
				local expr ""
				if regexm("`t'", "^([0-9]+)[bon]*\.(.+)$") {
					local lev = regexs(1)
					local vn  = regexs(2)
					local expr "(`vn' == `lev')"
				}
				else	local expr "(`t' != 0 & `t' < .)"

				capture quietly count if `touse' & `expr'
				if _rc continue
				local supp = r(N)
				if `supp' == 0 continue
				quietly count if `lost' & `expr'
				if r(N) == `supp' local pick `pick' `t'
			}

			if "`autodrop'" == "noautodrop" | "`pick'" == "" |             ///
			   `iter' > `maxdrop' {
				continue, break
			}

			local covs  : list covs - pick
			local drop`i' `drop`i'' `pick'
			local anydrop = 1
		}

		* keep the index; cdf/pdf are generated after the loop so that all
		* cdf variables are contiguous and all pdf variables are contiguous,
		* which is what varlist range notation (cdf1-cdfn) needs
		tempvar xbv`i'
		quietly gen double `xbv`i'' = `xb' if `touse'
		local nused`i' = e(N)
		quietly summarize `dv' if `touse', meanonly
		local pbar`i' = r(mean)

		* Keep this good's coefficients.  Strip the b/o/n markers from
		* factor-variable names first: when a level is dropped for one good
		* Stata rebases that good's factor, so the same variable can arrive
		* as "1b.zone" from one probit and "2b.zone" or "3b.zone" from
		* another.  Carrying those into one name list would declare several
		* base categories for one factor, which -matrix colnames- rejects
		* as a base category conflict.
		tempname b`i'
		matrix `b`i'' = e(b)
		local raw : colnames `b`i''
		local cn`i' ""
		foreach t of local raw {
			if regexm("`t'", "^([0-9]+)[bon]+\.(.+)$") {
				local t = regexs(1) + "." + regexs(2)
			}
			local cn`i' `cn`i'' `t'
		}
		local allterms : list allterms | cn`i'
	}

	/* ================================================================== *
	 * Create the outputs in blocks - all cdf, then all pdf, then all
	 * index - so each family is contiguous and cdf1-cdfn works.
	 * ================================================================== */
	quietly {
		forvalues i = 1/`n' {
			if `excl`i'' gen double `p'cdf`i' = 1 if `touse'
			else         gen double `p'cdf`i' = normal(`xbv`i'') if `touse'
		}
		forvalues i = 1/`n' {
			if `excl`i'' gen double `p'pdf`i' = 0 if `touse'
			else         gen double `p'pdf`i' = normalden(`xbv`i'') if `touse'
		}
		if "`genindex'" != "" {
			forvalues i = 1/`n' {
				if `excl`i'' gen double `genindex'`i' = . if `touse'
				else         gen double `genindex'`i' = `xbv`i'' if `touse'
			}
		}
	}

	/* ---------------- labels ------------------------------------------ */
	forvalues i = 1/`n' {
		local dv : word `i' of `dvars'
		label variable `p'cdf`i' "cumulative distribution function for `dv'"
		label variable `p'pdf`i' ///
		    "standard normal density for `dv'"
		if "`genindex'" != "" {
			label variable `genindex'`i' "linear prediction for `dv'"
		}
	}

	/* ================================================================== *
	 * Checks carried over from 03_probit.do
	 * ================================================================== */
	forvalues i = 1/`n' {
		quietly count if `touse' & `p'pdf`i' >= .
		if r(N) > 0 {
			di as error "PDF`i' contains a missing value"
			exit 498
		}
		quietly count if `touse' & `p'cdf`i' >= .
		if r(N) > 0 {
			di as error "CDF`i' contains a missing value"
			exit 498
		}
	}

	/* ================================================================== *
	 * Probit coefficients, as one matrix over the union of terms.
	 * Rows are goods; zero means the term was not in that good's model.
	 * Excluded goods are all-zero rows.
	 * ================================================================== */
	local nk : word count `allterms'
	tempname PB
	if `nk' > 0 {
		matrix `PB' = J(`n', `nk', 0)
		forvalues i = 1/`n' {
			if `excl`i'' continue
			local cnames `cn`i''
			local c = 0
			foreach t of local cnames {
				local ++c
				local pos : list posof "`t'" in allterms
				if `pos' matrix `PB'[`i', `pos'] = `b`i''[1, `c']
			}
		}
		matrix rownames `PB' = `dvars'
		matrix colnames `PB' = `allterms'
	}

	/* ================================================================== *
	 * Report
	 * ================================================================== */
	if "`summary'" != "nosummary" {
		di ""
		di as txt "First-stage probits: " as res `n' as txt " goods, "  ///
		   as res `nobs' as txt " observations"
		di ""
		di as txt "{hline 72}"
		di as txt %-5s "good" %-14s "  dummy" %10s "share=1"           ///
		   %8s "N used" %6s "cons" "  covariates dropped"
		di as txt "{hline 72}"
		forvalues i = 1/`n' {
			local dv : word `i' of `dvars'
			if `excl`i'' {
				di as txt %-5.0f `i' "  " as res %-12s abbrev("`dv'",12) ///
				   as txt %10s "-" %8s "-" %6s "-"                       ///
				   "  excluded: cdf=1, pdf=0"
			}
			else {
				local isnoc : list posof "`i'" in noconstant
				local ctxt = cond(`isnoc', "no", "yes")
				local dtxt ""
				if "`mdrop`i''" != "" {
					local dtxt "`mdrop`i'' [covdrop]"
				}
				if "`drop`i''" != "" {
					local dtxt "`dtxt' `drop`i'' [auto]"
				}
				if trim("`dtxt'") == "" local dtxt "-"
				di as txt %-5.0f `i' "  " as res %-12s abbrev("`dv'",12) ///
				   %10.3f `pbar`i'' %8.0f `nused`i''                     ///
				   as txt %6s "`ctxt'" "  " as res "`dtxt'"
			}
		}
		di as txt "{hline 72}"
		if `anydrop' {
			if "`autodrop'" == "noautodrop" {
				di as txt "covariates listed above were removed by covdrop()"
			}
			else {
				di as txt "covariates listed above were removed "     ///
				          "automatically: each predicted"
				di as txt "participation perfectly, which would have " ///
				          "left holes in cdf/pdf"
			}
		}
		if "`autodrop'" == "noautodrop" {
			di as txt "autodrop disabled"
		}
	}

	/* ================================================================== *
	 * e() returns.  This command posts nothing of its own, so e() from the
	 * last probit is cleared and replaced with a summary of the whole set.
	 * ================================================================== */
	local cdfnames ""
	local pdfnames ""
	forvalues i = 1/`n' {
		local cdfnames `cdfnames' `p'cdf`i'
		local pdfnames `pdfnames' `p'pdf`i'
	}

	tempvar touse2
	quietly gen byte `touse2' = `touse'
	ereturn post, esample(`touse2')

	ereturn local cmd            "ifpriprobit"
	ereturn local cmd2           "ifpriprobit"
	ereturn local title2         "First-stage probits for censored QUAIDS"
	ereturn local dummies        "`dvars'"
	ereturn local lnexpenditure  "`lnexpenditure'"
	ereturn local covariates     `"`covariates'"'
	ereturn local cdfvars        "`cdfnames'"
	ereturn local pdfvars        "`pdfnames'"
	ereturn local prefix         "`p'"
	ereturn local genindex       "`genindex'"
	ereturn local excluded       "`exclude'"
	ereturn local noconstant     "`noconstant'"
	ereturn local autodrop = cond("`autodrop'"=="noautodrop", "off", "on")

	forvalues i = 1/`n' {
		ereturn local dropped`i'    "`drop`i''"
		ereturn local covdropped`i' "`mdrop`i''"
	}

	ereturn scalar ngoods = `n'
	ereturn scalar N      = `nobs'
	if `nk' > 0 ereturn matrix prbeta = `PB'
end
