"""
    checkvcov!(args...)

Exclude rows that are invalid for variance-covariance estimator.
See also [`CheckVcov`](@ref).
"""
checkvcov!(data, esample::BitVector,
    vce::Union{Vcov.SimpleCovariance, Vcov.RobustCovariance}) = NamedTuple()

function checkvcov!(data, esample::BitVector, vce::Vcov.ClusterCovariance)
    esample .&= Vcov.completecases(data, vce)
    return (esample=esample,)
end

"""
    CheckVcov <: StatsStep

Call [`InteractionWeightedDIDs.checkvcov!`](@ref) to
exclude rows that are invalid for variance-covariance estimator.
"""
const CheckVcov = StatsStep{:CheckVcov, typeof(checkvcov!)}

required(::CheckVcov) = (:data, :esample)
default(::CheckVcov) = (vce=Vcov.robust(),)
copyargs(::CheckVcov) = (2,)

"""
    checkfes!(args...)

Extract any `FixedEffectTerm` from `xterms`,
drop singleton observations for any fixed effect
and determine whether intercept term should be omitted.
See also [`CheckFEs`](@ref).
"""
function checkfes!(data, esample::BitVector, xterms::Terms, drop_singletons::Bool)
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
        has_fe_intercept=has_fe_intercept, nsingle=nsingle)
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
copyargs(::CheckFEs) = (2,)

"""
    makefesolver(args...)

Construct `FixedEffects.AbstractFixedEffectSolver`.
See also [`MakeFESolver`](@ref).
"""
function makefesolver(fes::Vector{FixedEffect}, weights::AbstractWeights,
        esample::BitVector, nfethreads::Int)
    if !isempty(fes)
        fes = FixedEffect[fe[esample] for fe in fes]
        feM = AbstractFixedEffectSolver{Float64}(fes, weights, Val{:cpu}, nfethreads)
        return (feM=feM,)
    else
        return (feM=nothing,)
    end
end

"""
    MakeFESolver <: StatsStep

Call [`InteractionWeightedDIDs.makefesolver`](@ref) to construct the fixed effect solver.
"""
const MakeFESolver = StatsStep{:MakeFESolver, typeof(makefesolver)}

required(::MakeFESolver) = (:fes, :weights, :esample)
default(::MakeFESolver) = (nfethreads=Threads.nthreads(),)

function _feresiduals!(M::AbstractArray, feM::AbstractFixedEffectSolver,
        tol::Real, maxiter::Integer)
    _, iters, convs = solve_residuals!(M, feM; tol=tol, maxiter=maxiter, progress_bar=false)
    iter = maximum(iters)
    conv = all(convs)
    conv || @warn "no convergence of fixed effect solver in $(iter) iterations"
    return iter, conv
end

"""
    makeyxcols(args...)

Construct columns for outcome variables and covariates
and residualize them with fixed effects.
See also [`MakeYXCols`](@ref).
"""
function makeyxcols(data, weights::AbstractWeights, esample::BitVector,
        feM::Union{AbstractFixedEffectSolver, Nothing}, has_fe_intercept::Bool,
        contrasts::Union{Dict, Nothing}, fetol::Real, femaxiter::Int,
        allyterm::Set{AbstractTerm}, allxterms::Set{AbstractTerm})
    
    yxcols = Dict{AbstractTerm, VecOrMat{Float64}}()
    allyterm = (allyterm...,)
    allxterms = (allxterms...,)
    yxnames = union(termvars(allyterm), termvars(allxterms))
    yxdata = _getsubcolumns(data, yxnames, esample)
    concrete_yterms = apply_schema(allyterm, schema(allyterm, yxdata), StatisticalModel)
    yxterms = Dict{AbstractTerm, AbstractTerm}()
    for (t, ct) in zip(eachterm(allyterm), eachterm(concrete_yterms))
        ycol = convert(Vector{Float64}, modelcols(ct, yxdata))
        all(isfinite, ycol) || error("data for term $ct contain NaN or Inf")
        yxcols[t] = ycol
        yxterms[t] = ct
    end

    # Standardize how an intercept or omitsintercept is represented
    allxterms = parse_intercept(allxterms)

    # Add an intercept if not already having one
    has_fe_intercept || hasintercept(allxterms) ||
        (allxterms = (allxterms..., InterceptTerm{true}()))

    # Any term other than InterceptTerm{true}() that represents the intercept
    # will be replaced by InterceptTerm{true}()
    # Need to take such changes into account when creating X matrix
    xschema = contrasts === nothing ? schema(allxterms, yxdata) :
        schema(allxterms, yxdata, contrasts)
    concrete_xterms = apply_schema(allxterms, xschema, StatisticalModel)
    for (t, ct) in zip(eachterm(allxterms), eachterm(concrete_xterms))
        if width(ct) > 0
            xcols = convert(Matrix{Float64}, modelmatrix(ct, yxdata))
            all(isfinite, xcols) || error("data for term $ct contain NaN or Inf")
            yxcols[t] = xcols
        end
        yxterms[t] = ct
    end

    iter, conv = nothing, nothing
    if feM !== nothing
        YX = Combination(values(yxcols)...)
        iter, conv = _feresiduals!(YX, feM, fetol, femaxiter)
    end

    if !(weights isa UnitWeights)
        for col in values(yxcols)
            col .*= sqrt.(weights)
        end
    end

    return (yxcols=yxcols, yxterms=yxterms, nfeiterations=iter, feconverged=conv)
