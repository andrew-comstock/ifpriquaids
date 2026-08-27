*! version 1.0.0  25aug2026
*! _ifpriclean -- shared outlier-cleaning helper for the ifpriquaids package
*!
*! Sets outlying values of one variable to missing, in place, over the
*! observations selected by [if].  Used by both -ifpriquaidselas- and
*! -ifpriwl- so that the two apply an identical rule.
*!
*!   method(iqr)  outside  p25 - f*(p75-p25) .. p75 + f*(p75-p25)
*!   method(sd)   outside  mean -/+ f*sd
*!
*! Returns r(ndropped), r(lo), r(hi).

program _ifpriclean, rclass 
	version 14.0

	syntax varname(numeric) [if], METHod(string) Factor(real)

	if !inlist("`method'", "iqr", "sd") {
		di as err "_ifpriclean: method() must be iqr or sd"
		exit 198
	}
	if `factor' <= 0 {
		di as err "_ifpriclean: factor() must be positive"
		exit 198
	}

	marksample touse, novarlist
	local v `varlist'

	tempvar bad
	quietly {
		if "`method'" == "iqr" {
			summarize `v' if `touse', detail
			local spread = r(p75) - r(p25)
			local lo = r(p25) - `factor'*`spread'
			local hi = r(p75) + `factor'*`spread'
		}
		else {
			summarize `v' if `touse'
			local lo = r(mean) - `factor'*r(sd)
			local hi = r(mean) + `factor'*r(sd)
		}
		gen byte `bad' = `touse' & `v' < . & (`v' < `lo' | `v' > `hi')
		count if `bad'
		local nd = r(N)
		replace `v' = . if `bad'
	}

	return scalar ndropped = `nd'
	return scalar lo = `lo'
	return scalar hi = `hi'
end
