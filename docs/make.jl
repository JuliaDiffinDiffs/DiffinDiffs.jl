using Documenter
using DiffinDiffs

makedocs(
    modules = [DiffinDiffsBase, InteractionWeightedDIDs],
    format = Documenter.HTML(
        canonical = "https://JuliaDiffinDiffs.github.io/DiffinDiffs.jl/stable/",
        prettyurls = get(ENV, "CI", nothing) == "true",
        collapselevel = 1
    ),
    sitename = "DiffinDiffs.jl",
    authors = "Junyuan Chen",
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "Getting Started" => "man/getting-started.md"
        ],
        "Library" => [
            "Treatment Types" => "lib/treatments.md",
            "Parallel Types" => "lib/parallels.md",
            "Treatment Terms" => "lib/terms.md",
            "Miscellanea" => "lib/miscellanea.md"
        ],
        "About" => [
        ]
    ],
    workdir = joinpath(@__DIR__, "..")
)

deploydocs(
    repo = "github.com/JuliaDiffinDiffs/DiffinDiffs.jl.git",
    devbranch = "master"
)
