{smcl}
{* *! version 1.0.0  26aug2026}{...}
{vieweralsosee "ifpriquaidselas" "help ifpriquaidselas"}{...}
{vieweralsosee "ifpriwl" "help ifpriwl"}{...}
{viewerjumpto "Syntax" "ifpriunc##syntax"}{...}
{viewerjumpto "Description" "ifpriunc##description"}{...}
{viewerjumpto "Formulas" "ifpriunc##formulas"}{...}
{viewerjumpto "Chaining stages" "ifpriunc##chaining"}{...}
{viewerjumpto "Options" "ifpriunc##options"}{...}
{viewerjumpto "Difference from 05_elast_construct_clean.do" "ifpriunc##legacy"}{...}
{viewerjumpto "Examples" "ifpriunc##examples"}{...}
{viewerjumpto "Stored results" "ifpriunc##results"}{...}
{title:Title}

{phang}
{bf:ifpriunc} {hline 2} Unconditional elasticities by multi-stage budgeting


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:ifpriunc} {ifin}{cmd:,}
{cmdab:parentem(}{it:varname}|{it:#}{cmd:)}
{cmdab:parentep(}{it:varname}|{it:#}{cmd:)}
[{it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{cmdab:parentem(}{it:varname}|{it:#}{cmd:)}}unconditional expenditure
elasticity of the group this system is nested in{p_end}
{synopt:{cmdab:parentep(}{it:varname}|{it:#}{cmd:)}}unconditional own-price
elasticity of that group{p_end}

{syntab:Inputs}
{synopt:{cmdab:ng:oods(}{it:#}{cmd:)}}number of goods in this system; taken
from {cmd:e(ngoods)} if omitted{p_end}
{synopt:{cmd:em(}{it:stub}{cmd:)}}conditional expenditure elasticities
{it:stub}1..{it:stub}n; default {cmd:em(em_)}{p_end}
{synopt:{cmdab:sh:are(}{it:stub}{cmd:)}}conditional budget shares
{it:stub}1..{it:stub}n; default {cmd:share(cw)}{p_end}
{synopt:{cmd:epm(}{it:stub}{cmd:)}}conditional Marshallian elasticities
{it:stub}{it:i}_{it:j}; default {cmd:epm(epm_)}{p_end}
{synopt:{cmd:eph(}{it:stub}{cmd:)}}conditional Hicksian elasticities; needed
only with {cmd:legacy}; default {cmd:eph(eph_)}{p_end}

{syntab:Output}
{synopt:{cmdab:gen:erate(}{it:stub}{cmd:)}}prefix for the created
variables{p_end}
{synopt:{cmdab:nam:es(}{it:namelist}{cmd:)}}n names used in variable labels and
the summary table{p_end}
{synopt:{cmd:replace}}drop and recreate variables that already exist{p_end}
{synopt:{cmdab:nosum:mary}}suppress the summary table{p_end}

{syntab:Cleaning}
{synopt:{cmdab:iqr:clean(}{it:#}{cmd:)}}set outputs outside
p25 - #*IQR .. p75 + #*IQR to missing{p_end}
{synopt:{cmdab:sd:clean(}{it:#}{cmd:)}}set outputs outside mean +/- #*SD to
missing{p_end}

{syntab:Compatibility}
{synopt:{cmdab:leg:acy}}reproduce {cmd:05_elast_construct_clean.do} exactly,
including one formula error{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:ifpriunc} converts the {it:conditional} elasticities of one demand system
into {it:unconditional} ones, by combining them with the unconditional
elasticities of the group that system is nested in. It is the last stage of
the IFPRI demand pipeline: {helpb ifpriwl}, {helpb ifpriprobit},
{helpb ifpriquaids}, {helpb ifpriquaidselas}, {cmd:ifpriunc}.

{pstd}
Variables created, for {it:i}, {it:j} = 1..n:

{p2colset 8 26 28 2}{...}
{p2col:{cmd:em}{it:i}}unconditional expenditure elasticity{p_end}
{p2col:{cmd:ep}{it:i}{cmd:_}{it:j}}unconditional Marshallian price elasticity{p_end}
{p2col:{cmd:eop}{it:i}}unconditional own-price elasticity, i.e. {cmd:ep}{it:i}{cmd:_}{it:i}{p_end}
{p2colreset}{...}

{pstd}
The names follow {cmd:05_elast_construct_clean.do}. Note how little separates
them from the {it:conditional} names written by {helpb ifpriquaidselas}:
{cmd:em}{it:i} against {cmd:em_}{it:i}, {cmd:ep}{it:i}{cmd:_}{it:j} against
{cmd:epm_}{it:i}{cmd:_}{it:j}. Use {cmd:generate()} when both are in the
dataset.

{pstd}
One call handles {bf:one stage transition}. Chain calls for more stages; see
{it:Chaining stages}.


{marker formulas}{...}
{title:Formulas}

{pstd}
Write em_i, share_j and epm_ij for the conditional expenditure elasticity,
budget share and Marshallian price elasticity within this system, and Eparent
and EPparent for the unconditional expenditure and own-price elasticities of
the group it sits in. Then

{p 8 8 2}
E_i  = Eparent * em_i

{p 8 8 2}
U_ij = epm_ij + em_i * share_j * (1 + EPparent)

{pstd}
The price result follows from the response of group expenditure to a
within-group price. With m_G = P_G Q_G and d ln P_G / d ln p_j = share_j,

{p 8 8 2}
d ln m_G / d ln p_j = share_j * (1 + EPparent)

{pstd}
and the chain rule through this stage gives U_ij. Using the conditional
Slutsky identity epm_ij = eph_ij - em_i share_j, the same result can be
written in Hicksian form:

{p 8 8 2}
U_ij = eph_ij + em_i * share_j * EPparent

{pstd}
Both were checked to agree to about 1e-16 in testing. {cmd:ifpriunc} uses the
Marshallian form.


{marker chaining}{...}
{title:Chaining stages}

{pstd}
The command is deliberately one-transition-at-a-time, because the outputs of
one call are exactly the parent inputs of the next. Any number of stages
therefore works, and only the branches that actually have a sub-system need be
run.

{pstd}
For all food, then 15 food groups, then a dairy sub-system of milk, cheese and
yoghurt:

{phang2}{cmd:. * stage 1 -> 2: the 15 groups, nested in all food}{p_end}
{phang2}{cmd:. ifpriunc, ngoods(15) parentem(EM) parentep(EP)}{p_end}

{phang2}{cmd:. * stage 2 -> 3: dairy items, nested in food group 4}{p_end}
{phang2}{cmd:. ifpriunc, ngoods(3) parentem(em4) parentep(eop4)}{break}
{cmd:    em(dem_) share(dcw) epm(depm_) generate(d) names(milk cheese yoghurt)}{p_end}

{pstd}
The parent arguments in the second call are the {bf:unconditional} outputs of
the first, for the good the sub-system belongs to - not its conditional
elasticities. Feeding conditional values in would drop a stage from the chain
silently, so it is worth checking that {cmd:parentem()} and {cmd:parentep()}
name {cmd:em}{it:g} and {cmd:eop}{it:g}, not {cmd:em_}{it:g} and
{cmd:epm_}{it:g}{cmd:_}{it:g}.

{pstd}
The expenditure elasticity telescopes, so after two chained calls
{cmd:dem}{it:i} equals {cmd:EM * em_4 * dem_}{it:i} - verified exactly in
testing, and a cheap check to repeat on your own data.

{pstd}
Cross-price elasticities are within-system only. Elasticities between items in
{it:different} sub-systems are not produced: they do not follow from any one
conditional system and would need the full cross-group matrix of the stage
above.


{marker options}{...}
{title:Options}

{phang}
{cmd:parentem()} and {cmd:parentep()} accept a variable or a number. For the
first transition they are the Working-Leser results, {cmd:EM} and {cmd:EP}
from {helpb ifpriwl}. For later transitions they are this command's own
{cmd:em}{it:g} and {cmd:eop}{it:g} for the parent good {it:g}.

{phang}
{cmd:ngoods()} defaults to {cmd:e(ngoods)} when {helpb ifpriquaids} estimates
are in memory. Give it explicitly when working from saved variables.

{phang}
{cmd:em()}, {cmd:share()}, {cmd:epm()} and {cmd:eph()} name the input stubs.
The defaults match what {helpb ifpriquaidselas} writes, so the first
transition usually needs none of them; a sub-system fitted with
{cmd:prefix()} needs all of them set to that prefix.

{phang}
{cmd:iqrclean()} and {cmd:sdclean()} use the same rule, and the same code, as
{helpb ifpriquaidselas} and {helpb ifpriwl}. Specify at most one. Cleaning is
applied to every created variable. There is no cleaning unless you ask for it.

{phang}
{cmd:names()} supplies n labels, used both in the variable labels and in the
summary table.


{marker legacy}{...}
{title:Difference from 05_elast_construct_clean.do}

{pstd}
The reference computes

{p 12 12 2}
{cmd:ep`i'_`j' = eph_`i'_`j' + em_`i' * cw`j' * (1 + EP)}

{pstd}
pairing the {bf:Hicksian} conditional elasticity with the {bf:Marshallian}
multiplier. As shown under {it:Formulas}, the Hicksian form takes EPparent and
the Marshallian form takes 1 + EPparent; mixing them adds
em_i * share_j once too often. Testing confirmed the gap is exactly that
quantity.

{pstd}
The over-count compounds with the Slutsky correction in
{helpb ifpriquaidselas}: feeding a corrected {cmd:eph} into the reference
formula over-counts again. {cmd:legacy} reproduces the reference exactly -
verified to the last digit - for comparison against previously circulated
results, not for new ones.

{pstd}
The expenditure elasticities are unaffected: {cmd:em}{it:i} is identical
either way.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. ifpriwl foshare [aw=hh_wgt], lnexpenditure(ln_texp) lnprice(ln_avgp) covariates(hhsize)}{p_end}
{phang2}{cmd:. ifpriprobit d1-d15 [pw=hh_wgt], lnexpenditure(ln_texp) covariates(i.zone hhsize)}{p_end}
{phang2}{cmd:. ifpriquaids w1-w15 [aw=hh_wgt], lnprices(lnp1-lnp15) lnexpenditure(lnm)}{break}
{cmd:      cdf(`e(cdfvars)') pdf(`e(pdfvars)') demographics(z1) anot(a0) vce(robust)}{p_end}
{phang2}{cmd:. ifpriquaidselas, iqrclean(1.5)}{p_end}
{phang2}{cmd:. ifpriunc, ngoods(15) parentem(EM) parentep(EP) iqrclean(1.5)}{p_end}

{pstd}Reproduce the old do-file for comparison{p_end}
{phang2}{cmd:. ifpriunc, ngoods(15) parentem(EM) parentep(EP) generate(old) legacy}{p_end}


{title:A three-tier system}

{pstd}
All food, then 15 food groups, then a dairy sub-system of milk, cheese and
yoghurt. Dairy is food group 4. Only dairy has a sub-system here; the other
fourteen groups simply stop at tier 2.

{pstd}
{bf:Tier 1 - all food.} Working-Leser gives {cmd:EM} and {cmd:EP}.

{phang2}{cmd:. ifpriwl foshare [aw=hh_wgt], lnexpenditure(ln_texp) lnprice(ln_avgp)}{break}
{cmd:      covariates(hhsize urban) iqrclean(1.5)}{p_end}

{pstd}
{bf:Tier 2 - the 15 food groups}, nested in all food. Note {cmd:lnm} here is
log {it:food} expenditure.

{phang2}{cmd:. ifpriprobit d1-d15 [pw=hh_wgt], lnexpenditure(ln_texp) covariates(i.zone hhsize)}{p_end}
{phang2}{cmd:. ifpriquaids w1-w15 [aw=hh_wgt], lnprices(lnp1-lnp15) lnexpenditure(lnm)}{break}
{cmd:      cdf(`e(cdfvars)') pdf(`e(pdfvars)') demographics(z1) anot(a0) vce(robust)}{p_end}
{phang2}{cmd:. ifpriquaidselas, iqrclean(1.5)}{p_end}
{phang2}{cmd:. ifpriunc, ngoods(15) parentem(EM) parentep(EP) iqrclean(1.5)}{p_end}

{pstd}
That writes {cmd:em1}-{cmd:em15}, {cmd:ep}{it:i}{cmd:_}{it:j} and
{cmd:eop1}-{cmd:eop15}, all unconditional. Dairy's are {cmd:em4} and
{cmd:eop4}.

{pstd}
{bf:Tier 3 - milk, cheese and yoghurt}, nested in dairy. This is a separate,
self-contained system: its own probits, its own QUAIDS, its own conditional
elasticities. Fit it on log {it:dairy} expenditure, and use a prefix
throughout so nothing collides with tier 2.

{phang2}{cmd:. ifpriprobit dd1-dd3 [pw=hh_wgt], lnexpenditure(ln_texp)}{break}
{cmd:      covariates(i.zone hhsize) prefix(d)}{p_end}
{phang2}{cmd:. ifpriquaids dw1-dw3 [aw=hh_wgt], lnprices(dlnp1-dlnp3) lnexpenditure(dlnm)}{break}
{cmd:      cdf(`e(cdfvars)') pdf(`e(pdfvars)') demographics(z1) anot(da0) vce(robust)}{p_end}
{phang2}{cmd:. ifpriquaidselas, prefix(d) iqrclean(1.5)}{p_end}
{phang2}{cmd:. ifpriunc, ngoods(3) parentem(em4) parentep(eop4)}{break}
{cmd:      em(dem_) share(dcw) epm(depm_) generate(d)}{break}
{cmd:      names(milk cheese yoghurt) iqrclean(1.5)}{p_end}

{pstd}
The two things that make this a three-tier chain rather than two unrelated
two-tier ones:

{phang}
1. {cmd:parentem(em4)} and {cmd:parentep(eop4)} are the {bf:unconditional}
tier-2 outputs for dairy. Passing {cmd:em_4} and {cmd:epm_4_4} - the
{it:conditional} ones - would silently drop tier 1 out of the chain, and
nothing would error.{p_end}

{phang}
2. {cmd:em()}, {cmd:share()} and {cmd:epm()} point at the tier-3 stubs. Left
at their defaults they would read tier 2's variables and quietly produce
nonsense.{p_end}

{pstd}
The result is {cmd:dem1}-{cmd:dem3}, {cmd:dep}{it:i}{cmd:_}{it:j} and
{cmd:deop1}-{cmd:deop3}: elasticities of milk, cheese and yoghurt with respect
to total household expenditure and to their own prices, running through all
three tiers.

{pstd}
{bf:Worth checking once on your own data.} The expenditure elasticity
telescopes, so

{phang2}{cmd:. generate double chk = EM * em_4 * dem_1}{p_end}
{phang2}{cmd:. summarize chk dem1}{p_end}

{pstd}
must agree - it does so exactly in testing. If it does not, the parent
arguments are wrong, which is the one mistake this interface makes easy.

{pstd}
Further tiers chain the same way: a fourth tier under milk would take
{cmd:parentem(dem1) parentep(deop1)}. Cross-price elasticities remain
within-system throughout - milk against cheese, never milk against rice.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:ifpriunc} is {cmd:r}-class and leaves {cmd:e()} untouched.

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(ngoods)}}number of goods{p_end}
{synopt:{cmd:r(N)}}observations used{p_end}
{synopt:{cmd:r(ncleaned)}}values set to missing by cleaning{p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(generate)}}prefix used{p_end}
{synopt:{cmd:r(emvars)}}stub of the expenditure-elasticity variables{p_end}
{synopt:{cmd:r(epvars)}}stub of the price-elasticity variables{p_end}
{synopt:{cmd:r(eopvars)}}stub of the own-price variables{p_end}

{p2col 5 22 26 2: Matrices}{p_end}
{synopt:{cmd:r(em_median)}}1 x n median unconditional expenditure elasticities{p_end}
{synopt:{cmd:r(eop_median)}}1 x n median unconditional own-price elasticities{p_end}
{p2colreset}{...}


{title:Also see}

{psee}
Help: {helpb ifpriwl}, {helpb ifpriprobit}, {helpb ifpriquaids},
{helpb ifpriquaidselas}
{p_end}
