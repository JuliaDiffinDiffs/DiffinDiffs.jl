# InteractionWeightedDIDs.jl

*Regression-based multi-period difference-in-differences with heterogenous treatment effects*

[![CI-stable](https://github.com/JuliaDiffinDiffs/InteractionWeightedDIDs.jl/workflows/CI-stable/badge.svg)](https://github.com/JuliaDiffinDiffs/InteractionWeightedDIDs.jl/actions?query=workflow%3ACI-stable)
[![codecov](https://codecov.io/gh/JuliaDiffinDiffs/InteractionWeightedDIDs.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaDiffinDiffs/InteractionWeightedDIDs.jl)

This package provides a collection of regression-based estimators
and auxiliary tools for difference-in-differences (DID)
across multiple treatment groups over multiple time periods.
It is a component of [DiffinDiffs.jl](https://github.com/JuliaDiffinDiffs/DiffinDiffs.jl)
that can also be used as a standalone package.

> **Note:**
>
> The development of this package is still in an early stage.
> Not all features are production-ready.

## Applicable Environment

The baseline DID setup this package focuses on
is the same as the one considered by [Sun and Abraham (2020)](https://doi.org/10.1016/j.jeconom.2020.09.006):

* The treatment state is binary, irreversible and sharp.
* Units are treated in *different* periods (possibly never treated) in a staggered fashion.
* Treatment effects may evolve over time following possibly different paths across treated groups.

The parameters of interest include:

* A collection of average treatment effects
on each group of treated units in different periods.
* Interpretable aggregations of these group-time-level parameters.

## Motivation and Features

Although most estimation tasks covered by this package
can be conducted with existing statistical software,
the amount of programming work involved can be nontrivial.
Ad hoc implementation for a specific study
may be prone to programming errors,
not reusable for future projects and also computationally inefficient.
Some extra amount of automation in conducting the estimation procedures
is therefore desirable.
This is especially important when the estimation involves many regressors
and the dataset is relatively large.

This package aims to raise the productivity of empirical researchers
with the following features:

* Automatic and efficient generation of indicator variables based on empirical design and data coverage.
* Enforcement of an overlap condition based on the parallel trends assumption.
* Fast residualization of regressors from fixed effects via [FixedEffects.jl](https://github.com/FixedEffects/FixedEffects.jl).
* Interaction-weighted DID estimators proposed by [Sun and Abraham (2020)](https://doi.org/10.1016/j.jeconom.2020.09.006).
* Cell-level weight calculations for decomposing coefficient estimates from regression.

As a component of [DiffinDiffs.jl](https://github.com/JuliaDiffinDiffs/DiffinDiffs.jl),
it follows the same programming interface shared by all component packages.
In particular, it is benefited from the macros `@did` and `@specset`
that largely simplify the construction of groups of related specifications
and reduce unnecessary repetitions of identical intermediate steps
(e.g., partialling out fixed effects for the same regressors).
Tools for easing the export of estimation results are also being developed.

## Econometric Foundations

The package does not enforce the use of a specific estimation procedure
and allows flexibility from the users.
However, it is mainly designed to ease the adoption of
recent advances in econometric research
that overcome pitfalls in earlier empirical work.

The development of this package is directly based on the following studies:
* [Sun and Abraham (2020)](https://doi.org/10.1016/j.jeconom.2020.09.006)
* Unpublished work by the package author

Some other studies are also relevant and have provided inspiration:

* [de Chaisemartin and D'Haultfœuille (2020)](https://doi.org/10.1257/aer.20181169)
* [Borusyak and Jaravel (2018)](#BorusyakJ18)
* [Goodman-Bacon (2020)](#Goodman20)
* [Callaway and Sant'Anna (2020)](https://doi.org/10.1016/j.jeconom.2020.12.001)

## References

<a name="BorusyakJ18">**Borusyak, Kirill, and Xavier Jaravel.** 2018. "Revisiting Event Study Designs with an Application to the Estimation of the Marginal Propensity to Consume." Unpublished.</a>

<a name="CallawayS20">**Callaway, Brantly, and Pedro H. C. Sant'Anna.** 2020. "Difference-in-Differences with Multiple Time Periods." *Journal of Econometrics*, forthcoming.</a>

<a name="ChaisemartD20T">**de Chaisemartin, Clément, and Xavier D'Haultfœuille.** 2020. "Two-Way Fixed Effects Estimators with Heterogeneous Treatment Effects." *American Economic Review* 110 (9): 2964-96.</a>

<a name="Goodman20">**Goodman-Bacon, Andrew.** 2020. "Difference-in-Differences with Variation in Treatment Timing." Unpublished.</a>

<a name="SunA20">**Sun, Liyang, and Sarah Abraham.** 2020. "Estimating Dynamic Treatment Effects in Event Studies with Heterogeneous Treatment Effects." *Journal of Econometrics*, forthcoming.</a>
