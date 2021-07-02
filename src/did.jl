"""
    RegressionBasedDID <: DiffinDiffsEstimator

Estimation procedure for regression-based difference-in-differences.
"""
const RegressionBasedDID = DiffinDiffsEstimator{:RegressionBasedDID,
    Tuple{CheckData, GroupTreatintterms, GroupXterms, CheckVcov, CheckVars, GroupSample,
    ParseFEterms, GroupFEterms, MakeFEs, CheckFEs, MakeWeights, MakeFESolver,
    MakeYXCols, MakeTreatCols, SolveLeastSquares, EstVcov, SolveLeastSquaresWeights}}

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
        drop_singletons=get(args, :drop_singletons, true)::Bool,
        nfethreads=get(args, :nfethreads, Threads.nthreads())::Int,
        contrasts=get(args, :contrasts, nothing)::Union{Dict{Symbol,Any},Nothing},
        fetol=get(args, :fetol, 1e-8)::Float64,
        femaxiter=get(args, :femaxiter, 10000)::Int,
        cohortinteracted=get(args, :cohortinteracted, true)::Bool,
        solvelsweights=solvelsweights::Bool,
        lswtnames=get(args, :lswtnames, ()))
    return name, d, ntargs
end

"""
    RegressionBasedDIDResult{TR<:AbstractTreatment, CohortInteracted} <: DIDResult

Estimation results from regression-based difference-in-differences.
"""
struct RegressionBasedDIDResult{TR<:AbstractTreatment, CohortInteracted} <: DIDResult
    coef::Vector{Float64}
    vcov::Matrix{Float64}
    vce::CovarianceEstimator
    tr::TR
    pr::AbstractParallel
    cellweights::Vector{Float64}
    cellcounts::Vector{Int}
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
    ycellmeans::Union{Vector{Float64}, Nothing}
    ycellweights::Union{Vector{Float64}, Nothing}
    ycellcounts::Union{Vector{Int}, Nothing}
end

function result(::Type{Reg}, @nospecialize(nt::NamedTuple))
    yterm = nt.yxterms[nt.yterm]
    yname = coefnames(yterm)
    cnames = _treatnames(nt.treatcells)
    cnames = append!(cnames, coefnames.(nt.xterms))[nt.basiscols]
    coefinds = Dict(cnames .=> 1:length(cnames))
    didresult = RegressionBasedDIDResult{typeof(nt.tr), nt.cohortinteracted}(
        nt.coef, nt.vcov_mat, nt.vce, nt.tr, nt.pr, nt.cellweights, nt.cellcounts,
        nt.esample, sum(nt.esample), nt.dof_resid, nt.F, nt.p,
        yname, cnames, coefinds, nt.treatcells, nt.treatname, nt.yxterms,
        yterm, nt.xterms, nt.contrasts, nt.weightname,
        nt.fenames, nt.nfeiterations, nt.feconverged, nt.nsingle,
        nt.lsweights, nt.ycellmeans, nt.ycellweights, nt.ycellcounts)
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
    AggregatedRegBasedDIDResult{P<:RegressionBasedDIDResult, I} <: AggregatedDIDResult{P}

Estimation results aggregated from a [`RegressionBasedDIDResult`](@ref).
See also [`agg`](@ref).
"""
struct AggregatedRegBasedDIDResult{P<:RegressionBasedDIDResult, I} <: AggregatedDIDResult{P}
    parent::P
    inds::I
    coef::Vector{Float64}
    vcov::Matrix{Float64}
    coefweights::Matrix{Float64}
    cellweights::Vector{Float64}
    cellcounts::Vector{Int}
    coefnames::Vector{String}
    coefinds::Dict{String, Int}
    treatcells::VecColumnTable
    lsweights::Union{TableIndexedMatrix{Float64, Matrix{Float64}, VecColumnTable, VecColumnTable}, Nothing}
end

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
    pcellweights = view(r.cellweights, inds)
    pcellcounts = view(r.cellcounts, inds)
    # Ensure the weights for each relative time always sum up to one
    rels = view(r.treatcells.rel, inds)
    for (i, rs) in enumerate(rows)
        if length(rs) > 1
            relgroups = _groupfind(view(rels, rs))
            for inds in values(relgroups)
                if length(inds) > 1
                    cwts = view(pcellweights, view(rs, inds))
                    cweights[view(rs, inds), i] .= cwts ./ sum(cwts)
                else
                    cweights[rs[inds[1]], i] = 1.0
                end
            end
        else
            cweights[rs[1], i] = 1.0
        end
    end
    cf = cweights' * pcf
    v = cweights' * view(treatvcov(r), inds, inds) * cweights
    cellweights = [sum(pcellweights[rows[i]]) for i in 1:ncell]
    cellcounts = [sum(pcellcounts[rows[i]]) for i in 1:ncell]
    cnames = _treatnames(tcells)
    coefinds = Dict(cnames .=> keys(cnames))
    if r.lsweights === nothing
        lswt = nothing
    else
        lswtmat = view(r.lsweights.m, :, inds) * cweights
        lswt = TableIndexedMatrix(lswtmat, r.lsweights.r, tcells)
    end
    return AggregatedRegBasedDIDResult{typeof(r), typeof(inds)}(r, inds, cf, v, cweights,
        cellweights, cellcounts, cnames, coefinds, tcells, lswt)
end

vce(r::AggregatedRegBasedDIDResult) = vce(parent(r))
nobs(r::AggregatedRegBasedDIDResult) = nobs(parent(r))
outcomename(r::AggregatedRegBasedDIDResult) = outcomename(parent(r))
weights(r::AggregatedRegBasedDIDResult) = weights(parent(r))
treatnames(r::AggregatedRegBasedDIDResult) = coefnames(r)
dof_residual(r::AggregatedRegBasedDIDResult) = dof_residual(parent(r))
