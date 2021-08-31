"""
    DiffinDiffsEstimator{A,T} <: AbstractStatsProcedure{A,T}

Specify the estimation procedure for difference-in-differences.
"""
struct DiffinDiffsEstimator{A,T} <: AbstractStatsProcedure{A,T} end

"""
    DefaultDID <: DiffinDiffsEstimator

Default difference-in-differences estimator selected based on the context.
"""
const DefaultDID = DiffinDiffsEstimator{:DefaultDID, Tuple{}}

_key(::Type{<:DiffinDiffsEstimator}) = :d
_key(::AbstractString) = :name
_key(::AbstractTreatment) = :tr
_key(::AbstractParallel) = :pr
_key(::Any) = throw(ArgumentError("unacceptable positional arguments"))

function _totermset!(args::Dict{Symbol,Any}, s::Symbol)
    if haskey(args, s) && !(args[s] isa TermSet)
        arg = args[s]
        args[s] = arg isa Symbol ? termset(arg) : termset(arg...)
    end
end

"""
    parse_didargs!(args::Vector{Any}, kwargs::Dict{Symbol,Any})

Return a `Dict` that is suitable for being passed to
[`valid_didargs`](@ref) for further processing.

Any [`TreatmentTerm`](@ref) or [`FormulaTerm`](@ref) in `args` is decomposed.
Any collection of terms is converted to `TermSet`.
Keys are assigned to all positional arguments based on their types.
An optional `name` for [`StatsSpec`](@ref) can be included in `args` as a string.
The order of positional arguments is irrelevant.

This function is required for `@specset` to work properly.
"""
function parse_didargs!(args::Vector{Any}, kwargs::Dict{Symbol,Any})
    for arg in args
        if arg isa FormulaTerm
            treat, intacts, xs = parse_treat(arg)
            kwargs[_key(treat.tr)] = treat.tr
            kwargs[_key(treat.pr)] = treat.pr
            kwargs[:yterm] = arg.lhs
            kwargs[:treatname] = treat.sym
            kwargs[:treatintterms] = intacts
            kwargs[:xterms] = xs
        elseif arg isa TreatmentTerm
            kwargs[_key(arg.tr)] = arg.tr
            kwargs[_key(arg.pr)] = arg.pr
            kwargs[:treatname] = arg.sym
        else
            kwargs[_key(arg)] = arg
        end
    end
    foreach(n->_totermset!(kwargs, n), (:treatintterms, :xterms))
    return kwargs
end

"""
    valid_didargs(args::Dict{Symbol,Any})

Return a tuple of objects that can be accepted by
the constructor of [`StatsSpec`](@ref).
If no [`DiffinDiffsEstimator`](@ref) is found in `args`,
try to select one based on other information.

This function is required for `@specset` to work properly.
"""
function valid_didargs(args::Dict{Symbol,Any})
    if haskey(args, :tr) && haskey(args, :pr)
        d = pop!(args, :d, DefaultDID)
        return valid_didargs(d, args[:tr], args[:pr], args)
    else
        throw(ArgumentError("not all required arguments are specified"))
    end
end

valid_didargs(d::Type{<:DiffinDiffsEstimator},
    tr::AbstractTreatment, pr::AbstractParallel, ::Dict{Symbol,Any}) =
        error(d.instance, " is not implemented for $(typeof(tr)) and $(typeof(pr))")

"""
    didspec(args...; kwargs...)

Construct a [`StatsSpec`](@ref) for difference-in-differences
with the specified arguments.
"""
function didspec(args...; kwargs...)
    args = Any[args...]
    kwargs = Dict{Symbol,Any}(kwargs...)
    return didspec(args, kwargs)
end

didspec(args::Vector{Any}, kwargs::Dict{Symbol,Any}) =
    StatsSpec(valid_didargs(parse_didargs!(args, kwargs))...)

function _show_args(io::IO, sp::StatsSpec{<:DiffinDiffsEstimator})
    if haskey(sp.args, :tr) || haskey(sp.args, :pr)
        print(io, ":")
        haskey(sp.args, :tr) && print(io, "\n  ", sp.args[:tr])
        haskey(sp.args, :pr) && print(io, "\n  ", sp.args[:pr])
    end
end

function did(args...; verbose::Bool=false, keep=nothing, keepall::Bool=false, kwargs...)
    args = Any[args...]
    kwargs = Dict{Symbol,Any}(kwargs...)
    sp = didspec(args, kwargs)
    return sp(verbose=verbose, keep=keep, keepall=keepall)
end

