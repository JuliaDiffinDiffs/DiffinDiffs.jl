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

_argpair(arg::Type{<:DiffinDiffsEstimator}) = :d => arg
_argpair(arg::AbstractString) = :name => String(arg)
_argpair(arg::AbstractTreatment) = :tr => arg
_argpair(arg::AbstractParallel) = :pr => arg
_argpair(::Any) = throw(ArgumentError("unacceptable positional arguments"))

"""
    parse_didargs(args...; kwargs...)

Return a `NamedTuple` that is suitable for being passed to
[`valid_didargs`](@ref) for further processing.

Any [`TreatmentTerm`](@ref) or [`FormulaTerm`](@ref) in `args` is decomposed.
Keys are assigned to all positional arguments based on their types.
An optional `name` for [`StatsSpec`](@ref) can be included in `args` as a string.
The order of positional arguments is irrelevant.

This function is required for `@specset` to work properly.
"""
function parse_didargs(args...; kwargs...)
    pargs = Pair{Symbol,Any}[kwargs...]
    for arg in args
        if arg isa FormulaTerm
            treat, intacts, xs = parse_treat(arg)
            push!(pargs, _argpair(treat.tr), _argpair(treat.pr))
            push!(pargs, :yterm => arg.lhs, :treatname => treat.sym)
            intacts==() || push!(pargs, :treatintterms => intacts)
            xs==() || push!(pargs, :xterms => xs)
        elseif arg isa TreatmentTerm
            push!(pargs, _argpair(arg.tr), _argpair(arg.pr))
            push!(pargs, :treatname => arg.sym)
        else
            push!(pargs, _argpair(arg))
        end
    end
    keyargs = first.(pargs)
    length(keyargs) != length(unique(keyargs)) &&
        throw(ArgumentError("redundant arguments encountered"))
    ntargs = (; pargs...)
    return ntargs
end

"""
    valid_didargs(ntargs::NamedTuple)

Return a tuple of objects that can be accepted by
the constructor of [`StatsSpec`](@ref).
If no [`DiffinDiffsEstimator`](@ref) is found in `ntargs`,
try to select one based on other information.

This function is required for `@specset` to work properly.
"""
function valid_didargs(ntargs::NamedTuple)
    if haskey(ntargs, :tr) && haskey(ntargs, :pr)
        d = haskey(ntargs, :d) ? ntargs.d : DefaultDID
        return valid_didargs(d, ntargs.tr, ntargs.pr, ntargs)
    else
        throw(ArgumentError("not all required arguments are specified"))
    end
end

valid_didargs(d::Type{<:DiffinDiffsEstimator},
    tr::AbstractTreatment, pr::AbstractParallel, ::NamedTuple) =
        error(d.instance, " is not implemented for $(typeof(tr)) and $(typeof(pr))")

_didargs(args...; kwargs...) = valid_didargs(parse_didargs(args...; kwargs...))

"""
    didspec(args...; kwargs...)

Construct a [`StatsSpec`](@ref) for difference-in-differences
with the specified arguments.
"""
didspec(args...; kwargs...) = StatsSpec(_didargs(args...; kwargs...)...)

function _show_args(io::IO, sp::StatsSpec{A,<:DiffinDiffsEstimator}) where A
    if haskey(sp.args, :tr) || haskey(sp.args, :pr)
        print(io, ":")
        haskey(sp.args, :tr) && print(io, "\n  ", sp.args[:tr])
        haskey(sp.args, :pr) && print(io, "\n  ", sp.args[:pr])
    end
end

function did(args...; verbose::Bool=false, keep=nothing, keepall::Bool=false, kwargs...)
    sp = didspec(args...; kwargs...)
    return sp(verbose=verbose, keep=keep, keepall=keepall)
end

"""
    @did [option option=val ...] "name" args... kwargs...

Conduct difference-in-differences estimation with the specified arguments.
The order of the arguments is irrelevant.

# Arguments
- `[option option=val ...]`: optional settings for @did including keyword arguments passed to an instance of [`StatsSpec`](@ref).
- `name::AbstractString`: an optional name for the [`StatsSpec`](@ref).
- `args... kwargs...`: a list of arguments to be processed by [`parse_didargs`](@ref) and [`valid_didargs`](@ref).

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
"""
macro did(args...)
    nargs = length(args)
    options = :(Dict{Symbol, Any}())
    noproceed = false
    didargs = []
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
        return esc(:(StatsSpec(valid_didargs(parse_didargs($(dargs...); $(dkwargs...)))...)))
    else
        return esc(:(StatsSpec(valid_didargs(parse_didargs($(dargs...); $(dkwargs...)))...)(; $options...)))
    end
end

"""
    DIDResult <: StatisticalModel

Supertype for all types that collect estimation results for difference-in-differences.

All concrete subtypes of `DIDResult` are expected to have the following fields:
- `coef::Vector{Float64}`: point estimates of all treatment coefficients and covariates.
- `vcov::Matrix{Float64}`: variance-covariance matrix for estimates in `coef`.
- `nobs::Int`: number of observations (table rows) involved in estimation.
- `dof_residual::Int`: residual degrees of freedom.
- `yname::String`: name of the outcome variable (generated by `StatsModels.coefnames`).
- `coefnames::Vector{String}`: names of all treatment coefficients and covariates.
- `coefinds::Dict{String, Int}`: a map from `coefnames` to integer indices for retrieving estimates by name.
- `treatinds::Table`: tabular descriptions of treatment coefficients in the order of `coefnames` (do not contain covariates).
- `weights::Union{Symbol, Nothing}`: column name of the weight variable (if specified).
"""
abstract type DIDResult <: StatisticalModel end

