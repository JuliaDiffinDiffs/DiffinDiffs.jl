"""
    RegressionBasedDID <: DiffinDiffsEstimator

Estimation procedure for regression-based difference-in-differences.
"""
const RegressionBasedDID = DiffinDiffsEstimator{:RegressionBasedDID,
    Tuple{CheckData, CheckVcov, CheckVars, CheckFEs, MakeWeights, MakeFESolver,
    MakeYXCols, MakeTreatCols, SolveLeastSquares, EstVcov}}

const Reg = RegressionBasedDID

function _get_default(::Reg, @nospecialize(ntargs::NamedTuple))
    defaults = (subset=nothing, weightname=nothing, vce=Vcov.RobustCovariance(),
        treatintterms=(), xterms=(), drop_singletons=true, nfethreads=6,
        contrasts=Dict{Symbol,Any}(), fetol=1.0e-8, femaxiter=10000, cohortinteracted=true)
    return merge(defaults, ntargs)
end

function valid_didargs(d::Type{Reg}, ::DynamicTreatment{SharpDesign},
        ::TrendParallel{Unconditional, Exact}, @nospecialize(ntargs::NamedTuple))
    ntargs = _get_default(d(), ntargs)
    name = haskey(ntargs, :name) ? ntargs.name : ""
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
    contrasts::Dict{Symbol, Any}
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

has_fe(r::RegressionBasedDIDResult) = !isempty(r.fenames)

format_scientific(f::Number) = @sprintf("%.3f", f)

function _summary(r::RegressionBasedDIDResult)
    top = ["Number of obs" sprint(show, nobs(r), context=:compact=>true);
        "Degrees of freedom" sprint(show, nobs(r) - dof_residual(r), context=:compact=>true);
        "F-statistic" sprint(show, r.F, context = :compact => true);
        "p-value" format_scientific(r.p)]
    fe_info = has_fe(r) ?  
        ["Converged" sprint(show, r.feconverged, context=:compact=>true);
        "Singletons dropped" sprint(show, r.nfesingledropped, context=:compact=>true);
        ] : nothing
    return top, fe_info
end

_nunique(t::Table, s::Symbol) = length(unique(getproperty(t, s)))

_excluded_rel_str(tr::DynamicTreatment) = 
    isempty(tr.exc) ? "None" : join(string.(tr.exc), " ")

_treat_info(tr::DynamicTreatment, trinds::Table, treatname::Symbol) =
    ["Number of cohorts" sprint(show, _nunique(trinds, treatname), context=:compact=>true);
    "Interactions within cohorts" sprint(show, length(columnnames(trinds))-2, context=:compact=>true);
    "Relative time periods" sprint(show, _nunique(trinds, :rel), context=:compact=>true);
    "Excluded periods" sprint(show, NoQuote(_excluded_rel_str(tr)), context=:compact=>true)]

_treat_spec(r::RegressionBasedDIDResult{true}, tr::DynamicTreatment{SharpDesign}) =
    "Cohort-interacted sharp dynamic specification"

_treat_spec(r::RegressionBasedDIDResult{false}, tr::DynamicTreatment{SharpDesign}) =
    "Sharp dynamic specification"
    
function show(io::IO, r::RegressionBasedDIDResult;
    totalwidth::Int=70, interwidth::Int=4+mod(totalwidth,2))
    halfwidth = div(totalwidth-interwidth, 2)
    top, fe_info = _summary(r)
    tr_info = _treat_info(r.tr, r.treatinds, r.treatname)
    blocks = [top, tr_info, fe_info]
    fes = has_fe(r) ? join(string.(r.fenames), " ") : "none"
    fetitle = string("Fixed effects: ", fes)
    blocktitles = ["Summary of results",
                   _treat_spec(r, r.tr),
                   fetitle[1:min(totalwidth,length(fetitle))]]
    for (ib, b) in enumerate(blocks)
        for i in 1:size(b, 1)
            b[i, 1] = b[i, 1] * ":"
        end
        println(io, "─" ^totalwidth)
        println(io, blocktitles[ib])
        println(io, "─" ^totalwidth)
        for i in 1:(div(size(b, 1) - 1, 2)+1)
            print(io, b[2*i-1, 1])
            print(io, lpad(b[2*i-1, 2], halfwidth - length(b[2*i-1, 1])))
            print(io, " " ^interwidth)
            if size(b, 1) >= 2*i
                print(io, b[2*i, 1])
                print(io, lpad(b[2*i, 2], halfwidth - length(b[2*i, 1])))
            end
            println(io)
        end
    end
    println(io, "─" ^totalwidth)
end