"""
    @did [option option=val ...] "name" args... kwargs...

Conduct difference-in-differences estimation with the specified arguments.
The order of the arguments is irrelevant.

# Arguments
- `[option option=val ...]`: optional settings for @did including keyword arguments passed to an instance of [`StatsSpec`](@ref).
- `name::AbstractString`: an optional name for the [`StatsSpec`](@ref).
- `args... kwargs...`: a list of arguments to be processed by [`parse_didargs!`](@ref) and [`valid_didargs`](@ref).

# Notes
When expanded outside [`@specset`](@ref),
a [`StatsSpec`](@ref) is constructed and then estimated by calling this instance.
Options for [`StatsSpec`] can be provided in a bracket `[...]`
as the first argument after `@did` with each option separated by white space.
For options that take a Boolean value,
specifying the name of the option is enough for setting the value to be true.
By default, only a result object that is a subtype of [`DIDResult`](@ref) is returned.

When expanded inside [`@specset`](@ref),
`@did` informs [`@specset`](@ref) the methods for processing the arguments.
Any option specified in the bracket is ignored.

Options for the behavior of `@did` can be provided in a bracket `[...]`
as the first argument with each option separated by white space.
For options that take a Boolean value,
specifying the name of the option is enough for setting the value to be true.

The following options are available for altering the behavior of `@did`:
- `noproceed::Bool=false`: return the constructed [`StatsSpec`](@ref) without conducting the procedure.
- `verbose::Bool=false`: print the name of each step when it is called.
- `keep=nothing`: names (of type `Symbol`) of additional objects to be returned.
- `keepall::Bool=false`: return all objects generated by procedures along with arguments from the [`StatsSpec`](@ref)s.
- `pause::Int=0`: break the iteration over [`StatsStep`](@ref)s after finishing the specified number of steps (for debugging).
"""
macro did(args...)
    nargs = length(args)
    options = :(Dict{Symbol, Any}())
    noproceed = false
    didargs = ()
    if nargs > 0
        op = args[1]
        if op isa Expr && op.head in (:vect, :hcat, :vcat)
            noproceed = _parse!(options, op.args)
            nargs > 1 && (didargs = args[2:end])
        else
            didargs = args
        end
    end
    dargs, dkwargs = _args_kwargs(didargs)
    if noproceed
        return :(StatsSpec(valid_didargs(parse_didargs!($(esc(dargs)), $(esc(dkwargs))))...))
    else
        return :(StatsSpec(valid_didargs(parse_didargs!($(esc(dargs)), $(esc(dkwargs))))...)(; $(esc(options))...))
    end
end

"""
    AbstractDIDResult{TR<:AbstractTreatment} <: StatisticalModel

Interface supertype for all types that
collect estimation results for difference-in-differences
with treatment of type `TR`.

# Interface definition
| Required method | Default definition | Brief description |
|:---|:---|:---|
| `coef(r)` | `r.coef` | Vector of point estimates for all coefficients including covariates |
| `vcov(r)` | `r.vcov` | Variance-covariance matrix for estimates in `coef` |
| `vce(r)` | `r.vce` | Covariance estimator |
| `confint(r)` | Based on t or normal distribution | Confidence interval for estimates in `coef` |
| `treatment(r)` | `r.tr` | Treatment specification |
| `nobs(r)` | `r.nobs` | Number of observations (table rows) involved in estimation |
| `outcomename(r)` | `r.yname` | Name of the outcome variable |
| `coefnames(r)` | `r.coefnames` | Names (`Vector{String}`) of all coefficients including covariates |
| `treatcells(r)` | `r.treatcells` | `Tables.jl`-compatible tabular description of treatment coefficients in the order of `coefnames` (without covariates) |
| `weights(r)` | `r.weights` | Name of the column containing sample weights (if specified) |
| `ntreatcoef(r)` | `size(treatcells(r), 1)` | Number of treatment coefficients |
| `treatcoef(r)` | `view(coef(r), 1:ntreatcoef(r))` | A view of treatment coefficients |
| `treatvcov(r)` | `(N = ntreatcoef(r); view(vcov(r), 1:N, 1:N))` | A view of variance-covariance matrix for treatment coefficients |
| `treatnames(r)` | `coefnames(r)[1:ntreatcoef(r)]` | Names (`Vector{String}`) of treatment coefficients |
| **Optional methods** | | |
| `parent(r)` | `r.parent` or `r` | Result object from which `r` is generated |
| `dof_residual(r)` | `r.dof_residual` or `nothing` | Residual degrees of freedom |
| `responsename(r)` | `outcomename(r)` | Name of the outcome variable |
| `coefinds(r)` | `r.coefinds` or `nothing` | Lookup table (`Dict{String,Int}`) from `coefnames` to integer indices (for retrieving estimates by name) |
| `ncovariate(r)` | `length(coef(r)) - ntreatcoef(r)` | Number of covariate coefficients |
"""
abstract type AbstractDIDResult{TR<:AbstractTreatment} <: StatisticalModel end

