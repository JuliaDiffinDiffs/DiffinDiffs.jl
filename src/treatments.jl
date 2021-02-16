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

show(io::IO, ::SharpDesign) =
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
- `exc::Vector{Int}`: excluded relative time.
- `s::S`: an instance of [`TreatmentSharpness`](@ref).
"""
struct DynamicTreatment{S<:TreatmentSharpness} <: AbstractTreatment
    time::Symbol
    exc::Vector{Int}
    s::S
    function DynamicTreatment(time::Symbol, exc, s::TreatmentSharpness)
        exc = exc !== nothing ? unique!(sort!([exc...])) : Int[]
        return new{typeof(s)}(time, exc, s)
    end
end

show(io::IO, tr::DynamicTreatment) =
    print(IOContext(io, :compact=>true), "Dynamic{", tr.s, "}(",
        isempty(tr.exc) ? "none" : tr.exc, ")")

function show(io::IO, ::MIME"text/plain", tr::DynamicTreatment)
    println(io, tr.s, " dynamic treatment:")
    println(io, "  column name of time variable: ", tr.time)
    print(io, "  excluded relative time: ", isempty(tr.exc) ? "none" : tr.exc)
end

"""
    dynamic(time::Symbol, exc, s::TreatmentSharpness=sharp())

Construct a [`DynamicTreatment`](@ref) with fields set by the arguments.
By default, `s` is set as [`SharpDesign`](@ref).
When working with `@formula`,
a wrapper method of `dynamic` calls this method.

# Examples
```jldoctest; setup = :(using DiffinDiffsBase)
julia> dynamic(:month, -1)
Sharp dynamic treatment:
  column name of time variable: month
  excluded relative time: [-1]

julia> typeof(dynamic(:month, -1))
DynamicTreatment{SharpDesign,Tuple{Int64}}

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
    DynamicTreatment(time, exc, s)

"""
    dynamic(ts::AbstractTerm...)

A wrapper method of `dynamic` for working with `@formula`.
"""
@unpack dynamic

termvars(s::TreatmentSharpness) =
    error("StatsModels.termvars is not defined for $(typeof(s))")
termvars(::SharpDesign) = Symbol[]
termvars(tr::AbstractTreatment) =
    error("StatsModels.termvars is not defined for $(typeof(tr))")
termvars(tr::DynamicTreatment) = [tr.time, termvars(tr.s)...]
