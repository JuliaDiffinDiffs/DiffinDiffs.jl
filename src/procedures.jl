"""
    checkvcov!(args...)

Exclude rows that are invalid for `vcov`.
See also [`CheckVcov`](@ref).
"""
checkvcov!(data, vcov::Union{Vcov.SimpleCovariance,Vcov.RobustCovariance}, esample::BitArray) =
    NamedTuple(), false

function checkvcov!(data, vcov::Vcov.ClusterCovariance, esample::BitArray)
    esample .&= Vcov.completecases(data, vcov)
    return (esample=esample,), false
end

"""
    CheckVcov <: StatsStep

Call [`InteractionWeightedDIDs.checkvcov!`](@ref) to exclude invalid rows for
`Vcov.CovarianceEstimator`.
"""
const CheckVcov = StatsStep{:CheckVcov, typeof(checkvcov!)}

namedargs(::CheckVcov) = (data=nothing, vcov=Vcov.simple(), esample=nothing)

"""
    checkfes!(args...)

Extract any `FixedEffectTerm` from `xterms`,
drop singleton observations for any fixed effect
and determine whether intercept term should be omitted.
See also [`CheckFEs`](@ref).
"""
function checkfes!(data, xterms::Terms, drop_singletons::Bool, esample::BitArray)
    fes, fenames, xterms = parse_fixedeffect(data, xterms)
    has_fe_intercept = false
    nsingle = 0
    if !isempty(fes)
        has_fe_intercept = any(fe.interaction isa UnitWeights for fe in fes)
        if drop_singletons
            for fe in fes
                nsingle += drop_singletons!(esample, fe)
            end
        end
    end
    sum(esample) == 0 && error("no nonmissing data")
    return (xterms=xterms, esample=esample, fes=fes, fenames=fenames,
        has_fe_intercept=has_fe_intercept, nsingle=nsingle), false
end

"""
    CheckFEs <: StatsStep

Call [`InteractionWeightedDIDs.checkfes!`](@ref)
to extract any `FixedEffectTerm` from `xterms`
and drop singleton observations for any fixed effect.
"""
const CheckFEs = StatsStep{:CheckFixedEffects, typeof(checkfes!)}

namedargs(::CheckFEs) = (data=nothing, xterms=(), drop_singletons=true, esample=nothing)

"""
    makefesolver(args...)

Construct `FixedEffects.AbstractFixedEffectSolver`.
See also [`MakeFESolver`](@ref).
"""
function makefesolver(fenames::Vector{Symbol}, weights::AbstractWeights, esample::BitArray, fes::Vector{FixedEffect})
    if !isempty(fes)
        fes = FixedEffect[fe[esample] for fe in fes]
        feM = AbstractFixedEffectSolver{Float64}(fes, weights, Val{:cpu}, Threads.nthreads())
        return (feM=feM,), true
    else
        return (feM=nothing,), true
    end
end

"""
    MakeFESolver <: StatsStep

Call [`InteractionWeightedDIDs.makefesolver`](@ref) to construct the fixed effect solver.
The returned object named `feM` may be shared across multiple specifications.
"""
const MakeFESolver = StatsStep{:MakeFESolver, typeof(makefesolver)}

_getargs(nt::NamedTuple, ::MakeFESolver) = (nt.fenames, nt.weights)
_combinedargs(::MakeFESolver, allntargs) = allntargs[1].fes

function _feresiduals!(M::AbstractArray, feM::AbstractFixedEffectSolver,
    tol::Real, maxiter::Integer)
_, iters, convs = solve_residuals!(M, feM; tol=tol, maxiter=maxiter, progress_bar=false)
iter = maximum(iters)
all(convs) || @warn "fixed effect solver does not reach convergence in $(iter) iterations"
end

