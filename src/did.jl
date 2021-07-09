"""
    RegressionBasedDID <: DiffinDiffsEstimator

Estimation procedure for regression-based difference-in-differences.

A `StatsSpec` for this procedure accepts the following arguments:

| Key | Type restriction | Default value | Description |
|:---|:---|:---|:---|
| `data` | | | A `Tables.jl`-compatible data table |
| `tr` | `DynamicTreatment{SharpDesign}` | | Treatment specification |
| `pr` | `TrendOrUnspecifiedPR{Unconditional,Exact}` | | Parallel trend assumption |
| `yterm` | `AbstractTerm` | | A term for outcome variable |
| `treatname` | `Symbol` | | Column name for the variable representing treatment time |
| `subset` | `Union{BitVector,Nothing}` | `nothing` | Rows from `data` to be used for estimation |
| `weightname` | `Union{Symbol,Nothing}` | `nothing` | Column name of the sample weight variable |
| `vce` | `Vcov.CovarianceEstimator` | `Vcov.CovarianceEstimator` | Variance-covariance estimator |
| `treatintterms` | `TermSet` | `TermSet()` | Terms interacted with the treatment indicators |
| `xterms` | `TermSet` | `TermSet()` | Terms for covariates and fixed effects |
| `contrasts` | `Union{Dict{Symbol,Any},Nothing}` | `nothing` | Contrast coding to be processed by `StatsModels.jl` |
| `drop_singletons` | `Bool` | `true` | Drop singleton observations for fixed effects |
| `nfethreads` | `Int` | `Threads.nthreads()` | Number of threads to be used for solving fixed effects |
| `fetol` | `Float64` | `1e-8` | Tolerance level for the fixed effect solver |
| `femaxiter` | `Int` | `10000` | Maximum number of iterations allowed for the fixed effect solver |
| `cohortinteracted` | `Bool` | `true` | Interact treatment indicators by treatment time |
| `solvelsweights` | `Bool` | `false` | Solve the cell-level least-square weights with default cell partition |
| `lswtnames` | Iterable of `Symbol`s | `tuple()` | Column names from `treatcells` defining the cell partition used for solving least-square weights |
"""
const RegressionBasedDID = DiffinDiffsEstimator{:RegressionBasedDID,
    Tuple{CheckData, GroupTreatintterms, GroupXterms, GroupContrasts,
    CheckVcov, CheckVars, GroupSample,
    ParseFEterms, GroupFEterms, MakeFEs, CheckFEs, MakeWeights, MakeFESolver,
    MakeYXCols, MakeTreatCols, SolveLeastSquares, EstVcov, SolveLeastSquaresWeights}}

"""
    Reg <: DiffinDiffsEstimator

Alias for [`RegressionBasedDID`](@ref).
"""
const Reg = RegressionBasedDID

function valid_didargs(d::Type{Reg}, ::DynamicTreatment{SharpDesign},
        ::TrendOrUnspecifiedPR{Unconditional,Exact}, args::Dict{Symbol,Any})
    name = get(args, :name, "")::String
    treatintterms = haskey(args, :treatintterms) ? args[:treatintterms] : TermSet()
    xterms = haskey(args, :xterms) ? args[:xterms] : TermSet()
    solvelsweights = haskey(args, :lswtnames) || get(args, :solvelsweights, false)::Bool
    ntargs = (data=args[:data],
        tr=args[:tr]::DynamicTreatment{SharpDesign},
        pr=args[:pr]::TrendOrUnspecifiedPR{Unconditional,Exact},
        yterm=args[:yterm]::AbstractTerm,
        treatname=args[:treatname]::Symbol,
        subset=get(args, :subset, nothing)::Union{BitVector,Nothing},
        weightname=get(args, :weightname, nothing)::Union{Symbol,Nothing},
        vce=get(args, :vce, Vcov.RobustCovariance())::Vcov.CovarianceEstimator,
        treatintterms=treatintterms::TermSet,
        xterms=xterms::TermSet,
        contrasts=get(args, :contrasts, nothing)::Union{Dict{Symbol,Any},Nothing},
        drop_singletons=get(args, :drop_singletons, true)::Bool,
        nfethreads=get(args, :nfethreads, Threads.nthreads())::Int,
        fetol=get(args, :fetol, 1e-8)::Float64,
        femaxiter=get(args, :femaxiter, 10000)::Int,
        cohortinteracted=get(args, :cohortinteracted, true)::Bool,
        solvelsweights=solvelsweights::Bool,
        lswtnames=get(args, :lswtnames, ()))
    return name, d, ntargs
