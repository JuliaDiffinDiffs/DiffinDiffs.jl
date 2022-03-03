# DiffinDiffs.jl

Welcome to the documentation site for DiffinDiffs.jl!

[DiffinDiffs.jl](https://github.com/JuliaDiffinDiffs/DiffinDiffs.jl)
is a suite of Julia packages for difference-in-differences (DID).
The goal of its development is to promote applications of
the latest advances in econometric methodology related to DID in academic research
while leveraging the performance and composability of the Julia language.

## Why DiffinDiffs.jl?

- **Fast:** Handle datasets of multiple gigabytes with ease
- **Transparent:** Completely open source and natively written in Julia
- **Extensible:** Unified interface with modular package organization

## Package Organization

[DiffinDiffs.jl](https://github.com/JuliaDiffinDiffs/DiffinDiffs.jl)
reexports types, functions and macros defined in
component packages that are separately registered.
The package itself does not host any concrete functionality except documentation.
This facilitates decentralized code development under a unified framework.

| Package | Description | Version | Status |
|:--------|:------------|:--------|:-------|
[DiffinDiffsBase](https://github.com/JuliaDiffinDiffs/DiffinDiffs.jl/tree/master/lib/DiffinDiffsBase) | Base package for DiffinDiffs.jl | [![version](https://juliahub.com/docs/DiffinDiffsBase/version.svg)](https://juliahub.com/ui/Packages/DiffinDiffsBase/AGMId) | [![pkgeval](https://juliahub.com/docs/DiffinDiffsBase/pkgeval.svg)](https://juliahub.com/ui/Packages/DiffinDiffsBase/AGMId) |
[InteractionWeightedDIDs](https://github.com/JuliaDiffinDiffs/DiffinDiffs.jl/tree/master/lib/InteractionWeightedDIDs) | Regression-based multi-period DID | [![version](https://juliahub.com/docs/InteractionWeightedDIDs/version.svg)](https://juliahub.com/ui/Packages/InteractionWeightedDIDs/Vf93d) | [![pkgeval](https://juliahub.com/docs/InteractionWeightedDIDs/pkgeval.svg)](https://juliahub.com/ui/Packages/InteractionWeightedDIDs/Vf93d) |

More components will be included in the future as development moves forward.

## Installation

[DiffinDiffs.jl](https://github.com/JuliaDiffinDiffs/DiffinDiffs.jl)
can be installed with the Julia package manager
[Pkg](https://docs.julialang.org/en/v1/stdlib/Pkg/).
From the Julia REPL, type `]` to enter the Pkg REPL and run:

```
pkg> add DiffinDiffs
```

This will install all the component packages of
[DiffinDiffs.jl](https://github.com/JuliaDiffinDiffs/DiffinDiffs.jl)
as dependencies.
There is no need to explicitly add the individual components
unless one needs to access internal objects.
