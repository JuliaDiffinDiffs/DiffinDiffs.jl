"""
    DiffinDiffsEstimator{T} <: AbstractStatsProcedure{T}

Specify the estimation procedure for difference-in-differences.
"""
struct DiffinDiffsEstimator{T} <: AbstractStatsProcedure{T} end

"""
    DefaultDID <: DiffinDiffsEstimator

Default difference-in-differences estimator selected based on the context.
"""
const DefaultDID = DiffinDiffsEstimator{Tuple{}}

show(io::IO, d::Type{DefaultDID}) = print(io, "DefaultDID")

_argpair(arg::Type{<:DiffinDiffsEstimator}) = :d => arg
_argpair(arg::AbstractString) = :name => String(arg)
_argpair(arg::AbstractTreatment) = :tr => arg
_argpair(arg::AbstractParallel) = :pr => arg
_argpair(::Any) = throw(ArgumentError("unacceptable positional arguments"))

"""
    parse_didargs(args...; kwargs...)

Decompose any [`TreatmentTerm`](@ref) or [`FormulaTerm`](@ref) in `args`
and assign keys for all positional arguments based on their types.
An optional `name` for [`StatsSpec`](@ref) can be included in `args` as a string.
The order of positional arguments is irrelevant.
Return a `NamedTuple` that is suitable for passing to
[`valid_didargs`](@ref) for further processing.

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
All unspecified arguments are filled with the default values.
Throw error if any required argument without default value is unspecified.

This function is required for `@specset` to work properly
and also replaces [`did`](@ref) for the purpose of multiple dispatch.
"""
function valid_didargs(ntargs::NamedTuple)
    if haskey(ntargs, :tr) && haskey(ntargs, :pr)
        if haskey(ntargs, :d)
            return valid_didargs(ntargs[:d], ntargs[:tr], ntargs[:pr], ntargs)
        else
            return valid_didargs(DefaultDID, ntargs[:tr], ntargs[:pr], ntargs)
        end
    else
        throw(ArgumentError("not all required arguments are specified"))
    end
end

valid_didargs(d::Type{<:DiffinDiffsEstimator},
    tr::AbstractTreatment, pr::AbstractParallel, ntargs::NamedTuple) =
        error("$(typeof(d)) is not implemented for $(typeof(tr)) and $(typeof(pr))")

didargs(args...; kwargs...) = valid_didargs(parse_didargs(args...; kwargs...))
didspec(args...; kwargs...) = StatsSpec(didargs(args...; kwargs...)...)

"""
    @didspec "name" args... kwargs...

Construct a [`StatsSpec`](@ref) that can be accepted by [`did`](@ref).
The order of arguments is irrelevant.

# Arguments
- `name::AbstractString`: an optional name for the [`StatsSpec`](@ref).
- `args... kwargs...`: a list of arguments to be processed by [`parse_didargs`](@ref) and [`valid_didargs`](@ref).
"""
macro didspec(exprs...)
    args, kwargs = args_kwargs(exprs)
    return esc(:(didspec($(args...); $(kwargs...))))
end

function show(io::IO, sp::StatsSpec{T}) where {T<:DiffinDiffsEstimator}
    print(io, "StatsSpec{", sprintcompact(T), "}")
    _isnamed(sp) && print(io, ": ", sp.name)
    if get(io, :compact, false) || !haskey(sp.args, :tr) && !haskey(sp.args, :pr)
        return
    elseif !_isnamed(sp)
        print(io, ":")    
    end
    haskey(sp.args, :tr) && print(io, "\n  ", sprintcompact(sp.args[:tr]))
    haskey(sp.args, :pr) && print(io, "\n  ", sprintcompact(sp.args[:pr]))
end

function did(args...; verbose::Bool=false, keep=nothing, keepall::Bool=false, kwargs...)
    sp = didspec(args...; kwargs...)
    return sp(verbose=verbose, keep=keep, keepall=keepall)
end

const parse_did_options = parse_specset_options

"""
    @did [option option=val ...] "name" args... kwargs...

Call [`did`](@ref) with the specified arguments.
The order of the arguments is irrelevant.

Options for the behavior of `@did` can be provided in a bracket `[...]`
as the first argument with each option separated by white space.
For options that take a Boolean value,
specifying the name of the option is enough for setting the value to be true.
By default, only an object with a key `result` assigned by a [`StatsStep`](@ref)
or the last value returned by the last [`StatsStep`](@ref) is returned.
The options available are the same as the keyword arguments available for
[`StatsSpec`](@ref).
"""
macro did(args...)
    nargs = length(args)
    if nargs > 0 && isexpr(args[1], :vect, :hcat, :vcat)
        options = parse_did_options(args[1].args)
        if nargs > 1
            didargs = args[2:end]
        end
    else
        options = :(Dict{Symbol, Any}())
        didargs = args
    end
    dargs, dkwargs = args_kwargs(didargs)
    return esc(:(StatsSpec(valid_didargs(parse_didargs($(dargs...); $(dkwargs...)))...)(; $options...)))
end

"""
    DIDResult <: StatisticalModel

Supertype for all types that collect DID estimation results
produced by [`did`](@ref).
"""
abstract type DIDResult <: StatisticalModel end

"""
    agg(r::DIDResult, args...; kwargs...)

Aggregate estimates stored in a [`DIDResult`](@ref).
"""
agg(r::DIDResult, args...; kwargs...) =
    throw("agg is not defined for $(typeof(r)).")

"""
    AggregatedDIDResult <: StatisticalModel

Supertype for all types that collect aggregated DID estimation results
produced by [`agg`](@ref).
"""
abstract type AggregatedDIDResult <: StatisticalModel end
