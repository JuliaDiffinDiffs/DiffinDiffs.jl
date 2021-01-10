"""
    DiffinDiffsEstimator <: AbstractStatsProcedure

Supertype for all types specifying the estimation procedure for difference-in-differences.
"""
abstract type DiffinDiffsEstimator <: AbstractStatsProcedure end

"""
    DefaultDID <: DiffinDiffsEstimator

Default difference-in-differences estimator selected based on the context.
"""
struct DefaultDID <: DiffinDiffsEstimator end

did(tr::AbstractTreatment, pr::AbstractParallel; kwargs...) =
    did(DefaultDID, tr, pr; kwargs...)

# The only case in which a message replaces MethodError
did(d::Type{<:DiffinDiffsEstimator}, tr::AbstractTreatment, pr::AbstractParallel; kwargs...) =
    error("$(typeof(d)) is not implemented for $(typeof(tr)) and $(typeof(pr))")

"""
    did(d::Type{<:DiffinDiffsEstimator}, t::TreatmentTerm, args...; kwargs...)

A wrapper method that accepts a [`TreatmentTerm`](@ref).
"""
did(d::Type{<:DiffinDiffsEstimator}, @nospecialize(t::TreatmentTerm), args...; kwargs...) =
    did(d, t.tr, t.pr, args...; treatname=t.sym, kwargs...)

"""
    did(d::Type{<:DiffinDiffsEstimator}, formula::FormulaTerm, args...; kwargs...)

A wrapper method that accepts a formula.
"""
function did(d::Type{<:DiffinDiffsEstimator}, @nospecialize(formula::FormulaTerm),
    args...; kwargs...)
    treat, intacts, xs = parse_treat(formula)
    ints = intacts==() ? NamedTuple() : (treatintterms=intacts,)
    xterms = xs==() ? NamedTuple() : (xterms=xs,)
    return did(d, treat.tr, treat.pr, args...;
        yterm=formula.lhs, treatname=treat.sym, ints..., xterms..., kwargs...)
end

argpair(arg::Type{<:DiffinDiffsEstimator}) = :d => arg
argpair(arg::AbstractString) = :name => String(arg)
argpair(arg::AbstractTreatment) = :tr => arg
argpair(arg::AbstractParallel) = :pr => arg
argpair(::Any) = throw(ArgumentError("unacceptable positional arguments"))

"""
    parse_didargs(args...; kwargs...)

Classify positional arguments for [`did`](@ref) by type
and parse any [`TreatmentTerm`](@ref) or [`FormulaTerm`](@ref).
The order of positional arguments is irrelevant.
This function helps constructing a [`StatsSpec`](@ref)
that can be accepted by [`did`](@ref).

# Returns
- `Type{<:DiffinDiffsEstimator}`: either the type found in positional arguments or `DefaultDID`.
- `String`: either a string found in positional arguments or `""` if no instance of any subtype of `AbstractString` is found.
- `Dict`: up to two key-value pairs for instances of [`AbstractTreatment`](@ref) and [`AbstractParallel`](@ref) with keys being `:tr` and `:pr`.
- `Dict`: keyword arguments with possibly additional pairs after parsing positional arguments.
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
    sptype = pop!(args, :d, DefaultDID)
    name = pop!(args, :name, "")
    return sptype, name, args, kwargs
end

"""
    didspec(args...; kwargs...)

Construct a [`StatsSpec`](@ref) with fields set by processed arguments.
An optional `name` for [`StatsSpec`](@ref) can be included in `args` as a string.
The order of positional arguments is irrelevant.

This method simply passes objects returned by [`parse_didargs`](@ref)
to the constructor of [`StatsSpec`](@ref).
"""
didspec(args...; kwargs...) = StatsSpec(parse_didargs(args...; kwargs...)...)

"""
    @didspec ["name" args... kwargs...]

Call [`didspec`](@ref) for constructing a [`StatsSpec`](@ref).
The order of arguments is irrelevant.

# Arguments
- `name::AbstractString`: an optional name for the [`StatsSpec`](@ref).
- `args... kwargs...`: a list of arguments accepted by [`did`](@ref).
"""
macro didspec(exprs...)
    args, kwargs = args_kwargs(exprs)
    return esc(:(didspec($(args...); $(kwargs...))))
end

function show(io::IO, sp::StatsSpec{T}) where {T<:DiffinDiffsEstimator}
    print(io, "StatsSpec{", sprintcompact(T), "}")
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
    did(sp::StatsSpec)

A wrapper method that accepts a [`StatsSpec`](@ref).
"""
function did(sp::StatsSpec{T}) where {T<:DiffinDiffsEstimator}
    if haskey(sp.args, :tr) && haskey(sp.args, :pr)
        did(T, sp.args[:tr], sp.args[:pr]; sp.kwargs...)
    else
        throw(ArgumentError("not all required arguments are specified"))
    end
end

"""
    @did args... [kwargs...]

Call [`did`](@ref) with the specified arguments.
The order of the arguments is irrelevant.
"""
macro did(exprs...)
    args, kwargs = args_kwargs(exprs)
    return esc(:(did(didspec($(args...); $(kwargs...)))))
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
