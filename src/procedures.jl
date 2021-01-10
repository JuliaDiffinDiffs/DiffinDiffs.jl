"""
    AbstractStatsProcedure

Supertype for all types specifying the procedure for statistical estimation or inference.
"""
abstract type AbstractStatsProcedure end

"""
    StatsSpec{T<:AbstractStatsProcedure}

Record the specification for a statistical procedure and
optionally a name for the specification.

The specification is recorded based on the arguments
for a function that will conduct the procedure.
It is assumed that a tuple of positional arguments accepted by the function
can be constructed solely based on the type of each argument.

# Fields
- `name::String`: name for the specification.
- `args::Dict{Symbol}`: positional arguments indexed based on their types.
- `kwargs::Dict{Symbol}`: keyword arguments.
"""
struct StatsSpec{T<:AbstractStatsProcedure}
    name::String
    args::Dict{Symbol}
    kwargs::Dict{Symbol}
    StatsSpec(T::Type{<:AbstractStatsProcedure},
        name::String, args::Dict{Symbol}, kwargs::Dict{Symbol}) =
            new{T}(name, args, kwargs)
end

==(a::StatsSpec{T}, b::StatsSpec{T}) where {T<:AbstractStatsProcedure} =
    a.args == b.args && a.kwargs == b.kwargs

isnamed(sp::StatsSpec) = sp.name != ""

struct StatsSpecSet
    default::StatsSpec
    specs::Vector{StatsSpec}
end

