module InteractionWeightedDIDs

using Base: Callable
using DataAPI: refarray
using FixedEffectModels: FixedEffectTerm, Combination,
    fe, fesymbol, _multiply, invsym!, isnested, nunique
using FixedEffects
using LinearAlgebra: Cholesky, Factorization, Symmetric, cholesky!, diag
using Reexport
using StatsBase: AbstractWeights, CovarianceEstimator, UnitWeights, PValue, TestStat, NoQuote
using StatsFuns: fdistccdf
using StatsModels: coefnames
using Tables
using Tables: getcolumn, columnnames
using Vcov
@reexport using DiffinDiffsBase
using DiffinDiffsBase: ValidTimeType, termvars, isintercept, parse_intercept!,
    _count!, _groupfind, _treatnames, _parse_bycells!, _parse_subset

import Base: show
import DiffinDiffsBase: required, default, transformed, combinedargs, copyargs,
    valid_didargs, result, vce, treatment, nobs, outcomename, weights, treatnames,
    dof_residual, agg, post!, _parse_subset
import FixedEffectModels: has_fe

export Vcov,
       fe

export CheckVcov,
       ParseFEterms,
       GroupFEterms,
       MakeFEs,
       CheckFEs,
       MakeFESolver,
       MakeYXCols,
       MakeTreatCols,
       SolveLeastSquares,
       EstVcov,
       SolveLeastSquaresWeights,
       
       RegressionBasedDID,
       Reg,
       RegressionBasedDIDResult,
       has_fe,
       AggregatedRegDIDResult,
       has_lsweights,
       ContrastResult,
       contrast

include("utils.jl")
include("procedures.jl")
include("did.jl")

end
