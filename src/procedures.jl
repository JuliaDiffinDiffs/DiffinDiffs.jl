"""
    AbstractStatsProcedure{T<:NTuple{N,Function} where N}

Supertype for all types specifying the procedure for statistical estimation or inference.

The procedure is determined by the `parameters` of `T`,
which are types of a sequence of functions.
"""
abstract type AbstractStatsProcedure{T<:NTuple{N,Function} where N} end

length(p::AbstractStatsProcedure{T}) where T = length(T.parameters)
eltype(::Type{<:AbstractStatsProcedure}) = Function

function getindex(p::AbstractStatsProcedure{T}, i) where T
    fs = T.parameters[i]
    return fs isa Type && fs <: Function ? fs.instance : [f.instance for f in fs]
end

iterate(p::AbstractStatsProcedure{T}, state=1) where T =
    state > length(p) ? nothing : (p[state], state+1)

"""
    StatsSpec{T<:AbstractStatsProcedure, IsComplete}

Record the specification for a statistical procedure of type `T`
that may or may not be verified to be complete as indicated by `IsComplete`.

The specification is recorded based on the arguments
for a function that will conduct the procedure.
It is assumed that a tuple of positional arguments accepted by the function
can be constructed solely based on the type of each argument.

# Fields
- `name::String`: an optional name for the specification.
- `args::Dict{Symbol}`: positional arguments indexed based on their types.
- `kwargs::Dict{Symbol}`: keyword arguments.
"""
struct StatsSpec{T<:AbstractStatsProcedure, IsComplete}
    name::String
    args::Dict{Symbol}
    kwargs::Dict{Symbol}
end

StatsSpec(T::Type{<:AbstractStatsProcedure}, name::String,
    args::Dict{Symbol}, kwargs::Dict{Symbol}, IsComplete::Bool=false) =
        StatsSpec{T,IsComplete}(name, args, kwargs)

==(a::StatsSpec{T}, b::StatsSpec{T}) where {T<:AbstractStatsProcedure} =
    a.args == b.args && a.kwargs == b.kwargs

isnamed(sp::StatsSpec) = sp.name != ""

struct StatsSpecSet
    default::StatsSpec
    specs::Vector{StatsSpec}
end