end

"""
    RegressionBasedDIDResult{TR,CohortInteracted,Haslsweights} <: DIDResult{TR}

Estimation results from regression-based difference-in-differences.

# Fields
- `coef::Vector{Float64}`: coefficient estimates.
- `vcov::Matrix{Float64}`: variance-covariance matrix for the estimates.
- `vce::CovarianceEstimator`: variance-covariance estiamtor.
- `tr::TR`: treatment specification.
- `pr::AbstractParallel`: parallel trend assumption.
- `treatweights::Vector{Float64}`: total sample weights from observations for which the corresponding treatment indicator takes one.
- `treatcounts::Vector{Int}`: total number of observations for which the corresponding treatment indicator takes one.
- `esample::BitVector`: indicator for the rows from `data` involved in estimation.
- `nobs::Int`: number of observations involved in estimation.
- `dof_residual::Int`: residual degree of freedom.
- `F::Float64`: F-statistic for overall significance of regression model.
- `p::Float64`: p-value corresponding to the F-statistic.
- `yname::String`: name of the outcome variable.
- `coefnames::Vector{String}`: coefficient names.
- `coefinds::Dict{String, Int}`: a map from `coefnames` to integer indices for retrieving estimates by name.
- `treatcells::VecColumnTable`: a tabular description of cells where a treatment indicator takes one.
- `treatname::Symbol`: column name for the variable representing treatment time.
- `yxterms::Dict{AbstractTerm, AbstractTerm}`: a map from all specified terms to concrete terms.
- `yterm::AbstractTerm`: the specified term for outcome variable.
- `xterms::Vector{AbstractTerm}`: the specified terms for covariates and fixed effects.
- `contrasts::Union{Dict{Symbol, Any}, Nothing}`: contrast coding to be processed by `StatsModels.jl`.
- `weightname::Union{Symbol, Nothing}`: column name of the sample weight variable.
- `fenames::Vector{String}`: names of the fixed effects.
- `nfeiterations::Union{Int, Nothing}`: number of iterations for the fixed effect solver to reach convergence.
- `feconverged::Union{Bool, Nothing}`: whether the fixed effect solver has converged.
- `nfesingledropped::Int`: number of singleton observations for fixed effects that have been dropped.
- `lsweights::Union{TableIndexedMatrix, Nothing}`: cell-level least-square weights.
- `cellymeans::Union{Vector{Float64}, Nothing}`: cell-level averages of the outcome variable.
- `cellweights::Union{Vector{Float64}, Nothing}`: total sample weights for each cell.
- `cellcounts::Union{Vector{Int}, Nothing}`: number of observations for each cell.
"""
struct RegressionBasedDIDResult{TR,CohortInteracted,Haslsweights} <: DIDResult{TR}
    coef::Vector{Float64}
    vcov::Matrix{Float64}
    vce::CovarianceEstimator
    tr::TR
    pr::AbstractParallel
    treatweights::Vector{Float64}
    treatcounts::Vector{Int}
    esample::BitVector
    nobs::Int
    dof_residual::Int
    F::Float64
    p::Float64
    yname::String
    coefnames::Vector{String}
    coefinds::Dict{String, Int}
    treatcells::VecColumnTable
    treatname::Symbol
    yxterms::Dict{AbstractTerm, AbstractTerm}
    yterm::AbstractTerm
    xterms::Vector{AbstractTerm}
    contrasts::Union{Dict{Symbol, Any}, Nothing}
    weightname::Union{Symbol, Nothing}
    fenames::Vector{String}
    nfeiterations::Union{Int, Nothing}
    feconverged::Union{Bool, Nothing}
    nfesingledropped::Int
    lsweights::Union{TableIndexedMatrix{Float64, Matrix{Float64}, VecColumnTable, VecColumnTable}, Nothing}
    cellymeans::Union{Vector{Float64}, Nothing}
    cellweights::Union{Vector{Float64}, Nothing}
    cellcounts::Union{Vector{Int}, Nothing}
end

