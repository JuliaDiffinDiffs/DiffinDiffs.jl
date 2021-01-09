"""
    AbstractDiffinDiffs

Supertype for all types specifying the estimation procedure for difference-in-differences.
"""
abstract type AbstractDiffinDiffs end

"""
    DefaultDID <: AbstractDiffinDiffs

Try to use a default procedure based on other information.
"""
struct DefaultDID <: AbstractDiffinDiffs end

did(tr::AbstractTreatment, pr::AbstractParallel; kwargs...) =
    did(DefaultDID, tr, pr; kwargs...)

# The only case in which a message replaces MethodError
did(d::Type{<:AbstractDiffinDiffs}, tr::AbstractTreatment, pr::AbstractParallel; kwargs...) =
    error("$(typeof(d)) is not implemented for $(typeof(tr)) and $(typeof(pr))")

"""
    did(d::Type{<:AbstractDiffinDiffs}, t::TreatmentTerm, args...; kwargs...)

A wrapper method that accepts a [`TreatmentTerm`](@ref).
"""
did(d::Type{<:AbstractDiffinDiffs}, @nospecialize(t::TreatmentTerm), args...; kwargs...) =
    did(d, t.tr, t.pr, args...; treatname=t.sym, kwargs...)

"""
    did(d::Type{<:AbstractDiffinDiffs}, formula::FormulaTerm, args...; kwargs...)

A wrapper method that accepts a formula.
"""
function did(d::Type{<:AbstractDiffinDiffs}, @nospecialize(formula::FormulaTerm),
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

argpair(arg::AbstractString) = :name => String(arg)
argpair(arg::Type{<:AbstractDiffinDiffs}) = :d => arg
argpair(arg::AbstractTreatment) = :tr => arg
argpair(arg::AbstractParallel) = :pr => arg
argpair(::Any) = throw(ArgumentError("unacceptable positional arguments"))

"""
    parse_didargs(args...; kwargs...)

Classify positional arguments for [`did`](@ref) by type
and parse any [`TreatmentTerm`](@ref) or [`FormulaTerm`](@ref) in `args`.
The order of positional arguments in `args` does not make a difference.

# Returns
- `String`: optional name for [`DIDSpec`](@ref) (return `""` if no instance of a subtype of `AbstractString` is found).
- `Dict`: up to three key-value pairs for processed positional arguments.
- `Dict`: keyword arguments with possibly additional pairs after parsing `args`.

# Notes
The possible keys for the first `Dict` are `:d`, `:tr` and `:pr`.
They are used to index a subtype of [`AbstractDiffinDiffs`](@ref),
instances of [`AbstractTreatment`](@ref) and [`AbstractParallel`](@ref) respectively.

If `args` contains any [`TreatmentTerm`](@ref) or [`FormulaTerm`](@ref),
they are decomposed with additional key-value pairs
joining the other keyword arguments in the second `Dict`.

This function is useful for constructing [`DIDSpec`](@ref).
"""
function parse_didargs(args...; kwargs...)
    pargs = Pair{Symbol,Any}[]
    pkwargs = Pair{Symbol,Any}[kwargs...]
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
    name = pop!(args, :name, "")
    return name, args, kwargs
end

"""
    DIDSpec{T<:AbstractDiffinDiffs}

Record the positional arguments and keyword arguments for [`did`](@ref)
and optionally a name for the specification.

# Fields
- `name::String`: name for the specification.
- `args::Dict{Symbol}`: positional arguments indexed based on their types.
- `kwargs::Dict{Symbol}`: keyword arguments.
"""
struct DIDSpec{T<:AbstractDiffinDiffs}
    name::String
    args::Dict{Symbol}
    kwargs::Dict{Symbol}
    DIDSpec(name::String, args::Dict{Symbol}, kwargs::Dict{Symbol}) =
        new{pop!(args, :d, DefaultDID)}(name, args, kwargs)
end

==(a::DIDSpec{T}, b::DIDSpec{T}) where {T<:AbstractDiffinDiffs} =
    a.args == b.args && a.kwargs == b.kwargs

isnamed(sp::DIDSpec) = sp.name != ""

function show(io::IO, sp::DIDSpec{T}) where {T}
    print(io, "DIDSpec{", sprintcompact(T), "}")
    isnamed(sp) && print(io, ": ", sp.name)
    if get(io, :compact, false) || !haskey(sp.args, :tr) && !haskey(sp.args, :pr)
        return
    elseif !isnamed(sp)
        print(io, ":")    
    end
    haskey(sp.args, :tr) && print(io, "\n  ", sprintcompact(sp.args[:tr]))
    haskey(sp.args, :pr) && print(io, "\n  ", sprintcompact(sp.args[:pr]))
end

"""
    spec(args...; kwargs...)

Construct a [`DIDSpec`](@ref) with `args` and `kwargs`
processed by [`parse_didargs`](@ref).
An optional `name` for [`DIDSpec`](@ref) can be included in `args` as a string.

This method simply passes objects returned by [`parse_didargs`](@ref)
to the constructor of [`DIDSpec`](@ref).
"""
spec(args...; kwargs...) = DIDSpec(parse_didargs(args...; kwargs...)...)

"""
    @spec ["name" args... kwargs...]

Return a [`DIDSpec`](@ref) with fields set by the arguments.
The order of the arguments does not make a difference.

# Arguments
- `name::AbstractString`: an optional name for the specification.
- `args... kwargs...`: a list of arguments for [`did`](@ref).
"""
macro spec(exprs...)
    args, kwargs = args_kwargs(exprs)
    return esc(:(spec($(args...); $(kwargs...))))
end

"""
    did(sp::DIDSpec)

A wrapper method that accepts a [`DIDSpec`](@ref).
"""
function did(sp::DIDSpec{T}) where {T}
    if haskey(sp.args, :tr) && haskey(sp.args, :pr)
        did(T, sp.args[:tr], sp.args[:pr]; sp.kwargs...)
    else
        throw(ArgumentError("not all required arguments are specified"))
    end
end

"""
    @did args... [kwargs...]

Call [`did`](@ref) with the specified arguments.
The order of the arguments does not make a difference.
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