"""
    _treatnames(treatinds)

Generate names for treatment coefficients.
Assume `treatinds` is compatible with the `Tables.jl` interface.
"""
function _treatnames(treatinds)
    cols = columnnames(treatinds)
    ncol = length(cols)
    # Assume treatinds has at least one column
    c1 = cols[1]
    names = Ref(string(c1, ": ")).*string.(getcolumn(treatinds, c1))
    if ncol > 1
        for i in 2:ncol
            ci = cols[i]
            names .*= Ref(string(" & ", ci, ": ")).*string.(getcolumn(treatinds, ci))
        end
    end
    return names
end

"""
    coef(r::DIDResult)

Access the vector where all point estimates are stored in `r`.
"""
coef(r::DIDResult) = r.coef

"""
    coef(r::DIDResult, name::String)
    coef(r::DIDResult, name::Symbol)
    coef(r::DIDResult, i::Int)
    coef(r::DIDResult, inds)

Retrieve a point estimate by name (as in `coefnames`) or integer index.
Return an array of estimates if an iterable collection of names or integers are specified.

The main advantage of these methods is fast indexing by name.
If names are not used, it may be more efficient to
directly work with the array returned by `coef(r)`.
"""
coef(r::DIDResult, name::String) = r.coef[r.coefinds[name]]
coef(r::DIDResult, name::Symbol) = coef(r, string(name))
coef(r::DIDResult, i::Int) = r.coef[i]
coef(r::DIDResult, inds) = [coef(r, ind) for ind in inds]

"""
    coef(f::Function, r::DIDResult)

Return a vector of point estimates for treatment coefficients
selected based on whether `f` returns `true` or `false`
for each corresponding row in `treatinds`.

!!! note
    This method only selects estimates for treatment coefficients.
    Covariates are not taken into account.
"""
coef(f::Function, r::DIDResult) = view(r.coef, 1:length(r.treatinds))[f.(r.treatinds)]

"""
    vcov(r::DIDResult)

Return a variance-covariance matrix from estimation result `r`.
"""
vcov(r::DIDResult) = r.vcov

"""
    vcov(r::DIDResult, name1::Union{String, Symbol}, name2::Union{String, Symbol}=name1)
    vcov(r::DIDResult, i::Int, j::Int=i)
    vcov(r::DIDResult, inds)

Retrieve the covariance between two coefficients by name (as in `coefnames`) or integer index.
Return the variance if only one name or index is specified.
Return a variance-covariance matrix for selected coefficients
if an iterable collection of names or integers are specified.

The main advantage of these methods is fast indexing by name.
If names are not used, it may be more efficient to
directly work with the array returned by `vcov(r)`.
"""
vcov(r::DIDResult, i::Int, j::Int=i) = r.vcov[i,j]
vcov(r::DIDResult, name1::Union{String, Symbol}, name2::Union{String, Symbol}=name1) =
    vcov(r, r.coefinds[string(name1)], r.coefinds[string(name2)])

function vcov(r::DIDResult, inds)
    # inds needs to be one-dimensional for the output to be a matrix
    inds = [i isa Int ? i : r.coefinds[string(i)] for i in inds][:]
    return r.vcov[inds, inds]
end

"""
    vcov(f::Function, r::DIDResult)

Return a variance-covariance matrix for treatment coefficients
selected based on whether `f` returns `true` or `false`
for each corresponding row in `treatinds`.

!!! note
    This method only selects estimates for treatment coefficients.
    Covariates are not taken into account.
"""
function vcov(f::Function, r::DIDResult)
    N = length(r.treatinds)
    inds = f.(r.treatinds)
    return view(r.vcov, 1:N, 1:N)[inds, inds]
end

"""
    nobs(r::DIDResult)

Return the number of observations (table rows) involved in estimation.
"""
nobs(r::DIDResult) = r.nobs

"""
    dof_residual(r::DIDResult)

Return the residual degrees of freedom.
"""
dof_residual(r::DIDResult) = r.dof_residual

"""
    responsename(r::DIDResult)

Return the name of outcome variable generated by `StatsModels.coefnames`.
See also [`outcomename`](@ref).
"""
responsename(r::DIDResult) = r.yname

"""
    outcomename(r::DIDResult)

Return the name of outcome variable generated by `StatsModels.coefnames`.
This method is an alias of [`responsename`](@ref).
"""
outcomename(r::DIDResult) = responsename(r)

"""
    coefnames(r::DIDResult)

Return a vector of coefficient names.
"""
coefnames(r::DIDResult) = r.coefnames

"""
    treatnames(r::DIDResult)

Return a vector of names for treatment coefficients.
"""
treatnames(r::DIDResult) = r.coefnames[1:size(r.treatinds,1)]

"""
    weights(r::DIDResult)

Return the column name of the weight variable.
Return `nothing` if weights are not specified.
"""
weights(r::DIDResult) = r.weightname
