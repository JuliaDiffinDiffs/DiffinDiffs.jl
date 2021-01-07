"""
    AbstractDiffinDiffs

Supertype for all types specifying the estimation procedure for difference-in-differences.
"""
abstract type AbstractDiffinDiffs end

# The only case in which a message replaces MethodError
did(d::AbstractDiffinDiffs, tr::AbstractTreatment, pr::AbstractParallel; kwargs...) =
    error("$(typeof(d)) is not implemented for $(typeof(tr)) and $(typeof(pr))")

"""
    did(d::AbstractDiffinDiffs, t::TreatmentTerm, args...; kwargs...)

A wrapper method that accepts a [`TreatmentTerm`](@ref).
"""
did(d::AbstractDiffinDiffs, @nospecialize(t::TreatmentTerm), args...; kwargs...) =
    did(d, t.tr, t.pr, args...; treatname=t.sym, kwargs...)

"""
    did(formula::FormulaTerm, args...; kwargs...)

A wrapper method that accepts a formula.
"""
function did(d::AbstractDiffinDiffs, @nospecialize(formula::FormulaTerm),
    args...; kwargs...)
    treat, intacts, xs = parse_treat(formula)
    ints = intacts==() ? NamedTuple() : (treatintterms=intacts,)
    xterms = xs==() ? NamedTuple() : (xterms=xs,)
    return did(d, treat.tr, treat.pr, args...;
        yterm=formula.lhs, treatname=treat.sym, ints..., xterms..., kwargs...)
end

"""
    args_kwargs(exprs)

Partition a collection of expressions into two arrays
such that all expressions in the second array has `head` being `:(=)`.
This function is useful for separating out expressions
for positional arguments and those for keyword arguments.
"""
function args_kwargs(exprs)
    args = []
    kwargs = []
    for expr in exprs
        (expr isa Expr && expr.head==:(=)) ? push!(kwargs, expr) : push!(args, expr)
    end
    return args, kwargs
end

argpair(arg::AbstractDiffinDiffs) = :d => arg
argpair(arg::AbstractTreatment) = :tr => arg
argpair(arg::AbstractParallel) = :pr => arg
argpair(::Any) = throw(ArgumentError("unacceptable positional arguments"))

"""
    parse_didargs(args...; kwargs...)

Classify positional arguments for [`did`](@ref) by type
and parse any [`TreatmentTerm`](@ref) or [`FormulaTerm`](@ref) in `args`.

# Returns
- `Dict`: up to three key-value pairs for processed positional arguments.
- `Dict`: keyword arguments with possibly additional pairs after parsing `args`.

# Notes
The possible keys for the first `Dict` are `:d`, `:tr` and `:pr`.
They are used to index an instance of [`AbstractDiffinDiffs`](@ref),
[`AbstractTreatment`](@ref) and [`AbstractParallel`](@ref) respectively.

If `args` contains any [`TreatmentTerm`](@ref) or [`FormulaTerm`](@ref),
they are decomposed with additional key-value pairs
joining the other keyword arguments in the second `Dict`.

This function is useful for constructing [`DIDSpec`](@ref).
"""
function parse_didargs(args...; kwargs...)
    pkwargs = Pair{Symbol,Any}[kwargs...]
    pargs = Pair{Symbol,Any}[]
    for arg in args
        if arg isa FormulaTerm
            treat, intacts, xs = parse_treat(arg)
            push!(pargs, argpair(treat.tr), argpair(treat.pr))
            push!(pkwargs, :yterm => arg.lhs, :treatname => treat.sym)
            intacts==() || push!(pkwargs, :treatintterms => intacts)
            xs==() || push!(pkwargs, :xterms => xs)
        elseif arg isa TreatmentTerm
            push!(pargs, argpair(arg.tr), argpair(arg.pr))
            push!(pkwargs, :treatname => arg.sym)
        else
            push!(pargs, argpair(arg))
        end
    end
    args = Dict{Symbol,Any}(pargs...)
    kwargs = Dict{Symbol,Any}(pkwargs...)
    length(args) == length(pargs) && length(kwargs) == length(pkwargs) ||
        throw(ArgumentError("redundant arguments encountered"))
    return args, kwargs
end

"""
    DIDSpec

Record the name, positional arguments and keyword arguments
for a specification of estimation.
"""
struct DIDSpec
    name::Symbol
    args::Dict{Symbol,Any}
    kwargs::Dict{Symbol,Any}
end

==(a::DIDSpec, b::DIDSpec) = a.args == b.args && a.kwargs == b.kwargs

"""
    spec(args...; kwargs...)
    spec(name::Union{Symbol,String}, args...; kwargs...)

Construct a [`DIDSpec`](@ref) with `args` and `kwargs`
processed by [`parse_didargs`](@ref).
If `name` is not specified, the default value `Symbol("")` will be taken.
"""
spec(args...; kwargs...) = DIDSpec(Symbol(""), parse_didargs(args...; kwargs...)...)
spec(name::Union{Symbol,String}, args...; kwargs...) =
    DIDSpec(Symbol(name), parse_didargs(args...; kwargs...)...)

"""
    did(sp::DIDSpec)

A wrapper method that accepts a [`DIDSpec`](@ref).
"""
function did(sp::DIDSpec)
    if all(haskey.(Ref(sp.args), [:d, :tr, :pr]))
        did(sp.args[:d], sp.args[:tr], sp.args[:pr]; sp.kwargs...)
    else
        throw(ArgumentError("not all required arguments are specified"))
    end
end

"""
    @did args... kwargs...

Call [`did`](@ref) with the specified arguments.
Order of the arguments is not important.
"""
macro did(exprs...)
    args, kwargs = args_kwargs(exprs)
    return esc(:(did(spec($(args...); $(kwargs...)))))
end

struct DIDSpecSet
    default::DIDSpec
    specs::DIDSpec
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
