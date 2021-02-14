module InteractionWeightedDIDs

using Base: Callable
using Combinatorics: combinations
using Dictionaries: Dictionary
using FixedEffectModels: Vcov
using FixedEffectModels: FixedEffectTerm, Combination,
    fe, has_fe, parse_fixedeffect, omitsintercept, hasintercept,
    basecol, isnested, tss, Fstat
using FixedEffects
using LinearAlgebra: Symmetric, cholesky!
using Printf
using Reexport
using SplitApplyCombine: group, groupfind, groupreduce
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
       SolveLeastSquares,
       
       RegressionBasedDID,
       Reg

include("utils.jl")
include("procedures.jl")
include("did.jl")
include("lsweights.jl")

end
