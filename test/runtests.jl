using Test
using DiffinDiffsBase

using DataFrames
using DiffinDiffsBase: @fieldequal, unpack, @unpack, hastreat, parse_treat,
    isintercept, isomitsintercept, parse_intercept!,
    _f, _byid, groupargs, copyargs, pool, checkdata, groupterms, checkvars!, makeweights,
    _totermset!, parse_didargs!, _treatnames
using PooledArrays: PooledArray
using StatsBase: Weights, UnitWeights
using StatsModels: termvars
using TypedTables: Table

import Base: ==, show
import DiffinDiffsBase: required, valid_didargs, result

include("testutils.jl")

const tests = [
    "utils",
    "terms",
    "treatments",
    "parallels",
    "SubColumns",
    "operations",
    "StatsProcedures",
    "procedures",
    "did"
]

printstyled("Running tests:\n", color=:blue, bold=true)

@time for test in tests
    include("$test.jl")
    println("\033[1m\033[32mPASSED\033[0m: $(test)")
end