end

"""
    MakeYXCols <: StatsStep

Call [`InteractionWeightedDIDs.makeyxcols`](@ref) to obtain
residualized outcome variables and covariates.
"""
const MakeYXCols = StatsStep{:MakeYXCols, typeof(makeyxcols)}

required(::MakeYXCols) = (:data, :weights, :esample, :feM, :has_fe_intercept)
default(::MakeYXCols) = (contrasts=nothing, fetol=1e-8, femaxiter=10000)

function combinedargs(::MakeYXCols, allntargs)
    ys, xs = Set{AbstractTerm}(), Set{AbstractTerm}()
    @inbounds for nt in allntargs
        push!(ys, nt.yterm)
        foreach(x->push!(xs, x), nt.xterms)
    end
    return ys, xs
end

# Assume idx is sorted
function _genindicator(idx::Vector{Int}, esample::BitVector, n::Int)
    v = zeros(n)
    iv, r = 1, 1
    nr = length(idx)
    @inbounds for i in eachindex(esample)
        if esample[i]
            if idx[r] == i
                v[iv] = 1.0
                r += 1
            end
            iv += 1
        end
        r > nr && break
    end
    return v
end

_gencellweight(idx::Vector{Int}, data, weightname::Symbol) =
    sum(view(getcolumn(data, weightname), idx))

"""
    maketreatcols(args...)

Construct residualized binary columns that capture treatment effects
and obtain cell-level weight sums and observation counts.
See also [`MakeTreatCols`](@ref).
"""
function maketreatcols(data, treatname::Symbol, treatintterms::Terms,
        feM::Union{AbstractFixedEffectSolver, Nothing},
        weightname::Union{Symbol, Nothing}, weights::AbstractWeights,
        esample::BitVector, tr_rows::BitVector,
        cohortinteracted::Bool, fetol::Real, femaxiter::Int,
        ::Type{DynamicTreatment{SharpDesign}}, time::Symbol, exc::IdDict{Int,Int})

    nobs = sum(esample)
    tnames = (time, treatname, termvars(treatintterms)...)
    kept = tr_rows .& .!(haskey.(Ref(exc), getcolumn(data, time).-getcolumn(data, treatname)))
    ikept = findall(kept)
    # Obtain a fast row iterator without copying (after _getsubcolumns)
    trows = Table(_getsubcolumns(data, tnames, kept))
    # Obtain row indices that take value one for each treatment indicator
    itreats = group(trows, ikept)

    # Calculate relative time
    if cohortinteracted
        tnames = (:rel, treatname, termvars(treatintterms)...)
        f = k -> NamedTuple{tnames}((getfield(k, time) - getfield(k, treatname),
            getfield(k, treatname), (getfield(k, n) for n in termvars(treatintterms))...))
        itreats = Dictionary(map(f, keys(itreats)), itreats)
    else
        tnames = (:rel, termvars(treatintterms)...)
        byf = p -> NamedTuple{tnames}((getfield(p, time) - getfield(p, treatname),
            (getfield(p, n) for n in termvars(treatintterms))...))
        itreats = group(mapview(byf, keys(itreats)), itreats)
        itreats = map(x->sort!(vcat(x...)), itreats)
    end

    treatcols = map(x->_genindicator(x, esample, nobs), itreats)
    cellcounts = map(length, itreats)
    cellweights = weights isa UnitWeights ? cellcounts :
        map(x->_gencellweight(x, data, weightname), itreats)
    
    if feM !== nothing
        M = Combination(values(treatcols)...)
        _feresiduals!(M, feM, fetol, femaxiter)
    end

    if !(weights isa UnitWeights)
        for tcol in values(treatcols)
            tcol .*= sqrt.(weights)
        end
    end

    return (itreats=itreats, treatcols=treatcols, cellweights=cellweights,
        cellcounts=cellcounts)
end

"""
    MakeTreatCols <: StatsStep

Call [`InteractionWeightedDIDs.maketreatcols`](@ref) to obtain
residualized binary columns that capture treatment effects
and obtain cell-level weight sums and observation counts.
"""
const MakeTreatCols = StatsStep{:MakeTreatCols, typeof(maketreatcols)}

required(::MakeTreatCols) = (:data, :treatname, :treatintterms, :feM,
    :weightname, :weights, :esample, :tr_rows)
default(::MakeTreatCols) = (cohortinteracted=true, fetol=1e-8, femaxiter=10000)
transformed(::MakeTreatCols, @nospecialize(nt::NamedTuple)) =
    (typeof(nt.tr), nt.tr.time)

combinedargs(step::MakeTreatCols, allntargs) =
    combinedargs(step, allntargs, typeof(allntargs[1].tr))

