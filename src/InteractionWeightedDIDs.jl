module InteractionWeightedDIDs

using Base: Callable
using Combinatorics: combinations
using Dictionaries
using FixedEffectModels: Vcov
using FixedEffectModels: FixedEffectTerm, Combination,
    fe, has_fe, parse_fixedeffect, omitsintercept, hasintercept, isnested, tss, Fstat
using FixedEffects
using LinearAlgebra
using Printf
using Reexport
using SplitApplyCombine: groupfind
using StatsBase: AbstractWeights, UnitWeights, NoQuote
using StatsModels: termvars, FullRank
using Tables: columntable, getcolumn, rowtable
using TypedTables: Table
@reexport using DiffinDiffsBase

import Base: show
import DiffinDiffsBase: required, default, transformed, combinedargs, _getsubcolumns

export Vcov,
       fe

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
