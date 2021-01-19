using Test
using DiffinDiffsBase

using StatsModels: termvars

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
