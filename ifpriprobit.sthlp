{smcl}
{* *! version 1.0.0  25aug2026}{...}
{vieweralsosee "ifpriquaids" "help ifpriquaids"}{...}
{vieweralsosee "ifpriwl" "help ifpriwl"}{...}
{viewerjumpto "Syntax" "ifpriprobit##syntax"}{...}
{viewerjumpto "Description" "ifpriprobit##description"}{...}
{viewerjumpto "Options" "ifpriprobit##options"}{...}
{viewerjumpto "Problem covariates" "ifpriprobit##autodrop"}{...}
{viewerjumpto "Remarks" "ifpriprobit##remarks"}{...}
{viewerjumpto "Examples" "ifpriprobit##examples"}{...}
{viewerjumpto "Stored results" "ifpriprobit##results"}{...}
{title:Title}

{phang}
{bf:ifpriprobit} {hline 2} First-stage probits producing the cdf and pdf for a
censored QUAIDS


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:ifpriprobit} {it:dummies} {ifin} {weight}{cmd:,}
{cmdab:lnexp:enditure(}{it:varname}{cmd:)}
[{it:options}]

{pstd}
{it:dummies} is a {it:varlist} of n censoring indicators, one per good, equal
to 1 when the household consumes the good.

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{cmdab:lnexp:enditure(}{it:varname}{cmd:)}}log of total household
expenditure; enters every probit{p_end}

{syntab:Model}
{synopt:{cmdab:cov:ariates(}{it:varlist}{cmd:)}}covariates applied to every
good; factor variables allowed{p_end}
{synopt:{cmdab:covd:rop(}{it:spec}{cmd:)}}remove named covariates from named
goods; see {it:Problem covariates}{p_end}
{synopt:{cmdab:ex:clude(}{it:numlist}{cmd:)}}goods with no censoring: no probit
is run, cdf is set to 1 and pdf to 0{p_end}
{synopt:{cmdab:nocons:tant(}{it:numlist}{cmd:)}}goods to fit without a constant
term{p_end}
{synopt:{it:probit_options}}{cmd:vce()}, {cmd:iterate()} and so on, passed to
{helpb probit}{p_end}

