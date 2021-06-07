# A variant of SplitApplyCombine.groupfind using IdDict instead of Dictionaries.Dictionary
function _groupfind(container)
    T = keytype(container)
    inds = IdDict{eltype(container), Vector{T}}()
    @inbounds for i in keys(container)
        push!(get!(Vector{T}, inds, container[i]), i)
    end
    return inds
end

function _refs_pool(col::AbstractArray, reftype::Type{<:Integer}=UInt32)
    refs = refarray(col)
    pool = refpool(col)
    labeled = pool !== nothing && !(pool isa RotatingTimeRange)
    if !labeled
        refs, invpool, pool = _label(col, eltype(col), reftype)
    end
    return refs, pool, labeled
end

# Obtain unique labels for row-wise pairs of values from a1 and a2 when mult is large enough
function _mult!(a1::AbstractArray, a2::AbstractArray, mult)
    z = zero(eltype(a1))
    @inbounds for i in eachindex(a1)
        x1 = a1[i]
        x2 = a2[i]
        # Handle missing values represented by zeros
        if iszero(x1) || iszero(x2)
            a1[i] = z
        else
            a1[i] += mult * (x2 - 1)
        end
	end
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
    columns = Vector{AbstractVector}(undef, ncol)
    for i in 1:ncol
        c = cols[i]
        if typeof(c) <: ScaledArrOrSub
            columns[i] = similar(c, ncell)
        else
            columns[i] = Vector{eltype(c)}(undef, ncell)
        end
    end
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
    settime(data, timename; step, start, stop, reftype, rotation)
    settime(time::AbstractArray; step, start, stop, reftype, rotation)

Convert a column of time values to a [`ScaledArray`](@ref)
for representing discretized time periods of uniform length.
Time values can be provided either as a table containing the relevant column or as an array.
The returned array ensures well-defined time intervals for operations involving relative time
(such as [`lag`](@ref) and [`diff`](@ref)).
See also [`aligntime`](@ref).

# Arguments
- `data`: a Tables.jl-compatible data table.
- `timename::Union{Symbol,Integer}`: the name of the column in `data` that contains time values.
- `time::AbstractArray`: the array containing time values (only needed for the alternative method).

# Keywords
- `step=nothing`: the length of each time interval; try step=1 if not specified.
- `start=nothing`: the first element of the `pool` of the returned [`ScaledArray`](@ref).
- `stop=nothing`: the last element of the `pool` of the returned [`ScaledArray`](@ref).
- `reftype::Type{<:Signed}=Int32`: the element type of the reference values for the returned [`ScaledArray`](@ref).
- `rotation=nothing`: rotation groups in a rotating sampling design; use [`RotatingTimeValue`](@ref)s as reference values.
"""
function settime(time::AbstractArray; step=nothing, start=nothing, stop=nothing,
        reftype::Type{<:Signed}=Int32, rotation=nothing)
    T = eltype(time)
    T <: ValidTimeType && !(T <: RotatingTimeValue) ||
        throw(ArgumentError("unaccepted element type $T from time column"))
    step === nothing && (step = one(T))
    time = ScaledArray(time, start, step, stop; reftype=reftype)
    if rotation !== nothing
        refs = rotatingtime(rotation, time.refs)
        rots = unique(rotation)
        invpool = Dict{RotatingTimeValue{eltype(rotation), T}, eltype(refs)}()
        for (k, v) in time.invpool
            for r in rots
                rt = RotatingTimeValue(r, k)
                invpool[rt] = RotatingTimeValue(r, v)
            end
        end
        rmin, rmax = extrema(rots)
        pool = RotatingTimeValue(rmin, first(time.pool)):scale(time):RotatingTimeValue(rmax, last(time.pool))
        time = ScaledArray(RefArray(refs), pool, invpool)
    end
    return time
end

function settime(data, timename::Union{Symbol,Integer};
        step=nothing, start=nothing, stop=nothing,
        reftype::Type{<:Signed}=Int32, rotation=nothing)
    checktable(data)
    return settime(getcolumn(data, timename);
        step=step, start=start, stop=stop, reftype=reftype, rotation=rotation)
end

"""
    aligntime(data, colname::Union{Symbol,Integer}, timename::Union{Symbol,Integer})

Convert a column of time values indexed by `colname` from `data` table
to a [`ScaledArray`](@ref) with a `pool`
that has the same first element and step size as the `pool` from
the [`ScaledArray`](@ref) indexed by `timename`.
See also [`settime`](@ref).

