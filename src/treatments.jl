"""
    EleOrVec{T}

Union type of type `T` and `Vector{T}`.
"""
const EleOrVec{T} = Union{T,Vector{T}}

"""
    TreatmentSharpness

Supertype for all types specifying the sharpness of treatment.
"""
abstract type TreatmentSharpness end

@fieldequal TreatmentSharpness

"""
    SharpDesign <: TreatmentSharpness

Assume identical treatment within each treatment group.
"""
struct SharpDesign <: TreatmentSharpness end

show(io::IO, S::SharpDesign) =
    get(io, :compact, false) ? print(io, "S") : print(io, "Sharp")

"""
    sharp()

Alias for [`SharpDesign()`](@ref).
"""
sharp() = SharpDesign()

"""
    AbstractTreatment

Supertype for all treatment types.
"""
abstract type AbstractTreatment end

@fieldequal AbstractTreatment

"""
    DynamicTreatment{E<:EleOrVec{<:Integer},S<:TreatmentSharpness} <: AbstractTreatment

Specify an absorbing binary treatment with effects allowed to evolve over time.
See also [`dynamic`](@ref).

# Fields
- `time::Symbol`: column name of data representing calendar time.
- `exc::E`: excluded relative time (either an integer or vector of integers).
- `s::S`: a [`TreatmentSharpness`](@ref).
"""
struct DynamicTreatment{E<:EleOrVec{<:Integer},S<:TreatmentSharpness} <: AbstractTreatment
    time::Symbol
    exc::E
    s::S
    function DynamicTreatment(time::Symbol, exc::E, s::S) where
        {E<:EleOrVec{<:Integer},S<:TreatmentSharpness}
        if length(exc) > 1
            exc = sort!(exc)
        elseif E <: Vector
            exc = exc[1]
        end
        return new{typeof(exc),S}(time, exc, s)
    end
end

function show(io::IO, tr::DynamicTreatment)
    if get(io, :compact, false)
        print(io, "Dynamic{", tr.s, "}(", tr.exc, ")")
    else
        println(io, tr.s, " dynamic treatment:")
        println(io, "  column name of time variable: ", tr.time)
        print(io, "  excluded relative time: ", tr.exc)
    end
end

"""
    dynamic(time::Symbol, exc::iter{<:Integer}, s::TreatmentSharpness=sharp())

Construct a [`DynamicTreatment`](@ref) with fields set by the arguments.
By default, `s` is set as [`SharpDesign`](@ref).
When working with `@formula`,
a wrapper method of `dynamic` calls this method.

# Examples
```jldoctest; setup = :(using DiffinDiffsBase)
julia> dynamic(:month, -1)
Sharp dynamic treatment:
  column name of time variable: month
  excluded relative time: -1

julia> typeof(dynamic(:month, -1))
DynamicTreatment{Int64,SharpDesign}

julia> dynamic(:month, -3:-1)
Sharp dynamic treatment:
  column name of time variable: month
  excluded relative time: [-3, -2, -1]

julia> dynamic(:month, [-2,-1], sharp())
Sharp dynamic treatment:
  column name of time variable: month
  excluded relative time: [-2, -1]
```
"""
dynamic(time::Symbol, exc, s::TreatmentSharpness=sharp()) =
    DynamicTreatment(time, [exc...], s)

"""
    dynamic(ts::AbstractTerm...)

A wrapper method of `dynamic` for working with `@formula`.
"""
@unpack dynamic
