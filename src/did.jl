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
        args = (; (kv for kv in pairs(ntargs) if kv[1]!=:name && kv[1]!=:d)...)
        if haskey(ntargs, :d) && length(ntargs.d()) > 0
            return haskey(ntargs, :name) ? ntargs.name : "", ntargs.d, args
        else
            return valid_didargs(DefaultDID, ntargs.tr, ntargs.pr, args)
        end
    else
        throw(ArgumentError("not all required arguments are specified"))
    end
end

valid_didargs(d::Type{<:DiffinDiffsEstimator},
    tr::AbstractTreatment, pr::AbstractParallel, ::NamedTuple) =
        error("$d is not implemented for $(typeof(tr)) and $(typeof(pr))")

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
When used outside [`@specset`](@ref),
a [`StatsSpec`](@ref) is constructed and then estimated by calling this instance.
Options for [`StatsSpec`] can be provided in a bracket `[...]`
as the first argument after `@did` with each option separated by white space.
For options that take a Boolean value,
specifying the name of the option is enough for setting the value to be true.
By default, only a result object that is a subtype of [`DIDResult`](@ref) is returned.

When used inside [`@specset`](@ref),
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
"""
abstract type DIDResult <: StatisticalModel end
