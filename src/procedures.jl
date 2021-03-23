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
const CheckVcov = StatsStep{:CheckVcov, typeof(checkvcov!), true}

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
function checkfes!(data, esample::BitVector, xterms::TermSet, drop_singletons::Bool)
    fes, fenames, has_fe_intercept = parse_fixedeffect!(data, xterms)
    nsingle = 0
    if !isempty(fes)
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
const CheckFEs = StatsStep{:CheckFixedEffects, typeof(checkfes!), true}

required(::CheckFEs) = (:data, :esample, :xterms)
default(::CheckFEs) = (drop_singletons=true,)
copyargs(::CheckFEs) = (2,3)

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
const MakeFESolver = StatsStep{:MakeFESolver, typeof(makefesolver), true}

required(::MakeFESolver) = (:fes, :weights, :esample)
default(::MakeFESolver) = (nfethreads=Threads.nthreads(),)

function _makeyxcols!(yxterms::Dict, yxcols::Dict, yxschema, data, t::AbstractTerm)
    ct = apply_schema(t, yxschema, StatisticalModel)
    yxterms[t] = ct
    if width(ct) > 0
        tcol = convert(Array{Float64}, modelcols(ct, data))
        all(isfinite, tcol) || error("data for term $ct contain NaN or Inf")
        yxcols[ct] = tcol
    end
end

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
        contrasts::Union{Dict, Nothing}, fetol::Real, femaxiter::Int, allyxterms::TermSet)
    
    # Standardize how an intercept or omitsintercept is represented
    parse_intercept!(allyxterms)

    yxdata = subcolumns(data, termvars(allyxterms), esample)
    yxschema = StatsModels.FullRank(schema(allyxterms, yxdata, contrasts))
    has_fe_intercept && push!(yxschema.already, InterceptTerm{true}())

    yxterms = Dict{AbstractTerm, AbstractTerm}()
    yxcols = Dict{AbstractTerm, VecOrMat{Float64}}()
    for t in allyxterms
        _makeyxcols!(yxterms, yxcols, yxschema, yxdata, t)
    end

    if !has_fe_intercept
        yxcols[InterceptTerm{true}()] = ones(sum(esample))
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

    return (yxterms=yxterms, yxcols=yxcols, nfeiterations=iter, feconverged=conv)
end

"""
    MakeYXCols <: StatsStep

Call [`InteractionWeightedDIDs.makeyxcols`](@ref) to obtain
residualized outcome variables and covariates.
"""
const MakeYXCols = StatsStep{:MakeYXCols, typeof(makeyxcols), true}

required(::MakeYXCols) = (:data, :weights, :esample, :feM, :has_fe_intercept)
default(::MakeYXCols) = (contrasts=nothing, fetol=1e-8, femaxiter=10000)

function combinedargs(::MakeYXCols, allntargs)
    yx = TermSet()
    @inbounds for nt in allntargs
        push!(yx, nt.yterm)
        foreach(x->push!(yx, x), nt.xterms)
    end
    return (yx,)
end

