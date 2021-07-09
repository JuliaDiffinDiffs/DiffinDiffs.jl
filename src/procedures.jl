"""
    checkvcov!(args...)

Exclude rows that are invalid for variance-covariance estimator.
See also [`CheckVcov`](@ref).
"""
checkvcov!(data, esample::BitVector, aux::BitVector,
    vce::Union{Vcov.SimpleCovariance, Vcov.RobustCovariance}) = NamedTuple()

function checkvcov!(data, esample::BitVector, aux::BitVector, vce::Vcov.ClusterCovariance)
    for name in Vcov.names(vce)
        col = getcolumn(data, name)
        if Missing <: eltype(col)
            aux .= .!ismissing.(col)
            esample .&= aux
        end
    end
    return (esample=esample,)
end

"""
    CheckVcov <: StatsStep

Call [`InteractionWeightedDIDs.checkvcov!`](@ref) to
exclude rows that are invalid for variance-covariance estimator.
"""
const CheckVcov = StatsStep{:CheckVcov, typeof(checkvcov!), true}

# Get esample and aux directly from CheckData
required(::CheckVcov) = (:data, :esample, :aux)
default(::CheckVcov) = (vce=Vcov.robust(),)
copyargs(::CheckVcov) = (2,)

"""
    parsefeterms!(xterms)

Extract any `FixedEffectTerm` or interaction of `FixedEffectTerm` from `xterms`
and determine whether any intercept term should be omitted.
See also [`ParseFEterms`](@ref).
"""
function parsefeterms!(xterms::TermSet)
    feterms = Set{FETerm}()
    has_fe_intercept = false
    for t in xterms
        result = _parsefeterm(t)
        if result !== nothing
            push!(feterms, result)
            delete!(xterms, t)
        end
    end
    if !isempty(feterms)
        if any(t->isempty(t[2]), feterms)
            has_fe_intercept = true
            for t in xterms
                t isa Union{ConstantTerm,InterceptTerm} && delete!(xterms, t)
            end
            push!(xterms, InterceptTerm{false}())
        end
    end
    return (xterms=xterms, feterms=feterms, has_fe_intercept=has_fe_intercept)
end

const ParseFEterms = StatsStep{:ParseFEterms, typeof(parsefeterms!), true}

required(::ParseFEterms) = (:xterms,)

"""
    groupfeterms(feterms)

Return the argument without change for allowing later comparisons based on object-id.
See also [`GroupFEterms`](@ref).
"""
groupfeterms(feterms::Set{FETerm}) = (feterms=feterms,)

"""
    GroupFEterms <: StatsStep

Call [`InteractionWeightedDIDs.groupfeterms`](@ref)
to obtain one of the instances of `feterms`
that have been grouped by equality (`hash`)
for allowing later comparisons based on object-id.

This step is only useful when working with [`@specset`](@ref) and [`proceed`](@ref).
"""
const GroupFEterms = StatsStep{:GroupFEterms, typeof(groupfeterms), false}

required(::GroupFEterms) = (:feterms,)

"""
    makefes(args...)

Construct `FixedEffect`s from `data` (the full sample).
See also [`MakeFEs`](@ref).
"""
function makefes(data, allfeterms::Vector{FETerm})
    # Must use Dict instead of IdDict since the same feterm can be in multiple feterms
    allfes = Dict{FETerm,FixedEffect}()
    for t in allfeterms
        haskey(allfes, t) && continue
        if isempty(t[2])
            allfes[t] = FixedEffect((getcolumn(data, n) for n in t[1])...)
        else
            allfes[t] = FixedEffect((getcolumn(data, n) for n in t[1])...;
                interaction=_multiply(data, t[2]))
        end
    end
    return (allfes=allfes,)
end

"""
    MakeFEs <: StatsStep

Call [`InteractionWeightedDIDs.makefes`](@ref)
to construct `FixedEffect`s from `data` (the full sample).
"""
const MakeFEs = StatsStep{:MakeFEs, typeof(makefes), false}

