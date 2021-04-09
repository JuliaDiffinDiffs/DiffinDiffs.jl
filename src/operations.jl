# A variant of SplitApplyCombine.groupfind using IdDict instead of Dictionaries.Dictionary
function _groupfind(container)
    T = keytype(container)
    inds = IdDict{eltype(container), Vector{T}}()
    @inbounds for i in keys(container)
        push!(get!(Vector{T}, inds, container[i]), i)
    end
    return inds
end

function _refs_pool(col::AbstractArray, ref_type::Type{<:Integer}=UInt32)
    refs = refarray(col)
    pool = refpool(col)
    labeled = pool !== nothing
    if !labeled
        refs, invpool, pool = _label(col, eltype(col), ref_type)
    end
    return refs, pool, labeled
end

# Obtain unique labels for row-wise pairs of values from a1 and a2 when mult is large enough
function _mult!(a1::AbstractArray, a2::AbstractArray, mult)
    a1 .+= mult .* (a2 .- 1)
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
    refs, pool, labeled = _refs_pool(cols[1])
    mult = length(pool)
    if ncol > 1
        # Make a copy to be used as cache
        labeled && (refs = copy(refs))
        @inbounds for n in 2:ncol
            refsn, pool, labeled = _refs_pool(cols[n])
            multn = length(pool)
            _mult!(refs, refsn, mult)
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

"""
    PanelStructure{R<:Signed, T1, T2<:TimeType}

Panel data structure defined by unique combinations of unit ids and time periods.
It contains the information required for certain operations such as
[`lag`](@ref) and [`diff`](@ref).
See also [`setpanel`](@ref).

# Fields
- `refs::Vector{R}`: reference values that allow obtaining time gaps by taking differences.
- `invrefs::Dict{R, Int}`: inverse map from `refs` to indices.
- `idpool::Vector{T1}`: unique unit ids.
- `timepool::Vector{T2}`: sorted unique time periods.
- `laginds::Dict{Int, Vector{Int}}`: a map from lag distances to vectors of indices of lagged values.
"""
struct PanelStructure{R<:Signed, T1, T2<:TimeType}
    refs::Vector{R}
    invrefs::Dict{R, Int}
    idpool::Vector{T1}
    timepool::Vector{T2}
    laginds::Dict{Int, Vector{Int}}
    function PanelStructure(refs::Vector, idpool::Vector, timepool::Vector,
            laginds::Dict=Dict{Int, Vector{Int}}())
        invrefs = Dict{eltype(refs), Int}(ref=>i for (i, ref) in enumerate(refs))
        return new{eltype(refs), eltype(idpool), eltype(timepool)}(
            refs, invrefs, idpool, timepool, laginds)
    end
end

function _scaledrefs_pool(col::AbstractArray, step, ref_type::Type{<:Signed}=Int32)
    refs, pool, labeled = _refs_pool(col, ref_type)
    labeled && (refs = copy(refs))
    npool = length(pool)
    spool = sort(pool)
    if step === nothing
        gaps = view(spool, 2:npool) - view(spool, 1:npool-1)
        step = minimum(gaps)
    end
    pool1 = spool[1]
    refmap = Vector{eltype(refs)}(undef, npool)
    @inbounds for i in 1:npool
        refmap[i] = (pool[i] - pool1) ÷ step + 1
    end
    @inbounds for i in 1:length(refs)
        refs[i] = refmap[refs[i]]
    end
    return refs, spool
end

"""
    setpanel(data, idname, timename, timestep=nothing; ref_type=Int32)
    setpanel(id::AbstractArray, time::AbstractArray, timestep=nothing; ref_type=Int32)
    
Declare a [`PanelStructure`](@ref) which is required for certain operations
such as [`lag`](@ref) and [`diff`](@ref).
Either a `data` table with `idname` and `timename` for columns representing
unit ids and time periods
or two arrays `id` and `time` representing the two columns are required.
In the former case, `data` must be Tables.jl-compatible.

By default, the time interval `timestep` between two adjacent periods is inferred
based on the minimum gap between two values in the `time` column.
The element type of reference values for [`PanelStructure`](@ref)
can be specified with `ref_type`.

!!! note
    If the underlying data used to create the [`PanelStructure`](@ref) are modified.
    The changes will not be reflected in the existing instances of [`PanelStructure`](@ref).
    A new instance needs to be created with `setpanel`.
"""
function setpanel(id::AbstractArray, time::AbstractArray, timestep=nothing;
        ref_type::Type{<:Signed}=Int32)
    eltype(time) <: TimeType ||
        throw(ArgumentError("invalid element type $(eltype(time)) from time column"))
    length(id) == length(time) || throw(DimensionMismatch(
        "id has length $(length(id)) while time has length $(length(time))"))
    refs, idpool, labeled = _refs_pool(id)
    labeled && (refs = copy(refs))
    trefs, tpool = _scaledrefs_pool(time, timestep, ref_type)
    # Multiply 2 to create enough gaps between id groups for the largest possible l
    mult = 2 * length(tpool)
    _mult!(trefs, refs, mult)
    return PanelStructure(trefs, idpool, tpool)
end

function setpanel(data, idname::Union{Symbol,Integer}, timename::Union{Symbol,Integer},
        timestep=nothing; ref_type::Type{<:Signed}=Int32)
    istable(data) || throw(ArgumentError("input data is not Tables.jl-compatible"))
    return setpanel(getcolumn(data, idname), getcolumn(data, timename), timestep,
        ref_type=ref_type)
end

show(io::IO, panel::PanelStructure) = print(io, "Panel Structure")

