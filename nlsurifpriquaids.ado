*! version 2.0.0  25aug2026
*! function-evaluator program used by -ifpriquaids-
*! Censored QUAIDS, Shonkwiler-Yen two-step, homogeneity + symmetry imposed,
*! adding-up relaxed.  Flexible in the number of goods and demographics.
*!
*! v2: the fitted shares are computed in Mata from data cached on the first
*! call of an estimation, rather than by -generate-/-replace- over long
*! expression strings.  Measured about 10x faster per call at 15 goods and
*! 4,000 observations, and identical to the v1 result to ~1e-15.
*!
*! The option lists are taken as -string- deliberately: -syntax- would
*! otherwise re-validate 40-plus variables on every one of the thousands of
*! calls nlsur makes.  ifpriquaids validates them once, up front.

program nlsurifpriquaids
	version 14.0

	syntax varlist [aweight fweight pweight iweight] [if],               ///
		at(name)                                                         ///
		[ LNPrices(string)                                               ///
		  LNEXPenditure(string)                                          ///
		  CDFVars(string)                                                ///
		  PDFVars(string)                                                ///
		  ANOT(string)                                                   ///
		  DEMOgraphics(string)                                           ///
		  noQUADratic                                                    ///
		  ADDingup                                                       ///
		  NOSYindex(string) ]

	/* ------------------------------------------------------------------ *
	 * -ifpriquaids- always supplies lnprices().  -predict- (nlsur_p)
	 * re-calls this program with at() only, so recover the rest from e().
	 * ------------------------------------------------------------------ */
	local nocache = 0
	if `"`lnprices'"' == "" {
		if "`e(cmd2)'" != "ifpriquaids" {
			di as err "nlsurifpriquaids: lnprices() required"
			exit 198
		}
		* Reached only from -predict- (nlsur_p).  nlsur_p recreates the
		* variables it hands us between equations, and Stata reuses tempvar
		* names, so a cache keyed on names alone can match while its views
		* point at variables that have since been dropped.  Rebuild every
		* call on this path: predict runs a handful of times, so the cost
		* is irrelevant and correctness is not negotiable.
		local nocache = 1
		local lnexpenditure "`e(lnexpenditure)'"
		local cdfvars       "`e(cdfvars)'"
		local pdfvars       "`e(pdfvars)'"
		local demographics  "`e(demographics)'"
		local anot          "`e(anot)'"
		local nosyindex     "`e(nosyindex)'"
		if "`e(quadratic)'" == "no" local quadratic "noquadratic"
		if "`e(addingup)'" == "imposed" local addingup "addingup"

		* If the user gave prices()/expenditure() in levels, the logs were
		* built in tempvars that no longer exist; rebuild them here.
		local plevels "`e(prices)'"
		if "`plevels'" != "" {
			foreach v of local plevels {
				tempvar lv
				quietly gen double `lv' = ln(`v')
				local lnprices `lnprices' `lv'
			}
		}
		else	local lnprices "`e(lnprices)'"
		local mlevel "`e(expenditure)'"
		if "`mlevel'" != "" {
			tempvar lm
			quietly gen double `lm' = ln(`mlevel')
			local lnexpenditure `lm'
		}
	}

	if "`anot'" == "" local anot 0
	local qd = ("`quadratic'" != "noquadratic")
	local au = ("`addingup'" != "")

	* nlsur passes "if <its own touse variable>"; use it rather than
	* generating another one on every call
	gettoken ifword tvname : if
	local tv = trim("`tvname'")

	mata: ifq_run("`at'", "`varlist'", "`lnprices'", "`lnexpenditure'",  ///
	              "`cdfvars'", "`pdfvars'", "`demographics'",            ///
	              "`anot'", "`tv'", `qd', "`nosyindex'", `au', `nocache')
end


/* ====================================================================== *
 * Mata implementation.  Compiled when this file is first loaded.
 *
 * The right-hand-side data does not change during an estimation, so it is
 * copied into plain Mata matrices once and reused; only the share columns
 * remain a view, because those are what nlsur wants overwritten.  Reading
 * and writing through st_view on every call was the dominant cost.
 *
 * The cache is keyed on a signature built from the variable names, the
 * touse variable and the number of observations.  -ifpriquaids- also
 * clears it either side of the nlsur call, so a later -predict- can never
 * be served stale data.
 * ====================================================================== */

version 14.0

mata:
mata set matastrict off

void ifq_clear()
{
	external string scalar ifq__sig
	ifq__sig = ""
}

void ifq_run(string scalar atname,
             string scalar wv,       // share variables to overwrite
             string scalar pv,       // log prices
             string scalar mv,       // log expenditure
             string scalar cv,       // cdf variables
             string scalar dv,       // pdf variables
             string scalar zv,       // demographics ("" if none)
             string scalar a0spec,   // number or variable name
             string scalar tv,       // touse variable ("" for all)
             real   scalar qd,       // 1 if the quadratic term is present
             string scalar nosy,     // goods with no SY correction term
             real   scalar au,       // 1 if adding-up is imposed
             real   scalar nocache)  // 1 to rebuild the views unconditionally
{
	external string scalar  ifq__sig
	external real matrix    ifqP, ifqC, ifqD, ifqZ, ifqW
	external real colvector ifqm, ifqA0
	external real scalar    ifqk

	real rowvector at, omit
	real matrix    G, XB, Delta, v
	real colvector lnA, dm, alpha, beta, lambda, dp
	real scalar    n, N, i, j, pos, s, nf
	string scalar  sig

	/* ---- (re)build the cache when anything about the call changes ---- */
	sig = wv + "|" + pv + "|" + mv + "|" + cv + "|" + dv + "|" + zv +
	      "|" + a0spec + "|" + tv + "|" + strofreal(st_nobs())

	if (nocache | sig != ifq__sig) {
		st_view(v, ., tokens(pv), tv) ; ifqP = v
		st_view(v, ., tokens(cv), tv) ; ifqC = v
		st_view(v, ., tokens(dv), tv) ; ifqD = v
		st_view(v, ., mv, tv)         ; ifqm = v

		ifqk = 0
		if (zv != "") {
			st_view(v, ., tokens(zv), tv)
			ifqZ = v
			ifqk = cols(ifqZ)
		}
		else ifqZ = J(rows(ifqP), 0, 0)

		if (strtoreal(a0spec) == .) {
			st_view(v, ., a0spec, tv)
			ifqA0 = v
		}
		else ifqA0 = J(rows(ifqP), 1, strtoreal(a0spec))

		st_view(ifqW, ., tokens(wv), tv)

		/* On the predict path never record a valid signature, so the next
		   call cannot be served these views.                            */
		ifq__sig = (nocache ? "" : sig)
	}

	n = cols(ifqP)
	N = rows(ifqP)
	at = st_matrix(atname)

	/* ---- unpack `at' in the order ifpriquaids builds parameters() ---- */
	pos = 0

	/* With adding-up imposed the n-th element of alpha, beta, lambda and
	   of each delta column is derived rather than estimated.  gamma needs
	   no change: symmetry plus zero row sums already give zero column
	   sums.  deltapdf is unrestricted.                                  */
	nf = (au ? n - 1 : n)

	alpha = J(n, 1, 0)
	for (i = 1; i <= nf; i++) alpha[i] = at[++pos]
	if (au) alpha[n] = 1 - sum(alpha[1..n-1])

	/* gamma: free elements are the upper triangle, including the
	   diagonal, of the leading (n-1) x (n-1) block; symmetry imposed
	   here, then homogeneity gives the last row and column            */
	G = J(n, n, 0)
	for (i = 1; i <= n - 1; i++) {
		for (j = i; j <= n - 1; j++) {
			pos++
			G[i, j] = at[pos]
			G[j, i] = at[pos]
		}
	}
	for (i = 1; i <= n - 1; i++) {
		s = sum(G[i, 1..n-1])
		G[i, n] = -s
		G[n, i] = -s
	}
	G[n, n] = -sum(G[n, 1..n-1])

	beta = J(n, 1, 0)
	for (i = 1; i <= nf; i++) beta[i] = at[++pos]
	if (au) beta[n] = -sum(beta[1..n-1])

	lambda = J(n, 1, 0)
	if (qd) {
		for (i = 1; i <= nf; i++) lambda[i] = at[++pos]
		if (au) lambda[n] = -sum(lambda[1..n-1])
	}

	/* delta: demographic t outer, equation i inner */
	Delta = J(n, (ifqk > 0 ? ifqk : 1), 0)
	for (j = 1; j <= ifqk; j++) {
		for (i = 1; i <= nf; i++) Delta[i, j] = at[++pos]
		if (au) Delta[n, j] = -sum(Delta[1..n-1, j])
	}

	/* deltapdf; goods in nosy have no such parameter at all */
	omit = (nosy == "" ? J(1, 0, .) : strtoreal(tokens(nosy)))
	dp = J(n, 1, 0)
	for (i = 1; i <= n; i++) {
		if (!anyof(omit, i)) dp[i] = at[++pos]
	}

	/* ---- ln a(p), then the share equations, all goods at once ------- *
	 *   w_i = Phi_i * [ a_i + sum_j g_ij lnp_j
	 *                   + b_i (lnm - ln a(p))
	 *                   + l_i / b(p) * (lnm - ln a(p))^2
	 *                   + sum_t d_it z_t ]
	 *         + dp_i * phi_i
	 * ----------------------------------------------------------------- */
	lnA = ifqA0 + ifqP * alpha + 0.5 * rowsum((ifqP * G) :* ifqP)
	dm  = ifqm - lnA

	XB = J(N, 1, 1) * alpha' + ifqP * G + dm * beta'
	if (qd) XB = XB + (dm :^ 2 :/ exp(ifqP * beta)) * lambda'
	if (ifqk > 0) XB = XB + ifqZ * Delta'

	ifqW[., .] = ifqC :* XB + ifqD :* (J(N, 1, 1) * dp')
}
end

mata: ifq_clear()
