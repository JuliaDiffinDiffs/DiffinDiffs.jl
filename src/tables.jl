"""
    VecColumnTable <: AbstractColumns

A Tables.jl-compatible column table that stores data as `Vector{AbstractVector}`
and column names as `Vector{Symbol}`.
Retrieving columns by column names is achieved with a `Dict{Symbol,Int}`
that maps names to indices.

This table type is designed for retrieving and iterating
dynamically generated columns for which
specialization on names and order of columns are not desired.
It is not intended to be directly constructed for interactive usage.
"""
struct VecColumnTable <: AbstractColumns
    columns::Vector{AbstractVector}
    names::Vector{Symbol}
    lookup::Dict{Symbol,Int}
    function VecColumnTable(columns::Vector{AbstractVector}, names::Vector{Symbol}, 
            lookup::Dict{Symbol,Int})
        # Assume Symbols in names and lookup match
        length(columns) == length(names) == length(lookup) ||
            throw(ArgumentError("arguments do not share the same length"))
        return new(columns, names, lookup)
    end
end

function VecColumnTable(columns::Vector{AbstractVector}, names::Vector{Symbol})
    lookup = Dict{Symbol,Int}(names.=>keys(names))
    return VecColumnTable(columns, names, lookup)
end

function VecColumnTable(data, esample::Union{BitVector, Nothing}=nothing)
    Tables.istable(data) || throw(ArgumentError("input data is not Tables.jl-compatible"))
    names = collect(Tables.columnnames(data))
    ncol = length(names)
    columns = Vector{AbstractVector}(undef, ncol)
    cols = Tables.columns(data)
    if esample === nothing
        @inbounds for i in keys(names)
            columns[i] = Tables.getcolumn(cols, i)
        end
    else
        @inbounds for i in keys(names)
            columns[i] = view(Tables.getcolumn(cols, i), esample)
        end
    end
    return VecColumnTable(columns, names)
end

function VecColumnTable(cols::VecColumnTable, esample::Union{BitVector, Nothing}=nothing)
    esample === nothing && return cols
    columns = similar(_columns(cols))
    @inbounds for i in keys(columns)
        columns[i] = view(cols[i], esample)
    end
    return VecColumnTable(columns, _names(cols), _lookup(cols))
end

_columns(cols::VecColumnTable) = getfield(cols, :columns)
_names(cols::VecColumnTable) = getfield(cols, :names)
_lookup(cols::VecColumnTable) = getfield(cols, :lookup)

ncol(cols::VecColumnTable) = length(_names(cols))
nrow(cols::VecColumnTable) = ncol(cols) > 0 ? length(_columns(cols)[1])::Int : 0

Base.size(cols::VecColumnTable) = (nrow(cols), ncol(cols))
function Base.size(cols::VecColumnTable, i::Integer)
    if i == 1
        nrow(cols)
    elseif i == 2
        ncol(cols)
    else
        throw(ArgumentError("VecColumnTable only have two dimensions"))
    end
end

Base.length(cols::VecColumnTable) = ncol(cols)
Base.isempty(cols::VecColumnTable) = size(cols, 1) == 0 || size(cols, 2) == 0

@inline function Base.getindex(cols::VecColumnTable, i::Int)
    @boundscheck if !checkindex(Bool, axes(_columns(cols), 1), i)
        throw(BoundsError(cols, i))
    end
    @inbounds return _columns(cols)[i]
end

@inline Base.getindex(cols::VecColumnTable, n::Symbol) = cols[_lookup(cols)[n]]
@inline Base.getindex(cols::VecColumnTable, ns::AbstractArray{Symbol}) = map(n->cols[n], ns)
@inline Base.getindex(cols::VecColumnTable, ::Colon) = _columns(cols)[:]
@inline function Base.getindex(cols::VecColumnTable, I)
    @boundscheck if !checkindex(Bool, axes(_columns(cols), 1), I)
        throw(BoundsError(cols, I))
    end
    @inbounds return _columns(cols)[I]
end

Base.values(cols::VecColumnTable) = _columns(cols)
Base.haskey(cols::VecColumnTable, key::Symbol) = haskey(_lookup(cols), key)
Base.haskey(cols::VecColumnTable, i::Int) = 0 < i < length(_names(cols))

function Base.:(==)(x::VecColumnTable, y::VecColumnTable)
    size(x) == size(y) || return false
    _names(x) == _names(y) || return false
    eq = true
    for i in 1:size(x, 2)
        # missing could arise
        coleq = x[i] == y[i]
        isequal(coleq, false) && return false
        eq &= coleq
    end
    return eq