function show(io::IO, ::MIME"text/plain", panel::PanelStructure)
    println(io, "Panel Structure:")
    println(IOContext(io, :limit=>true, :displaysize=>(1, 80)), "  idpool:   ", panel.idpool)
    println(IOContext(io, :limit=>true, :displaysize=>(1, 80)), "  timepool:   ", panel.timepool)
    print(IOContext(io, :limit=>true, :displaysize=>(1, 80)), "  laginds:  ", panel.laginds)
end

"""
    findlag!(panel::PanelStructure, l::Integer=1)

Construct a vector of indices of the `l`th lagged values
for all id-time combinations of `panel`
and save the result in `panel.laginds`.
If a lagged value does not exist, its index is filled with 0.
See also [`ilag!`](@ref).
"""
function findlag!(panel::PanelStructure, l::Integer=1)
    abs(l) < length(panel.timepool) ||
        throw(ArgumentError("|l| must be smaller than $(length(panel.timepool)); got $l"))
    refs = panel.refs
    invrefs = panel.invrefs
    T = eltype(refs)
    inds = Vector{Int}(undef, size(refs))
    l = convert(T, l)
    z = zero(T)
    @inbounds for i in keys(refs)
        ref = refs[i]
        inds[i] = get(invrefs, ref-l, z)
    end
    panel.laginds[l] = inds
    return inds
end

"""
    findlead!(panel::PanelStructure, l::Integer=1)

Construct a vector of indices of the `l`th lead values
for all id-time combinations of `panel`
and save the result in `panel.laginds`.
If a lead value does not exist, its index is filled with 0.
See also [`ilead!`](@ref).
"""
findlead!(panel::PanelStructure, l::Integer=1) = findlag!(panel, -l)

"""
    ilag!(panel::PanelStructure, l::Integer=1)

Return a vector of indices of the `l`th lagged values
for all id-time combinations of `panel`.
The indices are retrieved from [`panel`](@ref) if they have been collected before.
Otherwise, they are created by calling [`findlag!`](@ref).
See also [`ilead!`](@ref).
"""
function ilag!(panel::PanelStructure, l::Integer=1)
    il = get(panel.laginds, l, nothing)
    return il === nothing ? findlag!(panel, l) : il
end

"""
    ilead!(panel::PanelStructure, l::Integer=1)

Return a vector of indices of the `l`th lead values
for all id-time combinations of `panel`.
The indices are retrieved from [`panel`](@ref) if they have been collected before.
Otherwise, they are created by calling [`findlead!`](@ref).
See also [`ilag!`](@ref).
"""
ilead!(panel::PanelStructure, l::Integer=1) = ilag!(panel, -l)

"""
    lag(panel::PanelStructure, v::AbstractArray, l::Integer=1; default=missing)

Return a vector of `l`th lagged values of `v` with missing values filled with `default`.
The `panel` structure is respected.
See also [`ilag!`](@ref) and [`lead`](@ref).
"""
function lag(panel::PanelStructure, v::AbstractArray, l::Integer=1; default=missing)
    length(v) == length(panel.refs) || throw(DimensionMismatch(
        "v has length $(length(v)) while expecting $(length(panel.refs))"))
    inds = ilag!(panel, l)
    out = default === missing ? similar(v, Union{eltype(v), Missing}) : similar(v)
    @inbounds for i in 1:length(v)
        out[i] = inds[i] == 0 ? default : v[inds[i]]
    end
    return out
end

"""
    lead(panel::PanelStructure, v::AbstractArray, l::Integer=1; default=missing)

Return a vector of `l`th lead values of `v` with missing values filled with `default`.
The `panel` structure is respected.
See also [`ilead!`](@ref) and [`lag`](@ref).
"""
lead(panel::PanelStructure, v::AbstractArray, l::Integer=1; default=missing) =
    lag(panel, v, -l, default=default)

function _diff!(dest::AbstractArray, v::AbstractArray, inds::AbstractArray, default)
    @inbounds for i in 1:length(v)
        dest[i] = inds[i] == 0 ? default : v[i] - v[inds[i]]
    end
end

"""
    diff!(dest::AbstractArray, panel::PanelStructure, v::AbstractArray; kwargs...)

Take the differences of `v` within observations for each unit in `panel`
and store the result in `dest`.
By default, it calculates the first differences.
See also [`diff`](@ref).

# Keywords
- `order::Integer=1`: the order of differences to be taken.
- `l::Integer=1`: the time interval between each pair of observations.
- `default=missing`: default values for indices where the differences do not exist.
"""
function diff!(dest::AbstractArray, panel::PanelStructure, v::AbstractArray;
        order::Integer=1, l::Integer=1, default=missing)
    length(dest) == length(v) || throw(DimensionMismatch(
        "dest has length $(length(dest)) while v has length $(length(v))"))
    0 < order < length(panel.timepool) || throw(ArgumentError(
        "order must be between 0 and $(length(panel.timepool)); got $order"))
    inds = get(panel.laginds, l, nothing)
    inds === nothing && (inds = findlag!(panel, l))
    _diff!(dest, v, inds, default)
    if order > 1
        cache = similar(dest)
        for i in 2:order
            copy!(cache, dest)
            _diff!(dest, cache, inds, default)
        end
    end
    return dest
end

"""
    diff(panel::PanelStructure, v::AbstractArray; kwargs...)

Return the differences of `v` within observations for each unit in `panel`.
By default, it calculates the first differences.
See also [`diff!`](@ref).

# Keywords
- `order::Integer=1`: the order of differences to be taken.
- `l::Integer=1`: the time interval between each pair of observations.
- `default=missing`: default values for indices where the differences do not exist.
"""
function diff(panel::PanelStructure, v::AbstractArray;
        order::Integer=1, l::Integer=1, default=missing)
    out = default === missing ? similar(v, Union{eltype(v), Missing}) : similar(v)
    diff!(out, panel, v, order=order, l=l, default=default)
    return out
end
