"""
    checkdata(args...)

Check `data` is a `Table` and find valid rows for options `subset` and `weights`.
See also [`CheckData`](@ref).
"""
function checkdata(data, subset::Union{AbstractVector, Nothing},
        weights::Union{Symbol, Nothing})

    istable(data) ||
        throw(ArgumentError("expect `data` being a `Table` while receiving a $(typeof(data))"))
    
    if subset !== nothing
        length(subset) != size(data, 1) &&
            throw(DimensionMismatch("`data` of $(size(data, 1)) rows cannot be matched with `subset` vector of $(length(subset)) elements"))
        esample = .!ismissing.(subset) .& subset
    else
        esample = trues(size(data, 1))
    end

    if weights !== nothing
        colweights = getcolumn(data, weights)
        esample .&= .!ismissing.(colweights) .& (colweights .> 0)
    end
    
    sum(esample) == 0 && error("no nonmissing data")
    return (esample=esample,), false
end

"""
    CheckData <: StatsStep

Call [`DiffinDiffsBase.checkdata`](@ref)
for some preliminary checks of the input data.
"""
const CheckData = StatsStep{:CheckData, typeof(checkdata)}

namedargs(::CheckData) = (data=nothing, subset=nothing, weights=nothing)

function _overlaptime(tr::DynamicTreatment, tr_rows::BitArray, data)
    control_time = Set(view(getcolumn(data, tr.time), .!tr_rows))
    treated_time = Set(view(getcolumn(data, tr.time), tr_rows))
    return intersect(control_time, treated_time), control_time, treated_time
end

function overlap!(esample::BitArray, tr_rows::BitArray, tr::DynamicTreatment,
        ::NeverTreatedParallel{Unconditional}, treatname::Symbol, data)
        overlap_time, control_time, treated_time = _overlaptime(tr, tr_rows, data)
    length(control_time)==length(treated_time)==length(overlap_time) ||
        (esample .&= getcolumn(data, tr.time).∈(overlap_time,))
    tr_rows .&= esample
end
    
function overlap!(esample::BitArray, tr_rows::BitArray, tr::DynamicTreatment,
        pr::NotYetTreatedParallel{Unconditional}, treatname::Symbol, data)
    overlap_time, _c, _t = _overlaptime(tr, tr_rows, data)
    timetype = eltype(overlap_time)
    if timetype <: Integer
        ecut = pr.ecut === nothing ? minimum(pr.e) : pr.ecut[1]
        valid_cohort = filter(x -> x < ecut || x in pr.e, overlap_time)
        filter!(x -> x < ecut, overlap_time)
        esample .&= (getcolumn(data, tr.time).∈(overlap_time,)) .&
            (getcolumn(data, treatname).∈(valid_cohort,))
    end
    tr_rows .&= esample
end

"""
    checkvars!(args...)

Exclude rows with missing data or violate the overlap condition
and find rows with data from treated units.
See also [`CheckVars`](@ref).
"""
function checkvars!(data, tr::AbstractTreatment, pr::AbstractParallel,
        yterm::AbstractTerm, treatname::Symbol, treatintterms::TupleTerm,
        xterms::TupleTerm, esample::BitArray)

    treatvars = union([treatname], (termvars(t) for t in (tr, pr, treatintterms))...)
    for v in treatvars
        eltype(getcolumn(data, v)) <: Union{Missing, Integer} ||
            throw(ArgumentError("data column $v has unaccepted element type"))
    end
    # Values of treatintterms from units in control groups are ignored
    allvars = union(treatvars, (termvars(t) for t in (yterm, xterms))...)
    treatedvars = setdiff(allvars, termvars(treatintterms))
    tr_rows = falses(length(esample))
    @inbounds for i in eachindex(esample)
        if esample[i]
            if istreated(pr, getcolumn(data, treatname)[i])
                esample[i] = all(v->!ismissing(getcolumn(data, v)[i]), treatedvars)
                esample[i] && (tr_rows[i] = true)
            else
                esample[i] = all(v->!ismissing(getcolumn(data, v)[i]), allvars)
            end
        end
    end

    overlap!(esample, tr_rows, tr, pr, treatname, data)
    sum(esample) == 0 && error("no nonmissing data")
    return (esample=esample, tr_rows=tr_rows), false
end

"""
    CheckVars <: StatsStep

Call [`DiffinDiffsBase.checkvars!`](@ref) to exclude invalid rows for relevant variables.
"""
const CheckVars = StatsStep{:CheckVars, typeof(checkvars!)}

namedargs(::CheckVars) = (data=nothing, tr=nothing, pr=nothing,
    yterm=nothing, treatname=nothing, treatintterms=(), xterms=(), esample=nothing)
