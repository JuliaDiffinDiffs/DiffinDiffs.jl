# Getting Started

To demonstrate the basic usage of
[DiffinDiffs.jl](https://github.com/JuliaDiffinDiffs/DiffinDiffs.jl),
we walk through the processes of reproducing empirical results from relevant studies.
Please refer to the original papers for details on the context.

## Dynamic Effects in Event Studies

As a starting point,
we reproduce results from the empirical illustration in [SunA21E](@cite).

### Data Preparation

[DiffinDiffs.jl](https://github.com/JuliaDiffinDiffs/DiffinDiffs.jl)
requires that the data used for estimation
are stored in a column table compatible with the interface defined in
[Tables.jl](https://github.com/JuliaData/Tables.jl).
This means that virtually all types of data frames,
including [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl),
are supported.
For the sake of illustration,
here we directly load the dataset that is bundled with the package
by calling [`exampledata`](@ref):

```@example reprSA
using DiffinDiffs
hrs = exampledata("hrs")
```

In this example, `hhidpn`, `wave`, and `wave_hosp`
are columns for the unit IDs, time IDs and treatment time respectively.
The rest of the columns contain the outcome variables and covariates.
It is important that the time IDs and treatment time
refer to each time period in a compatible way
so that subtracting a value of treatment time from a value of calendar time
(represented by a time ID) with operator `-` yields a meaningful value of relative time,
the amount of time elapsed since treatment time.

### Empirical Specifications

To produce the estimates reported in panel (a) of Table 3 from [SunA21E](@cite),
we specify the estimation via [`@did`](@ref) as follows:

```@example reprSA
r = @did(Reg, data=hrs, dynamic(:wave, -1), notyettreated(11),
    vce=Vcov.cluster(:hhidpn), yterm=term(:oop_spend), treatname=:wave_hosp,
    treatintterms=(), xterms=(fe(:wave)+fe(:hhidpn)))
nothing # hide
```

Before we look at the results,
we briefly explain some of the arguments that are relatively more important.
[`Reg`](@ref), which is a shorthand for [`RegressionBasedDID`](@ref),
is the type of the estimation to be conducted.
Here, we need estimation that is conducted by directly solving least-squares regression
and hence we use [`Reg`](@ref) to inform [`@did`](@ref)
the relevant set of procedures,
which also determines the set of arguments that are accepted by [`@did`](@ref).

We are interested in the dynamic treatment effects.
Hence, we use [`dynamic`](@ref) to specify the data column
containing values representing calendar time of the observations
and the reference period, which is `-1`.
For identification, a crucial assumption underlying DID
is the parallel trends assumption.
Here, we assume that the average outcome paths of units treated in periods before `11`
would be parallel to the observed paths of units treated in period `11`.
That is, we are taking units with treatment time `11` as the not-yet-treated control group.
We specify `treatname` to be `:wave_hosp`,
which indicates the column that contains the treatment time.
The interpretation of `treatname` depends on the context
that is jointly determined by the type of the estimator, the type of the treatment
and possibly the type of parallel trends assumption.
The rest of the arguments provide additional information on the regression specifications.
The use of them can be found in the documentation for [`RegressionBasedDID`](@ref).

We now move on to the result returned by [`@did`](@ref):

```@example reprSA
r # hide
```

The object returned is of type [`RegressionBasedDIDResult`](@ref),
which contains the estimates for treatment-group-specific average treatment effects
among other information.
Instead of printing the estimates from the regression,
which can be very long if there are many treatment groups,
REPL prints a summary table for `r`.
Here we verify that the estimate for relative time `0` among the cohort
who received treatment in period `8` is about `2826`,
the value reported in the third column of Table 3(a) in the paper.

```@example reprSA
coef(r, "wave_hosp: 8 & rel: 0")
```

Various accessor methods are defined for retrieving values from a result such as `r`.
See [Results](@ref) for a full list of them.

### Aggregation of Estimates

The treatment-group-specific estimates in `r`
are typically not the ultimate objects of interest.
We need to estimate the path of the average dynamic treatment effects
across all treatment groups.
Such estimates can be easily obtained
by aggregating the estimates in `r` via [`agg`](@ref):

```@example reprSA
a = agg(r, :rel)
```

Notice that `:rel` is a special value used to indicate that
the aggregation is conducted for each value of relative time separately.
The aggregation takes into account sample weights of each treatment group
and the variance-covariance matrix.
The resulting estimates match those reported in the second column of Table 3(a) exactly.

