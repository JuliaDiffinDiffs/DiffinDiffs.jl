const DEFAULT_REF_TYPE = Int32

# A wrapper only used for resolving method ambiguity when constructing ScaledArray
mutable struct RefArray{R}
    a::R
end

"""
    ScaledArray{T,R,N,RA,P} <: AbstractArray{T,N}

An array type that stores data as indices of a range.

# Fields
- `refs::RA<:AbstractArray{<:Any, N}`: an array of indices.
- `pool::P<:AbstractRange{T}`: a range that covers all possible values stored by the array.
- `invpool::Dict{T,R}`: a map from array elements to indices of `pool`.
"""
mutable struct ScaledArray{T,R,N,RA,P} <: AbstractArray{T,N}
    refs::RA
    pool::P
    invpool::Dict{T,R}
    ScaledArray{T,R,N,RA,P}(rs::RefArray{RA}, pool::P, invpool::Dict{T,R}) where
        {T, R, N, RA<:AbstractArray{R, N}, P<:AbstractRange{T}} =
            new{T,R,N,RA,P}(rs.a, pool, invpool)
end

ScaledArray(rs::RefArray{RA}, pool::P, invpool::Dict{T,R}) where
    {T,R,RA<:AbstractArray{R},P} = ScaledArray{T,R,ndims(RA),RA,P}(rs, pool, invpool)

const ScaledVector{T,R} = ScaledArray{T,R,1}
const ScaledMatrix{T,R} = ScaledArray{T,R,2}

scale(sa::ScaledArray) = step(sa.pool)

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

function validpool(x::AbstractArray, T::Type, start, step, stop, usepool::Bool)
    step === nothing && throw(ArgumentError("step cannot be nothing"))
    pool = DataAPI.refpool(x)
    xs = skipmissing(usepool && pool !== nothing ? pool : x)
    xmin, xmax = extrema(xs)
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
    start = convert(T, start)
    stop = convert(T, stop)
    return start:step:stop
end

function _scaledlabel!(labels::AbstractArray, invpool::Dict, xs::AbstractArray, start, step)
    z = zero(valtype(invpool))
    @inbounds for i in eachindex(labels)
        x = xs[i]
        lbl = get(invpool, x, z)
        if lbl !== z
            labels[i] = lbl
        elseif ismissing(x)
            labels[i] = z
            invpool[x] = z
        else
            r = start:step:x
            lbl = length(r)
            labels[i] = lbl
            invpool[x] = lbl
        end
    end
end

function scaledlabel(xs::AbstractArray, stepsize,
        R::Type=DEFAULT_REF_TYPE, T::Type=eltype(xs);
        start=nothing, stop=nothing, usepool::Bool=true)
    pool = validpool(xs, T, start, stepsize, stop, usepool)
    T = Missing <: T ? Union{eltype(pool), Missing} : eltype(pool)
    start = first(pool)
    stepsize = step(pool)
    if R <: Integer
        while typemax(R) < length(pool)
            R = widen(R)
        end
    end
    labels = similar(xs, R)
    invpool = Dict{T,R}()
    _scaledlabel!(labels, invpool, xs, start, stepsize)
    return labels, pool, invpool
end

function ScaledArray(x::AbstractArray, reftype::Type, xtype::Type, start, step, stop, usepool::Bool=true)
    refs, pool, invpool = scaledlabel(x, step, reftype, xtype; start=start, stop=stop, usepool=usepool)
    return ScaledArray(RefArray(refs), pool, invpool)
end

