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

"""
    findcell(cols::VecColumnTable)
    findcell(names, data, esample=Colon())

Group the row indices of a collection of data columns
so that the combination of row values from these columns
are the same within each group.

Instead of directly providing the relevant portions of columns as
[`VecColumnTable`](@ref)``,
one may specify the `names` of columns from
`data` of any Tables.jl-compatible table type
over selected rows indicated by `esample`.
Note that unless `esample` covers all rows of `data`,
the row indices are those for the subsample selected based on `esample`
rather than those for the full `data`.

# Returns
- `IdDict{Tuple, Vector{Int}}`: a map from unique row values to row indices.
"""
function findcell(cols::VecColumnTable)
    ncol = size(cols, 2)
    isempty(cols) && throw(ArgumentError("no data column is found"))
    col = cols[1]
    refs = refarray(col)
    pool = refpool(col)
    labeled = pool !== nothing && eltype(refs) <: Unsigned
    if !labeled
        refs, invpool, pool = _label(col)
    end
    mult = length(pool)
    if ncol > 1
        # Make a copy to be used as cache
        labeled && (refs = collect(refs))
        @inbounds for n in 2:ncol
            col = cols[n]
            refsn = refarray(col)
            pool = refpool(col)
            if pool === nothing || !(eltype(refsn) <: Unsigned)
                refsn, invpool, pool = _label(col)
            end
            multn = length(pool)
            _mult!(refs, mult, refsn)
            mult = mult * multn
        end
    end
    return _groupfind(refs)
end

findcell(names, data, esample=Colon()) =
    findcell(subcolumns(data, names, esample))

"""
    cellrows(cols::VecColumnTable, refrows::IdDict)

A utility function for processing the object `refrows` returned by [`findcell`](@ref).
Unique row values from `cols` corresponding to
the keys in `refrows` are sorted lexicographically
and stored as rows in a new `VecColumnTable`.
Groups of row indices from the values of `refrows` are permuted to
match the order of row values and collected in a `Vector`.

# Returns
- `cells::VecColumnTable`: unique row values from columns in `cols`.
- `rows::Vector{Vector{Int}}`: row indices for each combination.
"""
function cellrows(cols::VecColumnTable, refrows::IdDict)
    isempty(refrows) && throw(ArgumentError("refrows is empty"))
    isempty(cols) && throw(ArgumentError("no data column is found"))
    ncol = length(cols)
    ncell = length(refrows)
    rows = Vector{Vector{Int}}(undef, ncell)
    columns = AbstractVector[Vector{eltype(c)}(undef, ncell) for c in cols]
    refs = Vector{keytype(refrows)}(undef, ncell)
    r = 0
    @inbounds for (k, v) in refrows
        r += 1
        row1 = v[1]
        refs[r] = k
        for c in 1:ncol
            columns[c][r] = cols[c][row1]
        end
    end
    cells = VecColumnTable(columns, _names(cols), _lookup(cols))
    p = sortperm(cells)
    # Replace each column of cells with a new one in the sorted order
    @inbounds for i in 1:ncol
        columns[i] = cells[i][p]
    end
    # Collect rows in the same order as cells
    @inbounds for i in 1:ncell
        rows[i] = refrows[refs[p[i]]]
    end
    return cells, rows
end
