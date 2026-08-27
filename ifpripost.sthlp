{smcl}
{* *! version 1.0.0  26aug2026}{...}
{vieweralsosee "ifpriunc" "help ifpriunc"}{...}
{vieweralsosee "[R] bootstrap" "help bootstrap"}{...}
{viewerjumpto "Syntax" "ifpripost##syntax"}{...}
{viewerjumpto "Description" "ifpripost##description"}{...}
{viewerjumpto "Why bootstrap" "ifpripost##why"}{...}
{viewerjumpto "Template" "ifpripost##template"}{...}
{viewerjumpto "Options" "ifpripost##options"}{...}
{viewerjumpto "Practicalities" "ifpripost##practical"}{...}
{viewerjumpto "Stored results" "ifpripost##results"}{...}
{title:Title}

{phang}
{bf:ifpripost} {hline 2} Post elasticity summaries as e(b) so the demand
pipeline can be bootstrapped


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:ifpripost} {ifin} {weight}{cmd:,}
{cmdab:ng:oods(}{it:#}{cmd:)}
[{it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{cmdab:ng:oods(}{it:#}{cmd:)}}number of goods{p_end}
{synopt:{cmd:em(}{it:stub}{cmd:)}}expenditure-elasticity stub; default
{cmd:em(em)}{p_end}
{synopt:{cmd:eop(}{it:stub}{cmd:)}}own-price stub; default {cmd:eop(eop)}{p_end}
{synopt:{cmd:ep(}{it:stub}{cmd:)}}cross-price stub; default {cmd:ep(ep)}{p_end}
{synopt:{cmd:cross}}also post the full n x n cross-price matrix{p_end}
{synopt:{cmdab:ex:tra(}{it:varlist}{cmd:)}}also post these variables, e.g.
{cmd:EM} and {cmd:EP}{p_end}
{synopt:{cmdab:stat:istic(}{cmd:median}|{cmd:mean}{cmd:)}}summary to post;
default {cmd:median}{p_end}
{synopt:{cmdab:nosum:mary}}suppress the display{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
The elasticities written by {helpb ifpriquaidselas} and {helpb ifpriunc} are
observation level. What is reported is a summary of them across households -
normally the median. {cmd:ifpripost} computes those summaries and posts them
as {cmd:e(b)}, which is the form {helpb bootstrap} needs in order to attach
standard errors.

{pstd}
It is meant as the last line of a wrapper program that runs the whole
pipeline. On its own it does nothing but summarise.

{pstd}
By default it posts n expenditure elasticities and n own-price elasticities.
{cmd:cross} adds the n^2 cross-price elasticities, and {cmd:extra()} adds named
variables such as the Working-Leser {cmd:EM} and {cmd:EP}. Posting the full
cross matrix for 15 goods means 255 quantities, which makes each replication
slower and the reporting harder to read; add it when you need it.


{marker why}{...}
{title:Why bootstrap}

{pstd}
The elasticities are nonlinear functions of three estimated stages: the
Working-Leser coefficients, the probit coefficients, and the QUAIDS
parameters. Their sampling variability comes from all three. In addition the
cdf and pdf entering the QUAIDS are {it:generated regressors}, so the
second-stage standard errors reported by {helpb ifpriquaids} are conditional
on the first stage and understate uncertainty even for the parameters, let
alone for nonlinear functions of them.

{pstd}
Resampling households and re-running the entire chain propagates all of it.
That is what the template below does. An analytic alternative would mean the
delta method through all three stages including the generated-regressor
correction, which is a research exercise rather than a command.


{marker template}{...}
{title:Template}

{pstd}
A runnable template ships with the package as
{cmd:ifpri_bootstrap_template.do}. The essentials:

{phang2}{cmd:. program define pipeline, eclass}{p_end}
{phang2}{cmd:.     quietly ifpriwl foshare [aw=hh_wgt], ... replace nocheck nosummary}{p_end}
{phang2}{cmd:.     quietly ifpriprobit d1-d15 [pw=hh_wgt], ... replace nosummary}{p_end}
{phang2}{cmd:.     local cdfs "`e(cdfvars)'"}{p_end}
{phang2}{cmd:.     local pdfs "`e(pdfvars)'"}{p_end}
{phang2}{cmd:.     quietly ifpriquaids w1-w15 [aw=hh_wgt], ... cdf(`cdfs') pdf(`pdfs') initial(b_start)}{p_end}
{phang2}{cmd:.     quietly ifpriquaidselas, replace iqrclean(1.5) nosummary}{p_end}
{phang2}{cmd:.     quietly ifpriunc, ngoods(15) parentem(EM) parentep(EP) replace nosummary}{p_end}
{phang2}{cmd:.     ifpripost [aw=hh_wgt], ngoods(15) extra(EM EP) nosummary}{p_end}
{phang2}{cmd:. end}{p_end}

{phang2}{cmd:. bootstrap _b, reps(200) cluster(psu) strata(stratum) seed(1): pipeline}{p_end}

{pstd}
Three things every replication must get right:

{phang}
1. {bf:Use} {cmd:replace} {bf:everywhere}. The variables created by one
replication are still in the dataset at the start of the next, and a command
that refuses to overwrite will abort the whole bootstrap.

{phang}
2. {bf:Declare the program} {cmd:eclass}. {cmd:bootstrap} collects
{cmd:e(b)}, and a program that is not eclass cannot pass it up.

{phang}
3. {bf:Suppress the plausibility checks that are not wanted per replication.}
{cmd:ifpriwl}'s {cmd:nocheck} is there for this: a resample can easily throw
a median elasticity outside the default bounds, and you probably want that
replication to count rather than abort the run.

{pstd}
{cmd:cluster()} and {cmd:strata()} should reflect the survey design. Omitting
{cmd:cluster()} for a clustered sample understates the standard errors, often
badly.


{marker options}{...}
{title:Options}

{phang}
{cmd:statistic(median|mean)} chooses what is posted. {cmd:median} is the
default and matches the convention in the reference do-files. The median of a
ratio is far more stable than its mean when a denominator is small, which is
the same reason the cleaning options exist.

{phang}
Weights are used for the summary itself: {cmd:[aw=hh_wgt]} gives the weighted
median or mean. Within a bootstrap this is the right thing - {cmd:bootstrap}
handles the resampling, {cmd:ifpripost} handles the weighting.

{phang}
{cmd:ifpripost} refuses, with error 498, if any quantity it is asked to post
has no non-missing values. That is deliberate: {cmd:bootstrap} silently
discards a replication whose {cmd:e(b)} contains a missing value, and a run
that quietly drops a third of its replications is worse than one that stops.
The usual cause is an elasticity that cleaning has emptied in that resample.


{marker practical}{...}
{title:Practicalities}

{pstd}
{bf:Runtime is the binding constraint.} Each replication runs the whole
pipeline. On a simulated 4-good, 1,500-household problem a replication took
about 9 seconds, so 50 replications took under 8 minutes. A 15-good problem is
very much slower, because the QUAIDS itself is: budget for hours, not minutes,
and start with a small {cmd:reps()} to measure your own per-replication cost
before committing to a long run.

{pstd}
{bf:Check how many replications actually completed.} {cmd:e(N_reps)} against
what you asked for. A replication in which the QUAIDS fails to converge is
discarded. A handful is noise; a large fraction means the standard errors are
being computed from a self-selected subset of resamples that happened to
behave, which is not the same as a bootstrap distribution.

{pstd}
{bf:Warm starting is a convenience with a caveat.} Passing the full-sample
estimates through {cmd:initial()} saves time. It cannot bias the estimator,
since the optimum does not depend on where the search began - but only if each
replication genuinely converges. If replications stop early near their
starting value, the replicate estimates are pulled toward the full-sample
point and the bootstrap variance is understated. Given the convergence
behaviour already documented for this model under {cmd:ifgnls}, it is worth
confirming that replications converge rather than assuming it. Measured
benefit on a small problem was only about 8 per cent, so warm starting is not
worth much risk.

{pstd}
{bf:The probit specification can differ across replications.} With
{cmd:autodrop} on, a covariate that predicts participation perfectly in one
resample but not another will be removed in some replications and not others.
That is arguably part of the estimator and so properly inside the bootstrap,
but it does mean the replications are not all fitting an identical
specification. {cmd:covdrop()} with {cmd:noautodrop} fixes the specification
across replications if you would rather it were held constant.

{pstd}
{bf:What the standard errors cover.} Everything inside the wrapper program.
Anything done before it - constructing unit values, aggregating to food
groups, trimming outliers in the input data - is treated as fixed, and its
contribution to uncertainty is not measured.


{marker results}{...}
{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(ngoods)}}number of goods{p_end}
{synopt:{cmd:e(k)}}number of quantities posted{p_end}
{synopt:{cmd:e(N)}}observations used{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:ifpripost}{p_end}
{synopt:{cmd:e(statistic)}}{cmd:median} or {cmd:mean}{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}the posted summaries{p_end}
{p2colreset}{...}


{title:Also see}

{psee}
Help: {helpb ifpriunc}, {helpb ifpriquaidselas}, {manhelp bootstrap R}
{p_end}
