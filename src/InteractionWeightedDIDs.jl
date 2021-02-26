module InteractionWeightedDIDs

using Base: Callable
using Dictionaries: Dictionary
using FixedEffectModels: FixedEffectTerm, Combination,
    fe, parse_fixedeffect, basecol, isnested, nunique
using FixedEffects
using LinearAlgebra: Factorization, Symmetric, cholesky!
using Reexport
using SplitApplyCombine: group, mapview
using StatsBase: AbstractWeights, CovarianceEstimator, UnitWeights, PValue, TestStat, NoQuote
using StatsFuns: fdistccdf
using StatsModels: coefnames
using Tables: getcolumn, columnnames
using TypedTables: Table
using Vcov
@reexport using DiffinDiffsBase
using DiffinDiffsBase: termvars, hasintercept, omitsintercept, isintercept, parse_intercept,
    _getsubcolumns, _treatnames

import Base: show
import DiffinDiffsBase: required, default, transformed, combinedargs, copyargs,
    _get_default, valid_didargs, result
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

end