"""
    maketreatcols(args...)

Construct residualized binary columns that capture treatment effects
and obtain cell-level weight sums and observation counts.
See also [`MakeTreatCols`](@ref).
"""
function maketreatcols(data, treatname::Symbol, treatintterms::TermSet,
        feM::Union{AbstractFixedEffectSolver, Nothing},
        weights::AbstractWeights, esample::BitVector,
        cohortinteracted::Bool, fetol::Real, femaxiter::Int,
        ::Type{DynamicTreatment{SharpDesign}}, time::Symbol,
        exc::IdDict{Int,Int}, notreat::IdDict{TimeType,Int})

    nobs = sum(esample)
    # Putting treatname before time avoids sorting twice if cohortinteracted
    cellnames = Symbol[treatname, time, sort!(termvars(treatintterms))...]
    cols = subcolumns(data, cellnames, esample)
    cells, rows = cellrows(cols, findcell(cols))

    rel = cells[2] .- cells[1]
    kept = .!haskey.(Ref(exc), rel) .& .!haskey.(Ref(notreat), cells[1])
    treatrows = rows[kept]
    # Construct cells needed for treatment indicators
    if cohortinteracted
        ntcellcol = length(cellnames)
        tcellcols = Vector{AbstractVector}(undef, ntcellcol)
        tcellnames = Vector{Symbol}(undef, ntcellcol)
        tcellcols[1] = view(cells[1], kept)
        tcellnames[1] = cellnames[1]
        tcellcols[2] = view(rel, kept)
        tcellnames[2] = :rel
        if ntcellcol > 2
            @inbounds for i in 3:ntcellcol
                tcellcols[i] = view(cells[i], kept)
                tcellnames[i] = cellnames[i]
            end
        end
        treatcells = VecColumnTable(tcellcols, tcellnames)
    else
        ntcellcol = length(cellnames) - 1
        tcellcols = Vector{AbstractVector}(undef, ntcellcol)
        tcellnames = Vector{Symbol}(undef, ntcellcol)
        tcellcols[1] = view(rel, kept)
        tcellnames[1] = :rel
        if ntcellcol > 1
            @inbounds for i in 2:ntcellcol
                tcellcols[i] = view(cells[i+1], kept)
                tcellnames[i] = cellnames[i+1]
            end
        end
        treatcells = VecColumnTable(tcellcols, tcellnames)
        rowinds = Dict{VecColsRow, Int}()
        cellinds = Vector{Int}()
        trows = Vector{Vector{Int}}()
        i = 0
        @inbounds for row in Tables.rows(treatcells)
            i += 1
            r = get(rowinds, row, 0)
            if r === 0
                push!(cellinds, i)
                rowinds[row] = length(cellinds)
                push!(trows, copy(treatrows[i]))
            else
                append!(trows[r], treatrows[i])
            end
        end
        for i in 1:ntcellcol
            tcellcols[i] = view(tcellcols[i], cellinds)
        end
        # Need to sort the combined cells and rows
        p = sortperm(treatcells)
        @inbounds for i in 1:ntcellcol
            tcellcols[i] = tcellcols[i][p]
        end
        treatrows = trows[p]
    end

    # Generate treatment indicators
    ntcells = length(treatrows)
    treatcols = Vector{Vector{Float64}}(undef, ntcells)
    cellweights = Vector{Float64}(undef, ntcells)
    cellcounts = Vector{Int}(undef, ntcells)
    @inbounds for i in 1:ntcells
        rs = treatrows[i]
        tcol = zeros(nobs)
        tcol[rs] .= 1.0
        treatcols[i] = tcol
        cellcounts[i] = length(rs)
        if weights isa UnitWeights
            cellweights[i] = cellcounts[i]
        else
            cellweights[i] = sum(view(weights, rs))
        end
    end

    if feM !== nothing
        M = Combination(values(treatcols)...)
        _feresiduals!(M, feM, fetol, femaxiter)
    end

    if !(weights isa UnitWeights)
        for tcol in values(treatcols)
            tcol .*= sqrt.(weights)
        end
    end

    return (cells=cells::VecColumnTable, rows=rows::Vector{Vector{Int}},
        treatcells=treatcells::VecColumnTable, treatrows=treatrows::Vector{Vector{Int}},
        treatcols=treatcols::Vector{Vector{Float64}}, cellweights=cellweights,
        cellcounts=cellcounts)
end

"""
    MakeTreatCols <: StatsStep

Call [`InteractionWeightedDIDs.maketreatcols`](@ref) to obtain
residualized binary columns that capture treatment effects
and obtain cell-level weight sums and observation counts.
"""
const MakeTreatCols = StatsStep{:MakeTreatCols, typeof(maketreatcols), true}

required(::MakeTreatCols) = (:data, :treatname, :treatintterms, :feM, :weights, :esample)
default(::MakeTreatCols) = (cohortinteracted=true, fetol=1e-8, femaxiter=10000)
transformed(::MakeTreatCols, @nospecialize(nt::NamedTuple)) = (typeof(nt.tr), nt.tr.time)