"""
    DIDResult{TR} <: AbstractDIDResult{TR}

Supertype for all types that collect estimation results
directly obtained from [`DiffinDiffsEstimator`](@ref)
with treatment of type `TR`.
"""
abstract type DIDResult{TR} <: AbstractDIDResult{TR} end

"""
    AggregatedDIDResult{TR,P<:DIDResult} <: AbstractDIDResult{TR}

Supertype for all types that collect estimation results
aggregated from a [`DIDResult`](@ref) of type `P`
with treatment of type `TR`.
"""
abstract type AggregatedDIDResult{TR,P<:DIDResult} <: AbstractDIDResult{TR} end

"""
    coef(r::AbstractDIDResult)

Return the vector of point estimates for all coefficients.
"""
coef(r::AbstractDIDResult) = r.coef

"""
    coef(r::AbstractDIDResult, name::String)
    coef(r::AbstractDIDResult, name::Symbol)
    coef(r::AbstractDIDResult, i::Int)
    coef(r::AbstractDIDResult, inds)

Retrieve a point estimate by name (as in `coefnames`) or integer index.
Return a vector of estimates if an iterable collection of names or integers are specified.

Indexing by name requires the method [`coefinds(r)`](@ref).
See also [`AbstractDIDResult`](@ref).
"""
coef(r::AbstractDIDResult, name::String) = coef(r)[coefinds(r)[name]]
coef(r::AbstractDIDResult, name::Symbol) = coef(r, string(name))
coef(r::AbstractDIDResult, i::Int) = coef(r)[i]
coef(r::AbstractDIDResult, inds) = [coef(r, ind) for ind in inds]

"""
    coef(r::AbstractDIDResult, bys::Pair...)

Return a vector of point estimates for treatment coefficients
selected based on the specified functions that return either `true` or `false`.

Depending on the argument(s) accepted by a function `f`,
it is specified with argument `bys` as either `column_index => f` or `column_indices => f`
where `column_index` is either a `Symbol` or `Int`
for a column in [`treatcells`](@ref)
and `column_indices` is an iterable collection of such indices for multiple columns.
`f` is applied elementwise to each specified column
to obtain a `BitVector` for selecting coefficients.
If multiple `Pair`s are provided, the results are combined into one `BitVector`
through bit-wise `and`.

!!! note
    This method only selects estimates for treatment coefficients.
    Covariates are not taken into account.
"""
@inline function coef(r::AbstractDIDResult, bys::Pair...)
    inds = apply_and(treatcells(r), bys...)
    return treatcoef(r)[inds]
end

"""
    vcov(r::AbstractDIDResult)

Return the variance-covariance matrix for all coefficient estimates.
"""
vcov(r::AbstractDIDResult) = r.vcov

"""
    vcov(r::AbstractDIDResult, name1::Union{String, Symbol}, name2::Union{String, Symbol}=name1)
    vcov(r::AbstractDIDResult, i::Int, j::Int=i)
    vcov(r::AbstractDIDResult, inds)

Retrieve the covariance between two coefficients by name (as in `coefnames`) or integer index.
Return the variance if only one name or index is specified.
Return a variance-covariance matrix for selected coefficients
if an iterable collection of names or integers are specified.

Indexing by name requires the method [`coefinds(r)`](@ref).
See also [`AbstractDIDResult`](@ref).
"""
vcov(r::AbstractDIDResult, i::Int, j::Int=i) = vcov(r)[i,j]
function vcov(r::AbstractDIDResult, name1::Union{String, Symbol},
        name2::Union{String, Symbol}=name1)
    cfinds = coefinds(r)
    return vcov(r)[cfinds[string(name1)], cfinds[string(name2)]]
end

function vcov(r::AbstractDIDResult, inds)
    cfinds = coefinds(r)
    # inds needs to be one-dimensional for the output to be a matrix
    inds = [i isa Int ? i : cfinds[string(i)] for i in inds][:]
    return vcov(r)[inds, inds]
end

"""
    vcov(r::AbstractDIDResult, bys::Pair...)

Return a variance-covariance matrix for treatment coefficients
selected based on the specified functions that return either `true` or `false`.

Depending on the argument(s) accepted by a function `f`,
it is specified with argument `bys` as either `column_index => f` or `column_indices => f`
where `column_index` is either a `Symbol` or `Int`
for a column in [`treatcells`](@ref)
and `column_indices` is an iterable collection of such indices for multiple columns.
`f` is applied elementwise to each specified column
to obtain a `BitVector` for selecting coefficients.
If multiple `Pair`s are provided, the results are combined into one `BitVector`
through bit-wise `and`.

!!! note
    This method only selects estimates for treatment coefficients.
    Covariates are not taken into account.
"""
@inline function vcov(r::AbstractDIDResult, bys::Pair...)
    inds = apply_and(treatcells(r), bys...)
    return treatvcov(r)[inds, inds]