{syntab:Problem covariates}
{synopt:{cmdab:noautod:rop}}do not remove perfectly-predicting covariates
automatically{p_end}
{synopt:{cmdab:maxd:rop(}{it:#}{cmd:)}}maximum removal rounds per good; default
20{p_end}

{syntab:Naming}
{synopt:{cmdab:pre:fix(}{it:name}{cmd:)}}prefix for the created variables{p_end}
{synopt:{cmdab:geni:ndex(}{it:name}{cmd:)}}also keep the linear index as
{it:name}1 ... {it:name}n{p_end}
{synopt:{cmd:replace}}drop and recreate variables that already exist{p_end}
{synopt:{cmdab:nosum:mary}}suppress the summary table{p_end}
{synoptline}
{p2colreset}{...}
{p 4 6 2}{cmd:pweight}s, {cmd:fweight}s and {cmd:iweight}s are allowed;
{helpb probit} does not accept {cmd:aweight}s.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:ifpriprobit} runs one probit per good of the censoring dummy on log total
expenditure and covariates, then generates

{p2colset 8 24 26 2}{...}
{p2col:{cmd:cdf}{it:i}}the standard normal cdf at the fitted index{p_end}
{p2col:{cmd:pdf}{it:i}}the standard normal density at the fitted index{p_end}
{p2colreset}{...}

{pstd}
which are what {helpb ifpriquaids} expects in its {cmd:cdf()} and {cmd:pdf()}
options. It is stage 2 of the IFPRI demand pipeline: {helpb ifpriwl},
{cmd:ifpriprobit}, {helpb ifpriquaids}, {helpb ifpriquaidselas}.

{pstd}
All goods are fitted on {bf:one common sample} - the households with
non-missing values on every dummy, on log expenditure and on every covariate.
That matters because the demand system needs cdf and pdf present for every
good on the same households.

{pstd}
Built from {cmd:03_probit.do}, whose missing-value checks are retained.


{marker autodrop}{...}
{title:Problem covariates}

{pstd}
The practical difficulty this command exists to solve: if a covariate predicts
participation perfectly, {helpb probit} does not fail. It prints a note, omits
the covariate {bf:and drops those observations}, so {cmd:predict, xb} returns
missing for them. Those become missing cdf and pdf, which then break the
demand system. In one test, a single zone level that no household consumed
left 524 of 3,000 households with no prediction.

{pstd}
{cmd:ifpriprobit} detects this and, by default, removes the offending
covariate and refits, repeating until every household has a prediction. It
then reports exactly what it removed, per good, and stores the same in
{cmd:e(dropped}{it:i}{cmd:)}.

{pstd}
Detection is by {bf:observations lost}, not by the omission marker alone.
Ordinary collinearity also makes {helpb probit} omit a term, but costs no
observations and leaves no holes, so it is left alone - only omissions that
actually cost observations trigger a refit.

{pstd}
Factor variables are handled at the {bf:level}. If {cmd:i.zone} is supplied and
only zone 2 predicts perfectly, the command removes {cmd:2.zone} and keeps the
other levels, which is what one would do by hand.

{pstd}
{cmd:noautodrop} disables this. The probits then behave exactly as
{cmd:03_probit.do} did, and a good left with holes triggers the
{cmd:CDF}{it:i}{cmd:/PDF}{it:i}{cmd: contains a missing value} error.

{pstd}
{cmd:covdrop()} does the same removals by hand, using
{cmd:good: covariates}, several separated by semicolons:

{phang2}{cmd:. ifpriprobit d1-d15 ..., covdrop(13: 2.zone ; 7: hhsex urban)}{p_end}

{pstd}
Manual and automatic removal give identical estimates when they remove the
same term (verified). Manual removals are reported and stored separately, in
{cmd:e(covdropped}{it:i}{cmd:)}, so the two are always distinguishable.


{marker options}{...}
{title:Options}

{phang}
{cmd:lnexpenditure(}{it:varname}{cmd:)} is required and enters every probit as
the first regressor.

{phang}
{cmd:covariates(}{it:varlist}{cmd:)} is the base specification used for all
goods. Factor variables such as {cmd:i.zone} are allowed. This replaces the
fifteen near-identical {cmd:global prdem1}...{cmd:prdem15} definitions the
reference workflow required: state the base set once, then use
{cmd:covdrop()} or {cmd:autodrop} for the goods that need to differ.

{phang}
{cmd:exclude(}{it:numlist}{cmd:)} names goods consumed by every household, for
which no probit is possible. Their cdf is set to 1 and pdf to 0, which
collapses the corresponding demand equation to its uncensored form. Pair this
with {cmd:nosycorrection()} in {helpb ifpriquaids} for the same goods.

{phang}
{cmd:noconstant(}{it:numlist}{cmd:)} fits the named goods without a constant.
To suppress it everywhere, give every good number.

{phang}
{cmd:genindex(}{it:name}{cmd:)} additionally keeps the linear index. Not
needed to recover the cdf, since the index is {cmd:invnormal(cdf}{it:i}{cmd:)},
but it is exact and convenient, and the unconditional-elasticity stage will
want it.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Checks.} The command stops with error 498 if any cdf or pdf is missing
inside the estimation sample, reporting
{cmd:CDF}{it:i}{cmd: contains a missing value} as the reference did. The
reference's other two checks - that the {cmd:pdf*} and {cmd:cdf*} variables
exist at all - cannot fail here, because the command creates them itself.

{pstd}
{bf:Ordering.} {it:dummies} must be listed in the same order as the shares
later given to {helpb ifpriquaids}, since {cmd:cdf}{it:i} is matched to the
{it:i}th share by position.

{pstd}
{bf:Probit coefficients} are stored in {cmd:e(prbeta)}, one row per good over
the union of all terms used, with zero where a term was not in that good's
model and an all-zero row for excluded goods. Keeping them avoids re-running
the probits when the participation margin is needed.

{pstd}
{bf:Weights.} {helpb probit} does not accept {cmd:aweight}s, so neither does
this command, unlike the rest of the package. The reference used
{cmd:[pw=$wgt]}.

{pstd}
{bf:e()} holds a summary of the whole set of probits, not any single one:
{cmd:e(b)} from the individual fits is not retained. Use {cmd:e(prbeta)}.


{marker examples}{...}
{title:Examples}

{pstd}Base specification for every good, one good consumed by everyone{p_end}
{phang2}{cmd:. ifpriprobit d1-d15 [pw=hh_wgt], lnexpenditure(ln_texp)}{break}
{cmd:    covariates(ln_hhage hhsex head_primary head_secondary dep_rat hindu islam i.zone)}{break}
{cmd:    exclude(4)}{p_end}

{pstd}Good 13 needs no constant, and zone 2 removed by hand{p_end}
{phang2}{cmd:. ifpriprobit d1-d15 [pw=hh_wgt], lnexpenditure(ln_texp)}{break}
{cmd:    covariates(ln_hhage hhsex dep_rat i.zone) noconstant(13)}{break}
{cmd:    covdrop(13: 2.zone) noautodrop}{p_end}

{pstd}Feed the result straight into the demand system{p_end}
{phang2}{cmd:. local cdfs "`e(cdfvars)'"}{p_end}
{phang2}{cmd:. local pdfs "`e(pdfvars)'"}{p_end}
{phang2}{cmd:. ifpriquaids w1-w15 [aw=hh_wgt], lnprices(lnp1-lnp15) lnexpenditure(lnm)}{break}
{cmd:    cdf(`cdfs') pdf(`pdfs') demographics(z1) anot(a0) nosycorrection(w4)}{p_end}


{marker results}{...}
{title:Stored results}

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:e(ngoods)}}number of goods{p_end}
{synopt:{cmd:e(N)}}size of the common estimation sample{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:ifpriprobit}{p_end}
{synopt:{cmd:e(cmd2)}}{cmd:ifpriprobit}{p_end}
{synopt:{cmd:e(dummies)}}censoring indicators{p_end}
{synopt:{cmd:e(lnexpenditure)}}log-expenditure variable{p_end}
{synopt:{cmd:e(covariates)}}base covariate specification{p_end}
{synopt:{cmd:e(cdfvars)}}names of the cdf variables created{p_end}
{synopt:{cmd:e(pdfvars)}}names of the pdf variables created{p_end}
{synopt:{cmd:e(excluded)}}goods given cdf=1, pdf=0{p_end}
{synopt:{cmd:e(noconstant)}}goods fitted without a constant{p_end}
{synopt:{cmd:e(autodrop)}}{cmd:on} or {cmd:off}{p_end}
{synopt:{cmd:e(dropped}{it:i}{cmd:)}}terms removed automatically for good {it:i}{p_end}
{synopt:{cmd:e(covdropped}{it:i}{cmd:)}}terms removed by {cmd:covdrop()} for good {it:i}{p_end}
{synopt:{cmd:e(prefix)}}prefix used{p_end}
{synopt:{cmd:e(genindex)}}index stub, if any{p_end}

{p2col 5 24 28 2: Matrices}{p_end}
{synopt:{cmd:e(prbeta)}}n x K probit coefficients over the union of terms{p_end}

{p2col 5 24 28 2: Functions}{p_end}
{synopt:{cmd:e(sample)}}marks the common estimation sample{p_end}
{p2colreset}{...}


{title:Also see}

{psee}
Help: {helpb ifpriwl}, {helpb ifpriquaids}, {helpb ifpriquaidselas},
{manhelp probit R}
{p_end}