required(::MakeFEs) = (:data,)
combinedargs(::MakeFEs, allntargs) = (FETerm[t for nt in allntargs for t in nt.feterms],)

"""
    checkfes!(args...)

Drop any singleton observation from fixed effects over the relevant subsample.
See also [`CheckFEs`](@ref).
"""
function checkfes!(feterms::Set{FETerm}, allfes::Dict{FETerm,FixedEffect},
        esample::BitVector, drop_singletons::Bool)
    nsingle = 0
    nfe = length(feterms)
    if nfe > 0
        fes = Vector{FixedEffect}(undef, nfe)
        fenames = Vector{String}(undef, nfe)
        # Loop together to ensure the orders are the same
        for (i, t) in enumerate(feterms)
            fes[i] = allfes[t]
            fenames[i] = getfename(t)
        end
        # Determine the unique order based on names
        order = sortperm(fenames)
        fes = fes[order]
        fenames = fenames[order]

        if drop_singletons
            for fe in fes
                nsingle += drop_singletons!(esample, fe)
            end
        end
        sum(esample) == 0 && error("no nonmissing data")

        for i in 1:nfe
            fes[i] = fes[i][esample]
        end
        return (esample=esample, fes=fes, fenames=fenames, nsingle=nsingle)
    else
        return (esample=esample, fes=FixedEffect[], fenames=String[], nsingle=0)
    end
end

"""
    CheckFEs <: StatsStep

Call [`InteractionWeightedDIDs.checkfes!`](@ref)
to drop any singleton observation from fixed effects over the relevant subsample.
"""
const CheckFEs = StatsStep{:CheckFEs, typeof(checkfes!), true}

required(::CheckFEs) = (:feterms, :allfes, :esample)
default(::CheckFEs) = (drop_singletons=true,)
copyargs(::CheckFEs) = (3,)

"""
    makefesolver(args...)

Construct `FixedEffects.AbstractFixedEffectSolver`.
See also [`MakeFESolver`](@ref).
"""
function makefesolver(fes::Vector{FixedEffect}, weights::AbstractWeights, nfethreads::Int)
    if !isempty(fes)
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

required(::MakeFESolver) = (:fes, :weights)
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
    for nt in allntargs
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
        cohortinteracted::Bool, fetol::Real, femaxiter::Int, time::Symbol,
        exc::Dict{Int,Int}, notreat::IdDict{ValidTimeType,Int})

    nobs = sum(esample)
    # Putting treatname before time avoids sorting twice if cohortinteracted
    cellnames = Symbol[treatname, time, sort!(termvars(treatintterms))...]
    cols = subcolumns(data, cellnames, esample)
    cells, rows = cellrows(cols, findcell(cols))

    if cells[1] isa RotatingTimeArray
        rel = refarray(cells[2].time) .- refarray(cells[1].time)
    else
        rel = refarray(cells[2]) .- refarray(cells[1])
    end
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
        tcols = VecColumnTable(tcellcols, tcellnames)
        treatcells, subtrows = cellrows(tcols, findcell(tcols))
        trows = Vector{Vector{Int}}(undef, length(subtrows))
        @inbounds for (i, rs) in enumerate(subtrows)
            trows[i] = vcat(view(treatrows, rs)...)
        end
        treatrows = trows
    end

    # Generate treatment indicators
    ntcells = length(treatrows)
    treatcols = Vector{Vector{Float64}}(undef, ntcells)
    treatweights = Vector{Float64}(undef, ntcells)
    treatcounts = Vector{Int}(undef, ntcells)
    @inbounds for i in 1:ntcells
        rs = treatrows[i]
        tcol = zeros(nobs)
        tcol[rs] .= 1.0
        treatcols[i] = tcol
        treatcounts[i] = length(rs)
        if weights isa UnitWeights
            treatweights[i] = treatcounts[i]
        else
            treatweights[i] = sum(view(weights, rs))
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
        treatcols=treatcols::Vector{Vector{Float64}}, treatweights=treatweights,
        treatcounts=treatcounts)
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
# No need to consider typeof(tr) and typeof(pr) given the restrictions by valid_didargs
transformed(::MakeTreatCols, @nospecialize(nt::NamedTuple)) = (nt.tr.time,)

