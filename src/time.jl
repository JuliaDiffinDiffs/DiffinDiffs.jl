"""
    RotatingTimeValue{R, T}

A wrapper around a time value for distinguishing potentially different
rotation group it could belong to in a rotating sampling design.
See also [`rotatingtime`](@ref) and [`settime`](@ref).

# Fields
- `rotation::R`: a rotation group in a rotating sampling design.
- `time::T`: a time value belonged to the rotation group.
"""
struct RotatingTimeValue{R, T}
    rotation::R
    time::T
end

RotatingTimeValue(::Type{RotatingTimeValue{R,T}}, rotation, time) where {R,T} =
    RotatingTimeValue(convert(R, rotation), convert(T, time))

"""
    rotatingtime(rotation, time)

Construct [`RotatingTimeValue`](@ref)s from `rotation` and `time`.
This method simply broadcasts the default constructor over the arguments.
"""
rotatingtime(rotation, time) = RotatingTimeValue.(rotation, time)

+(x::RotatingTimeValue, y) = RotatingTimeValue(x.rotation, x.time + y)
+(x, y::RotatingTimeValue) = RotatingTimeValue(y.rotation, x + y.time)
-(x::RotatingTimeValue, y) = RotatingTimeValue(x.rotation, x.time - y)
-(x, y::RotatingTimeValue) = RotatingTimeValue(y.rotation, x - y.time)
*(x::RotatingTimeValue, y) = RotatingTimeValue(x.rotation, x.time * y)
*(x, y::RotatingTimeValue) = RotatingTimeValue(y.rotation, x * y.time)

function -(x::RotatingTimeValue, y::RotatingTimeValue)
    rx = x.rotation
    ry = y.rotation
    rx == ry || throw(ArgumentError("x has rotation $rx while y has rotation $ry"))
    return x.time - y.time
end

# Compare time first
isless(x::RotatingTimeValue, y::RotatingTimeValue) =
    isequal(x.time, y.time) ? isless(x.rotation, y.rotation) : isless(x.time, y.time)

isless(x::RotatingTimeValue, y) = isless(x.time, y)
isless(x, y::RotatingTimeValue) = isless(x, y.time)
isless(::RotatingTimeValue, ::Missing) = true
isless(::Missing, ::RotatingTimeValue) = false

==(x::RotatingTimeValue, y::RotatingTimeValue) =
    x.rotation == y.rotation && x.time == y.time

==(x::RotatingTimeValue, y) = x.time == y
==(x, y::RotatingTimeValue) = x == y.time
==(::RotatingTimeValue, ::Missing) = missing
==(::Missing, ::RotatingTimeValue) = missing

Base.zero(::Type{RotatingTimeValue{R,T}}) where {R,T} = RotatingTimeValue(zero(R), zero(T))
Base.iszero(x::RotatingTimeValue) = iszero(x.time)

Base.convert(::Type{RotatingTimeValue{R,T}}, x::RotatingTimeValue) where {R,T} =
    RotatingTimeValue(convert(R, x.rotation), convert(T, x.time))

Base.checkindex(::Type{Bool}, inds::AbstractUnitRange, i::RotatingTimeValue) =
    checkindex(Bool, inds, i.time)

@propagate_inbounds getindex(X::AbstractArray, i::RotatingTimeValue) = getindex(X, i.time)

Base.iterate(x::RotatingTimeValue) = (x, nothing)
Base.iterate(x::RotatingTimeValue, ::Any) = nothing

Base.length(x::RotatingTimeValue) = 1

show(io::IO, x::RotatingTimeValue) = print(io, x.rotation, "_", x.time)
function show(io::IO, ::MIME"text/plain", x::RotatingTimeValue)
    println(io, typeof(x), ':')
    println(io, "  rotation: ", x.rotation)
    print(io, "  time:     ", x.time)
end

"""
    RotatingTimeRange{T<:RotatingTimeValue,R<:AbstractRange} <: AbstractRange{T}

A range type that wraps a [`RotationTimeValue`](@ref) with a range of type `R`
for producing a range of [`RotationTimeValue`](@ref)s.
It can be created with the syntax `a:b:c` when `a` and `c` are [`RotationTimeValue`](@ref)s.
"""
struct RotatingTimeRange{T<:RotatingTimeValue,R<:AbstractRange} <: AbstractRange{T}
    value::T
    range::R
end

Base.:(:)(start::RotatingTimeValue, step, stop::RotatingTimeValue) =
    RotatingTimeRange(start, start.time:step:stop.time)

Base.first(r::RotatingTimeRange) = RotatingTimeValue(r.value.rotation, first(r.range))
Base.step(r::RotatingTimeRange) = step(r.range)
Base.last(r::RotatingTimeRange) = RotatingTimeValue(r.value.rotation, last(r.range))

Base.length(r::RotatingTimeRange) = length(r.range)

@propagate_inbounds Base.getindex(r::RotatingTimeRange{T}, i::Int) where T =
    RotatingTimeValue(T, r.value.rotation, r.range[i])

@propagate_inbounds Base.getindex(r::RotatingTimeRange{T}, i::RotatingTimeValue) where T =
    RotatingTimeValue(T, i.rotation, r.range[i.time])

const ValidTimeType = Union{Signed, TimeType, Period, RotatingTimeValue}