"""
    makeyxcols(args...)

Construct columns for outcome variables and covariates
and residualize them with fixed effects.
See also [`MakeYXCols`](@ref).
"""
function makeyxcols(data, feM::Union{AbstractFixedEffectSolver, Nothing},
        weights::AbstractWeights, contrasts::Dict, has_fe_intercept::Bool,
        fetol::Real, femaxiter::Int, esample::BitArray,
        allyterm::Terms, allxterms::Terms)
    
    allycol = Dict{AbstractTerm, Vector{Float64}}()
    ynames = termvars(allyterm)
    ycols = _getsubcolumns(data, ynames, esample)
    concrete_yterms = apply_schema(allyterm, schema(allyterm, ycols), StatisticalModel)
    for (t, ct) in zip(eachterm(allyterm), eachterm(concrete_yterms))
        allycol[t] = modelcols(ct, ycols)
    end

    allxcols = Dict{AbstractTerm, Matrix{Float64}}()
    xnames = termvars(allxterms)
    xcols = _getsubcolumns(data, xnames, esample)
    xschema = schema(allxterms, xcols, contrasts)
    has_fe_intercept && (xschema = FullRank(xschema, Set(InterceptTerm{true}())))
    concrete_xterms = apply_schema(allxterms, xschema, StatisticalModel)
    for (t, ct) in zip(eachterm(allxterms), eachterm(concrete_xterms))
        width(t)>0 && (allxcols[t] = modelmatrix(ct, xcols))
    end

    if feM !== nothing
        YX = Combination(values(allycol)..., values(allycol)...)
        _feresiduals!(YX, feM, fetol, femaxiter)
    end

    if !(weights isa UnitWeights)
        for ycol in values(allycol)
            ycol .*= sqrt.(weights)
        end
        for xcols in values(allxcols)
            xcols .*= sqrt.(weights)
        end
    end

    return (allycol=allycol, allxcols=allxcols), true
end

"""
    MakeYXCols <: StatsStep

Call [`InteractionWeightedDIDs.makeyxcols`](@ref) to obtain residuals columns of
outcome variables and covariates.
The returned object named `allycol` and `allxcols`
may be shared across multiple specifications.
"""
const MakeYXCols = StatsStep{:MakeYXCols, typeof(makeyxcols)}

_getargs(nt::NamedTuple, ::MakeYXCols) = _update(nt,
    (data=nothing, feM=nothing, weights=nothing, contrasts=Dict{Symbol, Any}(),
    has_fe_intercept=nothing, fetol=1e-8, femaxiter=10000, esample=nothing))

function _combinedargs(::MakeYXCols, allntargs)
    allyterm, allxterms = allntargs[1].yterm, allntargs[1].xterms
    if length(allntargs) > 1
        for i in 2:length(allntargs)
            allyterm += allntargs[i].yterm
            allxterms += allntargs[i].xterms
        end
    end
    return allyterm, allxterms
end

"""
    maketreatcols(args...)

Construct columns for capturing treatment effects.
See also [`MakeTreatCols`](@ref).
"""
function maketreatcols(data, ::Type{<:DynamicTreatment{SharpDesign}},
        time::Symbol, treatname::Symbol, treatintterms::Terms,
        feM::Union{AbstractFixedEffectSolver, Nothing}, weights::AbstractWeights,
        fetol::Real, femaxiter::Int, esample::BitArray, tr_rows::BitArray,
        exc::Set{<:Integer})

    alltreatcols = Dict{NamedTuple, Vector{Float64}}()
    tnames = (treatname, time, termvars(treatintterms)...)
    kept = tr_rows .& .!(getcolumn(data, time).-getcolumn(data, treatname).∈(exc,))
    # Convert to row table without copying again
    trows = Table(_getsubcolumns(data, tnames, kept))
    nobs = sum(esample)
    @inbounds for (n, i) in enumerate(findall(kept))
        tcol = get!(alltreatcols, trows[n], zeros(nobs))
        tcol[i] = 1.0
    end
    
    if feM !== nothing
        M = Combination(values(alltreatcols)...)
        _feresiduals!(M, feM, fetol, femaxiter)
    end

    if !(weights isa UnitWeights)
        for tcol in values(alltreatcols)
            tcol .*= sqrt.(weights)
        end
    end

    return (alltreatcols=alltreatcols,), true
end

"""
    MakeTreatCols <: StatsStep

Call [`InteractionWeightedDIDs.maketreatcols`](@ref) to obtain
residualized columns that capture treatment effects.
The returned object named `alltreatcols`
may be shared across multiple specifications.
"""
const MakeTreatCols = StatsStep{:MakeTreatCols, typeof(maketreatcols)}

_getargs(nt::NamedTuple, ::MakeTreatCols) =
    (nt.data, typeof(nt.tr), nt.tr.time, nt.treatname, nt.treatintterms,
    nt.feM, nt.weights, _update(nt, (fetol=1e-8, femaxiter=10000))...,
    nt.esample, nt.tr_rows)

_combinedargs(step::MakeTreatCols, allntargs) =
    _combinedargs(step, allntargs, typeof(allntargs[1].nt.tr))

_combinedargs(::MakeTreatCols, allntargs, ::Type{<:DynamicTreatment{SharpDesign}}) =
    Set(intersect((nt.tr.exc for nt in allntargs)...))
