const DEFAULT_REF_TYPE = Int32

# A wrapper only used for resolving method ambiguity when constructing ScaledArray
mutable struct RefArray{R}
    a::R
end

"""
    ScaledArray{T,N,RA,S,P} <: AbstractArray{T,N}

An array type that stores data as indices of a range.

# Fields
- `refs::RA<:AbstractArray{<:Any, N}`: an array of indices.
- `start::T`: the starting value of the range.
- `step::S`: the step size of the range.
- `stop::T`: the stopping value of the range.
- `pool::P<:AbstractRange{T}`: a range that covers all possible values stored by the array.
"""
mutable struct ScaledArray{T,N,RA,S,P} <: AbstractArray{T,N}
    refs::RA
    start::T
    step::S
    stop::T
    pool::P
    ScaledArray{T,N,RA,S,P}(rs::RefArray{RA}, start::T, step::S, stop::T,
        pool::P=start:step:stop) where
        {T, N, RA<:AbstractArray{<:Any, N}, S, P<:AbstractRange{T}} =
            new{T,N,RA,S,P}(rs.a, start, step, stop, pool)
end

ScaledArray(rs::RefArray{RA}, start::T, step::S, stop::T, pool::P=start:step:stop) where
    {T,RA,S,P} = ScaledArray{T,ndims(RA),RA,S,P}(rs, start, step, stop, pool)

const ScaledVector{T} = ScaledArray{T,1}
const ScaledMatrix{T} = ScaledArray{T,2}

function _validmin(min, xmin, isstart::Bool)
    if min === nothing
        min = xmin
    elseif min > xmin
        str = isstart ? "start =" : "stop ="
        throw(ArgumentError("$str $min is greater than the allowed minimum element $xmin"))
    end
    return min
end

function _validmax(max, xmax, isstart::Bool)
    if max === nothing
        max = xmax
    elseif max < xmax
        str = isstart ? "start =" : "stop ="
        throw(ArgumentError("$str $max is smaller than the allowed maximum element $xmax"))
    end
    return max
end

function validstartstepstop(x::AbstractArray, start, step, stop, usepool)
    step === nothing && throw(ArgumentError("step cannot be nothing"))
    pool = DataAPI.refpool(x)
    xmin, xmax = usepool && pool !== nothing ? extrema(pool) : extrema(x)
    applicable(+, xmin, step) || throw(ArgumentError(
        "step of type $(typeof(step)) does not match array with element type $(eltype(x))"))
    if xmin + step > xmin
        start = _validmin(start, xmin, true)
        stop = _validmax(stop, xmax, false)
    elseif xmin + step < xmin
        start = _validmax(start, xmax, true)
        stop = _validmin(stop, xmin, false)
    else
        throw(ArgumentError("step cannot be zero"))
    end
    T = promote_type(eltype(x), eltype(start:step:stop))
    return convert(T, start), convert(T, stop)
end

function _scaledlabel(x::AbstractArray, step, reftype::Type{<:Signed}=DEFAULT_REF_TYPE;
        start=nothing, stop=nothing, usepool::Bool=true)
    start, stop = validstartstepstop(x, start, step, stop, usepool)
    pool = start:step:stop
    while typemax(reftype) < length(pool)
        reftype = widen(reftype)
    end
    refs = similar(x, reftype)
    @inbounds for i in eachindex(refs)
        refs[i] = length(start:step:x[i])
    end
    return refs, start, step, stop
end

function ScaledArray(x::AbstractArray, reftype::Type, start, step, stop, usepool::Bool=true)
    refs, start, step, stop = _scaledlabel(x, step, reftype; start=start, stop=stop, usepool=usepool)
    return ScaledArray(RefArray(refs), start, step, stop)
end