This is useful for representing all discretized time periods with the same scale
so that the underlying reference values returned by `DataAPI.refarray`
can be directly comparable across the columns.
"""
function aligntime(data, colname::Union{Symbol,Integer}, timename::Union{Symbol,Integer})
    checktable(data)
    return align(getcolumn(data, colname), getcolumn(data, timename))
end

"""
    PanelStructure{R<:Signed, IP<:AbstractVector, TP<:AbstractVector}

Panel data structure defined by unique combinations of unit ids and time periods.
It contains the information required for certain operations such as
[`lag`](@ref) and [`diff`](@ref).
See also [`setpanel`](@ref).

# Fields
- `refs::Vector{R}`: reference values that allow obtaining time gaps by taking differences.
- `invrefs::Dict{R, Int}`: inverse map from `refs` to indices.
- `idpool::IP`: unique unit ids.
- `timepool::TP`: sorted unique time periods.
- `laginds::Dict{Int, Vector{Int}}`: a map from lag distances to vectors of indices of lagged values.
"""
struct PanelStructure{R<:Signed, IP<:AbstractVector, TP<:AbstractVector}
    refs::Vector{R}
    invrefs::Dict{R, Int}
    idpool::IP
    timepool::TP
    laginds::Dict{Int, Vector{Int}}
    function PanelStructure(refs::Vector{R}, idpool::IP, timepool::TP,
            laginds::Dict=Dict{Int, Vector{Int}}()) where {R,IP,TP}
        invrefs = Dict{R, Int}(ref=>i for (i, ref) in enumerate(refs))
        return new{R,IP,TP}(refs, invrefs, idpool, timepool, laginds)
    end
end

"""
    setpanel(data, idname, timename; step, reftype, rotation)
    setpanel(id::AbstractArray, time::AbstractArray; step, reftype, rotation)
    
Declare a [`PanelStructure`](@ref) which is required for certain operations
such as [`lag`](@ref) and [`diff`](@ref).
Unit IDs and time values can be provided either
as a table containing the relevant columns or as arrays.
`timestep` must be specified unless the `time` array is a [`ScaledArray`](@ref)
that is returned by [`settime`](@ref).

# Arguments
- `data`: a Tables.jl-compatible data table.
- `idname::Union{Symbol,Integer}`: the name of the column in `data` that contains unit IDs.
- `timename::Union{Symbol,Integer}`: the name of the column in `data` that contains time values.
- `id::AbstractArray`: the array containing unit IDs (only needed for the alternative method).
- `time::AbstractArray`: the array containing time values (only needed for the alternative method).

# Keywords
- `step=nothing`: the length of each time interval; try step=1 if not specified.
- `reftype::Type{<:Signed}=Int32`: the element type of the reference values for [`PanelStructure`](@ref).
- `rotation=nothing`: rotation groups in a rotating sampling design; use [`RotatingTimeValue`](@ref)s as reference values.

!!! note
    If the underlying data used to create the [`PanelStructure`](@ref) are modified.
    The changes will not be reflected in the existing instances of [`PanelStructure`](@ref).
    A new instance needs to be created with `setpanel`.
"""
function setpanel(id::AbstractArray, time::AbstractArray; step=nothing,
        reftype::Type{<:Signed}=Int32, rotation=nothing)
    eltype(time) <: ValidTimeType ||
        throw(ArgumentError("unaccepted element type $(eltype(time)) from time column"))
    length(id) == length(time) || throw(DimensionMismatch(
        "id has length $(length(id)) while time has length $(length(time))"))
    refs, idpool, labeled = _refs_pool(id)
    labeled && (refs = copy(refs); idpool = copy(idpool))
    time = settime(time; step=step, reftype=reftype, rotation=rotation)
    trefs = refarray(time)
    tpool = refpool(time)
    # Multiply 2 to create enough gaps between id groups for the largest possible lead/lag
    mult = 2 * length(tpool)
    _mult!(trefs, refs, mult)
    return PanelStructure(trefs, idpool, tpool)
end

function setpanel(data, idname::Union{Symbol,Integer}, timename::Union{Symbol,Integer};
        step=nothing, reftype::Type{<:Signed}=Int32)
    checktable(data)
    return setpanel(getcolumn(data, idname), getcolumn(data, timename);
        step=step, reftype=reftype)
end

show(io::IO, ::PanelStructure) = print(io, "Panel Structure")

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
