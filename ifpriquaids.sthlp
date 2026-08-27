{smcl}
{* *! version 1.1.0  24aug2026}{...}
{vieweralsosee "[R] nlsur" "help nlsur"}{...}
{viewerjumpto "Syntax" "ifpriquaids##syntax"}{...}
{viewerjumpto "Description" "ifpriquaids##description"}{...}
{viewerjumpto "Options" "ifpriquaids##options"}{...}
{viewerjumpto "Model" "ifpriquaids##model"}{...}
{viewerjumpto "Remarks" "ifpriquaids##remarks"}{...}
{viewerjumpto "Examples" "ifpriquaids##examples"}{...}
{viewerjumpto "Stored results" "ifpriquaids##results"}{...}
{title:Title}

{phang}
{bf:ifpriquaids} {hline 2} Censored QUAIDS demand system, Shonkwiler-Yen
two-step, with homogeneity and symmetry imposed and adding-up relaxed


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:ifpriquaids} {it:shares} {ifin} {weight}{cmd:,}
{cmdab:cdf(}{it:varlist}{cmd:)}
{cmdab:pdf(}{it:varlist}{cmd:)}
[{it:options}]

{pstd}
{it:shares} is a {it:varlist} of n budget-share variables, one per good.
Zero shares are the censored observations.

{synoptset 32 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{cmdab:cdf(}{it:varlist}{cmd:)}}n variables holding the standard normal
{bf:cdf} evaluated at the first-stage probit index, one per share{p_end}
{synopt:{cmdab:pdf(}{it:varlist}{cmd:)}}n variables holding the standard normal
{bf:pdf} evaluated at the first-stage probit index, one per share{p_end}

{syntab:Prices (specify one)}
{synopt:{cmdab:lnpr:ices(}{it:varlist}{cmd:)}}n log-price variables{p_end}
{synopt:{cmdab:pr:ices(}{it:varlist}{cmd:)}}n price variables in levels; logs are
taken internally{p_end}

{syntab:Expenditure (specify one)}
{synopt:{cmdab:lnexp:enditure(}{it:varname}{cmd:)}}log of total expenditure{p_end}
{synopt:{cmdab:exp:enditure(}{it:varname}{cmd:)}}total expenditure in levels; the
log is taken internally{p_end}