function result(::Type{Reg}, @nospecialize(nt::NamedTuple))
    yterm = nt.yxterms[nt.yterm]
    yname = coefnames(yterm)
    cnames = _treatnames(nt.treatcells)
    cnames = append!(cnames, coefnames.(nt.xterms))[nt.basiscols]
    coefinds = Dict(cnames .=> 1:length(cnames))
    didresult = RegressionBasedDIDResult{typeof(nt.tr),
        nt.cohortinteracted, nt.lsweights!==nothing}(
        nt.coef, nt.vcov_mat, nt.vce, nt.tr, nt.pr, nt.treatweights, nt.treatcounts,
        nt.esample, sum(nt.esample), nt.dof_resid, nt.F, nt.p,
        yname, cnames, coefinds, nt.treatcells, nt.treatname, nt.yxterms,
        yterm, nt.xterms, nt.contrasts, nt.weightname,
        nt.fenames, nt.nfeiterations, nt.feconverged, nt.nsingle,
        nt.lsweights, nt.cellymeans, nt.cellweights, nt.cellcounts)
    return merge(nt, (result=didresult,))
end

"""
    has_fe(r::RegressionBasedDIDResult)

Test whether any fixed effect is involved in regression.
"""
has_fe(r::RegressionBasedDIDResult) = !isempty(r.fenames)

_top_info(r::RegressionBasedDIDResult) = (
    "Number of obs" => nobs(r),
    "Degrees of freedom" => nobs(r) - dof_residual(r),
    "F-statistic" => TestStat(r.F),
    "p-value" => PValue(r.p)
)

_nunique(t, s::Symbol) = length(unique(getproperty(t, s)))

_excluded_rel_str(tr::DynamicTreatment) =
    isempty(tr.exc) ? "none" : join(string.(tr.exc), " ")

_treat_info(r::RegressionBasedDIDResult{<:DynamicTreatment, true}) = (
    "Number of cohorts" => _nunique(r.treatcells, r.treatname),
    "Interactions within cohorts" => length(columnnames(r.treatcells)) - 2,
    "Relative time periods" => _nunique(r.treatcells, :rel),
    "Excluded periods" => NoQuote(_excluded_rel_str(r.tr))
)

_treat_info(r::RegressionBasedDIDResult{<:DynamicTreatment, false}) = (
    "Relative time periods" => _nunique(r.treatcells, :rel),
    "Excluded periods" => NoQuote(_excluded_rel_str(r.tr))
)

_treat_spec(r::RegressionBasedDIDResult{DynamicTreatment{SharpDesign}, true}) =
    "Cohort-interacted sharp dynamic specification"

_treat_spec(r::RegressionBasedDIDResult{DynamicTreatment{SharpDesign}, false}) =
    "Sharp dynamic specification"

_fe_info(r::RegressionBasedDIDResult) = (
    "Converged" => r.feconverged,
    "Singletons dropped" => r.nfesingledropped
)

show(io::IO, ::RegressionBasedDIDResult) = print(io, "Regression-based DID result")

function show(io::IO, ::MIME"text/plain", r::RegressionBasedDIDResult;
        totalwidth::Int=70, interwidth::Int=4+mod(totalwidth,2))
    halfwidth = div(totalwidth-interwidth, 2)
    top_info = _top_info(r)
    fe_info = has_fe(r) ? _fe_info(r) : ()
    tr_info = _treat_info(r)
    blocks = (top_info, tr_info, fe_info)
    fes = has_fe(r) ? join(string.(r.fenames), " ") : "none"
    fetitle = string("Fixed effects: ", fes)
    blocktitles = ("Summary of results: Regression-based DID",
        _treat_spec(r), fetitle[1:min(totalwidth,length(fetitle))])

    for (ib, b) in enumerate(blocks)
        println(io, repeat('─', totalwidth))
        println(io, blocktitles[ib])
        if !isempty(b)
            # Print line between block title and block content
            println(io, repeat('─', totalwidth))
            for (i, e) in enumerate(b)
                print(io, e[1], ':')
                print(io, lpad(e[2], halfwidth - length(e[1]) - 1))
                print(io, isodd(i) ? repeat(' ', interwidth) : '\n')
            end
        end
    end
    print(io, repeat('─', totalwidth))
end

