using Test
using InteractionWeightedDIDs

using DataFrames
using Dictionaries
using DiffinDiffsBase: required, default, transformed, combinedargs
using FixedEffects
using InteractionWeightedDIDs: checkvcov!, checkfes!, makefesolver,
    _feresiduals!, makeyxcols, maketreatcols, solveleastsquares
using StatsBase: Weights, uweights

import Base: ==

==(x::FixedEffect{R,I}, y::FixedEffect{R,I}) where {R,I} =
    x.refs == y.refs && x.interaction == y.interaction && x.n == y.n

const tests = [
    "procedures"
]

printstyled("Running tests:\n", color=:blue)

for test in tests
    include("$test.jl")
    println("\033[1m\033[32mPASSED\033[0m: $(test)")
end
