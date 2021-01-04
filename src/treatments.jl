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
    DynamicTreatment{S<:TreatmentSharpness} <: AbstractTreatment

Specify an absorbing binary treatment with effects allowed to evolve over time.
See also [`dynamic`](@ref).

# Fields
- `time::Symbol`: column name of data representing calendar time.
- `s::S`: a [`TreatmentSharpness`](@ref).
"""
struct DynamicTreatment{S<:TreatmentSharpness} <: AbstractTreatment
    time::Symbol
    s::S
    DynamicTreatment(time::Symbol, s::S) where {S<:TreatmentSharpness} =
        new{S}(time, s)
end

function show(io::IO, tr::DynamicTreatment)
    if get(io, :compact, false)
        print(io, "Dynamic{", tr.s, "}")
    else
        println(io, tr.s, " dynamic treatment:")
        println(io, "  column name of time variable: ", tr.time)
    end
end

"""
    dynamic(time::Symbol, s::TreatmentSharpness=sharp())

Construct a [`DynamicTreatment`](@ref) with fields set by the arguments.
By default, `s` is set as [`SharpDesign`](@ref).
When working with `@formula`,
a wrapper method of `dynamic` calls this method.

# Examples
```jldoctest; setup = :(using DiffinDiffsBase)
julia> dynamic(:month)
Sharp dynamic treatment:
  column name of time variable: month

julia> typeof(dynamic(:month))
DynamicTreatment{SharpDesign}

julia> dynamic(:month, sharp())
Sharp dynamic treatment:
  column name of time variable: month
```
"""
dynamic(time::Symbol, s::TreatmentSharpness=sharp()) =
    DynamicTreatment(time, s)

"""
    dynamic(ts::AbstractTerm...)

A wrapper method of `dynamic` for working with `@formula`.
"""
@unpack dynamic
