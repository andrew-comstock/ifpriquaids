*! version 1.0.0  26aug2026
*! ifpripost -- post elasticity summaries as e(b) so the pipeline can be
*!              bootstrapped
*!
*! The elasticities produced by ifpriquaidselas and ifpriunc are
*! observation level.  What gets reported is a summary of them - normally
*! the median across households.  This command collects those summaries
*! into e(b), which is what -bootstrap- needs in order to attach standard
*! errors to them.
*!
*! Intended as the last line of a wrapper program that runs the whole
*! pipeline; see the help file for a worked template.

program ifpripost, eclass
	version 14.0

	syntax [if] [in] [aweight pweight fweight iweight] ,                 ///
		NGoods(integer)                                                  ///
		[ EM(name)                                                       ///
		  EOP(name)                                                      ///
		  EP(name)                                                       ///
		  CROSS                                                          ///
		  EXTRA(varlist numeric)                                         ///
		  STATistic(name)                                                ///
		  noSUMmary ]

	local n = `ngoods'

	if "`statistic'" == "" local statistic median
	if !inlist("`statistic'", "median", "mean") {
		di as err "statistic() must be median or mean"
		exit 198
	}

	/* Defaults match what ifpriunc writes.  Point them at ifpriquaidselas
	   stubs (em_, eph_/epm_) to summarise conditional elasticities. */
	if "`em'"  == "" local em  "em"
	if "`eop'" == "" local eop "eop"
	if "`ep'"  == "" local ep  "ep"

	marksample touse, novarlist
	quietly count if `touse'
	if r(N) == 0 error 2000
	local nobs = r(N)

	local wgt ""
	if "`weight'" != "" local wgt "[aw`exp']"

	/* ---------------- assemble the list to summarise ------------------ */
	local vars ""
	local nms  ""
	foreach v of local extra {
		local vars `vars' `v'
		local nms  `nms'  `v'
	}
	forvalues i = 1/`n' {
		local vars `vars' `em'`i'
		local nms  `nms'  em_`i'
	}
	forvalues i = 1/`n' {
		local vars `vars' `eop'`i'
		local nms  `nms'  eop_`i'
	}
	if "`cross'" != "" {
		forvalues i = 1/`n' {
			forvalues j = 1/`n' {
				local vars `vars' `ep'`i'_`j'
				local nms  `nms'  ep_`i'_`j'
			}
		}
	}

	local k : word count `vars'
	foreach v of local vars {
		capture confirm numeric variable `v'
		if _rc {
			di as err "`v' not found - check ngoods(), em(), eop()" ///
			   + cond("`cross'"!="", " and ep()", "")
			exit 111
		}
	}

	/* ---------------- summarise --------------------------------------- *
	 * Every element must be non-missing: bootstrap discards a replication
	 * whose e(b) has a missing entry, and silently doing so would bias the
	 * result.  A cleaned elasticity that is missing for every household in
	 * a replication is the likely cause.
	 * ------------------------------------------------------------------ */
	tempname b
	matrix `b' = J(1, `k', .)
	local c = 0
	local badlist ""
	foreach v of local vars {
		local ++c
		if "`statistic'" == "mean" {
			quietly summarize `v' `wgt' if `touse'
			matrix `b'[1, `c'] = r(mean)
		}
		else {
			quietly count if `touse' & `v' < .
			if r(N) > 0 {
				quietly _pctile `v' `wgt' if `touse', p(50)
				matrix `b'[1, `c'] = r(r1)
			}
		}
		if `b'[1, `c'] >= . {
			local nm : word `c' of `nms'
			local badlist `badlist' `nm'
		}
	}
	if "`badlist'" != "" {
		di as err "ifpripost: no non-missing values for:`badlist'"
		exit 498
	}

	matrix colnames `b' = `nms'

	tempvar esamp
	quietly gen byte `esamp' = `touse'
	ereturn post `b', esample(`esamp') obs(`nobs')

	ereturn local cmd       "ifpripost"
	ereturn local cmd2      "ifpripost"
	ereturn local statistic "`statistic'"
	ereturn scalar ngoods   = `n'
	ereturn scalar k        = `k'

	if "`summary'" != "nosummary" {
		di ""
		di as txt "Elasticity summaries posted as e(b) ("            ///
		   as res "`statistic'" as txt ", " as res `k'               ///
		   as txt " quantities, " as res `nobs' as txt " obs)"
		ereturn display
	}
end
