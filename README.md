# InteractionWeightedDIDs.jl

*Regression-based multi-period difference-in-differences with heterogenous treatment effects*

[![CI-stable](https://github.com/JuliaDiffinDiffs/InteractionWeightedDIDs.jl/workflows/CI-stable/badge.svg)](https://github.com/JuliaDiffinDiffs/InteractionWeightedDIDs.jl/actions?query=workflow%3ACI-stable)
[![codecov](https://codecov.io/gh/JuliaDiffinDiffs/InteractionWeightedDIDs.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaDiffinDiffs/InteractionWeightedDIDs.jl)

This package provides a collection of regression-based estimators
and auxiliary tools for difference-in-differences (DID)
across multiple treatment groups over multiple time periods.
It is a component of [DiffinDiffs.jl](https://github.com/JuliaDiffinDiffs/DiffinDiffs.jl)
that can also be used as a standalone package.

## Applicable Environment

The baseline DID setup this package focuses on
is the same as the one considered by [Sun and Abraham (2020)](#SunA20):

* The treatment state is binary, irreversible and sharp.
* Units are treated in *different* periods (possibly never treated) in a staggered fashion.
* Treatment effects may evolve over time following possibly different paths across groups.

The parameters of interest include:

* A collection of average treatment effects
on each group of treated units in different periods.
* Interpretable aggregations of these group-time-level parameters.

## Purposes and Functionality

Although it is possible to accomplish the estimation goals
by directly working with the regression functionality in any statistical software,
the amount of work involved can be nontrivial.
Ad hoc implementation for a specific study
may be prone to programming errors,
not reusable for future projects and also computationally inefficient.
A package that fills in the gap
between data preparation and estimation procedures is therefore desirable.

Some main functionality provided by this package includes:

* Memory-efficient generation of indicator variables needed for estimation based on data coverage.
* Enforcement of an overlap condition based on the parallel trends assumption.
* Fast residualization of regressors from fixed effects via [FixedEffects.jl](https://github.com/FixedEffects/FixedEffects.jl).
* Interaction-weighted DID estimators as proposed by [Sun and Abraham (2020)](#SunA20).
* Cell-level weight calculations for decomposing estimates from regression.

As a component of [DiffinDiffs.jl](https://github.com/JuliaDiffinDiffs/DiffinDiffs.jl),
it follows the same programming interface shared by all component packages.
In particular, it is benefited from the `@specset` macro
that largely simplifies the construction of groups of related specifications
and avoids unnecessary repetitions of the same intermediate steps
(e.g., partialling out fixed effects).
Tools for easing the export of estimation results are also available.

## Econometric Foundations

The package does not enforce the use of a specific estimation procedure
and allows flexible usage from the users.
However, it is designed to ease the adoption of
recent advances in econometric research
that overcome pitfalls in earlier empirical work.

The most relevant econometric studies that provide theoretical guidance
are the following:

* [Sun and Abraham (2020)](#SunA20)
* [Goodman-Bacon (2020)](#Goodman20)
* [Borusyak and Jaravel (2018)](#BorusyakJ18)
* Unpublished work by the package author

## References

<a name="BorusyakJ18">**Borusyak, Kirill, and Xavier Jaravel.** 2018. "Revisiting Event Study Designs with an Application to the Estimation of the Marginal Propensity to Consume." Unpublished.</a>

<a name="Goodman20">**Goodman-Bacon, Andrew.** 2020. "Difference-in-Differences with Variation in Treatment Timing." Unpublished.</a>

<a name="SunA20">**Sun, Liyang, and Sarah Abraham.** 2020. "Estimating Dynamic Treatment Effects in Event Studies with Heterogeneous Treatment Effects." *Journal of Econometrics*, forthcoming.</a>
