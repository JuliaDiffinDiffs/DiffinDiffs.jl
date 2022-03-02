# Redirect test to the library package if TEST_TARGET is set
using Pkg
tar = get(ENV, "TEST_TARGET", nothing)
libpath = joinpath(dirname(@__DIR__), "lib")
if tar in readdir(libpath)
    Pkg.test(tar; coverage=true)
    exit()
end

using Test
using DiffinDiffs
using Documenter

@time doctest(DiffinDiffs)
