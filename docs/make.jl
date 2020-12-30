using Documenter
using DocumenterTools: Themes
using DiffinDiffs

# Create the themes
for w in ("light", "dark")
    header = read(joinpath(@__DIR__, "src/assets/diffindiffs-style.scss"), String)
    theme = read(joinpath(@__DIR__, "src/assets/diffindiffs-$(w)defs.scss"), String)
    write(joinpath(@__DIR__, "src/assets/diffindiffs-$(w).scss"), header*"\n"*theme)
end
# Compile the themes
Themes.compile(joinpath(@__DIR__, "src/assets/diffindiffs-light.scss"), joinpath(@__DIR__, "src/assets/themes/documenter-light.css"))
Themes.compile(joinpath(@__DIR__, "src/assets/diffindiffs-dark.scss"), joinpath(@__DIR__, "src/assets/themes/documenter-dark.css"))

makedocs(
    modules = [DiffinDiffsBase, InteractionWeightedDIDs],
    format = Documenter.HTML(
        assets = ["assets/favicon.ico", asset("https://fonts.googleapis.com/css?family=Montserrat|Source+Code+Pro&display=swap", class=:css)],
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
    ]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