"""
    AggregatedRegDIDResult{TR,Haslsweights,P<:RegressionBasedDIDResult,I} <: AggregatedDIDResult{TR,P}

Estimation results aggregated from a [`RegressionBasedDIDResult`](@ref).
See also [`agg`](@ref).

# Fields
- `parent::P`: the [`RegressionBasedDIDResult`](@ref) from which the results are generated.
- `inds::I`: indices of the coefficient estimates from `parent` used to generate the results.
- `coef::Vector{Float64}`: coefficient estimates.
- `vcov::Matrix{Float64}`: variance-covariance matrix for the estimates.
- `coefweights::Matrix{Float64}`: coefficient weights used to aggregate the coefficient estimates from `parent`.
- `treatweights::Vector{Float64}`: sum of `treatweights` from `parent` over combined `treatcells`.
- `treatcounts::Vector{Int}`: sum of `treatcounts` from `parent` over combined `treatcells`.
- `coefnames::Vector{String}`: coefficient names.
- `coefinds::Dict{String, Int}`: a map from `coefnames` to integer indices for retrieving estimates by name.
- `treatcells::VecColumnTable`: cells combined from the `treatcells` from `parent`.
- `lsweights::Union{TableIndexedMatrix, Nothing}`: cell-level least-square weights.
- `cellymeans::Union{Vector{Float64}, Nothing}`: cell-level averages of the outcome variable.
- `cellweights::Union{Vector{Float64}, Nothing}`: total sample weights for each cell.
- `cellcounts::Union{Vector{Int}, Nothing}`: number of observations for each cell.
"""
struct AggregatedRegDIDResult{TR,Haslsweights,P<:RegressionBasedDIDResult,I} <: AggregatedDIDResult{TR,P}
    parent::P
    inds::I
    coef::Vector{Float64}
    vcov::Matrix{Float64}
    coefweights::Matrix{Float64}
    treatweights::Vector{Float64}
    treatcounts::Vector{Int}
    coefnames::Vector{String}
    coefinds::Dict{String, Int}
    treatcells::VecColumnTable
    lsweights::Union{TableIndexedMatrix{Float64, Matrix{Float64}, VecColumnTable, VecColumnTable}, Nothing}
    cellymeans::Union{Vector{Float64}, Nothing}
    cellweights::Union{Vector{Float64}, Nothing}
    cellcounts::Union{Vector{Int}, Nothing}
end

"""
    agg(r::RegressionBasedDIDResult{<:DynamicTreatment}, names=nothing; kwargs...)

Aggregate coefficient estimates from `r` by values taken by
the columns from `r.treatcells` indexed by `names`
with weights proportional to `treatweights` within each relative time.

# Keywords
- `bys=nothing`: columnwise transformations over `r.treatcells` before grouping by `names`.
- `subset=nothing`: subset of treatment coefficients used for aggregation.
"""
function agg(r::RegressionBasedDIDResult{<:DynamicTreatment}, names=nothing;
        bys=nothing, subset=nothing)
    inds = subset === nothing ? Colon() : _parse_subset(r, subset, false)
    ptcells = treatcells(r)
    bycells = view(ptcells, inds)
    _parse_bycells!(getfield(bycells, :columns), ptcells, bys)
    names === nothing || (bycells = subcolumns(bycells, names, nomissing=false))

    tcells, rows = cellrows(bycells, findcell(bycells))
    ncell = length(rows)
    pcf = view(treatcoef(r), inds)
    cweights = zeros(length(pcf), ncell)
    ptreatweights = view(r.treatweights, inds)
    ptreatcounts = view(r.treatcounts, inds)
    # Ensure the weights for each relative time always sum up to one
    rels = view(r.treatcells.rel, inds)
    for (i, rs) in enumerate(rows)
        if length(rs) > 1
            relgroups = _groupfind(view(rels, rs))
            for ids in values(relgroups)
                if length(ids) > 1
                    cwts = view(ptreatweights, view(rs, ids))
                    cweights[view(rs, ids), i] .= cwts ./ sum(cwts)
                else
                    cweights[rs[ids[1]], i] = 1.0
                end
            end
        else
            cweights[rs[1], i] = 1.0
        end
    end
    cf = cweights' * pcf
    v = cweights' * view(treatvcov(r), inds, inds) * cweights
    treatweights = [sum(ptreatweights[rows[i]]) for i in 1:ncell]
    treatcounts = [sum(ptreatcounts[rows[i]]) for i in 1:ncell]
    cnames = _treatnames(tcells)
    coefinds = Dict(cnames .=> keys(cnames))
    if r.lsweights === nothing
        lswt = nothing
    else
        lswtmat = view(r.lsweights.m, :, inds) * cweights
        lswt = TableIndexedMatrix(lswtmat, r.lsweights.r, tcells)
    end
    return AggregatedRegDIDResult{typeof(r.tr), lswt!==nothing, typeof(r), typeof(inds)}(
        r, inds, cf, v, cweights, treatweights, treatcounts, cnames, coefinds, tcells,
        lswt, r.cellymeans, r.cellweights, r.cellcounts)