end

"""
    vce(r::AbstractDIDResult)

Return the covariance estimator used to estimate variance-covariance matrix.
"""
vce(r::AbstractDIDResult) = r.vce

"""
    confint(r::AbstractDIDResult; level::Real=0.95)

Return a confidence interval for each coefficient estimate.
The returned object is of type `Tuple{Vector{Float64}, Vector{Float64}}`
where the first vector collects the lower bounds for all intervals
and the second one collects the upper bounds.
"""
function confint(r::AbstractDIDResult; level::Real=0.95)
    dofr = dof_residual(r)
    if dofr === nothing
        scale = norminvcdf(1 - (1 - level) / 2)
    else
        scale = tdistinvcdf(dofr, 1 - (1 - level) / 2)
    end
    se = stderror(r)
    return coef(r) .- scale .* se, coef(r) .+ scale .* se
end

"""
    treatment(r::AbstractDIDResult)

Return the treatment specification.
"""
treatment(r::AbstractDIDResult) = r.tr

"""
    nobs(r::AbstractDIDResult)

Return the number of observations (table rows) involved in estimation.
"""
nobs(r::AbstractDIDResult) = r.nobs

"""
    outcomename(r::AbstractDIDResult)

Return the name of outcome variable generated by `StatsModels.coefnames`.
See also [`responsename`](@ref).
"""
outcomename(r::AbstractDIDResult) = r.yname

"""
    coefnames(r::AbstractDIDResult)

Return a vector of coefficient names.
"""
coefnames(r::AbstractDIDResult) = r.coefnames

"""
    treatcells(r::AbstractDIDResult)

Return a `Tables.jl`-compatible tabular description of treatment coefficients
in the order of coefnames (without covariates).
"""
treatcells(r::AbstractDIDResult) = r.treatcells

"""
    weights(r::AbstractDIDResult)

Return the column name of the weight variable.
Return `nothing` if `weights` is not specified for estimation.
"""
weights(r::AbstractDIDResult) = r.weightname

"""
    ntreatcoef(r::AbstractDIDResult)

Return the number of treatment coefficients.
"""
ntreatcoef(r::AbstractDIDResult) = size(treatcells(r), 1)

"""
    treatcoef(r::AbstractDIDResult)

Return a view of treatment coefficients.
"""
treatcoef(r::AbstractDIDResult) = view(coef(r), 1:ntreatcoef(r))

"""
    treatvcov(r::AbstractDIDResult)

Return a view of variance-covariance matrix for treatment coefficients.
"""
treatvcov(r::AbstractDIDResult) = (N = ntreatcoef(r); view(vcov(r), 1:N, 1:N))

"""
    treatnames(r::AbstractDIDResult)

Return a vector of names for treatment coefficients.
"""
treatnames(r::AbstractDIDResult) = coefnames(r)[1:ntreatcoef(r)]

"""
    parent(r::AbstractDIDResult)

Return the `AbstractDIDResult` from which `r` is generated.
"""
parent(r::AbstractDIDResult) = hasfield(typeof(r), :parent) ? r.parent : r

"""
    dof_residual(r::AbstractDIDResult)

Return the residual degrees of freedom.
"""
dof_residual(r::AbstractDIDResult) =
    hasfield(typeof(r), :dof_residual) ? r.dof_residual : nothing

"""
    responsename(r::AbstractDIDResult)

Return the name of outcome variable generated by `StatsModels.coefnames`.
This method is an alias of [`outcomename`](@ref).
"""
responsename(r::AbstractDIDResult) = outcomename(r)

"""
    coefinds(r::AbstractDIDResult)

Return the map from coefficient names to integer indices
for retrieving estimates by name.
"""
coefinds(r::AbstractDIDResult) = hasfield(typeof(r), :coefinds) ? r.coefinds : nothing

"""
    ncovariate(r::AbstractDIDResult)

Return the number of covariate coefficients.
"""
ncovariate(r::AbstractDIDResult) = length(coef(r)) - ntreatcoef(r)

"""
    agg(r::DIDResult)

Aggregate difference-in-differences estimates
and return a subtype of [`AggregatedDIDResult`](@ref).
The implementation depends on the type of `r`.
"""
agg(r::DIDResult) = error("agg is not implemented for $(typeof(r))")

