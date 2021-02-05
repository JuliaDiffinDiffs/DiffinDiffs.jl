"""
    checkvcov!(args...)

Exclude rows that are invalid for `vcov`.
See also [`CheckVcov`](@ref).
"""
checkvcov!(data, esample::BitArray, vcov::Union{Vcov.SimpleCovariance,Vcov.RobustCovariance}) =
    NamedTuple(), false

function checkvcov!(data, esample::BitArray, vcov::Vcov.ClusterCovariance)
    esample .&= Vcov.completecases(data, vcov)
    return (esample=esample,), false
end

"""
    CheckVcov <: StatsStep

Call [`InteractionWeightedDIDs.checkvcov!`](@ref) to exclude invalid rows for
`Vcov.CovarianceEstimator`.
"""
const CheckVcov = StatsStep{:CheckVcov, typeof(checkvcov!)}

required(::CheckVcov) = (:data, :esample)
default(::CheckVcov) = (vcov=Vcov.robust(),)

"""
    checkfes!(args...)

Extract any `FixedEffectTerm` from `xterms`,
drop singleton observations for any fixed effect
and determine whether intercept term should be omitted.
See also [`CheckFEs`](@ref).
"""
function checkfes!(data, esample::BitArray, xterms::Terms, drop_singletons::Bool)
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

required(::CheckFEs) = (:data, :esample)
default(::CheckFEs) = (xterms=(), drop_singletons=true)

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

required(::MakeFESolver) = (:fenames, :weights, :esample)
# Determine equality of fes by fenames
combinedargs(::MakeFESolver, allntargs) = (allntargs[1].fes,)

function _feresiduals!(M::AbstractArray, feM::AbstractFixedEffectSolver,
        tol::Real, maxiter::Integer)
    _, iters, convs = solve_residuals!(M, feM; tol=tol, maxiter=maxiter, progress_bar=false)
    iter = maximum(iters)
    all(convs) || @warn "no convergence of fixed effect solver in $(iter) iterations"
end

"""
    makeyxcols(args...)

Construct columns for outcome variables and covariates
and residualize them with fixed effects.
See also [`MakeYXCols`](@ref).
"""
function makeyxcols(data, weights::AbstractWeights, esample::BitArray,
        feM::Union{AbstractFixedEffectSolver, Nothing}, has_fe_intercept::Bool,
        contrasts::Dict, fetol::Real, femaxiter::Int, allyterm::Terms, allxterms::Terms)
    
    yxcols = Dict{AbstractTerm, VecOrMat{Float64}}()
    yxnames = union(termvars(allyterm), termvars(allxterms))
    yxdata = _getsubcolumns(data, yxnames, esample)
    concrete_yterms = apply_schema(allyterm, schema(allyterm, yxdata), StatisticalModel)
    for (t, ct) in zip(eachterm(allyterm), eachterm(concrete_yterms))
        ycol = convert(Vector{Float64}, modelcols(ct, yxdata))
        all(isfinite, ycol) || error("data for term $ct contain NaN or Inf")
        yxcols[t] = ycol
    end

    xschema = schema(allxterms, yxdata, contrasts)
    has_fe_intercept && (xschema = FullRank(xschema, Set([InterceptTerm{true}()])))
    concrete_xterms = apply_schema(allxterms, xschema, StatisticalModel)
    for (t, ct) in zip(eachterm(allxterms), eachterm(concrete_xterms))
        if width(ct) > 0
            xcols = convert(Matrix{Float64}, modelmatrix(ct, yxdata))
            all(isfinite, xcols) || error("data for term $ct contain NaN or Inf")
            yxcols[t] = xcols
        end
    end

    if feM !== nothing
        YX = Combination(values(yxcols)...)
        _feresiduals!(YX, feM, fetol, femaxiter)
    end

    if !(weights isa UnitWeights)
        for col in values(yxcols)
            col .*= sqrt.(weights)
        end
    end

    return (yxcols=yxcols,), true
