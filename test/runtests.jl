using Test
using InteractionWeightedDIDs

using DataFrames
using Dates: Date, Year
using DiffinDiffsBase: ValidTimeType, @fieldequal,
    required, default, transformed, combinedargs, _byid, valid_didargs
using FixedEffectModels: Combination, nunique, _multiply
using FixedEffects
using InteractionWeightedDIDs: FETerm, _parsefeterm, getfename,
    checkvcov!, parsefeterms!, groupfeterms, makefes, checkfes!, makefesolver,
    _feresiduals!, makeyxcols, maketreatcols, solveleastsquares!, estvcov,
    solveleastsquaresweights
using LinearAlgebra
using StatsBase: Weights, uweights

import Base: ==

@fieldequal FixedEffect
@fieldequal Vcov.ClusterCovariance
@fieldequal RegressionBasedDIDResult

const tests = [
    "utils",
    "procedures",
    "did"
]

printstyled("Running tests:\n", color=:blue, bold=true)

@time for test in tests
    include("$test.jl")
    println("\033[1m\033[32mPASSED\033[0m: $(test)")
end