end

vce(r::AggregatedRegDIDResult) = vce(parent(r))
treatment(r::AggregatedRegDIDResult) = treatment(parent(r))
nobs(r::AggregatedRegDIDResult) = nobs(parent(r))
outcomename(r::AggregatedRegDIDResult) = outcomename(parent(r))
weights(r::AggregatedRegDIDResult) = weights(parent(r))
treatnames(r::AggregatedRegDIDResult) = coefnames(r)
dof_residual(r::AggregatedRegDIDResult) = dof_residual(parent(r))

"""
    RegDIDResultOrAgg{TR,Haslsweights}

Union type of [`RegressionBasedDIDResult`](@ref) and [`AggregatedRegDIDResult`](@ref).
"""
const RegDIDResultOrAgg{TR,Haslsweights} =
    Union{RegressionBasedDIDResult{TR,<:Any,Haslsweights},
    AggregatedRegDIDResult{TR,Haslsweights}}

"""
    has_lsweights(r::RegDIDResultOrAgg)

Test whether `r` contains computed least-sqaure weights (`r.lsweights!==nothing`).
"""
has_lsweights(::RegDIDResultOrAgg{TR,H}) where {TR,H} = H

"""
    ContrastResult{T,M,R,C} <: AbstractMatrix{T}

Matrix type that holds least-square weights obtained from one or more
[`RegDIDResultOrAgg`](@ref)s computed over the same set of cells
and cell-level averages.
See also [`contrast`](@ref).

The least-square weights are stored in a `Matrix` that can be retrieved
with property name `:m`,
where the weights for each treatment coefficient
are stored columnwise starting from the second column and
the first column contains the cell-level averages of outcome variable.
The indices for cells can be accessed with property name `:r`;
and indices for identifying the coefficients can be accessed with property name `:c`.
The [`RegDIDResultOrAgg`](@ref)s used to generate the `ContrastResult`
can be accessed by calling `parent`.
"""
struct ContrastResult{T,M,R,C} <: AbstractMatrix{T}
    rs::Vector{RegDIDResultOrAgg}
    m::TableIndexedMatrix{T,M,R,C}
    function ContrastResult(rs::Vector{RegDIDResultOrAgg},
            m::TableIndexedMatrix{T,M,R,C}) where {T,M,R,C}
        cnames = columnnames(m.c)
        cnames[1]==:iresult && cnames[2]==:icoef && cnames[3]==:name || throw(ArgumentError(
            "Table paired with column indices has unaccepted column names"))
        return new{T,M,R,C}(rs, m)
    end
end

_getmat(cr::ContrastResult) = getfield(cr, :m)
Base.size(cr::ContrastResult) = size(_getmat(cr))
Base.getindex(cr::ContrastResult, i) = _getmat(cr)[i]
Base.getindex(cr::ContrastResult, i, j) = _getmat(cr)[i,j]
Base.IndexStyle(::Type{<:ContrastResult{T,M}}) where {T,M} = IndexStyle(M)
Base.getproperty(cr::ContrastResult, n::Symbol) = getproperty(_getmat(cr), n)
Base.parent(cr::ContrastResult) = getfield(cr, :rs)

"""
    contrast(r1::RegDIDResultOrAgg, rs::RegDIDResultOrAgg...)

Construct a [`ContrastResult`](@ref) by collecting the computed least-square weights
from each of the [`RegDIDResultOrAgg`](@ref).
"""
function contrast(r1::RegDIDResultOrAgg, rs::RegDIDResultOrAgg...)
    has_lsweights(r1) && all(r->has_lsweights(r), rs) || throw(ArgumentError(
        "Results must contain computed least-sqaure weights"))
    ri = r1.lsweights.r
    ncoef = ntreatcoef(r1)
    m = r1.lsweights.m
    for r in rs
        r.lsweights.r == ri || throw(ArgumentError(
            "Cells for least-square weights comparisons must be identical across the inputs"))
        ncoef += ntreatcoef(r)
    end
    rs = RegDIDResultOrAgg[r1, rs...]
    m = hcat(r1.cellymeans, (r.lsweights.m for r in rs)...)
    rinds = vcat(0, (fill(i+1, ntreatcoef(r)) for (i, r) in enumerate(rs))...)
    cinds = vcat(0, (1:ntreatcoef(r) for r in rs)...)
    names = vcat("cellymeans", (treatnames(r) for r in rs)...)
    ci = VecColumnTable((iresult=rinds, icoef=cinds, name=names))
    return ContrastResult(rs, TableIndexedMatrix(m, ri, ci))