function ScaledArray(sa::ScaledArray, reftype::Type, start, step, stop, usepool::Bool=true)
    if step !== nothing && step != sa.step
        refs, start, step, stop = _scaledlabel(sa, step, reftype; start=start, stop=stop, usepool=usepool)
        return ScaledArray(RefArray(refs), start, step, stop)
    else
        step = sa.step
        start, stop = validstartstepstop(sa, start, step, stop, usepool)
        refs = similar(sa.refs, reftype)
        if start == sa.start
            copy!(refs, sa.refs)
        elseif start < sa.start && start < stop || start > sa.start && start > stop
            offset = length(start:step:sa.start) - 1
            refs .= sa.refs .+ offset
        else
            offset = length(sa.start:step:start) - 1
            refs .= sa.refs .- offset
        end
        return ScaledArray(RefArray(refs), start, step, stop)
    end
end

"""
    ScaledArray(x::AbstractArray, start, step[, stop]; reftype=Int32, usepool=true)
    ScaledArray(x::AbstractArray, step; reftype=Int32, start, stop, usepool=true)

Construct a `ScaledArray` from `x` given the `step` size.
If `start` or `stop` is not specified, it will be chosen based on the extrema of `x`.

# Keywords
- `reftype::Type=Int32`: the element type of field `refs`.
- `usepool::Bool=true`: find extrema of `x` based on `DataAPI.refpool`.
"""
ScaledArray(x::AbstractArray, start, step, stop=nothing;
    reftype::Type=DEFAULT_REF_TYPE, usepool::Bool=true) =
        ScaledArray(x, reftype, start, step, stop, usepool)

ScaledArray(sa::ScaledArray, start, step, stop=nothing;
    reftype::Type=eltype(refarray(sa)), usepool::Bool=true) =
        ScaledArray(sa, reftype, start, step, stop, usepool)

ScaledArray(x::AbstractArray, step; reftype::Type=DEFAULT_REF_TYPE,
    start=nothing, stop=nothing, usepool::Bool=true) =
        ScaledArray(x, reftype, start, step, stop, usepool)

ScaledArray(sa::ScaledArray, step=nothing; reftype::Type=eltype(refarray(sa)),
    start=nothing, stop=nothing, usepool::Bool=true) =
        ScaledArray(sa, reftype, start, step, stop, usepool)

Base.size(sa::ScaledArray) = size(sa.refs)
Base.IndexStyle(::Type{<:ScaledArray{T,N,RA}}) where {T,N,RA} = IndexStyle(RA)

DataAPI.refarray(sa::ScaledArray) = sa.refs
DataAPI.refvalue(sa::ScaledArray, n::Integer) = getindex(DataAPI.refpool(sa), n)
DataAPI.refpool(sa::ScaledArray) = sa.pool

DataAPI.refarray(ssa::SubArray{<:Any, <:Any, <:ScaledArray}) =
    view(parent(ssa).refs, ssa.indices...)
DataAPI.refvalue(ssa::SubArray{<:Any, <:Any, <:ScaledArray}, n::Integer) =
    DataAPI.refvalue(parent(ssa), n)
DataAPI.refpool(ssa::SubArray{<:Any, <:Any, <:ScaledArray}) =
    DataAPI.refpool(parent(ssa))

@inline function Base.getindex(sa::ScaledArray, i::Int)
    refs = DataAPI.refarray(sa)
    @boundscheck checkbounds(refs, i)
    @inbounds n = refs[i]
    pool = DataAPI.refpool(sa)
    @boundscheck checkbounds(pool, n)
    return @inbounds pool[n]
end

@inline function Base.getindex(sa::ScaledArray, I...)
    refs = DataAPI.refarray(sa)
    @boundscheck checkbounds(refs, I...)
    @inbounds ns = refs[I...]
    pool = DataAPI.refpool(sa)
    @boundscheck checkbounds(pool, ns)
    return @inbounds pool[ns]
end

function Base.:(==)(x::ScaledArray, y::ScaledArray)
    size(x) == size(y) || return false
    x.start == y.start && x.step == y.step && return x.refs == y.refs
    eq = true
    for (p, q) in zip(x, y)
        # missing could arise
        veq = p == q
        isequal(veq, false) && return false
        eq &= veq
    end
    return eq
end
