{smcl}
{* *! version 1.0.0  25aug2026}{...}
{vieweralsosee "ifpriquaids" "help ifpriquaids"}{...}
{vieweralsosee "ifpriquaidselas" "help ifpriquaidselas"}{...}
{viewerjumpto "Syntax" "ifpriwl##syntax"}{...}
{viewerjumpto "Description" "ifpriwl##description"}{...}
{viewerjumpto "Options" "ifpriwl##options"}{...}
{viewerjumpto "Validity checks" "ifpriwl##checks"}{...}
{viewerjumpto "Remarks" "ifpriwl##remarks"}{...}
{viewerjumpto "Examples" "ifpriwl##examples"}{...}
{viewerjumpto "Stored results" "ifpriwl##results"}{...}
{title:Title}

{phang}
{bf:ifpriwl} {hline 2} Working-Leser all-food model with observation-level
elasticities


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:ifpriwl} {it:foodshare} {ifin} {weight}{cmd:,}
{cmdab:lnexp:enditure(}{it:varname}{cmd:)}
{cmdab:lnp:rice(}{it:varname}{cmd:)}
[{it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{cmdab:lnexp:enditure(}{it:varname}{cmd:)}}log of total household
expenditure{p_end}
{synopt:{cmdab:lnp:rice(}{it:varname}{cmd:)}}log of the average food price{p_end}

{syntab:Model}
{synopt:{cmdab:cov:ariates(}{it:varlist}{cmd:)}}additional right-hand-side
variables; factor variables allowed{p_end}
{synopt:{it:regress_options}}{cmd:vce()}, {cmd:noconstant}, {cmd:level()} and
so on, passed to {helpb regress}{p_end}

{syntab:Naming}
{synopt:{cmdab:pre:fix(}{it:name}{cmd:)}}prefix for {cmd:EM} and {cmd:EP}{p_end}
{synopt:{cmd:replace}}drop and recreate {cmd:EM} and {cmd:EP} if they
exist{p_end}

{syntab:Cleaning}
{synopt:{cmdab:iqr:clean(}{it:#}{cmd:)}}set elasticities outside
p25 - #*IQR .. p75 + #*IQR to missing{p_end}
{synopt:{cmdab:sd:clean(}{it:#}{cmd:)}}set elasticities outside
mean +/- #*SD to missing{p_end}

{syntab:Checks and reporting}
{synopt:{cmdab:emb:ounds(}{it:# #}{cmd:)}}acceptable range for the median
{cmd:EM}; default {cmd:embounds(.2 2)}{p_end}
{synopt:{cmdab:epb:ounds(}{it:# #}{cmd:)}}acceptable range for the median
{cmd:EP}; default {cmd:epbounds(-2 -.2)}{p_end}
{synopt:{cmdab:noch:eck}}skip the plausibility bounds{p_end}
{synopt:{cmdab:nosum:mary}}suppress the summary table{p_end}
{synoptline}
{p2colreset}{...}
{p 4 6 2}{cmd:aweight}s, {cmd:fweight}s, {cmd:pweight}s and {cmd:iweight}s are
allowed; see {help weight}.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:ifpriwl} fits the Working-Leser food-versus-non-food model

{p 8 8 2}
{it:foodshare} = a + beta_p * ln(average food price)
+ beta_m * ln(total expenditure) + covariates

{pstd}
by weighted least squares, and generates the implied observation-level
all-food elasticities

{p 8 8 2}
{cmd:EM} =  1 + beta_m / {it:foodshare}     (expenditure elasticity)

{p 8 8 2}
{cmd:EP} = -1 + beta_p / {it:foodshare}     (own-price elasticity)

{pstd}
Both are created over the estimation sample and labelled.
It is stage 1 of the IFPRI demand pipeline: {cmd:ifpriwl} for all food, then
{helpb ifpriquaids} for the within-food system and {helpb ifpriquaidselas} for
the conditional elasticities.

{pstd}
{cmd:ifpriwl} is built from {cmd:03_WL.do} and reproduces it exactly, to
within the precision of the original (see {it:Remarks}). Its four validity
checks are retained; see {it:Validity checks}.


{marker options}{...}
{title:Options}

{phang}
{cmd:lnexpenditure(}{it:varname}{cmd:)} and {cmd:lnprice(}{it:varname}{cmd:)}
are required and are expected already in logs. They enter the regression as
{cmd:lnprice} then {cmd:lnexpenditure} then {cmd:covariates}, matching the
order in {cmd:03_WL.do}; the order matters only for which of a collinear pair
{cmd:regress} drops.

{phang}
{cmd:covariates(}{it:varlist}{cmd:)} adds controls. Factor variables such as
{cmd:i.region} are allowed: the estimation sample is taken from the fit
itself, so missing-value handling and factor expansion are done by
{helpb regress}.

{phang}
{cmd:prefix(}{it:name}{cmd:)} prefixes both output variables, so several
specifications can coexist. {cmd:replace} drops {cmd:EM} and {cmd:EP} before
recreating them; without it the command refuses to overwrite and exits 110.

{phang}
{cmd:iqrclean(}{it:#}{cmd:)} and {cmd:sdclean(}{it:#}{cmd:)} set outlying
elasticities to missing; specify at most one. They use the same rule, and the
same code, as {helpb ifpriquaidselas}. Cleaning happens {bf:after} the
plausibility checks, so the checks always see the model's own output. The
number of values set to missing is reported and returned in
{cmd:e(ncleaned)}. There is no cleaning unless you ask for it.

{phang}
{cmd:embounds()}, {cmd:epbounds()} and {cmd:nocheck} control the plausibility
tests described below. The defaults are the bounds hard-coded in
{cmd:03_WL.do}.


{marker checks}{...}
{title:Validity checks}

{pstd}
The command stops with error 498 if any of the following holds. The first,
third and fourth reproduce {cmd:03_WL.do}; the second is an addition.

{phang}
1. Either {cmd:_b[lnexpenditure]} or {cmd:_b[lnprice]} is missing. The
reference wrote each coefficient into a variable and checked that no
observation was missing; because {cmd:_b[]} is a scalar that is exactly a test
of the coefficient itself, so it is done directly.

{phang}
2. {bf:(addition)} Either key regressor was dropped by {cmd:regress} for
collinearity. An omitted regressor returns {cmd:_b[] = 0}, not missing, so the
reference's test would not catch it and the command would silently report
{cmd:EM = 1} or {cmd:EP = -1} for every household. Detected from the
{cmd:o.} prefix in {cmd:colnames e(b)}.

{phang}
3. The median {cmd:EM} lies outside {cmd:embounds()}, default 0.2 to 2.

{phang}
4. The median {cmd:EP} lies outside {cmd:epbounds()}, default -2 to -0.2.

{pstd}
Medians for checks 3 and 4 are unweighted, matching the reference, and are
computed before any cleaning. {cmd:nocheck} skips checks 3 and 4 only; checks
1 and 2 always run, since they indicate a broken fit rather than an
implausible one. When a check fires, {cmd:EM} and {cmd:EP} have already been
created, so they can be inspected.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Precision.} {cmd:03_WL.do} stored each coefficient in a {cmd:float}
variable ({cmd:gen value_beta = _b[ln_texp]}) before dividing by the food
share. {cmd:ifpriwl} keeps the coefficient in a double-precision scalar, so
the elasticities differ from the reference in about the eighth significant
digit. That difference is the reference losing precision, not this command
introducing error.

{pstd}
{bf:Sample.} Elasticities are generated over {cmd:e(sample)} only. The
reference generated them wherever the food share was non-missing, including
households dropped from the regression for missing covariates. If you need
that wider coverage, say so - it is a one-line change.

{pstd}
{bf:Weights.} Weights are passed to {cmd:regress}. The summary table reports
unweighted median and mean, plus a weighted median when weights are
specified, and all are returned in {cmd:e()}. The plausibility checks use the
unweighted median, as the reference did.

{pstd}
{bf:Interpretation.} {cmd:EP} is the uncompensated own-price elasticity of
total food demand. Because the model has a single price term it cannot
separate substitution among foods; that is what {helpb ifpriquaids} is for.

{pstd}
{bf:Postestimation.} {cmd:e(cmd)} is left as {cmd:regress}, so the usual
{cmd:regress} postestimation works; {cmd:e(cmd2)} is {cmd:ifpriwl}. The two
coefficients are also in {cmd:e(beta_exp)} and {cmd:e(beta_price)}.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. ifpriwl foshare [aw=hhwt], lnexpenditure(ln_texp) lnprice(ln_avgp)}{break}
{cmd:    covariates(hhsize urban)}{p_end}

{pstd}With the 1.5 x IQR cleaning{p_end}
{phang2}{cmd:. ifpriwl foshare [aw=hhwt], lnexpenditure(ln_texp) lnprice(ln_avgp)}{break}
{cmd:    covariates(hhsize urban) replace iqrclean(1.5)}{p_end}

{pstd}Robust standard errors and region fixed effects{p_end}
{phang2}{cmd:. ifpriwl foshare [aw=hhwt], lnexpenditure(ln_texp) lnprice(ln_avgp)}{break}
{cmd:    covariates(hhsize urban i.region) replace vce(robust)}{p_end}

{pstd}Widen the acceptable range{p_end}
{phang2}{cmd:. ifpriwl foshare, lnexpenditure(ln_texp) lnprice(ln_avgp)}{break}
{cmd:    replace embounds(.1 3) epbounds(-3 -.1)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:ifpriwl} adds the following to what {helpb regress} stores.

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:e(beta_exp)}}coefficient on log expenditure{p_end}
{synopt:{cmd:e(beta_price)}}coefficient on log price{p_end}
{synopt:{cmd:e(EM_median)}}median EM, unweighted{p_end}
{synopt:{cmd:e(EM_mean)}}mean EM, unweighted{p_end}
{synopt:{cmd:e(EP_median)}}median EP, unweighted{p_end}
{synopt:{cmd:e(EP_mean)}}mean EP, unweighted{p_end}
{synopt:{cmd:e(EM_median_w)}}weighted median EM (missing if unweighted){p_end}
{synopt:{cmd:e(EM_mean_w)}}weighted mean EM{p_end}
{synopt:{cmd:e(EP_median_w)}}weighted median EP{p_end}
{synopt:{cmd:e(EP_mean_w)}}weighted mean EP{p_end}
{synopt:{cmd:e(ncleaned)}}values set to missing by cleaning{p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:e(cmd2)}}{cmd:ifpriwl}{p_end}
{synopt:{cmd:e(foodshare)}}food-share variable{p_end}
{synopt:{cmd:e(lnexpenditure)}}log-expenditure variable{p_end}
{synopt:{cmd:e(lnprice)}}log-price variable{p_end}
{synopt:{cmd:e(covariates)}}covariates{p_end}
{synopt:{cmd:e(emvar)}}name of the EM variable created{p_end}
{synopt:{cmd:e(epvar)}}name of the EP variable created{p_end}
{synopt:{cmd:e(cleanmethod)}}{cmd:iqr}, {cmd:sd}, or empty{p_end}
{synopt:{cmd:e(prefix)}}prefix used{p_end}
{p2colreset}{...}


{title:Also see}

{psee}
Help: {helpb ifpriquaids}, {helpb ifpriquaidselas}, {manhelp regress R}
{p_end}