end

Base.show(io::IO, cols::VecColumnTable) = print(io, nrow(cols), '×', ncol(cols), " VecColumnTable")

function Base.show(io::IO, ::MIME"text/plain", cols::VecColumnTable)
    show(io, cols)
    if ncol(cols) > 0
        print(io, ":\n")
        names = _names(cols)
        types = map(c->eltype(c), _columns(cols))
        Base.print_matrix(io, hcat(names, types))
    end
end

Base.summary(cols::VecColumnTable) =
    string(nrow(cols), '×', ncol(cols), ' ', nameof(typeof(cols)))
Base.summary(io::IO, cols::VecColumnTable) = print(io, summary(cols))

Tables.getcolumn(cols::VecColumnTable, i::Int) = cols[i]
Tables.getcolumn(cols::VecColumnTable, n::Symbol) = cols[n]
Tables.columnnames(cols::VecColumnTable) = _names(cols)

Tables.schema(cols::VecColumnTable) =
    Tables.Schema{(_names(cols)...,), Tuple{(eltype(col) for col in _columns(cols))...}}()
Tables.materializer(::VecColumnTable) = VecColumnTable

Tables.columnindex(cols::VecColumnTable, n::Symbol) = _lookup(cols)[n]
Tables.columntype(cols::VecColumnTable, n::Symbol) = eltype(cols[n])
Tables.rowcount(cols::VecColumnTable) = nrow(cols)

"""
    subcolumns(data, names, rows=Colon(); nomissing=true)

Construct a [`VecColumnTable`](@ref) from `data`
using columns specified with `names` over selected `rows`.

By default, columns are converted to drop support for missing values.
When possible, resulting columns share memory with original columns.
"""
function subcolumns(data, names, rows=Colon(); nomissing=true)
    Tables.istable(data) || throw(ArgumentError("input data is not Tables.jl-compatible"))
    names = names isa Vector{Symbol} ? names : Symbol[names...]
    ncol = length(names)
    columns = Vector{AbstractVector}(undef, ncol)
    lookup = Dict{Symbol,Int}()
    @inbounds for i in keys(names)
        col = view(Tables.getcolumn(data, names[i]), rows)
        nomissing && (col = disallowmissing(col))
        columns[i] = col
        lookup[names[i]] = i
    end
    return VecColumnTable(columns, names, lookup)
end

subcolumns(data, names::Symbol, rows=Colon(); nomissing=true) =
    subcolumns(data, [names], rows, nomissing=nomissing)

const VecColsRow = Tables.ColumnsRow{VecColumnTable}

ncol(r::VecColsRow) = length(r)

_rowhash(cols::Tuple{AbstractVector}, r::Int, h::UInt=zero(UInt))::UInt =
    hash(cols[1][r], h)

function _rowhash(cols::Tuple{Vararg{AbstractVector}}, r::Int, h::UInt=zero(UInt))::UInt
    h = hash(cols[1][r], h)
    _rowhash(Base.tail(cols), r, h)
end

# hash is implemented following DataFrames.DataFrameRow for getting unique row values
# Column names are not taken into account
Base.hash(r::VecColsRow, h::UInt=zero(UInt)) =
    _rowhash(ntuple(c->Tables.getcolumns(r)[c], ncol(r)), Tables.getrow(r), h)

# Column names are not taken into account
function Base.isequal(r1::VecColsRow, r2::VecColsRow)
    length(r1) == length(r2) || return false
    return all(((a, b),) -> isequal(a, b), zip(r1, r2))
end

# Column names are not taken into account
function Base.isless(r1::VecColsRow, r2::VecColsRow)
    length(r1) == length(r2) ||
        throw(ArgumentError("compared VecColsRow do not have the same length"))
    for (a, b) in zip(r1, r2)
        isequal(a, b) || return isless(a, b)
    end
    return false
end

Base.sortperm(cols::VecColumnTable; @nospecialize(kwargs...)) =
    sortperm(collect(Tables.rows(cols)); kwargs...)

# names and lookup are not copied
function Base.sort(cols::VecColumnTable; @nospecialize(kwargs...))
    p = sortperm(cols; kwargs...)
    columns = similar(_columns(cols))
    i = 0
    @inbounds for col in cols
        i += 1
        columns[i] = col[p]
    end
    return VecColumnTable(columns, _names(cols), _lookup(cols))
end

function Base.sort!(cols::VecColumnTable; @nospecialize(kwargs...))
    p = sortperm(cols; kwargs...)
    @inbounds for col in cols
        col .= col[p]
    end
end
