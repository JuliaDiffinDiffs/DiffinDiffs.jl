using Documenter
using DiffinDiffs
using DocumenterCitations
using StatsProcedures
using Vcov

bib = CitationBibliography(joinpath(@__DIR__, "../paper/paper.bib"), sorting=:nyt)

makedocs(bib,
    modules = [DiffinDiffsBase, InteractionWeightedDIDs],
    format = Documenter.HTML(
        assets = ["assets/favicon.ico"],
        canonical = "https://JuliaDiffinDiffs.github.io/DiffinDiffs.jl/stable/",
        prettyurls = get(ENV, "CI", nothing) == "true",
        collapselevel = 2,
        ansicolor = true
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
            "Formula Terms" => "lib/terms.md",
            "Estimators" => "lib/estimators.md",
            "Inference" => "lib/inference.md",
            "Procedures" => "lib/procedures.md",
            "Results" => "lib/results.md",
            "Tables" => "lib/tables.md",
            "Panel Operations" => "lib/panel.md",
            "ScaledArrays" => "lib/ScaledArrays.md",
            "StatsProcedures" => "lib/StatsProcedures.md",
            "Miscellanea" => "lib/miscellanea.md"
        ],
        "About" => [
            "References" => "about/references.md",
            "License" => "about/license.md"
        ]
    ],
    workdir = joinpath(@__DIR__, ".."),
    doctest = false
)

deploydocs(
    repo = "github.com/JuliaDiffinDiffs/DiffinDiffs.jl.git",
    devbranch = "master"
)