function coeftable(r::AbstractDIDResult; level::Real=0.95)
    cf = coef(r)
    se = stderror(r)
    ts = cf ./ se
    dofr = dof_residual(r)
    if dofr === nothing
        pv = 2 .* normccdf.(abs.(ts))
        tname = "z"
    else
        pv = 2 .* tdistccdf.(dofr, abs.(ts))
        tname = "t"
    end
    cil, ciu = confint(r)
    cnames = coefnames(r)
    levstr = isinteger(level*100) ? string(Integer(level*100)) : string(level*100)
    return CoefTable(Vector[cf, se, ts, pv, cil, ciu],
        ["Estimate", "Std. Error", tname, "Pr(>|$tname|)", "Lower $levstr%", "Upper $levstr%"],
        ["$(cnames[i])" for i = 1:length(cf)], 4, 3)
end

show(io::IO, r::AbstractDIDResult) = show(io, coeftable(r))

"""
    _treatnames(treatcells)

Generate names for treatment coefficients.
Assume `treatcells` is compatible with the `Tables.jl` interface.
"""
function _treatnames(treatcells)
    cols = columnnames(treatcells)
    ncol = length(cols)
    # Assume treatcells has at least one column
    c1 = cols[1]
    names = Ref(string(c1, ": ")).*string.(getcolumn(treatcells, c1))
    if ncol > 1
        for i in 2:ncol
            ci = cols[i]
            names .*= Ref(string(" & ", ci, ": ")).*string.(getcolumn(treatcells, ci))
        end
    end
    return names
end

# Helper functions that parse the bys option for agg
function _parse_bycells!(bycols::Vector, cells::VecColumnTable, by::Pair{Symbol})
    lookup = getfield(cells, :lookup)
    _parse_bycells!(bycols, cells, lookup[by[1]]=>by[2])
end

function _parse_bycells!(bycols::Vector, cells::VecColumnTable, by::Pair{Int})
    if by[2] isa Function
        bycols[by[1]] = apply(cells, by[1]=>by[2])
    else
        bycols[by[1]] = apply(cells, by[2][1]=>by[2][2])
    end
end

function _parse_bycells!(bycols::Vector, cells::VecColumnTable, bys)
    eltype(bys) <: Pair || throw(ArgumentError("unaccepted type of bys"))
    for by in bys
        _parse_bycells!(bycols, cells, by)
    end
end

_parse_bycells!(bycols::Vector, cells::VecColumnTable, bys::Nothing) = nothing

# Helper function for _parse_subset
function _fill_x!(r::AbstractDIDResult, inds::BitVector)
    nx = ncovariate(r)
    nx > 0 && push!(inds, (false for i in 1:nx)...)
end

# Helper functions for handling subset option that may involves Pairs
_parse_subset(r::AbstractDIDResult, by::Pair, fill_x::Bool) =
    (inds = apply_and(treatcells(r), by); fill_x && _fill_x!(r, inds); return inds)

function _parse_subset(r::AbstractDIDResult, inds, fill_x::Bool)
    eltype(inds) <: Pair || return inds
    inds = apply_and(treatcells(r), inds...)
    fill_x && _fill_x!(r, inds)
    return inds
end

_parse_subset(r::AbstractDIDResult, ::Colon, fill_x::Bool) =
    fill_x ? (1:length(coef(r))) : 1:ntreatcoef(r)

# Count number of elements selected by indices `inds`
_nselected(inds) = eltype(inds) == Bool ? sum(inds) : length(inds)
_nselected(::Colon) = throw(ArgumentError("cannot accept Colon (:)"))

"""
    treatindex(ntcoef::Int, I)

Extract indices referencing the treatment coefficients from `I`
based on the total number of treatment coefficients `ntcoef`.
"""
treatindex(ntcoef::Int, ::Colon) = 1:ntcoef
treatindex(ntcoef::Int, i::Real) = i<=ntcoef ? i : 1:0
treatindex(ntcoef::Int, I::AbstractVector{<:Real}) = view(I, I.<=ntcoef)
treatindex(ntcoef::Int, I::AbstractVector{Bool}) = view(I, 1:ntcoef)
treatindex(ntcoef::Int, i) =
    throw(ArgumentError("invalid index of type $(typeof(i))"))

"""
    checktreatindex(inds, tinds)

Check whether all indices for treatment coefficients `tinds`
are positioned before any other index in `inds`.
This is required to be true for methods such as `treatcoef` and `treatvcov`
to work properly.
If the test fails, an `ArgumentError` exception is thrown.
"""
function checktreatindex(inds::AbstractVector{<:Real}, tinds)
    length(tinds) == length(union(tinds, inds[1:length(tinds)])) ||
        throw(ArgumentError("indices for treatment coefficients must come first"))
end

checktreatindex(inds::AbstractVector{Bool}, tinds) = true
checktreatindex(inds, tinds) = true

"""
    SubDIDResult{TR,P<:AbstractDIDResult,I,TI} <: AbstractDIDResult{TR}

A view into a DID result of type `P` with indices for all coefficients of type `I`
and indices for treatment coefficients of type `TI`.
See also [`view(r::AbstractDIDResult, inds)`](@ref).
"""
struct SubDIDResult{TR,P<:AbstractDIDResult,I,TI} <: AbstractDIDResult{TR}
    parent::P
    inds::I
    treatinds::TI
    coefinds::Dict{String,Int}
