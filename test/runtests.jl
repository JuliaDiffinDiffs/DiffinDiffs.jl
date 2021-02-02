using Test
using DiffinDiffsBase

using DataFrames
using DiffinDiffsBase: unpack, @unpack, hastreat, parse_treat,
    _f, checkdata, checkvars!, makeweights, parse_didargs
using StatsBase: Weights, UnitWeights
using StatsModels: termvars

import DiffinDiffsBase: valid_didargs, namedargs

include("testutils.jl")

const tests = [
    "utils",
    "terms",
    "treatments",
    "parallels",
    "StatsProcedures",
    "procedures",
    "did"
]

printstyled("Running tests:\n", color=:blue)

for test in tests
    include("$test.jl")
    println("\033[1m\033[32mPASSED\033[0m: $(test)")
end