end

"""
    MakeYXCols <: StatsStep

Call [`InteractionWeightedDIDs.makeyxcols`](@ref) to obtain
residualized outcome variables and covariates.
The returned object named `yxcols`
may be shared across multiple specifications.
"""
const MakeYXCols = StatsStep{:MakeYXCols, typeof(makeyxcols)}

required(::MakeYXCols) = (:data, :weights, :esample, :feM, :has_fe_intercept)
default(::MakeYXCols) = (contrasts=Dict{Symbol, Any}(), fetol=1e-8, femaxiter=10000)

function combinedargs(::MakeYXCols, allntargs)
    allyterm, allxterms = (allntargs[1].yterm,), allntargs[1].xterms
    if length(allntargs) > 1
        for i in 2:length(allntargs)
            allyterm += allntargs[i].yterm
            allxterms += allntargs[i].xterms
        end
    end
    return allyterm, allxterms
end

function _genindicator(idx::Vector{Int}, n::Int)
    v = zeros(n)
    v[idx] .= 1
    return v
end

_gencellweight(idx::Vector{Int}, weights::AbstractWeights) = sum(weights[idx])

"""
    maketreatcols(args...)

Construct residualized binary columns that capture treatment effects
and obtain cell-level weight sums and observation counts.
See also [`MakeTreatCols`](@ref).
"""
function maketreatcols(data, treatname::Symbol, treatintterms::Terms,
        feM::Union{AbstractFixedEffectSolver, Nothing}, weights::AbstractWeights,
        esample::BitArray, tr_rows::BitArray, fetol::Real, femaxiter::Int,
        ::Type{<:DynamicTreatment{SharpDesign}}, time::Symbol, exc::Set{<:Integer})

    nobs = sum(esample)
    tnames = (treatname, time, termvars(treatintterms)...)
    kept = tr_rows .& .!(getcolumn(data, time).-getcolumn(data, treatname).∈(exc,))
    # Obtain a fast row iterator without copying (if no missing)
    trows = Table(_getsubcolumns(data, tnames, kept))
    itreats = groupfind(trows)
    treatcols = map(x->_genindicator(x, nobs), itreats)
    cellweights = map(x->_gencellweight(x, weights), itreats)
    cellcounts = weights isa UnitWeights ? cellweights : map(length, itreats)
    
    if feM !== nothing
        M = Combination(values(treatcols)...)
        _feresiduals!(M, feM, fetol, femaxiter)
    end

    if !(weights isa UnitWeights)
        for tcol in values(treatcols)
            tcol .*= sqrt.(weights)
        end
    end

    return (treatcols=treatcols, cellweights=cellweights, cellcounts=cellcounts), true
end

"""
    MakeTreatCols <: StatsStep

Call [`InteractionWeightedDIDs.maketreatcols`](@ref) to obtain
residualized binary columns that capture treatment effects
and obtain cell-level weight sums and observation counts.
The returned objects named `treatcols`, `cellweights` and `cellcounts`
may be shared across multiple specifications.
"""
const MakeTreatCols = StatsStep{:MakeTreatCols, typeof(maketreatcols)}

required(::MakeTreatCols) = (:data, :treatname, :treatintterms, :feM,
    :weights, :esample, :tr_rows)
default(::MakeTreatCols) = (fetol=1e-8, femaxiter=10000)
transformed(::MakeTreatCols, @nospecialize(nt::NamedTuple)) =
    (typeof(nt.tr), nt.tr.time)

combinedargs(step::MakeTreatCols, allntargs) =
    combinedargs(step, allntargs, typeof(allntargs[1].nt.tr))

combinedargs(::MakeTreatCols, allntargs, ::Type{<:DynamicTreatment{SharpDesign}}) =
    (Set(intersect((nt.tr.exc for nt in allntargs)...)),)