combinedargs(step::MakeTreatCols, allntargs) =
    combinedargs(step, allntargs, typeof(allntargs[1].tr))

# Obtain the relative time periods excluded by all tr in allntargs
function combinedargs(::MakeTreatCols, allntargs, ::Type{DynamicTreatment{SharpDesign}})
    exc = IdDict{Int,Int}()
    notreat = IdDict{TimeType,Int}()
    @inbounds for nt in allntargs
        foreach(x->_count!(exc, x), nt.tr.exc)
        foreach(x->_count!(notreat, x), nt.pr.e)
    end
    nnt = length(allntargs)
    @inbounds for (k, v) in exc
        v == nnt || delete!(exc, k)
    end
    @inbounds for (k, v) in notreat
        v == nnt || delete!(notreat, k)
    end
    return (exc, notreat)
end

"""
    solveleastsquares!(args...)

Solve the least squares problem for regression coefficients and residuals.
See also [`SolveLeastSquares`](@ref).
"""
function solveleastsquares!(tr::DynamicTreatment{SharpDesign}, pr::TrendParallel,
        yterm::AbstractTerm, xterms::TermSet, yxterms::Dict, yxcols::Dict,
        treatcells::VecColumnTable, treatcols::Vector,
        cohortinteracted::Bool, has_fe_intercept::Bool)

    y = yxcols[yxterms[yterm]]
    if cohortinteracted
        tinds = .!((treatcells[2] .∈ (tr.exc,)).| (treatcells[1] .∈ (pr.e,)))
    else
        tinds = .!(treatcells[1] .∈ (tr.exc,))
    end
    treatcells = VecColumnTable(treatcells, tinds)
    tcols = view(treatcols, tinds)

    has_intercept, has_omitsintercept = parse_intercept!(xterms)
    xwidth = 0
    xs = Vector{AbstractTerm}()
    for x in xterms
        cx = yxterms[x]
        w = width(cx)
        xwidth += w
        w > 0 && push!(xs, cx)
    end
    sort!(xs, by=coefnames)
    # Add back an intercept to the last position if needed
    if !has_fe_intercept && !has_omitsintercept
        push!(xs, InterceptTerm{true}())
        xwidth += 1
    end

    X = hcat(tcols..., (yxcols[x] for x in xs)...)
    
    ntcols = length(tcols)
    basecols = trues(size(X,2))
    if size(X, 2) > ntcols
        basecols = basecol(X)
        # Do not drop any treatment indicator
        sum(basecols[1:ntcols]) == ntcols ||
            error("covariates are collinear with treatment indicators")
        sum(basecols) < size(X, 2) &&
            (X = X[:, basecols])
    end

    crossx = cholesky!(Symmetric(X'X))
    coef = crossx \ (X'y)
    residuals = y - X * coef

    return (coef=coef::Vector{Float64}, X=X::Matrix{Float64},
        crossx=crossx::Cholesky{Float64,Matrix{Float64}},
        residuals=residuals::Vector{Float64}, treatcells=treatcells::VecColumnTable,
        xterms=xs::Vector{AbstractTerm}, basecols=basecols::BitVector)
end

"""
    SolveLeastSquares <: StatsStep

Call [`InteractionWeightedDIDs.solveleastsquares!`](@ref) to
solve the least squares problem for regression coefficients and residuals.
"""
const SolveLeastSquares = StatsStep{:SolveLeastSquares, typeof(solveleastsquares!), true}

required(::SolveLeastSquares) = (:tr, :pr, :yterm, :xterms, :yxterms, :yxcols,
    :treatcells, :treatcols, :cohortinteracted, :has_fe_intercept)
copyargs(::SolveLeastSquares) = (4,)

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
    cludata = subcolumns(data, Vcov.names(vce), esample)
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
        xterms::Vector{AbstractTerm}, fes::Vector{FixedEffect}, has_fe_intercept::Bool)
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
const EstVcov = StatsStep{:EstVcov, typeof(estvcov), true}

required(::EstVcov) = (:data, :esample, :vce, :coef, :X, :crossx, :residuals, :xterms,
    :fes, :has_fe_intercept)
