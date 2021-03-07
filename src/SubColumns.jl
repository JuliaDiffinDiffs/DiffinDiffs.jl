struct SubColumns
    columns::Vector{AbstractVector}
    names::Vector{Symbol}
    lookup::Dict{Symbol,Int}
    # The inner constructor resolves method ambiguity
    SubColumns(columns::Vector{AbstractVector}, names::Vector{Symbol}, 
        lookup::Dict{Symbol,Int}) = new(columns, names, lookup)
end

"""
    SubColumns(data, names, rows=Colon(); nomissing=true)

Construct a column table from `data` using columns specified with `names` over selected `rows`.

By default, columns are converted to drop support for missing values.
When possible, resulting columns share memory with original columns.
"""
function SubColumns(data, names, rows=Colon(); nomissing=true)
    Tables.istable(data) || throw(ArgumentError("data must support Tables.jl interface"))
    names = names isa Vector{Symbol} ? names : Symbol[names...]
    ncol = length(names)
    columns = Vector{AbstractVector}(undef, ncol)
    lookup = Dict{Symbol,Int}()
    if ncol > 0
        @inbounds for i in 1:ncol
            col = view(getcolumn(data, names[i]), rows)
            nomissing && (col = disallowmissing(col))
            columns[i] = col
            lookup[names[i]] = i
        end
    end
    return SubColumns(columns, names, lookup)
end

SubColumns(data, names::Symbol, rows=Colon(); nomissing=true) =
    SubColumns(data, [names], rows, nomissing=nomissing)

_columns(cols::SubColumns) = getfield(cols, :columns)
_names(cols::SubColumns) = getfield(cols, :names)
_lookup(cols::SubColumns) = getfield(cols, :lookup)

ncol(cols::SubColumns) = length(_names(cols))
nrow(cols::SubColumns) = ncol(cols) > 0 ? length(_columns(cols)[1])::Int : 0

Base.size(cols::SubColumns) = (nrow(cols), ncol(cols))
function Base.size(cols::SubColumns, i::Integer)
    if i == 1
        nrow(cols)
    elseif i == 2
        ncol(cols)
    else
        throw(ArgumentError("SubColumns only have two dimensions"))
    end
end

Base.isempty(cols::SubColumns) = size(cols, 1) == 0 || size(cols, 2) == 0

@inline function Base.getindex(cols::SubColumns, i)
    @boundscheck if !checkindex(Bool, axes(_columns(cols), 1), i)
        throw(BoundsError(cols, i))
    end
    @inbounds return _columns(cols)[i]
end

@inline Base.getindex(cols::SubColumns, n::Symbol) = cols[_lookup(cols)[n]]
@inline Base.getproperty(cols::SubColumns, n::Symbol) = cols[n]
Base.propertynames(cols::SubColumns) = copy(_names(cols))

function Base.:(==)(x::SubColumns, y::SubColumns)
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

Base.show(io::IO, cols::SubColumns) = print(io, nrow(cols), '×', ncol(cols), " SubColumns")

function Base.show(io::IO, ::MIME"text/plain", cols::SubColumns)
    show(io, cols)
    ncol(cols) > 0 && print(io, ":\n  ", join(propertynames(cols), ' '))
end

Base.summary(cols::SubColumns) = string(nrow(cols), '×', ncol(cols), ' ', nameof(typeof(cols)))
Base.summary(io::IO, cols::SubColumns) = print(io, summary(cols))

Tables.istable(::Type{SubColumns}) = true
Tables.columnaccess(::Type{SubColumns}) = true
Tables.columns(cols::SubColumns) = cols

Tables.getcolumn(cols::SubColumns, i::Int) = cols[i]
Tables.getcolumn(cols::SubColumns, n::Symbol) = cols[n]
