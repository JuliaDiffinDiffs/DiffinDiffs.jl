module InteractionWeightedDIDs

using Base: Callable
using FixedEffectModels: FixedEffectTerm, Combination,
    fe, _parse_fixedeffect, basecol, isnested, nunique
using FixedEffects
using LinearAlgebra: Cholesky, Factorization, Symmetric, cholesky!
using Reexport
using StatsBase: AbstractWeights, CovarianceEstimator, UnitWeights, PValue, TestStat, NoQuote
using StatsFuns: fdistccdf
using StatsModels: coefnames
using Tables
using Tables: getcolumn, columnnames
using Vcov
@reexport using DiffinDiffsBase
using DiffinDiffsBase: TimeType, termvars, isintercept, parse_intercept!, _treatnames

import Base: show
import DiffinDiffsBase: required, default, transformed, combinedargs, copyargs,
    valid_didargs, result, _count!
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