end

@propagate_inbounds function SubDIDResult(p::AbstractDIDResult{TR}, inds) where {TR}
    @boundscheck if !checkindex(Bool, axes(coef(p), 1), inds)
        throw(BoundsError(p, inds))
    end
    tinds = treatindex(ntreatcoef(p), inds)
    checktreatindex(inds, tinds)
    cnames = view(coefnames(p), inds)
    cfinds = Dict{String,Int}(n=>i for (i,n) in enumerate(cnames))
    return SubDIDResult{TR, typeof(p), typeof(inds), typeof(tinds)}(p, inds, tinds, cfinds)
end

"""
    view(r::AbstractDIDResult, inds)

Return a [`SubDIDResult`](@ref) that lazily references elements
from `r` at the given index or indices `inds` without constructing a copied subset.
"""
@propagate_inbounds view(r::AbstractDIDResult, inds) = SubDIDResult(r, inds)

coef(r::SubDIDResult) = view(coef(parent(r)), r.inds)
vcov(r::SubDIDResult) = view(vcov(parent(r)), r.inds, r.inds)
vce(r::SubDIDResult) = vce(parent(r))
treatment(r::SubDIDResult) = treatment(parent(r))
nobs(r::SubDIDResult) = nobs(parent(r))
outcomename(r::SubDIDResult) = outcomename(parent(r))
coefnames(r::SubDIDResult) = view(coefnames(parent(r)), r.inds)
treatcells(r::SubDIDResult) = view(treatcells(parent(r)), r.treatinds)
weights(r::SubDIDResult) = weights(parent(r))
ntreatcoef(r::SubDIDResult) = _nselected(r.treatinds)
treatcoef(r::SubDIDResult) = view(treatcoef(parent(r)), r.treatinds)
treatvcov(r::SubDIDResult) = view(treatvcov(parent(r)), r.treatinds, r.treatinds)
treatnames(r::SubDIDResult) = view(treatnames(parent(r)), r.treatinds)
dof_residual(r::SubDIDResult) = dof_residual(parent(r))
responsename(r::SubDIDResult) = responsename(parent(r))

"""
    TransformedDIDResult{TR,P,M} <: AbstractDIDResult{TR}

Estimation results obtained from a linear transformation
of all coefficient estimates from [`DIDResult`](@ref).
See also [`TransSubDIDResult`](@ref), [`lincom`](@ref) and [`rescale`](@ref).

# Parameters
- `P`: type of the result that is transformed.
- `M`: type of the matrix representing the linear transformation.
"""
struct TransformedDIDResult{TR,P,M} <: AbstractDIDResult{TR}
    parent::P
    linmap::M
    coef::Vector{Float64}
    vcov::Matrix{Float64}
    function TransformedDIDResult(r::AbstractDIDResult{TR}, linmap::AbstractMatrix{<:Real},
            cf::Vector{Float64}, v::Matrix{Float64}) where {TR}
        return new{TR, typeof(r), typeof(linmap)}(r, linmap, cf, v)
    end
end

"""
    TransSubDIDResult{TR,P,M,I,TI} <: AbstractDIDResult{TR}

Estimation results obtained from a linear transformation
of a subset of coefficient estimates from [`DIDResult`](@ref).
See also [`TransformedDIDResult`](@ref), [`lincom`](@ref) and [`rescale`](@ref).

# Parameters
- `P`: type of the result that is transformed.
- `M`: type of the matrix representing the linear transformation.
- `I`: type of indices for all coefficients.
- `TI`: type of indices for treatment coefficients.
"""
struct TransSubDIDResult{TR,P,M,I,TI} <: AbstractDIDResult{TR}
    parent::P
    linmap::M
    coef::Vector{Float64}
    vcov::Matrix{Float64}
    inds::I
    treatinds::TI
    coefinds::Dict{String,Int}
    function TransSubDIDResult(r::AbstractDIDResult{TR}, linmap::AbstractMatrix{<:Real},
            cf::Vector{Float64}, v::Matrix{Float64}, inds) where {TR}
        if !checkindex(Bool, axes(coef(r), 1), inds)
            throw(BoundsError(r, inds))
        end
        tinds = treatindex(ntreatcoef(r), inds)
        checktreatindex(inds, tinds)
        cnames = view(coefnames(r), inds)
        cfinds = Dict{String,Int}(n=>i for (i,n) in enumerate(cnames))
        return new{TR, typeof(r), typeof(linmap), typeof(inds), typeof(tinds)}(
            r, linmap, cf, v, inds, tinds, cfinds)
    end
