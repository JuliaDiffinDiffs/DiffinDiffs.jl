using Test
using InteractionWeightedDIDs

using DataFrames
using Dictionaries
using DiffinDiffsBase: required, default, transformed, combinedargs, valid_didargs
using FixedEffectModels: Combination, nunique
using FixedEffects
using InteractionWeightedDIDs: checkvcov!, checkfes!, makefesolver,
    _feresiduals!, makeyxcols, maketreatcols, solveleastsquares!, estvcov
using LinearAlgebra
using StatsBase: Weights, uweights
using StatsModels: ConstantTerm, ContinuousTerm, schema, apply_schema

import Base: ==

==(x::FixedEffect{R,I}, y::FixedEffect{R,I}) where {R,I} =
    x.refs == y.refs && x.interaction == y.interaction && x.n == y.n

const tests = [
    "procedures",
    "did"
]

printstyled("Running tests:\n", color=:blue)

for test in tests
    include("$test.jl")
    println("\033[1m\033[32mPASSED\033[0m: $(test)")
end
