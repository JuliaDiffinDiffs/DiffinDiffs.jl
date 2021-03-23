using Test
using InteractionWeightedDIDs

using DataFrames
using DiffinDiffsBase: TimeType, @fieldequal,
    required, default, transformed, combinedargs, valid_didargs
using FixedEffectModels: Combination, nunique
using FixedEffects
using InteractionWeightedDIDs: parse_fixedeffect!, checkvcov!, checkfes!, makefesolver,
    _feresiduals!, makeyxcols, maketreatcols, solveleastsquares!, estvcov
using LinearAlgebra
using StatsBase: Weights, uweights

import Base: ==

==(x::FixedEffect{R,I}, y::FixedEffect{R,I}) where {R,I} =
    x.refs == y.refs && x.interaction == y.interaction && x.n == y.n

# A workaround to be replaced
==(x::Vcov.ClusterCovariance, y::Vcov.ClusterCovariance) = true

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