end

const TransOrTransSub{TR} = Union{TransformedDIDResult{TR}, TransSubDIDResult{TR}}

vce(r::TransOrTransSub) = vce(parent(r))
treatment(r::TransOrTransSub) = treatment(parent(r))
nobs(r::TransOrTransSub) = nobs(parent(r))
outcomename(r::TransOrTransSub) = outcomename(parent(r))
coefnames(r::TransformedDIDResult) = coefnames(parent(r))
coefnames(r::TransSubDIDResult) = view(coefnames(parent(r)), r.inds)
treatcells(r::TransformedDIDResult) = treatcells(parent(r))
treatcells(r::TransSubDIDResult) = view(treatcells(parent(r)), r.treatinds)
weights(r::TransOrTransSub) = weights(parent(r))
ntreatcoef(r::TransformedDIDResult) = ntreatcoef(parent(r))
ntreatcoef(r::TransSubDIDResult) = _nselected(r.treatinds)
treatnames(r::TransformedDIDResult) = treatnames(parent(r))
treatnames(r::TransSubDIDResult) = view(treatnames(parent(r)), r.treatinds)
dof_residual(r::TransOrTransSub) = dof_residual(parent(r))
responsename(r::TransOrTransSub) = responsename(parent(r))
coefinds(r::TransformedDIDResult) = coefinds(parent(r))

"""
    lincom(r::AbstractDIDResult, linmap::AbstractMatrix{<:Real}, subset=nothing)

Linearly transform the coefficient estimates from DID result `r`
through a matrix `linmap`.
The number of columns of `linmap` must match the total number of coefficients from `r`.
If `linmap` is not square (with fewer rows than columns),
`subset` must be specified with indices representing coefficients
that remain after the transformation.
See also [`rescale`](@ref).
"""
function lincom(r::AbstractDIDResult, linmap::AbstractMatrix{<:Real}, subset::Nothing=nothing)
    nr, nc = size(linmap)
    length(coef(r)) == nc ||
        throw(DimensionMismatch("linmap must have $(length(coef(r))) columns"))
    nr == nc || throw(ArgumentError("subset must be specified if linmap is not square"))
    cf = linmap * coef(r)
    v = linmap * vcov(r) * linmap'
    return TransformedDIDResult(r, linmap, cf, v)
end

function lincom(r::AbstractDIDResult, linmap::AbstractMatrix{<:Real}, subset)
    inds = _parse_subset(r, subset, true)
    nr, nc = size(linmap)
    length(coef(r)) == nc ||
        throw(DimensionMismatch("linmap must have $(length(coef(r))) columns"))
    _nselected(inds) == nr || throw(ArgumentError("subset must select $nr elements"))
    cf = linmap * coef(r)
    v = linmap * vcov(r) * linmap'
    return TransSubDIDResult(r, linmap, cf, v, inds)
end

"""
    rescale(r::AbstractDIDResult, scale::AbstractVector{<:Real}, subset=nothing)
    rescale(r::AbstractDIDResult, by::Pair, subset=nothing)

Rescale the coefficient estimates from DID result `r`.
The order of elements in `scale` must match the order of coefficients.
If the length of `scale` is smaller than the total number of coefficient,
`subset` must be specified with indices representing coefficients
that remain after the transformation.
Alternatively, if `by` is specified in the same way for [`apply`](@ref),
the scales can be computed based on values in [`treatcells(r)`](@ref).
In this case, only treatment coefficients are transformed
even if `subset` is not specified.
See [`lincom`](@ref) for more general transformation.
"""
function rescale(r::AbstractDIDResult, scale::AbstractVector{<:Real}, subset::Nothing=nothing)
    N0 = length(coef(r))
    N1 = length(scale)
    N0 == N1 || throw(ArgumentError(
        "subset must be specified if scale does not have $N0 elements"))
    cf = scale .* coef(r)
    v = Matrix{Float64}(undef, N0, N0)
    pv = vcov(r)
    @inbounds for j in 1:N0
        for i in 1:N0
            v[i, j] = scale[i]*scale[j]*pv[i, j]
        end
    end
    return TransformedDIDResult(r, Diagonal(scale), cf, v)
end

function rescale(r::AbstractDIDResult, scale::AbstractVector{<:Real}, subset)
    inds = _parse_subset(r, subset, true)
    N = length(scale)
    _nselected(inds) == N || throw(ArgumentError("subset must select $N elements"))
    cf = scale .* view(coef(r), inds)
    v = Matrix{Float64}(undef, N, N)
    pv = view(vcov(r), inds, inds)
    @inbounds for j in 1:N
        for i in 1:N
            v[i, j] = scale[i]*scale[j]*pv[i, j]
        end
    end
    return TransSubDIDResult(r, Diagonal(scale), cf, v, inds)