{syntab:Model}
{synopt:{cmdab:demo:graphics(}{it:varlist}{cmd:)}}demographic/other shifters
entering every share equation{p_end}
{synopt:{cmd:anot(}{it:#}|{it:varname}{cmd:)}}value of a0 in the translog price
index; default {cmd:anot(0)}{p_end}
{synopt:{cmdab:noqu:adratic}}fit an AIDS rather than a QUAIDS (drop the lambda
terms){p_end}
{synopt:{cmdab:add:ingup}}impose the adding-up restrictions on the latent
system{p_end}
{synopt:{cmdab:nosy:correction(}{it:varlist}{cmd:)}}omit the Shonkwiler-Yen
correction term for these goods entirely{p_end}

{syntab:Estimation}
{synopt:{cmdab:init:ial(}{it:matname}{cmd:)}}initial values, passed to {cmd:nlsur}{p_end}
{synopt:{cmd:fgnls}}two-step FGNLS estimator; {bf:the default}{p_end}
{synopt:{cmd:ifgnls}}iterative FGNLS estimator{p_end}
{synopt:{cmd:nls}}nonlinear least-squares estimator{p_end}
{synopt:{it:nlsur_options}}{cmd:vce()}, {cmd:nolog}, {cmd:trace},
{cmd:iterate()}, {cmd:eps()}, {cmd:delta()}, {cmd:level()}, {cmd:title()},
{cmd:ifgnlsiterate()}, {cmd:ifgnlseps()}; all passed through to {helpb nlsur}{p_end}

{syntab:Reporting}
{synopt:{cmdab:coefv:ars}}create constant variables holding the point estimates
({cmd:a}{it:i}, {cmd:g}{it:i}{cmd:_}{it:j}, {cmd:b}{it:i}, {cmd:l}{it:i},
{cmd:d}{it:i}{cmd:_}{it:t}, {cmd:dp}{it:i}){p_end}
{synopt:{cmdab:pre:fix(}{it:name}{cmd:)}}prefix for the variables created by
{cmd:coefvars}{p_end}
{synoptline}
{p2colreset}{...}
{p 4 6 2}{cmd:aweight}s, {cmd:fweight}s, {cmd:pweight}s and {cmd:iweight}s are
allowed; see {help weight}.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:ifpriquaids} fits a censored Quadratic Almost Ideal Demand System (QUAIDS)
by the Shonkwiler-Yen (1999) two-step procedure, for an arbitrary number of
goods n and an arbitrary number of demographic shifters.

{pstd}
{bf:The first-stage probits are not run by this command.} You estimate them
yourself, one per good, and pass the resulting standard normal cdf and pdf,
evaluated at the fitted probit index, through {cmd:cdf()} and {cmd:pdf()}.
This is deliberate: it keeps the choice of first-stage specification,
exclusion restrictions and sample entirely under your control, and it lets you
inspect and reuse the first stage. It is the main difference from
{cmd:quaidsce}, which runs the probit internally.

{pstd}
Because the two stages are separate, the reported standard errors are
{bf:conditional on the first stage} and do not account for the fact that the
cdf and pdf are generated regressors. Bootstrap the two steps jointly if you
need correct inference; see {it:Remarks}.

{pstd}
{cmd:ifpriquaids} is a wrapper around {helpb nlsur}'s function-evaluator
method. The evaluator is {cmd:nlsurifpriquaids.ado}, which must be on the
ado-path.


{marker model}{...}
{title:Model}

{pstd}
The estimated share equation for good i is

{p 8 8 2}
w_i = Phi_i * [ alpha_i + sum_j gamma_ij ln p_j + beta_i (ln m - ln a(p))
+ lambda_i / b(p) * (ln m - ln a(p))^2 + sum_t delta_it z_t ] + deltapdf_i * phi_i

{pstd}
where Phi_i and phi_i are the cdf and pdf supplied in {cmd:cdf()} and
{cmd:pdf()},

{p 8 8 2}
ln a(p) = a0 + sum_i alpha_i ln p_i + 0.5 sum_i sum_j gamma_ij ln p_i ln p_j

{p 8 8 2}
ln b(p) = sum_i beta_i ln p_i

{pstd}
{bf:Restrictions.} Homogeneity (sum_j gamma_ij = 0 for every i) and Slutsky
symmetry (gamma_ij = gamma_ji) are imposed by construction, not by constrained
optimisation. The free gamma parameters are the upper triangle, including the
diagonal, of the leading (n-1) x (n-1) block: n(n-1)/2 parameters. The
remaining row and column are derived. {bf:Adding-up is relaxed by default}: all
n share equations are estimated and alpha_i, beta_i and lambda_i are all free.
This is the usual choice under Shonkwiler-Yen censoring, where the fitted
shares are not constrained to sum to one. {cmd:addingup} imposes it on the
latent system; see the option and {it:Remarks}.

{pstd}
The parameter count is
n + n(n-1)/2 + n + n + n*K + n,
dropping the third term under {cmd:noquadratic}, one from the last term for
each good named in {cmd:nosycorrection()}, and a further 3 + K under
{cmd:addingup}, where K is the number of demographics. With n = 15 and K = 1
this is 180, or 176 with {cmd:addingup}.


{marker options}{...}
{title:Options}

{phang}
{cmd:cdf(}{it:varlist}{cmd:)} and {cmd:pdf(}{it:varlist}{cmd:)} supply, for each
good, the standard normal cdf and pdf evaluated at the first-stage probit
index. Both must contain exactly n variables, listed in the same order as
{it:shares}. Typically built as in the example below with
{cmd:predict, xb}, {cmd:normal()} and {cmd:normalden()}.

{phang}
{cmd:lnprices(}{it:varlist}{cmd:)} / {cmd:prices(}{it:varlist}{cmd:)} supply the
n prices, in logs or in levels. Exactly one must be given, with exactly n
variables in the same order as {it:shares}.

{phang}
{cmd:lnexpenditure(}{it:varname}{cmd:)} / {cmd:expenditure(}{it:varname}{cmd:)}
supply total expenditure, in logs or in levels. Exactly one must be given.

{phang}
{cmd:demographics(}{it:varlist}{cmd:)} adds K shifters to every share equation,
inside the cdf-scaled bracket, with a separate coefficient per equation
(n*K parameters). May be omitted.

{phang}
{cmd:anot(}{it:#}|{it:varname}{cmd:)} sets a0 in the translog price index.
A number or a variable name is accepted; a variable lets a0 vary across
observations, as in the original do-file. a0 is not estimated. The
conventional choice is a value slightly below the smallest ln m in the sample.
The default, {cmd:anot(0)}, is rarely what you want.

{phang}
{cmd:noquadratic} drops the lambda terms, reducing the model to a censored
AIDS.

{phang}
{cmd:addingup} imposes sum_i alpha_i = 1, sum_i beta_i = 0,
sum_i lambda_i = 0 and sum_i delta_it = 0 for each demographic, by dropping
the n-th parameter of each block and deriving it. That is 3 + K fewer
parameters. {bf:The gamma block is unchanged}: adding-up requires the column
sums of gamma to be zero, and the symmetry and homogeneity already imposed
deliver that for free, since sum_i gamma_ij = sum_i gamma_ji = row sum j = 0.
{cmd:deltapdf} is left free, having no counterpart in the latent system.

{pmore}
{bf:What this does and does not buy.} The restrictions apply to the {it:latent}
shares. The fitted shares are Phi_i w*_i + deltapdf_i phi_i and still do not sum
to one - that is inherent to Shonkwiler-Yen and no option can change it. So
{cmd:addingup} gives a theoretically coherent latent demand system, not
adding-up in the data.

{pmore}
{bf:It also makes the error covariance matrix worse conditioned}, because it
pushes the fitted shares closer to summing to one, tightening the near-linear
dependence among the n residuals. If every good is uncensored the dependence is
exact, the covariance matrix is singular, and the command refuses with an
explanatory error rather than letting {cmd:nlsur} fail obscurely. With real
censoring it will run, but expect convergence to be harder rather than easier,
particularly under {cmd:ifgnls}.

{phang}
{cmd:nosycorrection(}{it:varlist}{cmd:)} names goods, by their share variables,
whose Shonkwiler-Yen term is to be {bf:removed from the model} rather than
estimated. No {cmd:deltapdf} parameter is created for them, so they do not
appear in {cmd:e(b)} and the parameter count falls by one per good; the
corresponding entry of {cmd:e(deltapdf)} is 0. Use it for goods consumed by
every household, where the term is unidentified anyway (see {it:Remarks}). The
point estimates are the same either way, but omitting removes a flat direction
from the optimisation instead of leaving {cmd:nlsur} to detect and constrain
it, which is worth doing when diagnosing convergence trouble. If a named good's
pdf is {it:not} identically zero, the command says so: there you are imposing a
real, testable restriction rather than tidying up bookkeeping.

{phang}
{cmd:coefvars} creates constant variables holding the point estimates, named
{cmd:a}{it:i}, {cmd:g}{it:i}{cmd:_}{it:j} (the full n x n gamma matrix,
including the derived row and column), {cmd:b}{it:i}, {cmd:l}{it:i},
{cmd:d}{it:i}{cmd:_}{it:t} and {cmd:dp}{it:i}. This reproduces what the
original 15-good do-file did with {cmd:svmat} and is intended for do-files
already written around those names. The command refuses to overwrite existing
variables. {cmd:prefix()} prefixes all of them. The same numbers are available
without touching the data in {cmd:e(alpha)}, {cmd:e(gamma)}, and so on.

{phang}
{it:nlsur_options} are passed straight through. In particular {cmd:vce(robust)}
and {cmd:ifgnls} reproduce the settings of the original do-file.

{phang}
{cmd:fgnls}, {cmd:ifgnls} and {cmd:nls} choose the estimator. {cmd:fgnls}, the
two-step non-iterated estimator, is the {helpb nlsur} default: {bf:omitting}
{cmd:ifgnls} gives you two-step FGNLS, and specifying {cmd:fgnls} explicitly is
equivalent. {cmd:ifgnls} iterates the FGNLS step to convergence and is
equivalent to maximum likelihood under joint normality. Note that the output
table is headed "FGNLS regression" under both; check {cmd:e(method)}, which is
{cmd:fgnls}, {cmd:ifgnls} or {cmd:nls}, or watch for the "FGNLS iteration"
lines in the log. {cmd:ifgnlsiterate()} and {cmd:ifgnlseps()} control that
outer loop and require {cmd:ifgnls} to be specified as well. There is no
{cmd:sure} or {cmd:isure} option in {cmd:nlsur}.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Ordering.} {it:shares}, {cmd:lnprices()}, {cmd:cdf()} and {cmd:pdf()} must
list variables for the goods in the same order. Beware of {it:var1}-{it:var15}
range notation: it selects variables by their position in the dataset, not by
their names, so it can silently pick up unrelated variables. Prefer explicit
lists, or check with {cmd:ds}.

{pstd}
{bf:Which good is "last".} Homogeneity is used to derive the gamma terms for
the n-th good in {it:shares}. The fitted model is invariant to that choice, but
the free-parameter list, and hence the reported gamma standard errors, is not.
Parameters for the derived row and column do not appear in {cmd:e(b)}; use
{cmd:nlcom} if you need standard errors for them.

{pstd}
{bf:Goods consumed by every household.} Such a good has no first-stage probit
to run. Set its cdf to 1 and its pdf to 0: the correction term vanishes and its
equation collapses to the uncensored QUAIDS form, which is the correct
treatment. Its Shonkwiler-Yen coefficient then multiplies an identically-zero
variable and is exactly unidentified. Two ways to proceed:

{phang2}
(a) Do nothing. {cmd:nlsur} detects the collinearity, retains the parameter in
{cmd:e(b)} as a zero and reports it as {cmd:(constrained)}.
{cmd:ifpriquaids} checks for this before estimation and prints a note naming
the affected goods, so it is not missed in a long coefficient table.

{phang2}
(b) Name those goods in {cmd:nosycorrection()}. The parameter is then never
created. Point estimates are identical to (a) - verified to 1.9e-07 in testing
- but the flat direction is gone from the optimisation rather than being
detected and pinned after the fact.

{pstd}
{bf:Watch for divergence under} {cmd:ifgnls}{bf:.} Flat directions can prevent
the outer FGNLS loop from having a stable fixed point. It may then run to the
{cmd:ifgnlsiterate()} cap and {bf:report estimates from a diverged point without
an error message}. Always check {cmd:e(converged)}, and compare the equation
R-squareds against an {cmd:fgnls} fit: negative R-squareds are the tell.
{cmd:fgnls} estimates remain consistent, so reporting them is a defensible
answer when the iterated version will not settle. Raising
{cmd:ifgnlsiterate()} makes a diverging loop worse, not better, and warm-
starting through {cmd:initial()} does not help either: {cmd:ifgnls} iterates a
fixed point on (parameters, Sigma-hat), so round 1 lands on the {cmd:fgnls}
answer whatever the starting values.

{pstd}
{bf:Inference.} Standard errors are conditional on the first-stage probits.
To account for the generated regressors, wrap both steps in a bootstrap: put
the probit loop and the {cmd:ifpriquaids} call in one program and
{cmd:bootstrap} that program.

{pstd}
{bf:Starting values and speed.} {cmd:nlsur} starts from zeros unless
{cmd:initial()} is given, and computes derivatives numerically, so the cost
grows quickly with the parameter count. On a simulated 15-good, 1-demographic,
4,000-observation problem (180 parameters) estimation took roughly 8 minutes.
If convergence is slow, fit a smaller or {cmd:noquadratic} model first and feed
{cmd:e(b)} back in through {cmd:initial()}.

{pstd}
{bf:Postestimation.} {cmd:e(cmd)} is deliberately left as {cmd:nlsur}, so
{cmd:test}, {cmd:nlcom}, {cmd:estimates} and the usual reporting tools all work
as they do after {cmd:nlsur}. {cmd:e(cmd2)} identifies the wrapper. Typing
{cmd:ifpriquaids} alone replays the results.

{pstd}
{cmd:predict} {it:newvar}{cmd:, equation(#}{it:i}{cmd:)} returns the fitted
share for good i, that is Phi_i * [...] + deltapdf_i * phi_i, the unconditional
expected share under the Shonkwiler-Yen specification. Equations are numbered,
not named: use {cmd:equation(#1)} for the first share. Because the fitted
shares are not constrained to add up, they will not sum to one.


{marker examples}{...}
{title:Examples}

{pstd}First stage: one probit per good, then the cdf and pdf{p_end}
{phang2}{cmd:. forvalues i = 1/5 {c -(}}{p_end}
{phang2}{cmd:.     generate byte buy`i' = w`i' > 0}{p_end}
{phang2}{cmd:.     probit buy`i' lnp1-lnp5 lnm hhsize urban}{p_end}
{phang2}{cmd:.     predict double xb`i', xb}{p_end}
{phang2}{cmd:.     generate double cdf`i' = normal(xb`i')}{p_end}
{phang2}{cmd:.     generate double pdf`i' = normalden(xb`i')}{p_end}
{phang2}{cmd:. {c )-}}{p_end}

{pstd}Second stage{p_end}
{phang2}{cmd:. ifpriquaids w1 w2 w3 w4 w5 [aw=hhwt],}{break}
{cmd:    lnprices(lnp1 lnp2 lnp3 lnp4 lnp5) lnexpenditure(lnm)}{break}
{cmd:    cdf(cdf1 cdf2 cdf3 cdf4 cdf5) pdf(pdf1 pdf2 pdf3 pdf4 pdf5)}{break}
{cmd:    demographics(hhsize) anot(2) vce(robust) ifgnls}{p_end}

{pstd}The same model with 15 goods differs only in the variable lists{p_end}
{phang2}{cmd:. ifpriquaids w1-w15 [aw=hhwt], lnprices(lnp1-lnp15) lnexpenditure(lnm)}{break}
{cmd:    cdf(cdf1-cdf15) pdf(pdf1-pdf15) demographics(z1) anot(a0)}{break}
{cmd:    vce(robust) ifgnls}{p_end}

{pstd}Goods 4 and 13 are consumed by every household: their cdf is set to 1 and
pdf to 0, and their correction term is dropped from the model{p_end}
{phang2}{cmd:. ifpriquaids w1-w15 [aw=hhwt], lnprices(lnp1-lnp15) lnexpenditure(lnm)}{break}
{cmd:    cdf(cdf1-cdf15) pdf(pdf1-pdf15) demographics(z1) anot(a0)}{break}
{cmd:    nosycorrection(w4 w13) vce(robust)}{p_end}

{pstd}Inspect the parameters{p_end}
{phang2}{cmd:. matrix list e(gamma)}{p_end}
{phang2}{cmd:. matrix list e(alpha)}{p_end}
{phang2}{cmd:. matrix list e(deltapdf)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:ifpriquaids} adds the following to what {helpb nlsur} stores.

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:e(ngoods)}}number of goods n{p_end}
{synopt:{cmd:e(ndemos)}}number of demographics K{p_end}
{synopt:{cmd:e(nparam)}}number of free parameters{p_end}
{synopt:{cmd:e(nnosy)}}number of goods with the SY correction omitted{p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:e(cmd2)}}{cmd:ifpriquaids}{p_end}
{synopt:{cmd:e(cmdline)}}command as typed{p_end}
{synopt:{cmd:e(title2)}}title{p_end}
{synopt:{cmd:e(shares)}}share variables{p_end}
{synopt:{cmd:e(lnprices)}}log-price variables used{p_end}
{synopt:{cmd:e(prices)}}price variables, if {cmd:prices()} was used{p_end}
{synopt:{cmd:e(lnexpenditure)}}log-expenditure variable used{p_end}
{synopt:{cmd:e(expenditure)}}expenditure variable, if {cmd:expenditure()} was used{p_end}
{synopt:{cmd:e(cdfvars)}}cdf variables{p_end}
{synopt:{cmd:e(pdfvars)}}pdf variables{p_end}
{synopt:{cmd:e(demographics)}}demographic variables{p_end}
{synopt:{cmd:e(anot)}}a0 as specified{p_end}
{synopt:{cmd:e(quadratic)}}{cmd:yes} or {cmd:no}{p_end}
{synopt:{cmd:e(nosycorrection)}}goods with the SY correction omitted{p_end}
{synopt:{cmd:e(nosyindex)}}their positions in {cmd:e(shares)}{p_end}
{synopt:{cmd:e(homogeneity)}}{cmd:imposed}{p_end}
{synopt:{cmd:e(symmetry)}}{cmd:imposed}{p_end}
{synopt:{cmd:e(addingup)}}{cmd:imposed} or {cmd:relaxed}{p_end}

{p2col 5 22 26 2: Matrices}{p_end}
{synopt:{cmd:e(alpha)}}1 x n vector of alpha{p_end}
{synopt:{cmd:e(beta)}}1 x n vector of beta{p_end}
{synopt:{cmd:e(gamma)}}full n x n gamma matrix, symmetric with zero row sums{p_end}
{synopt:{cmd:e(lambda)}}1 x n vector of lambda (absent under {cmd:noquadratic}){p_end}
{synopt:{cmd:e(delta)}}n x K matrix of demographic coefficients (absent if K = 0){p_end}
{synopt:{cmd:e(deltapdf)}}1 x n vector of coefficients on the pdf terms; 0 for
goods named in {cmd:nosycorrection()}{p_end}
{p2colreset}{...}


{title:References}

{phang}
Banks, J., R. Blundell, and A. Lewbel. 1997. Quadratic Engel curves and
consumer demand. {it:Review of Economics and Statistics} 79: 527-539.

{phang}
Poi, B. P. 2012. Easy demand-system estimation with quaids.
{it:Stata Journal} 12: 433-446.

{phang}
Shonkwiler, J. S., and S. T. Yen. 1999. Two-step estimation of a censored
system of equations. {it:American Journal of Agricultural Economics}
81: 972-982.


{title:Also see}

{psee}
Help: {manhelp nlsur R}, {helpb quaids}, {helpb quaidsce}
{p_end}
