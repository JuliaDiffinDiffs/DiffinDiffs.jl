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

# Compare time first
isless(x::RotatingTimeValue, y::RotatingTimeValue) =
    isequal(x.time, y.time) ? isless(x.rotation, y.rotation) : isless(x.time, y.time)

isless(x::RotatingTimeValue, y) = isless(x.time, y)
isless(x, y::RotatingTimeValue) = isless(x, y.time)
isless(::RotatingTimeValue, ::Missing) = true
isless(::Missing, ::RotatingTimeValue) = false

Base.isequal(x::RotatingTimeValue, y::RotatingTimeValue) =
    isequal(x.rotation, y.rotation) && isequal(x.time, y.time)

function ==(x::RotatingTimeValue, y::RotatingTimeValue)
    req = x.rotation == y.rotation
    isequal(req, missing) && return missing
    teq = x.time == y.time
    isequal(teq, missing) && return missing
    return req && teq
end

==(x::RotatingTimeValue, y) = x.time == y
==(x, y::RotatingTimeValue) = x == y.time
==(::RotatingTimeValue, ::Missing) = missing
==(::Missing, ::RotatingTimeValue) = missing

Base.zero(::Type{RotatingTimeValue{R,T}}) where {R,T} = RotatingTimeValue(zero(R), zero(T))
Base.iszero(x::RotatingTimeValue) = iszero(x.time)
Base.one(::Type{RotatingTimeValue{R,T}}) where {R,T} = RotatingTimeValue(one(R), one(T))
Base.isone(x::RotatingTimeValue) = isone(x.time)

Base.convert(::Type{RotatingTimeValue{R,T}}, x::RotatingTimeValue) where {R,T} =
    RotatingTimeValue(convert(R, x.rotation), convert(T, x.time))

Base.nonmissingtype(::Type{RotatingTimeValue{R,T}}) where {R,T} =
    RotatingTimeValue{nonmissingtype(R), nonmissingtype(T)}

Base.iterate(x::RotatingTimeValue) = (x, nothing)
Base.iterate(x::RotatingTimeValue, ::Any) = nothing

Base.length(x::RotatingTimeValue) = 1

show(io::IO, x::RotatingTimeValue) = print(io, x.rotation, '_', x.time)
function show(io::IO, ::MIME"text/plain", x::RotatingTimeValue)
    println(io, typeof(x), ':')
    println(io, "  rotation: ", x.rotation)
    print(io, "  time:     ", x.time)
end

"""
    RotatingTimeArray{T<:RotatingTimeValue,N,C,I} <: AbstractArray{T,N}

Array type for [`RotatingTimeValue`](@ref)s that stores
the field values `rotation` and `time` in two arrays for efficiency.
The two arrays that hold the field values for all elements can be accessed as properties.
"""
struct RotatingTimeArray{T<:RotatingTimeValue,N,C,I} <: AbstractArray{T,N}
    a::StructArray{T,N,C,I}
    RotatingTimeArray(a::StructArray{T,N,C,I}) where {T,N,C,I} = new{T,N,C,I}(a)
end

"""
    RotatingTimeArray(rotation::AbstractArray, time::AbstractArray)

Construct a [`RotatingTimeValue`](@ref) from arrays of `rotation` and `time`.
"""
function RotatingTimeArray(rotation::AbstractArray, time::AbstractArray)
    a = StructArray{RotatingTimeValue{eltype(rotation), eltype(time)}}((rotation, time))
    return RotatingTimeArray(a)
end

_getarray(a::RotatingTimeArray) = getfield(a, :a)

Base.size(a::RotatingTimeArray) = size(_getarray(a))
Base.IndexStyle(::Type{<:RotatingTimeArray{<:Any,<:Any,<:Any,I}}) where I =
    I === Int ? IndexLinear() : IndexCartesian()

Base.@propagate_inbounds Base.getindex(a::RotatingTimeArray, i::Int) = _getarray(a)[i]
Base.@propagate_inbounds Base.getindex(a::RotatingTimeArray, I) =
    RotatingTimeArray(_getarray(a).rotation[I], _getarray(a).time[I])

Base.@propagate_inbounds Base.setindex!(a::RotatingTimeArray, v, i::Int) =
    setindex!(_getarray(a), v, i)
Base.@propagate_inbounds Base.setindex!(a::RotatingTimeArray, v, I) =
    setindex!(_getarray(a), v, I)

@inline Base.view(a::RotatingTimeArray, I...) = RotatingTimeArray(view(_getarray(a), I...))

Base.similar(a::RotatingTimeArray, dims::Dims=size(a)) =
    RotatingTimeArray(similar(_getarray(a), dims))

Base.similar(a::RotatingTimeArray, dims::Int...) = similar(a, dims)

Base.getproperty(a::RotatingTimeArray, n::Symbol) = getproperty(_getarray(a), n)

DataAPI.refarray(a::RotatingTimeArray) =
    RotatingTimeArray(DataAPI.refarray(a.rotation), DataAPI.refarray(a.time))

const ValidTimeType = Union{Signed, TimeType, Period, RotatingTimeValue}
