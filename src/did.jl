"""
    RegressionBasedDID <: DiffinDiffsEstimator

Estimation procedure for regression-based difference-in-differences.
"""
const RegressionBasedDID = DiffinDiffsEstimator{:RegressionBasedDID,
    Tuple{CheckData, GroupTerms, CheckVcov, CheckVars, CheckFEs, MakeWeights, MakeFESolver,
    MakeYXCols, MakeTreatCols, SolveLeastSquares, EstVcov}}

const Reg = RegressionBasedDID

function valid_didargs(d::Type{Reg}, ::DynamicTreatment{SharpDesign},
        ::TrendParallel{Unconditional, Exact}, args::Dict{Symbol,Any})
    name = get(args, :name, "")::String
    ntargs = (data=args[:data],
        tr=args[:tr]::DynamicTreatment{SharpDesign},
        pr=args[:pr]::TrendParallel{Unconditional, Exact},
        yterm=args[:yterm]::AbstractTerm,
        treatname=args[:treatname]::Symbol,
        subset=get(args, :subset, nothing)::Union{BitVector,Nothing},
        weightname=get(args, :weightname, nothing)::Union{Symbol,Nothing},
        vce=get(args, :vce, Vcov.RobustCovariance())::Vcov.CovarianceEstimator,
        treatintterms=get(args, :treatintterms, TermSet())::TermSet,
        xterms=get(args, :xterms, TermSet())::TermSet,
        drop_singletons=get(args, :drop_singletons, true)::Bool,
        nfethreads=get(args, :nfethreads, Threads.nthreads())::Int,
        contrasts=get(args, :contrasts, nothing)::Union{Dict{Symbol,Any},Nothing},
        fetol=get(args, :fetol, 1e-8)::Float64,
        femaxiter=get(args, :femaxiter, 10000)::Int,
        cohortinteracted=get(args, :cohortinteracted, true)::Bool)
    return name, d, ntargs
end

struct RegressionBasedDIDResult{CohortInteracted} <: DIDResult
    coef::Vector{Float64}
    vcov::Matrix{Float64}
    vce::CovarianceEstimator
    tr::AbstractTreatment
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
    treatinds::Table
    yxterms::Dict{AbstractTerm, AbstractTerm}
    treatname::Symbol
    contrasts::Union{Dict{Symbol, Any}, Nothing}
    weightname::Union{Symbol, Nothing}
    fenames::Vector{Symbol}
    nfeiterations::Union{Int, Nothing}
    feconverged::Union{Bool, Nothing}
    nfesingledropped::Int
end

function result(::Type{Reg}, @nospecialize(nt::NamedTuple))
    cellweights = [nt.cellweights[k] for k in nt.treatinds]
    cellcounts = [nt.cellcounts[k] for k in nt.treatinds]
    yname = coefnames(nt.yxterms[nt.yterm])
    tnames = _treatnames(nt.treatinds)
    cnames = [coefnames(nt.yxterms[x]) for x in nt.xterms if width(nt.yxterms[x])>0]
    cnames = vcat(tnames, cnames)[nt.basecols]
    coefinds = Dict(cnames .=> 1:length(cnames))
    didresult = RegressionBasedDIDResult{nt.cohortinteracted}(
        nt.coef, nt.vcov_mat, nt.vce, nt.tr, nt.pr, cellweights, cellcounts,
        nt.esample, sum(nt.esample), nt.dof_resid, nt.F, nt.p,
        yname, cnames, coefinds, nt.treatinds, nt.yxterms, nt.treatname, nt.contrasts,
        nt.weightname, nt.fenames, nt.nfeiterations, nt.feconverged, nt.nsingle)
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

_nunique(t::Table, s::Symbol) = length(unique(getproperty(t, s)))

_excluded_rel_str(tr::DynamicTreatment) =
    isempty(tr.exc) ? "none" : join(string.(tr.exc), " ")

_treat_info(r::RegressionBasedDIDResult{true}, tr::DynamicTreatment) = (
    "Number of cohorts" => _nunique(r.treatinds, r.treatname),
    "Interactions within cohorts" => length(columnnames(r.treatinds)) - 2,
    "Relative time periods" => _nunique(r.treatinds, :rel),
    "Excluded periods" => NoQuote(_excluded_rel_str(tr))
)

_treat_info(r::RegressionBasedDIDResult{false}, tr::DynamicTreatment) = (
    "Relative time periods" => _nunique(r.treatinds, :rel),
    "Excluded periods" => NoQuote(_excluded_rel_str(tr))
)

_treat_spec(r::RegressionBasedDIDResult{true}, tr::DynamicTreatment{SharpDesign}) =
    "Cohort-interacted sharp dynamic specification"

_treat_spec(r::RegressionBasedDIDResult{false}, tr::DynamicTreatment{SharpDesign}) =
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
    tr_info = _treat_info(r, r.tr)
    blocks = (top_info, tr_info, fe_info)
    fes = has_fe(r) ? join(string.(r.fenames), " ") : "none"
    fetitle = string("Fixed effects: ", fes)
    blocktitles = ("Summary of results: Regression-based DID",
        _treat_spec(r, r.tr), fetitle[1:min(totalwidth,length(fetitle))])

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
