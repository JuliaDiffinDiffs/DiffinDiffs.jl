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
        if isexpr(args[1], :vect, :hcat, :vcat)
            noproceed = _parse!(options, args[1].args)
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
    AbstractDIDResult <: StatisticalModel

Interface supertype for all types that
collect estimation results for difference-in-differences.

# Interface definition
| Required methods | Default definition | Brief description |
|---|---|---|
| `coef(r)` | `r.coef` | Vector of point estimates for all treatment coefficients and covariates |
| `vcov(r)` | `r.vcov` | Variance-covariance matrix for estimates in `coef` |
| `nobs(r)` | `r.nobs` | Number of observations (table rows) involved in estimation |
| `outcomename(r)` | `r.yname` | Name of the outcome variable |
| `coefnames(r)` | `r.coefnames` | Names (`Vector{String}`) of all treatment coefficients and covariates |
| `treatnames(r)` | `coefnames(r)[1:ntreatcoef(r)]` | Names (`Vector{String}`) of treatment coefficients |
| `treatcells(r)` | `r.treatcells` | Tables.jl-compatible tabular description of treatment coefficients in the order of `coefnames` (without covariates) |
| `ntreatcoef(r)` | `size(treatcells(r), 1)` | Number of treatment coefficients |
| `treatcoef(r)` | `view(coef(r), 1:ntreatcoef(r))` | A view of treatment coefficients |
| `treatvcov(r)` | `(N = ntreatcoef(r); view(vcov(r), 1:N, 1:N))` | A view of variance-covariance matrix for treatment coefficients |
| `weights(r)` | `r.weights` | Column name of the weight variable (if specified) |
| **Optional methods** | | |
| `parent(r)` | `r.parent` | Result object from which `r` is generated |
| `responsename(r)` | `outcomename(r)` | Name of the outcome variable |
| `coefinds(r)` | `r.coefinds` | Lookup table (`Dict{String,Int}`) from `coefnames` to integer indices (for retrieving estimates by name) |
| `dof_residual(r)` | `r.dof_residual` | Residual degrees of freedom |
"""
abstract type AbstractDIDResult <: StatisticalModel end

"""
    DIDResult <: AbstractDIDResult

Supertype for all types that collect estimation results
directly obtained from [`DiffinDiffsEstimator`](@ref).
"""
abstract type DIDResult <: AbstractDIDResult end

"""
    AggregatedDIDResult{P<:DIDResult} <: AbstractDIDResult

Supertype for all types that collect estimation results
aggregated from a [`DIDResult`](@ref).
"""
abstract type AggregatedDIDResult{P<:DIDResult} <: AbstractDIDResult end

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
    treatnames(r::AbstractDIDResult)

Return a vector of names for treatment coefficients.
"""
treatnames(r::AbstractDIDResult) = coefnames(r)[1:ntreatcoef(r)]

"""
    treatcells(r::AbstractDIDResult)

Return a Tables.jl-compatible tabular description of treatment coefficients
in the order of coefnames (without covariates).
"""
treatcells(r::AbstractDIDResult) = r.treatcells

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
    weights(r::AbstractDIDResult)

Return the column name of the weight variable.
Return `nothing` if `weights` is not specified for estimation.
"""
weights(r::AbstractDIDResult) = r.weightname

"""
    parent(r::AbstractDIDResult)

Return the `AbstractDIDResult` from which `r` is generated.
"""
parent(r::AbstractDIDResult) = r.parent

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
coefinds(r::AbstractDIDResult) = r.coefinds

"""
    dof_residual(r::AbstractDIDResult)