# Obtain the relative time periods excluded by all tr
# and the treatment groups excluded by all pr in allntargs
function combinedargs(::MakeTreatCols, allntargs)
    # exc cannot be IdDict for comparing different types of one
    exc = Dict{Int,Int}()
    notreat = IdDict{ValidTimeType,Int}()
    for nt in allntargs
        foreach(x->_count!(exc, x), nt.tr.exc)
        if nt.pr isa TrendParallel
            foreach(x->_count!(notreat, x), nt.pr.e)
        end
    end
    nnt = length(allntargs)
    for (k, v) in exc
        v == nnt || delete!(exc, k)
    end
    for (k, v) in notreat
        v == nnt || delete!(notreat, k)
    end
    return (exc, notreat)
end

"""
    solveleastsquares!(args...)

Solve the least squares problem for regression coefficients and residuals.
See also [`SolveLeastSquares`](@ref).
"""
function solveleastsquares!(tr::DynamicTreatment{SharpDesign}, pr::TrendOrUnspecifiedPR,
        yterm::AbstractTerm, xterms::TermSet, yxterms::Dict, yxcols::Dict,
        treatcells::VecColumnTable, treatcols::Vector,
        treatweights::Vector, treatcounts::Vector,
        cohortinteracted::Bool, has_fe_intercept::Bool)

    y = yxcols[yxterms[yterm]]
    if cohortinteracted
        if pr isa TrendParallel
            tinds = .!((treatcells[2] .∈ (tr.exc,)) .| (treatcells[1] .∈ (pr.e,)))
        else
            tinds = .!(treatcells[2] .∈ (tr.exc,))
        end
    else
        tinds = .!(treatcells[1] .∈ (tr.exc,))
    end
    treatcells = VecColumnTable(treatcells, tinds)
    tcols = view(treatcols, tinds)
    # Copy the relevant weights and counts
    tweights = treatweights[tinds]
    tcounts = treatcounts[tinds]

    has_intercept, has_omitsintercept = parse_intercept!(xterms)
    xwidth = 0
    # Only terms with positive width should be collected into xs
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
    
    # Check collinearity
    ntcols = length(tcols)
    basiscols = trues(size(X,2))
    if size(X, 2) > ntcols
        basiscols = diag(invsym!(X'X)) .> 0
        # Do not drop any treatment indicator
        sum(basiscols[1:ntcols]) == ntcols ||
            error("covariates are collinear with treatment indicators")
        sum(basiscols) < size(X, 2) &&
            (X = X[:, basiscols])
    end

    crossx = cholesky!(Symmetric(X'X))
    coef = crossx \ (X'y)
    residuals = y - X * coef

    return (coef=coef::Vector{Float64}, X=X::Matrix{Float64},
        crossx=crossx::Cholesky{Float64,Matrix{Float64}},
        residuals=residuals::Vector{Float64}, treatcells=treatcells::VecColumnTable,
        xterms=xs::Vector{AbstractTerm}, basiscols=basiscols::BitVector,
        treatweights=tweights::Vector{Float64}, treatcounts=tcounts::Vector{Int})
end

"""
    SolveLeastSquares <: StatsStep

Call [`InteractionWeightedDIDs.solveleastsquares!`](@ref) to
solve the least squares problem for regression coefficients and residuals.
"""
const SolveLeastSquares = StatsStep{:SolveLeastSquares, typeof(solveleastsquares!), true}

required(::SolveLeastSquares) = (:tr, :pr, :yterm, :xterms, :yxterms, :yxcols,
    :treatcells, :treatcols, :treatweights, :treatcounts,
    :cohortinteracted, :has_fe_intercept)
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

"""
    solveleastsquaresweights(args...)

Solve the cell-level weights assigned by least squares.
If `lswtnames` is not specified,
cells are defined by the partition based on treatment time and calendar time.
See also [`SolveLeastSquaresWeights`](@ref).
"""
function solveleastsquaresweights(::DynamicTreatment{SharpDesign},
        solvelsweights::Bool, lswtnames,
        cells::VecColumnTable, rows::Vector{Vector{Int}},
        X::Matrix, crossx::Factorization, coef::Vector, treatcells::VecColumnTable,
        yterm::AbstractTerm, xterms::Vector{AbstractTerm}, yxterms::Dict, yxcols::Dict,
        feM::Union{AbstractFixedEffectSolver, Nothing}, fetol::Real, femaxiter::Int,
        weights::AbstractWeights)

    solvelsweights || return (lsweights=nothing, cellymeans=nothing, cellweights=nothing,
        cellcounts=nothing)
    cellnames = propertynames(cells)
    length(lswtnames) == 0 && (lswtnames = cellnames)
    for n in lswtnames
        n in cellnames || throw(ArgumentError("$n is invalid for lswtnames"))
    end

    # Construct Y residualized by covariates and FEs but not treatment indicators
    yresid = yxcols[yxterms[yterm]]
    nx = length(xterms)
    nt = size(treatcells, 1)
    if nx > 0
        yresid = copy(yresid)
        for i in 1:nx
            yresid .-= coef[nt+i] .* yxcols[xterms[i]]
        end
    end
    weights isa UnitWeights || (yresid .*= sqrt.(weights))

    if lswtnames == cellnames
        lswtcells = cells
        lswtrows = 1:size(cells,1)
    else
        cols = subcolumns(cells, lswtnames)
        lswtcells, lswtrows = cellrows(cols, findcell(cols))
    end

    # Dummy variable on the left-hand-side
    d = Matrix{Float64}(undef, length(yresid), 1)
    nlswtrow = length(lswtrows)
    lswtmat = Matrix{Float64}(undef, nlswtrow, nt)
    cellymeans = zeros(nlswtrow)
    cellweights = zeros(nlswtrow)
    cellcounts = zeros(Int, nlswtrow)
    @inbounds for i in 1:nlswtrow
        # Reinitialize d for reuse
        fill!(d, 0.0)
        for r in lswtrows[i]
            rs = rows[r]
            d[rs] .= 1.0
            wts = view(weights, rs)
            cellymeans[i] += sum(view(yresid, rs).*wts)
            cellweights[i] += sum(wts)
            cellcounts[i] += length(rs)
        end
        feM === nothing || _feresiduals!(d, feM, fetol, femaxiter)
        weights isa UnitWeights || (d .*= sqrt.(weights))
        lswtmat[i,:] .= view((crossx \ (X'd)), 1:nt)
    end
    cellymeans ./= cellweights
    lswt = TableIndexedMatrix(lswtmat, lswtcells, treatcells)
    return (lsweights=lswt, cellymeans=cellymeans, cellweights=cellweights,
        cellcounts=cellcounts)
end

"""
    SolveLeastSquaresWeights <: StatsStep

Call [`InteractionWeightedDIDs.solveleastsquaresweights`](@ref)
to solve the cell-level weights assigned by least squares.
If `lswtnames` is not specified,
cells are defined by the partition based on treatment time and calendar time.
"""
const SolveLeastSquaresWeights = StatsStep{:SolveLeastSquaresWeights,
    typeof(solveleastsquaresweights), true}

required(::SolveLeastSquaresWeights) = (:tr, :solvelsweights, :lswtnames, :cells, :rows,
    :X, :crossx, :coef, :treatcells, :yterm, :xterms, :yxterms, :yxcols,
    :feM, :fetol, :femaxiter, :weights)
