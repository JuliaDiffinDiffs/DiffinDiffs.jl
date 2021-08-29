using Test
using DiffinDiffsBase

using DataAPI: refarray, refvalue, refpool, invrefpool
using DataFrames
using Dates: Date, Year
using DiffinDiffsBase: @fieldequal, unpack, @unpack, checktable, hastreat, parse_treat,
    isintercept, isomitsintercept, parse_intercept!,
    ncol, nrow, _mult!,
    checkdata!, grouptreatintterms, groupxterms, groupcontrasts,
    checkvars!, groupsample, makeweights,
    _totermset!, parse_didargs!, _treatnames, _parse_bycells!, _parse_subset, _nselected,
    treatindex, checktreatindex, DefaultExportFormat
using LinearAlgebra: Diagonal
using Missings: allowmissing, disallowmissing
using PooledArrays: PooledArray
using StatsBase: Weights, UnitWeights
using StatsModels: termvars
using StatsProcedures: _f, _byid, groupargs, copyargs, pool
using Tables: table

import Base: ==, show
import DiffinDiffsBase: valid_didargs
import StatsProcedures: required, result

include("testutils.jl")

const tests = [
    "tables",
    "utils",
    "time",
    "ScaledArrays",
    "terms",
    "treatments",
    "parallels",
    "operations",
    "procedures",
    "did"
]

printstyled("Running tests:\n", color=:blue, bold=true)

@time for test in tests
    include("$test.jl")
    println("\033[1m\033[32mPASSED\033[0m: $(test)")
end
