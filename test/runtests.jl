using Test
using DiffinDiffsBase

using DataAPI: refarray, refvalue, refpool, invrefpool
using DataFrames
using Dates: Date, Year
using DiffinDiffsBase: @fieldequal, unpack, @unpack, checktable, hastreat, parse_treat,
    isintercept, isomitsintercept, parse_intercept!,
    ncol, nrow, _mult!,
    _f, _byid, groupargs, copyargs, pool, checkdata, groupterms, checkvars!, makeweights,
    _totermset!, parse_didargs!, _treatnames, _parse_bycells!, _parse_subset, _nselected,
    treatindex, checktreatindex
using LinearAlgebra: Diagonal
using PooledArrays: PooledArray
using StatsBase: Weights, UnitWeights
using StatsModels: termvars
using Tables: table

import Base: ==, show
import DiffinDiffsBase: required, valid_didargs, result

include("testutils.jl")

const tests = [
    "utils",
    "time",
    "tables",
    "ScaledArrays",
    "terms",
    "treatments",
    "parallels",
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
