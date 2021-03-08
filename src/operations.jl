# Obtain unique labels for row-wise pairs of values from a1 and a2 when mult1 is large enough
function _mult!(a1::Array, mult1::Integer, a2::AbstractArray)
    a1 .+= mult1 .* (a2 .- 1)
end

# A variant of SplitApplyCombine.groupfind using IdDict instead of Dictionaries.Dictionary
function _groupfind(container)
    T = keytype(container)
    inds = IdDict{eltype(container), Vector{T}}()
    @inbounds for i in keys(container)
        push!(get!(Vector{T}, inds, container[i]), i)
    end
    return inds
end

# Convert the keys from refs to cells
function _cellrows(cols::SubColumns, refrows::IdDict)
    ncol = size(cols, 2)
    cellrows = IdDict{Tuple, Vector{Int}}()
    for rows in values(refrows)
        cell = ntuple(n->cols[n][rows[1]], ncol)
        cellrows[cell] = rows
    end
    return cellrows
end

"""
    findcell(cellnames, data, esample=Colon())

Group the row indices of a subsample of `data` over `esample`
so that the row-wise combinations of values from columns indexed by `cellnames`
are the same within each group.

Note that unless `esample` covers all rows of `data`,
the row indices are those for the subsample selected based on `esample`
rather than those for the full `data`.

# Returns
- `IdDict{Tuple, Vector{Int}}`: a map from row-wise combinations of values to row indices of these combinations.
"""
function findcell(cellnames, data, esample=Colon())
    cols = SubColumns(data, cellnames, esample)
    ncol = size(cols, 2)
    ncol == 0 && throw(ArgumentError("no data column is found"))
    col = cols[1]
    refs = refarray(col)
    pool = refpool(col)
    pooled = pool !== nothing
    if !pooled
        refs, invpool, pool = _label(col)
    end
    mult = length(pool)
    if ncol > 1
        # Make a copy to be used as cache
        pooled && (refs = collect(refs))
        @inbounds for n in 2:ncol
            col = cols[n]
            refsn = refarray(col)
            pool = refpool(col)
            if pool === nothing
                refsn, invpool, pool = _label(col)
            end
            multn = length(pool)
            _mult!(refs, mult, refsn)
            mult = mult * multn
        end
    end
    cellrows = _cellrows(cols, _groupfind(refs))
    return cellrows
end