Return the residual degrees of freedom.
"""
dof_residual(r::AbstractDIDResult) = r.dof_residual

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

function _parse_bys!(bycols::Vector, cells::VecColumnTable, by::Pair{Symbol})
    lookup = getfield(cells, :lookup)
    _parse_bys!(bycols, cells, lookup[by[1]]=>by[2])
end

function _parse_bys!(bycols::Vector, cells::VecColumnTable, by::Pair{Int})
    if by[2] isa Function
        bycols[by[1]] = apply(cells, by[1]=>by[2])
    else
        bycols[by[1]] = apply(cells, by[2][1]=>by[2][2])
    end
end

function _parse_bys!(bycols::Vector, cells::VecColumnTable, bys)
    eltype(bys) <: Pair || throw(ArgumentError("unaccepted type of bys"))
    for by in bys
        _parse_bys!(bycols, cells, by)
    end
end

function _bycells(r::DIDResult, names, bys)
    tcells = treatcells(r)
    bynames = names === nothing ? getfield(tcells, :names) : collect(Symbol, names)
    bycols = AbstractVector[getcolumn(tcells, n) for n in bynames]
    bys === nothing || _parse_bys!(bycols, tcells, bys)
    return VecColumnTable(bycols, bynames)
end

# Count number of elements selected by indices `inds`
_nselected(inds) = eltype(inds) == Bool ? sum(inds) : length(inds)

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
    SubDIDResult{P<:AbstractDIDResult,I,TI} <: AbstractDIDResult

A view into a DID result of type `P` with indices for all coefficients of type `I`
and indices for treatment coefficients of type `TI`.
See also [`view(r::AbstractDIDResult, inds)`](@ref).
"""
struct SubDIDResult{P<:AbstractDIDResult,I,TI} <: AbstractDIDResult
    parent::P
    inds::I
    treatinds::TI
    coefinds::Dict{String,Int}
end

@propagate_inbounds function SubDIDResult(p::AbstractDIDResult, inds)
    @boundscheck if !checkindex(Bool, axes(coef(p), 1), inds)
        throw(BoundsError(p, inds))
    end
    tinds = treatindex(ntreatcoef(p), inds)
    checktreatindex(inds, tinds)
    cnames = view(coefnames(p), inds)
    cfinds = Dict{String,Int}(n=>i for (i,n) in enumerate(cnames))
    return SubDIDResult{typeof(p), typeof(inds), typeof(tinds)}(p, inds, tinds, cfinds)
end

"""
    view(r::AbstractDIDResult, inds)

Return a [`SubDIDResult`](@ref) that lazily references elements
from `r` at the given index or indices `inds` without constructing a copied subset.
"""
@propagate_inbounds view(r::AbstractDIDResult, inds) = SubDIDResult(r, inds)

coef(r::SubDIDResult) = view(coef(parent(r)), r.inds)
vcov(r::SubDIDResult) = view(vcov(parent(r)), r.inds, r.inds)
nobs(r::SubDIDResult) = nobs(parent(r))
outcomename(r::SubDIDResult) = outcomename(parent(r))
coefnames(r::SubDIDResult) = view(coefnames(parent(r)), r.inds)
treatnames(r::SubDIDResult) = view(treatnames(parent(r)), r.treatinds)
treatcells(r::SubDIDResult) = view(treatcells(parent(r)), r.treatinds)
ntreatcoef(r::SubDIDResult) = _nselected(r.treatinds)
treatcoef(r::SubDIDResult) = view(treatcoef(parent(r)), r.treatinds)
treatvcov(r::SubDIDResult) = view(treatvcov(parent(r)), r.treatinds, r.treatinds)
weights(r::SubDIDResult) = weights(parent(r))
responsename(r::SubDIDResult) = responsename(parent(r))
dof_residual(r::SubDIDResult) = dof_residual(parent(r))

"""
    TransformedDIDResult{P,M} <: AbstractDIDResult

Estimation results obtained from a linear transformation
of all coefficient estimates from [`DIDResult`](@ref).
See also [`TransSubDIDResult`](@ref), [`lincom`](@ref) and [`rescale`](@ref).

# Parameters
- `P`: type of the result that is transformed.
- `M`: type of the matrix representing the linear transformation.
"""
struct TransformedDIDResult{P,M} <: AbstractDIDResult
    parent::P
    linmap::M
    coef::Vector{Float64}
    vcov::Matrix{Float64}
    function TransformedDIDResult(r::AbstractDIDResult, linmap::AbstractMatrix{<:Real},
            cf::Vector{Float64}, v::Matrix{Float64})
        return new{typeof(r), typeof(linmap)}(r, linmap, cf, v)
    end