end

function Base.:(==)(x::ContrastResult, y::ContrastResult)
    # Assume no missing
    x.m == y.m || return false
    x.r == y.r || return false
    x.c == y.c || return false
    return parent(x) == parent(y)
end

function Base.sort!(cr::ContrastResult; @nospecialize(kwargs...))
    p = sortperm(cr.r; kwargs...)
    @inbounds for col in cr.r
        col .= col[p]
    end
    @inbounds cr.m .= cr.m[p,:]
    return cr
end

_parse_subset(cr::ContrastResult, by::Pair) = (inds = apply(cr.r, by); return inds)

function _parse_subset(cr::ContrastResult, inds)
    eltype(inds) <: Pair || return inds
    inds = apply_and(cr.r, inds...)
    return inds
end

_parse_subset(::ContrastResult, ::Colon) = Colon()

function Base.view(cr::ContrastResult, subset)
    inds = _parse_subset(cr, subset)
    r = view(cr.r, inds)
    m = view(cr.m, inds, :)
    return ContrastResult(parent(cr), TableIndexedMatrix(m, r, cr.c))
end

function _checklengthmatch(v, name::String, N::Int)
    length(v) == N || throw(ArgumentError(
        "The length of $name ($(length(v))) does not match the number of rows of cr ($(N))"))
end

_checklengthmatch(v::Nothing, name::String, N::Int) = nothing

"""
    post!(gl, gr, gd, ::StataPostHDF, cr::ContrastResult, left::Int=2, right::Int=3; kwargs...)

Export the least-square weights for coefficients indexed by `left` and `right`
from `cr` for Stata module [`posthdf`](https://github.com/junyuan-chen/posthdf).
The contribution of each cell to the difference between two coefficients
are computed and also exported.
The weights and contributions are stored as coefficient estimates
in three groups `gl`, `gr` and `gd` respectively.
The groups can be `HDF5.Group`s or objects that can be indexed by strings.

# Keywords
- `lefttag::String=string(left)`: name to be used as `depvar` in Stata after being prefixed by `"l_"` for the coefficient indexed by `left`.
- `righttag::String=string(right)`: name to be used as `depvar` in Stata after being prefixed by `"r_"` for the coefficient indexed by `right`.
- `model::String="InteractionWeightedDIDs.ContrastResult"`: name of the model.
- `eqnames::Union{AbstractVector, Nothing}=nothing`: equation names prefixed to coefficient names in Stata.
- `colnames::Union{AbstractVector, Nothing}=nothing`: column names used as coefficient names in Stata.
- `at::Union{AbstractVector{<:Real}, Nothing}=nothing`: the `at` vector in Stata.
"""
function post!(gl, gr, gd, ::StataPostHDF, cr::ContrastResult, left::Int=2, right::Int=3;
        lefttag::String=string(left), righttag::String=string(right),
        model::String="InteractionWeightedDIDs.ContrastResult",
        eqnames::Union{AbstractVector, Nothing}=nothing,
        colnames::Union{AbstractVector, Nothing}=nothing,
        at::Union{AbstractVector{<:Real}, Nothing}=nothing)
    N = size(cr.m, 1)
    _checklengthmatch(eqnames, "eqnames", N)
    _checklengthmatch(colnames, "colnames", N)
    _checklengthmatch(at, "at", N)
    gl["depvar"] = string("l_", lefttag)
    wtl = view(cr.m, :, left)[:]
    gl["b"] = wtl
    gr["depvar"] = string("r_", righttag)
    wtr = view(cr.m, :, right)[:]
    gr["b"] = wtr
    gd["depvar"] = string("d_", lefttag, "_", righttag)
    diff = (wtl.-wtr).*view(cr.m,:,1)[:]
    gd["b"] = diff
    colnames === nothing && (colnames = 1:N)
    cnames = eqnames === nothing ? string.(colnames) : string.(eqnames, ":", colnames)
    for g in (gl, gr, gd)
        g["model"] = model
        g["coefnames"] = cnames
        at === nothing || (g["at"] = at)
    end
end
