module InteractionWeightedDIDs

using Base: Callable
using Combinatorics: combinations
using Dictionaries: Dictionary
using FixedEffectModels: FixedEffectTerm, Combination,
    fe, has_fe, parse_fixedeffect, omitsintercept, hasintercept,
    basecol, isnested, tss, Fstat, nunique
using FixedEffects
using LinearAlgebra: Factorization, Symmetric, cholesky!
using Printf
using Reexport
using SplitApplyCombine: group, groupfind, groupreduce
using StatsBase: AbstractWeights, UnitWeights, NoQuote, vcov
using StatsModels: termvars, FullRank
using Tables: columntable, getcolumn, rowtable
using TypedTables: Table
using Vcov
@reexport using DiffinDiffsBase

import Base: show
import DiffinDiffsBase: required, default, transformed, combinedargs, _getsubcolumns

# Handle naming conflicts
const getvcov = vcov

export Vcov,
       fe

export CheckVcov,
       CheckFEs,
       MakeFESolver,
       MakeYXCols,
       MakeTreatCols,
       SolveLeastSquares,
       EstVcov,
       
       RegressionBasedDID,
       Reg

include("utils.jl")
include("procedures.jl")
include("did.jl")
include("lsweights.jl")

end