# Obtain the relative time periods excluded by all tr in allntargs
function combinedargs(::MakeTreatCols, allntargs, ::Type{DynamicTreatment{SharpDesign}})
    count = IdDict{Int,Int}()
    @inbounds for nt in allntargs
        foreach(x->_count!(count, x), nt.tr.exc)
    end
    nnt = length(allntargs)
    @inbounds for (k, v) in count
        v == nnt || delete!(count, k)
    end
    return (count,)
end

"""
    solveleastsquares!(args...)

Solve the least squares problem for regression coefficients and residuals.
See also [`SolveLeastSquares`](@ref).
"""
function solveleastsquares!(tr::DynamicTreatment{SharpDesign}, yterm::AbstractTerm,
        xterms::Terms, yxterms::Dict, yxcols::Dict, treatcols::Dictionary,
        has_fe_intercept::Bool)
    y = yxcols[yterm]
    ts = sort!([k for k in keys(treatcols) if !(k.rel in tr.exc)])
    # Be consistent with allxterms in makeyxcols
    xterms = parse_intercept(xterms)
    # Add an intercept if needed
    has_fe_intercept || hasintercept(xterms) ||
        omitsintercept(xterms) || (xterms = (xterms..., InterceptTerm{true}()))
    
    X = hcat((treatcols[k] for k in ts)...,
        (yxcols[k] for k in xterms if width(yxterms[k])>0)...)
    
    nts = length(ts)
    basecols = trues(size(X,2))
    if size(X, 2) > nts
        basecols = basecol(X)
        # Do not drop any treatment indicator
        sum(basecols[1:nts]) == nts ||
            error("Covariates are collinear with treatment indicators")
        sum(basecols) < size(X, 2) &&
            (X = X[:, basecols])
    end
    
    crossx = cholesky!(Symmetric(X'X))
    coef = crossx \ (X'y)
    residuals = y - X * coef

    treatinds = Table(ts)

    return (coef=coef, X=X, crossx=crossx, residuals=residuals, treatinds=treatinds,
        xterms=xterms, basecols=basecols)
end

"""
    SolveLeastSquares <: StatsStep

Call [`InteractionWeightedDIDs.solveleastsquares!`](@ref) to
solve the least squares problem for regression coefficients and residuals.
"""
const SolveLeastSquares = StatsStep{:SolveLeastSquares, typeof(solveleastsquares!)}

required(::SolveLeastSquares) = (:tr, :yterm, :xterms, :yxterms, :yxcols, :treatcols,
    :has_fe_intercept)

function _vce(data, esample::BitVector,
        vce::Union{Vcov.SimpleCovariance,Vcov.RobustCovariance}, fes::Vector{FixedEffect})
    dof_absorb = 0
    for fe in fes
        dof_absorb += nunique(fe)
    end
    return vce, dof_absorb
end

function _vce(data, esample::BitVector, vce::Vcov.ClusterCovariance,
        fes::Vector{FixedEffect})
    cludata = _getsubcolumns(data, vce.clusters, esample)
    concrete_vce = Vcov.materialize(cludata, vce)
    dof_absorb = 0
    for fe in fes
        # ! To be fixed
        dof_absorb += any(c->isnested(fe, c.refs), concrete_vce.clusters) ? 1 : nunique(fe)
    end
    return concrete_vce, dof_absorb
end

"""
    estvcov(args...)

Estimate variance-covariance matrix and F-statistic.
See also [`EstVcov`](@ref).
"""
function estvcov(data, esample::BitVector, vce::CovarianceEstimator, coef::Vector,
        X::Matrix, crossx::Factorization, residuals::Vector,
        xterms::Terms, fes::Vector{FixedEffect}, has_fe_intercept::Bool)
    concrete_vce, dof_absorb = _vce(data, esample, vce, fes)
    dof_resid = max(1, sum(esample) - size(X,2) - dof_absorb)
    vce_data = Vcov.VcovData(X, crossx, residuals, dof_resid)
    vcov_mat = vcov(vce_data, concrete_vce)

    # Fstat assumes the last coef is intercept if having any intercept
    has_intercept = !isempty(xterms) && isintercept(xterms[end])
    F = Fstat(coef, vcov_mat, has_intercept)
    has_intercept = has_intercept || has_fe_intercept
    df_F = max(1, Vcov.df_FStat(vce_data, concrete_vce, has_intercept))
    p = fdistccdf(max(length(coef) - has_intercept, 1), df_F, F)
    return (vcov_mat=vcov_mat::Symmetric{Float64,Array{Float64,2}},
        vce=concrete_vce, dof_resid=dof_resid::Int, F=F::Float64, p=p::Float64)
end

"""
    EstVcov <: StatsStep

Call [`InteractionWeightedDIDs.estvcov`](@ref) to
estimate variance-covariance matrix and F-statistic.
"""
const EstVcov = StatsStep{:EstVcov, typeof(estvcov)}

required(::EstVcov) = (:data, :esample, :vce, :coef, :X, :crossx, :residuals, :xterms,
    :fes, :has_fe_intercept)
