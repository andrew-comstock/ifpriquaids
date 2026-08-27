{smcl}
{* *! version 1.0.0  25aug2026}{...}
{vieweralsosee "ifpriquaids" "help ifpriquaids"}{...}
{viewerjumpto "Syntax" "ifpriquaidselas##syntax"}{...}
{viewerjumpto "Description" "ifpriquaidselas##description"}{...}
{viewerjumpto "Options" "ifpriquaidselas##options"}{...}
{viewerjumpto "Formulas" "ifpriquaidselas##formulas"}{...}
{viewerjumpto "Differences from 04_postestimation_clean.do" "ifpriquaidselas##legacy"}{...}
{viewerjumpto "Remarks" "ifpriquaidselas##remarks"}{...}
{viewerjumpto "Examples" "ifpriquaidselas##examples"}{...}
{viewerjumpto "Stored results" "ifpriquaidselas##results"}{...}
{title:Title}

{phang}
{bf:ifpriquaidselas} {hline 2} Observation-level conditional elasticities after
{helpb ifpriquaids}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:ifpriquaidselas} {ifin} [{cmd:,} {it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Naming}
{synopt:{cmdab:pre:fix(}{it:name}{cmd:)}}prefix for every variable created{p_end}
{synopt:{cmd:replace}}drop and recreate variables that already exist{p_end}

{syntab:Model}
{synopt:{cmdab:priceg:roup(}{it:varname}{cmd:)}}use within-group mean log prices
in d ln a(p)/d ln p{p_end}
{synopt:{cmdab:leg:acy}}reproduce {cmd:04_postestimation_clean.do} exactly,
including two formula errors; see {it:Differences}{p_end}

{syntab:Cleaning}
{synopt:{cmdab:iqr:clean(}{it:#}{cmd:)}}set elasticities outside
p25 - #*IQR .. p75 + #*IQR to missing{p_end}
{synopt:{cmdab:sd:clean(}{it:#}{cmd:)}}set elasticities outside
mean +/- #*SD to missing{p_end}

{syntab:Reporting}
{synopt:{cmdab:nosum:mary}}suppress the summary table{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:ifpriquaidselas} computes, for every observation in {cmd:e(sample)}, the
conditional expenditure, Marshallian (uncompensated) and Hicksian
(compensated) price elasticities implied by the last {helpb ifpriquaids} fit,
together with the latent budget shares they are built from. It is flexible in
the number of goods: everything is read from {cmd:e()}.

{pstd}
Variables created, where n is the number of goods and {it:i}, {it:j} index
goods in the order given by {cmd:e(shares)}:

{p2colset 8 24 26 2}{...}
{p2col:{cmd:cw}{it:i}}latent (SY expected) budget share for good {it:i}{p_end}
{p2col:{cmd:em_}{it:i}}conditional expenditure elasticity{p_end}
{p2col:{cmd:epm_}{it:i}{cmd:_}{it:j}}conditional Marshallian price elasticity{p_end}
{p2col:{cmd:eph_}{it:i}{cmd:_}{it:j}}conditional Hicksian price elasticity{p_end}
{p2colreset}{...}

{pstd}
That is 2n + 2n^2 variables: 480 for a 15-good system. All are labelled with
the share variable they refer to. {cmd:prefix()} renames them all.

{pstd}
The latent shares {cmd:cw}{it:i} are kept as output, not as intermediates.
They are identical to what {cmd:predict} {it:newvar}{cmd:, equation(#}{it:i}{cmd:)}
returns after {cmd:ifpriquaids} (verified to machine precision), and they are
the denominator of every elasticity below.


{marker formulas}{...}
{title:Formulas}

{pstd}
Write w*_i for the uncensored share, Phi_i and phi_i for the first-stage cdf
and pdf, ln a(p) for the translog price index and b(p) for the Cobb-Douglas
price aggregator:

{p 8 8 2}
cw_i = Phi_i * w*_i + deltapdf_i * phi_i

{p 8 8 2}
mu_i = d w*_i / d ln m = beta_i + (2 lambda_i / b(p)) (ln m - ln a(p))

{p 8 8 2}
d cw_i / d ln m = Phi_i * mu_i

{p 8 8 2}
d cw_i / d ln p_j = Phi_i * [ gamma_ij - mu_i * dA_j
- (lambda_i beta_j / b(p)) (ln m - ln a(p))^2 ]

{pstd}
where dA_j = d ln a(p) / d ln p_j = alpha_j + sum_k gamma_jk ln p_k. The
elasticities are then

{p 8 8 2}
e_i     = (d cw_i / d ln m) / cw_i + 1

{p 8 8 2}
e^m_ij  = (d cw_i / d ln p_j) / cw_i - kronecker(i,j)

{p 8 8 2}
e^h_ij  = e^m_ij + e_i * cw_j        (Slutsky)

{pstd}
Phi_i and phi_i are held fixed: these are elasticities conditional on the
first stage, and they do not include the participation margin.

{pstd}
The price and expenditure derivatives were verified against numerical
differentiation of {cmd:cw}{it:i} (agreement to about 1e-08, the limit of a
forward difference), and the Slutsky step against Hicksian homogeneity,
sum_j e^h_ij = 0, in an uncensored system whose shares sum to one (agreement
to about 1e-08).


{marker legacy}{...}
{title:Differences from 04_postestimation_clean.do}

{pstd}
{cmd:ifpriquaidselas} follows the reference do-file except in two places,
where the reference appears to be wrong. {bf:Both change the reported
numbers.} {cmd:legacy} restores the reference behaviour exactly, so the two
can be compared on real data.

{pstd}
{bf:1. The Slutsky equation.} The reference computes

{p 12 12 2}
{cmd:eph_i_j = (y_i_j / cw_i) - (em_i * cw_i)}

{pstd}
which is e^m_ij {bf:-} e_i w{bf:_i}. The Slutsky equation is e^m_ij {bf:+}
e_i w{bf:_j}: the sign is reversed and the share is indexed by {it:i} rather
than {it:j}. The consequence is that Hicksian homogeneity fails. In a test
system whose shares sum to one, mean |sum_j e^h_ij| was 9e-09 under the
corrected formula and 2.00 under the reference one. On censored test data the
median own-price Hicksian elasticities moved from about -0.65 to about -1.21,
which is the difference between an inelastic and an elastic good.

{pstd}
{bf:2. An extra Phi in the price derivative.} The reference builds

{p 12 12 2}
{cmd:y_i_j = cdf_i * (g_ij - y_i * dA_j - ...)}

{pstd}
substituting {cmd:y_i} = Phi_i * mu_i where the chain rule calls for the
unscaled mu_i, so the middle term carries Phi_i^2 instead of Phi_i. This is
exact when Phi_i = 1 and biased for every censored good. It is much the
smaller of the two: on test data with participation around 0.86 the median
own-price Marshallian elasticities moved by 0.002 to 0.010.

{pstd}
Expenditure elasticities are unaffected by both: {cmd:em_}{it:i} is identical
under {cmd:legacy}.

{pstd}
The reference also takes within-{cmd:area} mean log prices in dA_j. That is
not an error, just a choice, and it is available through
{cmd:pricegroup()}. To reproduce the reference exactly, use
{cmd:legacy pricegroup(area) iqrclean(1.5)}.


{marker options}{...}
{title:Options}

{phang}
{cmd:prefix(}{it:name}{cmd:)} prefixes every created variable, so several
variants can coexist. {cmd:replace} drops any of the target variables that
already exist before recreating them; without it, the command refuses to
overwrite and exits with error 110.

{phang}
{cmd:pricegroup(}{it:varname}{cmd:)} replaces each household's own log price
with the mean log price within groups of {it:varname} when forming
d ln a(p)/d ln p_j, reproducing the {cmd:bysort area: egen mean} of the
reference do-file. If prices are already constant within the group the two
coincide. Everything else still uses the household's own prices.

{phang}
{cmd:iqrclean(}{it:#}{cmd:)} and {cmd:sdclean(}{it:#}{cmd:)} set outlying
elasticities to missing; specify at most one. {cmd:iqrclean(1.5)} is the rule
used in the reference do-file. Cleaning is applied to {cmd:em_*},
{cmd:epm_*} and {cmd:eph_*}, each variable independently, over the estimation
sample. {bf:The latent shares are never cleaned.} The total number of values
set to missing is reported and returned in {cmd:r(ncleaned)}. There is no
cleaning unless you ask for it.

{phang}
{cmd:legacy} reproduces {cmd:04_postestimation_clean.do}, including both
formula errors described above. Use it to compare against previously
circulated results, not to produce new ones.

{phang}
{cmd:nosummary} suppresses the table of median elasticities. The {cmd:r()}
matrices are returned either way.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Cleaning is destructive.} Values are set to missing in place, so a later
{cmd:iqrclean()} run on already-cleaned variables would clean the cleaned
distribution. Always re-run with {cmd:replace}, which rebuilds from the
estimates, rather than cleaning twice.

{pstd}
{bf:Elasticities at the median.} The command produces observation-level
elasticities; the {cmd:r()} matrices summarise them by median and by mean over
the estimation sample, using the estimation weights if any were specified.
Report the median if that is your convention - the mean of a ratio with a
small denominator is easily dominated by a handful of households with tiny
latent shares, which is also why the cleaning options exist.

{pstd}
{bf:Standard errors.} None are produced. The elasticities are nonlinear
functions of the estimates and of the first-stage cdf and pdf, so their
sampling variability comes from both stages. Bootstrapping the whole
pipeline - probits, {cmd:ifpriquaids}, {cmd:ifpriquaidselas} - is the
defensible route.

{pstd}
{bf:Sample.} Computation is restricted to {cmd:e(sample)}; {cmd:if} and
{cmd:in} narrow it further. Variables are missing outside it.

{pstd}
{bf:Adding-up.} {cmd:ifpriquaids} relaxes adding-up, so the latent shares are
not constrained to sum to one. Where they do not, the Hicksian homogeneity
check sum_j e^h_ij = 0 will not hold exactly; that reflects the estimated
model, not the elasticity code.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. ifpriquaids w1-w15 [aw=hhwt], lnprices(lnp1-lnp15) lnexpenditure(lnm)}{break}
{cmd:    cdf(cdf1-cdf15) pdf(pdf1-pdf15) demographics(z1) anot(a0) vce(robust)}{p_end}

{pstd}Elasticities, no cleaning{p_end}
{phang2}{cmd:. ifpriquaidselas}{p_end}

{pstd}With the reference do-file's 1.5 x IQR cleaning{p_end}
{phang2}{cmd:. ifpriquaidselas, replace iqrclean(1.5)}{p_end}

{pstd}Three standard deviations instead{p_end}
{phang2}{cmd:. ifpriquaidselas, replace sdclean(3)}{p_end}

{pstd}Reproduce the old do-file exactly, for comparison{p_end}
{phang2}{cmd:. ifpriquaidselas, prefix(old) legacy pricegroup(area) iqrclean(1.5)}{p_end}

{pstd}Median elasticity matrices{p_end}
{phang2}{cmd:. matrix list r(eph_median)}{p_end}
{phang2}{cmd:. matrix list r(em_median)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:ifpriquaidselas} is {cmd:r}-class and leaves {cmd:e()} untouched.

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(ngoods)}}number of goods{p_end}
{synopt:{cmd:r(ncleaned)}}values set to missing by cleaning{p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(cleanmethod)}}{cmd:iqr}, {cmd:sd}, or empty{p_end}
{synopt:{cmd:r(prefix)}}prefix used{p_end}

{p2col 5 22 26 2: Matrices}{p_end}
{synopt:{cmd:r(em_median)}}1 x n median expenditure elasticities{p_end}
{synopt:{cmd:r(em_mean)}}1 x n mean expenditure elasticities{p_end}
{synopt:{cmd:r(epm_median)}}n x n median Marshallian elasticities{p_end}
{synopt:{cmd:r(epm_mean)}}n x n mean Marshallian elasticities{p_end}
{synopt:{cmd:r(eph_median)}}n x n median Hicksian elasticities{p_end}
{synopt:{cmd:r(eph_mean)}}n x n mean Hicksian elasticities{p_end}
{p2colreset}{...}


{title:Also see}

{psee}
Help: {helpb ifpriquaids}, {manhelp nlsur R}
{p_end}