end

"""
    TransSubDIDResult{P,M,I,TI} <: AbstractDIDResult

Estimation results obtained from a linear transformation
of a subset of coefficient estimates from [`DIDResult`](@ref).
See also [`TransformedDIDResult`](@ref), [`lincom`](@ref) and [`rescale`](@ref).

# Parameters
- `P`: type of the result that is transformed.
- `M`: type of the matrix representing the linear transformation.
- `I`: type of indices for all coefficients.
- `TI`: type of indices for treatment coefficients.
"""
struct TransSubDIDResult{P,M,I,TI} <: AbstractDIDResult
    parent::P
    linmap::M
    coef::Vector{Float64}
    vcov::Matrix{Float64}
    inds::I
    treatinds::TI
    coefinds::Dict{String,Int}
    function TransSubDIDResult(r::AbstractDIDResult, linmap::AbstractMatrix{<:Real},
            cf::Vector{Float64}, v::Matrix{Float64}, inds)
        if !checkindex(Bool, axes(coef(r), 1), inds)
            throw(BoundsError(r, inds))
        end
        tinds = treatindex(ntreatcoef(r), inds)
        checktreatindex(inds, tinds)
        cnames = view(coefnames(r), inds)
        cfinds = Dict{String,Int}(n=>i for (i,n) in enumerate(cnames))
        return new{typeof(r), typeof(linmap), typeof(inds), typeof(tinds)}(
            r, linmap, cf, v, inds, tinds, cfinds)
    end
end

const TransOrTransSub = Union{TransformedDIDResult, TransSubDIDResult}

nobs(r::TransOrTransSub) = nobs(parent(r))
outcomename(r::TransOrTransSub) = outcomename(parent(r))
coefnames(r::TransformedDIDResult) = coefnames(parent(r))
coefnames(r::TransSubDIDResult) = view(coefnames(parent(r)), r.inds)
treatnames(r::TransOrTransSub) = treatnames(parent(r))
treatcells(r::TransformedDIDResult) = treatcells(parent(r))
treatcells(r::TransSubDIDResult) = view(treatcells(parent(r)), r.treatinds)
ntreatcoef(r::TransformedDIDResult) = ntreatcoef(parent(r))
ntreatcoef(r::TransSubDIDResult) = _nselected(r.treatinds)
weights(r::TransOrTransSub) = weights(parent(r))
responsename(r::TransOrTransSub) = responsename(parent(r))
coefinds(r::TransformedDIDResult) = coefinds(parent(r))
dof_residual(r::TransOrTransSub) = dof_residual(parent(r))

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
    nr, nc = size(linmap)
    length(coef(r)) == nc ||
        throw(DimensionMismatch("linmap must have $(length(coef(r))) columns"))
    _nselected(subset) == nr || throw(ArgumentError("subset must select $nr elements"))
    cf = linmap * coef(r)
    v = linmap * vcov(r) * linmap'
    return TransSubDIDResult(r, linmap, cf, v, subset)
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
    N1 = length(scale)
    _nselected(subset) == N1 || throw(ArgumentError("subset must select $N1 elements"))
    cf = scale .* view(coef(r), subset)
    v = Matrix{Float64}(undef, N1, N1)
    pv = view(vcov(r), subset, subset)
    @inbounds for j in 1:N1
        for i in 1:N1
            v[i, j] = scale[i]*scale[j]*pv[i, j]
        end
    end
    return TransSubDIDResult(r, Diagonal(scale), cf, v, subset)
end

rescale(r::AbstractDIDResult, by::Pair, subset::Nothing=nothing) =
    rescale(r, apply(treatcells(r), by), 1:ntreatcoef(r))

rescale(r::AbstractDIDResult, by::Pair, subset) =
    rescale(r, apply(view(treatcells(r), subset), by), subset)