function ScaledArray(sa::ScaledArray, reftype::Type, xtype::Type, start, step, stop, usepool::Bool=true)
    if step !== nothing && step != scale(sa)
        refs, pool, invpool = scaledlabel(sa, step, reftype, xtype; start=start, stop=stop, usepool=usepool)
        return ScaledArray(RefArray(refs), pool, invpool)
    else
        step = scale(sa)
        pool = validpool(sa, xtype, start, step, stop, usepool)
        T = Missing <: xtype ? Union{eltype(pool), Missing} : eltype(pool)
        refs = similar(sa.refs, reftype)
        invpool = Dict{T, reftype}()
        start0 = first(sa.pool)
        start = first(pool)
        stop = last(pool)
        if start == start0
            copy!(refs, sa.refs)
            copy!(invpool, sa.invpool)
        elseif start < start0 && start < stop || start > start0 && start > stop
            offset = length(start:step:start0) - 1
            refs .= sa.refs .+ offset
            for (k, v) in sa.invpool
                invpool[k] = v + offset
            end
        else
            offset = length(start0:step:start) - 1
            refs .= sa.refs .- offset
            for (k, v) in sa.invpool
                invpool[k] = v - offset
            end
        end
        return ScaledArray(RefArray(refs), pool, invpool)
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
    reftype::Type=DEFAULT_REF_TYPE, xtype::Type=eltype(x), usepool::Bool=true) =
        ScaledArray(x, reftype, xtype, start, step, stop, usepool)

ScaledArray(sa::ScaledArray, start, step, stop=nothing;
    reftype::Type=eltype(refarray(sa)), xtype::Type=eltype(sa), usepool::Bool=true) =
        ScaledArray(sa, reftype, xtype, start, step, stop, usepool)

ScaledArray(x::AbstractArray, step; reftype::Type=DEFAULT_REF_TYPE,
    start=nothing, stop=nothing, xtype::Type=eltype(x), usepool::Bool=true) =
        ScaledArray(x, reftype, xtype, start, step, stop, usepool)

ScaledArray(sa::ScaledArray, step=nothing; reftype::Type=eltype(refarray(sa)),
    start=nothing, stop=nothing, xtype::Type=eltype(sa), usepool::Bool=true) =
        ScaledArray(sa, reftype, xtype, start, step, stop, usepool)

Base.size(sa::ScaledArray) = size(sa.refs)
Base.IndexStyle(::Type{<:ScaledArray{T,R,N,RA}}) where {T,R,N,RA} = IndexStyle(RA)

DataAPI.refarray(sa::ScaledArray) = sa.refs
DataAPI.refvalue(sa::ScaledArray, n::Integer) = getindex(DataAPI.refpool(sa), n)
DataAPI.refpool(sa::ScaledArray) = sa.pool
DataAPI.invrefpool(sa::ScaledArray) = sa.invpool

DataAPI.refarray(ssa::SubArray{<:Any, <:Any, <:ScaledArray}) =
    view(parent(ssa).refs, ssa.indices...)
DataAPI.refvalue(ssa::SubArray{<:Any, <:Any, <:ScaledArray}, n::Integer) =
    DataAPI.refvalue(parent(ssa), n)
DataAPI.refpool(ssa::SubArray{<:Any, <:Any, <:ScaledArray}) =
    DataAPI.refpool(parent(ssa))
DataAPI.invrefpool(ssa::SubArray{<:Any, <:Any, <:ScaledArray}) =
    DataAPI.invrefpool(parent(ssa))

@inline function Base.getindex(sa::ScaledArray, i::Int)
    refs = DataAPI.refarray(sa)
    @boundscheck checkbounds(refs, i)
    @inbounds n = refs[i]
    iszero(n) && return missing
    pool = DataAPI.refpool(sa)
    @boundscheck checkbounds(pool, n)
    return @inbounds pool[n]
end

@inline function Base.getindex(sa::ScaledArray, I...)
    refs = DataAPI.refarray(sa)
    @boundscheck checkbounds(refs, I...)
    @inbounds ns = refs[I...]
    pool = DataAPI.refpool(sa)
    N = length(pool)
    @boundscheck checkindex(Bool, 0:N, ns) || throw_boundserror(pool, ns)
    return @inbounds pool[ns]
end

function Base.:(==)(x::ScaledArray, y::ScaledArray)
    size(x) == size(y) || return false
    first(x.pool) == first(y.pool) && step(x.pool) == step(y.pool) && return x.refs == y.refs
    eq = true
    for (p, q) in zip(x, y)
        # missing could arise
        veq = p == q
        isequal(veq, false) && return false
        eq &= veq
    end
    return eq
end
