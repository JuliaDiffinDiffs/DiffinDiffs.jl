module InteractionWeightedDIDs

using Base: Callable
using Combinatorics: combinations
using Dictionaries: Dictionary
using FixedEffectModels: FixedEffectTerm, Combination,
    fe, has_fe, parse_fixedeffect, basecol, isnested, nunique
using FixedEffects
using LinearAlgebra: Factorization, Symmetric, cholesky!
using Printf
using Reexport
using SplitApplyCombine: group, mapview
using StatsBase: AbstractWeights, CovarianceEstimator, UnitWeights, NoQuote, vcov
using StatsFuns: fdistccdf
using StatsModels: coefnames
using Tables: getcolumn
using TypedTables: Table
using Vcov
@reexport using DiffinDiffsBase
using DiffinDiffsBase: termvars, hasintercept, omitsintercept, isintercept, parse_intercept

import Base: show
import DiffinDiffsBase: required, default, transformed, combinedargs, _getsubcolumns,
    valid_didargs, result
import FixedEffectModels: has_fe

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
       Reg,
       RegressionBasedDIDResult

include("utils.jl")
include("procedures.jl")
include("did.jl")
include("lsweights.jl")

end
