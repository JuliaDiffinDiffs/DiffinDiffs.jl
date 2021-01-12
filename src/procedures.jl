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
    StatsSpec{T<:AbstractStatsProcedure, IsValidated}

Record the specification for a statistical procedure of type `T`
that may or may not be verified to be valid as indicated by `IsValidated`.

The specification is recorded based on the arguments
for a function that will conduct the procedure.
It is assumed that a tuple of positional arguments accepted by the function
can be constructed solely based on the type of each argument.

# Fields
- `name::String`: an optional name for the specification.
- `args::NamedTuple`: positional arguments indexed based on their types.
- `kwargs::NamedTuple`: keyword arguments.
"""
struct StatsSpec{T<:AbstractStatsProcedure, IsValidated}
    name::String
    args::NamedTuple
    kwargs::NamedTuple
end

StatsSpec(T::Type{<:AbstractStatsProcedure}, name::String,
    args::NamedTuple, kwargs::NamedTuple, IsValidated::Bool=false) =
        StatsSpec{T,IsValidated}(name, args, kwargs)

"""
    ==(x::StatsSpec{T}, y::StatsSpec{T}) where T

Test whether two instances of [`StatsSpec`](@ref)
with the same parameter `T` also have the same fields `args` and `kwargs`.

See also [`≊`](@ref).
"""
==(x::StatsSpec{T}, y::StatsSpec{T}) where T =
    x.args == y.args && x.kwargs == y.kwargs

"""
    ≊(x::StatsSpec{T}, y::StatsSpec{T}) where T

Test whether two instances of [`StatsSpec`](@ref)
with the same parameter `T` also have the fields `args` and `kwargs`
containing the same sets of key-value pairs
while ignoring the orders.
"""
≊(x::StatsSpec{T}, y::StatsSpec{T}) where T =
    x.args ≊ y.args && x.kwargs ≊ y.kwargs

isnamed(sp::StatsSpec) = sp.name != ""

struct StatsSpecSet
    default::StatsSpec
    specs::Vector{StatsSpec}
end

