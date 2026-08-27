# ifpriquaids

Stata commands for estimating censored Quadratic Almost Ideal Demand Systems
(QUAIDS) by the Shonkwiler–Yen two-step method, and for turning the estimates
into observation-level elasticities.

Homogeneity and symmetry are imposed by construction. Adding-up is relaxed by
default, as is usual under Shonkwiler–Yen censoring, and available through an
option. The commands are flexible in the number of goods, the number of
demographic shifters, and the number of budgeting stages.

## Installation

```stata
net install ifpriquaids, from("https://raw.githubusercontent.com/andrew-comstock/ifpriquaids/master/") replace
```

Replace `andrew-comstock/ifpriquaids` with the repository, and `master` with the branch if it
differs. **The trailing slash is required.** If the package files sit in a
subdirectory rather than the repository root, point at that subdirectory:

```stata
net install ifpriquaids, from("https://raw.githubusercontent.com/andrew-comstock/ifpriquaids/master/src/") replace
```

`from()` must be the **raw** content host (`raw.githubusercontent.com`), not
the ordinary `github.com` page URL, which serves HTML rather than the files.

To install the example and template do-files as well:

```stata
net get ifpriquaids, replace
```

These are ancillary files and land in the current working directory, not on the
ado-path.

To upgrade later, re-run the `net install` with `replace`. To remove:

```stata
ado uninstall ifpriquaids
```

### Repository layout

`net install` needs two files beside the code, at whatever URL `from()` points
to:

- `stata.toc` — lists the packages available at that location
- `ifpriquaids.pkg` — lists the files in this package

Everything else can be arranged as you like, but the `.ado` and `.sthlp` files
must sit next to those two.

## The commands

The pipeline runs in order. Each stage feeds the next.

| Command | Stage |
| --- | --- |
| `ifpriwl` | Working-Leser model for all food |
| `ifpriprobit` | first-stage probits giving the cdf and pdf |
| `ifpriquaids` | censored QUAIDS |
| `ifpriquaidselas` | conditional expenditure and price elasticities |
| `ifpriunc` | unconditional elasticities by multi-stage budgeting |
| `ifpripost` | posts elasticity summaries so the chain can be bootstrapped |

Two files are internal and are not called directly: `nlsurifpriquaids.ado`, the
`nlsur` function evaluator, and `_ifpriclean.ado`, the shared outlier-cleaning
helper.

Each user-facing command has a help file: `help ifpriquaids`, and so on.

## A minimal run

```stata
* stage 1: all food
ifpriwl foshare [aw=hh_wgt], lnexpenditure(ln_texp) lnprice(ln_avgp) ///
    covariates(hhsize urban)

* stage 2: probits for the 15 food groups
ifpriprobit d1-d15 [pw=hh_wgt], lnexpenditure(ln_texp) ///
    covariates(ln_hhage hhsex dep_rat i.zone)

* stage 3: the demand system
ifpriquaids w1-w15 [aw=hh_wgt], lnprices(lnp1-lnp15) lnexpenditure(lnm) ///
    cdf(`e(cdfvars)') pdf(`e(pdfvars)') demographics(z1) anot(a0) vce(robust)

* stage 4: conditional elasticities
ifpriquaidselas, iqrclean(1.5)

* stage 5: unconditional
ifpriunc, ngoods(15) parentem(EM) parentep(EP) iqrclean(1.5)
```

`ifpriquaids_example.do` is a runnable version on simulated data.

## Design notes

**The probits are deliberately separate from the demand system.**
`ifpriquaids` takes the cdf and pdf as required options rather than running the
first stage itself, so the first-stage specification, exclusion restrictions
and sample stay under the user's control and can be inspected and reused. This
is the main difference from the `quaidsce` package.

**Standard errors from `ifpriquaids` are conditional on the first stage.** The
cdf and pdf are generated regressors. For inference that accounts for all
stages, bootstrap the whole pipeline; `ifpri_bootstrap_template.do` is a
runnable template and `help ifpripost` documents the approach and its traps.
Budget accordingly — a 15-good bootstrap replication took about 7.5 minutes in
testing, so 200 replications is an overnight job.

**Perfectly-predicting covariates are handled.** If a covariate predicts
participation perfectly, `probit` drops observations and leaves holes in the
cdf and pdf that break the demand system downstream. `ifpriprobit` detects
this, removes the offending covariate — a single factor level where that is
what is at fault — refits, and reports exactly what it did.

**Goods consumed by every household** have no first stage. Set their cdf to 1
and pdf to 0, and name them in `ifpriquaids`'s `nosycorrection()` and
`ifpriprobit`'s `exclude()`.

## Requirements

Stata 14 or later. No dependencies beyond official Stata.

## Author

Andrew Comstock, IFPRI — a.comstock@cgiar.org