end

rescale(r::AbstractDIDResult, by::Pair, subset::Nothing=nothing) =
    rescale(r, apply(treatcells(r), by), 1:ntreatcoef(r))

function rescale(r::AbstractDIDResult, by::Pair, subset)
    inds = _parse_subset(r, subset, true)
    tinds = treatindex(ntreatcoef(r), inds)
    return rescale(r, apply(view(treatcells(r), tinds), by), inds)
end

"""
    ExportFormat

Supertype for all types representing the format for exporting an [`AbstractDIDResult`](@ref).
"""
abstract type ExportFormat end

"""
    StataPostHDF <: ExportFormat

Export an [`AbstractDIDResult`](@ref) for Stata module
[`posthdf`](https://github.com/junyuan-chen/posthdf).
"""
struct StataPostHDF <: ExportFormat end

const DefaultExportFormat = ExportFormat[StataPostHDF()]

"""
    getexportformat()

Return the default [`ExportFormat`](@ref) for [`post!`](@ref).
"""
getexportformat() = DefaultExportFormat[1]

"""
    setexportformat!(format::ExportFormat)

Set the default [`ExportFormat`](@ref) for [`post!`](@ref).
"""
setexportformat!(format::ExportFormat) = (DefaultExportFormat[1] = format)

"""
    post!(f, r; kwargs...)

Export result `r` in a default [`ExportFormat`](@ref).

The default format can be retrieved via [`getexportformat`](@ref)
and modified via [`setexportformat!`](@ref).
The keyword arguments that can be accepted depend on the format
and the type of `r`.
"""
post!(f, r; kwargs...) =
    post!(f, getexportformat(), r; kwargs...)

_statafield(v::Symbol) = string(v)
_statafield(v::Union{Real, String, Vector{<:Real}, Vector{String}, Matrix{<:Real}}) = v
_statafield(v::Vector{Symbol}) = string.(v)
_statafield(::Nothing) = ""
_statafield(v) = nothing

function _postfields!(f, r::AbstractDIDResult,
        fields::AbstractVector{<:Union{Symbol, Pair{String,Symbol}}})
    for k in fields
        if k isa Symbol
            s = string(k)
            n = k
        else
            s, n = k
        end
        v = _statafield(getfield(r, n))
        v === nothing && throw(ArgumentError(
            "Field $n has a type that cannot be posted via posthdf"))
        f[s] = v
    end
end

_postat!(f, r::AbstractDIDResult, at) = nothing
_postat!(f, r::AbstractDIDResult, at::AbstractVector) = (f["at"] = at)
_postat!(f, r::AbstractDIDResult{<:DynamicTreatment}, at::Bool) =
    at && (f["at"] = treatcells(r).rel)

"""
    post!(f, ::StataPostHDF, r::AbstractDIDResult; kwargs...)

Export result `r` for Stata module
[`posthdf`](https://github.com/junyuan-chen/posthdf).
A subset of field values from `r` are placed in `f` by setting key-value pairs,
where `f` can be either an `HDF5.Group` or any object that can be indexed by strings.

# Keywords
- `model::String=repr(typeof(r))`: name of the model.
- `fields::Union{AbstractVector{<:Union{Symbol, Pair{String,Symbol}}}, Nothing}=nothing`: additional fields to be exported; alternative names can be specified with `Pair`s.
- `at::Union{AbstractVector{<:Real}, Bool, Nothing}=nothing`: post the `at` vector in Stata.
"""
function post!(f, ::StataPostHDF, r::AbstractDIDResult;
        model::String=repr(typeof(r)),
        fields::Union{AbstractVector{<:Union{Symbol, Pair{String,Symbol}}}, Nothing}=nothing,
        at::Union{AbstractVector{<:Real}, Bool, Nothing}=nothing)
    f["model"] = model
    f["b"] = coef(r)
    f["V"] = vcov(r)
    f["vce"] = repr(vce(r))
    f["N"] = nobs(r)
    f["depvar"] = string(outcomename(r))
    f["coefnames"] = convert(AbstractVector{String}, coefnames(r))
    f["weights"] = (w = weights(r); w === nothing ? "" : string(w))
    f["ntreatcoef"] = ntreatcoef(r)
    dofr = dof_residual(r)
    dofr === nothing || (f["df_r"] = dofr)
    fields === nothing || _postfields!(f, r, fields)
    if at !== nothing
        pat = _postat!(f, r, at)
        pat === nothing && throw(ArgumentError(
            "Keyword argument `at` of type $(typeof(at)) is not accepted."))
        pat == false || length(pat) != length(coef(r)) && throw(ArgumentError(
            "The length of at ($(length(pat))) does not match the length of b ($(length(coef(r))))"))
    end
    return f
end
