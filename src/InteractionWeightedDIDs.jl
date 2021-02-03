module InteractionWeightedDIDs

using Base: Callable
using Combinatorics: combinations
using FixedEffectModels: Vcov
using FixedEffectModels: FixedEffectTerm, Combination,
    fe, has_fe, parse_fixedeffect, omitsintercept, hasintercept, isnested, tss, Fstat
using FixedEffects
using LinearAlgebra
using Printf
using Reexport
using StatsBase: AbstractWeights, UnitWeights, NoQuote
using StatsModels: FullRank
using Tables: columntable, getcolumn
using TypedTables: Table
@reexport using DiffinDiffsBase

import Base: show
import DiffinDiffsBase: namedargs, _getargs, _combinedargs, _getsubcolumns

export CheckVcov,
       CheckFEs,
       MakeFESolver,
       MakeYXCols,
       MakeTreatCols,
       
       RegressionBasedDID,
       Reg

include("fe.jl")
include("procedures.jl")
include("did.jl")
include("lsweights.jl")

end
