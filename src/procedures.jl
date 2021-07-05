"""
    checkdata!(args...)

Check `data` is `Tables.AbstractColumns`-compatible
and find valid rows for options `subset` and `weightname`.
See also [`CheckData`](@ref).
"""
function checkdata!(data, subset::Union{BitVector, Nothing}, weightname::Union{Symbol, Nothing})
    checktable(data)
    nrow = Tables.rowcount(data)
    if subset !== nothing
        length(subset) == nrow || throw(DimensionMismatch(
            "data contain $(nrow) rows while subset has $(length(subset)) elements"))
        esample = subset
    else
        esample = trues(nrow)
    end

    # A cache that makes updating BitVector (esample or tr_rows) faster
    # See https://github.com/JuliaData/DataFrames.jl/pull/2726
    aux = BitVector(undef, nrow)

    if weightname !== nothing
        colweights = getcolumn(data, weightname)
        if Missing <: eltype(colweights)
            aux .= .!ismissing.(colweights)
            esample .&= aux
        end
        aux[esample] .= view(colweights, esample) .> 0
        esample[esample] .&= view(aux, esample)
    end
    sum(esample) == 0 && error("no nonmissing data")
    return (esample=esample, aux=aux)
end

"""
    CheckData <: StatsStep

Call [`DiffinDiffsBase.checkdata!`](@ref)
for some preliminary checks of the input data.
"""
const CheckData = StatsStep{:CheckData, typeof(checkdata!), true}

required(::CheckData) = (:data,)
default(::CheckData) = (subset=nothing, weightname=nothing)

"""
    grouptreatintterms(treatintterms)

Return the argument without change for allowing later comparisons based on object-id.
See also [`GroupTreatintterms`](@ref).
"""
grouptreatintterms(treatintterms::TermSet) = (treatintterms=treatintterms,)

"""
    GroupTreatintterms <: StatsStep

Call [`DiffinDiffsBase.grouptreatintterms`](@ref)
to obtain one of the instances of `treatintterms`
that have been grouped by equality (`hash`)
for allowing later comparisons based on object-id.

This step is only useful when working with [`@specset`](@ref) and [`proceed`](@ref).
"""
const GroupTreatintterms = StatsStep{:GroupTreatintterms, typeof(grouptreatintterms), false}

default(::GroupTreatintterms) = (treatintterms=TermSet(),)

"""
    groupxterms(xterms)

Return the argument without change for allowing later comparisons based on object-id.
See also [`GroupXterms`](@ref).
"""
groupxterms(xterms::TermSet) = (xterms=xterms,)

"""
    GroupXterms <: StatsStep

Call [`DiffinDiffsBase.groupxterms`](@ref)
to obtain one of the instances of `xterms`
that have been grouped by equality (`hash`)
for allowing later comparisons based on object-id.

This step is only useful when working with [`@specset`](@ref) and [`proceed`](@ref).
"""
const GroupXterms = StatsStep{:GroupXterms, typeof(groupxterms), false}

default(::GroupXterms) = (xterms=TermSet(),)

"""
    groupcontrasts(contrasts)

Return the argument without change for allowing later comparisons based on object-id.
See also [`GroupContrasts`](@ref).
"""
groupcontrasts(contrasts::Union{Dict{Symbol,Any},Nothing}) = (contrasts=contrasts,)

"""
    GroupContrasts <: StatsStep

Call [`DiffinDiffsBase.groupcontrasts`](@ref)
to obtain one of the instances of `contrasts`
that have been grouped by equality (`hash`)
for allowing later comparisons based on object-id.

This step is only useful when working with [`@specset`](@ref) and [`proceed`](@ref).
"""
const GroupContrasts = StatsStep{:GroupContrasts, typeof(groupcontrasts), false}

default(::GroupContrasts) = (contrasts=nothing,)

function _checkscales(col1::AbstractArray, col2::AbstractArray, treatvars::Vector{Symbol})
    if col1 isa ScaledArrOrSub || col2 isa ScaledArrOrSub
        col1 isa ScaledArrOrSub && col2 isa ScaledArrOrSub ||
            throw(ArgumentError("time fields in both columns $(treatvars[1]) and $(treatvars[2]) must be ScaledArrays; see settime and aligntime"))
        first(DataAPI.refpool(col1)) == first(DataAPI.refpool(col2)) &&
            scale(col1) == scale(col2) || throw(ArgumentError(
            "time fields in columns $(treatvars[1]) and $(treatvars[2]) are not aligned; see aligntime"))
    else
        eltype(col1) <: Integer || throw(ArgumentError(
            "columns $(treatvars[1]) and $(treatvars[2]) must be stored in ScaledArrays; see settime and aligntime"))
    end
end

function checktreatvars(::DynamicTreatment{SharpDesign},
        pr::TrendOrUnspecifiedPR{Unconditional}, treatvars::Vector{Symbol}, data)
    # treatvars should be cohort and time variables
    col1 = getcolumn(data, treatvars[1])
    col2 = getcolumn(data, treatvars[2])
    T1 = nonmissingtype(eltype(col1))
    T2 = nonmissingtype(eltype(col2))
    T1 == T2 || throw(ArgumentError(
        "nonmissing elements from columns $(treatvars[1]) and $(treatvars[2]) have different types $T1 and $T2"))
    T1 <: ValidTimeType ||
        throw(ArgumentError("column $(treatvars[1]) has unaccepted element type $(T1)"))
    if pr isa TrendParallel
        eltype(pr.e) == T1 || throw(ArgumentError("element type $(eltype(pr.e)) of control cohorts from $pr does not match element type $T1 from data; expect $T1"))
    end
    if T1 <: RotatingTimeValue
        col1 isa RotatingTimeArray && col2 isa RotatingTimeArray ||
            throw(ArgumentError("columns $(treatvars[1]) and $(treatvars[2]) must be RotatingTimeArrays; see settime"))
        _checkscales(col1.time, col2.time, treatvars)
    else
        _checkscales(col1, col2, treatvars)
    end
end

function _overlaptime(tr::DynamicTreatment, tr_rows::BitVector, data)
    timeref = refarray(getcolumn(data, tr.time))
    control_time = Set(view(timeref, .!tr_rows))
    treated_time = Set(view(timeref, tr_rows))
    return intersect(control_time, treated_time), control_time, treated_time
end

function overlap!(esample::BitVector, tr_rows::BitVector, aux::BitVector, tr::DynamicTreatment,
        ::NeverTreatedParallel{Unconditional}, treatname::Symbol, data)
    overlap_time, control_time, treated_time = _overlaptime(tr, tr_rows, data)
    if !(length(control_time)==length(treated_time)==length(overlap_time))
        aux[esample] .= view(refarray(getcolumn(data, tr.time)), esample) .∈ (overlap_time,)
        esample[esample] .&= view(aux, esample)
    end
    tr_rows .&= esample
end

function overlap!(esample::BitVector, tr_rows::BitVector, aux::BitVector, tr::DynamicTreatment,
        pr::NotYetTreatedParallel{Unconditional}, treatname::Symbol, data)
    overlap_time, _c, _t = _overlaptime(tr, tr_rows, data)
    timecol = getcolumn(data, tr.time)
    if !(eltype(timecol) <: RotatingTimeValue)
        invpool = invrefpool(timecol)
        e = invpool === nothing ? Set(pr.e) : Set(invpool[c] for c in pr.e)
        ecut = invpool === nothing ? pr.ecut[1] : invpool[pr.ecut[1]]
        filter!(x -> x < ecut, overlap_time)
        isvalidcohort = x -> x < ecut || x in e
    else
        invpool = invrefpool(timecol.time)
        if invpool === nothing
            e = Set(pr.e)
            ecut = IdDict(e.rotation=>e.time for e in pr.ecut)
        else
            e = Set(RotatingTimeValue(c.rotation, invpool[c.time]) for c in pr.e)
            ecut = IdDict(e.rotation=>invpool[e.time] for e in pr.ecut)
        end
        filter!(x -> x.time < ecut[x.rotation], overlap_time)
        isvalidcohort = x -> x.time < ecut[x.rotation] || x in e
    end
    aux[esample] .= view(refarray(timecol), esample) .∈ (overlap_time,)
    esample[esample] .&= view(aux, esample)
    aux[esample] .= isvalidcohort.(view(refarray(getcolumn(data, treatname)), esample))
    esample[esample] .&= view(aux, esample)
    tr_rows .&= esample
end

overlap!(esample::BitVector, tr_rows::BitVector, aux::BitVector, tr::DynamicTreatment,
    pr::UnspecifiedParallel{Unconditional}, treatname::Symbol, data) = nothing

"""
    checkvars!(args...)

Exclude rows with missing data or violate the overlap condition
and find rows with data from treated units.
See also [`CheckVars`](@ref).
"""
function checkvars!(data, pr::AbstractParallel,
        yterm::AbstractTerm, treatname::Symbol, esample::BitVector, aux::BitVector,
        treatintterms::TermSet, xterms::TermSet, ::Type, @nospecialize(trvars::Tuple),
        tr::AbstractTreatment)
    # Do not check eltype of treatintterms
    treatvars = union([treatname], trvars, termvars(pr))
    checktreatvars(tr, pr, treatvars, data)

    allvars = union(treatvars, termvars(yterm), termvars(xterms))
    for v in allvars
        col = getcolumn(data, v)
        if Missing <: eltype(col)
            aux .= .!ismissing.(col)
            esample .&= aux
        end
    end
    # Values of treatintterms from untreated units are ignored
    tr_rows = copy(esample)
    if !(pr isa UnspecifiedParallel)
        istreated!(view(aux, esample), pr, view(getcolumn(data, treatname), esample))
        tr_rows[esample] .&= view(aux, esample)
    end
    treatintvars = termvars(treatintterms)
    for v in treatintvars
        col = getcolumn(data, v)
        if Missing <: eltype(col)
            aux[tr_rows] .= .!ismissing.(view(col, tr_rows))
            esample[tr_rows] .&= view(aux, tr_rows)
        end
    end
    isempty(treatintvars) || (tr_rows[tr_rows] .&= view(esample, tr_rows))

    overlap!(esample, tr_rows, aux, tr, pr, treatname, data)
    sum(esample) == 0 && error("no nonmissing data")
    return (esample=esample, tr_rows=tr_rows::BitVector)
end

"""
    CheckVars <: StatsStep

Call [`DiffinDiffsBase.checkvars!`](@ref) to exclude invalid rows for relevant variables.
"""
const CheckVars = StatsStep{:CheckVars, typeof(checkvars!), true}

required(::CheckVars) = (:data, :pr, :yterm, :treatname, :esample, :aux,
    :treatintterms, :xterms)
transformed(::CheckVars, @nospecialize(nt::NamedTuple)) =
    (typeof(nt.tr), (termvars(nt.tr)...,))

combinedargs(step::CheckVars, allntargs) =
    combinedargs(step, allntargs, typeof(allntargs[1].tr))

combinedargs(::CheckVars, allntargs, ::Type{DynamicTreatment{SharpDesign}}) =
    (allntargs[1].tr,)

copyargs(::CheckVars) = (5,)

"""
    groupsample(esample)

Return the argument without change for allowing later comparisons based on object-id.
See also [`GroupSample`](@ref).
"""
groupsample(esample::BitVector) = (esample=esample,)

"""
    GroupSample <: StatsStep

Call [`DiffinDiffsBase.groupsample`](@ref)
to obtain one of the instances of `esample`
that have been grouped by equality (`hash`)
for allowing later comparisons based on object-id.

This step is only useful when working with [`@specset`](@ref) and [`proceed`](@ref).
"""
const GroupSample = StatsStep{:GroupSample, typeof(groupsample), false}

required(::GroupSample) = (:esample,)

"""
    makeweights(args...)

Construct a generic `Weights` vector.
See also [`MakeWeights`](@ref).
"""
function makeweights(data, esample::BitVector, weightname::Symbol)
    weights = Weights(convert(Vector{Float64}, view(getcolumn(data, weightname), esample)))
    all(isfinite, weights) || error("data column $weightname contain not-a-number values")
    return (weights=weights,)
end

function makeweights(data, esample::BitVector, weightname::Nothing)
    weights = uweights(sum(esample))
    return (weights=weights,)
end

"""
    MakeWeights <: StatsStep

Call [`DiffinDiffsBase.makeweights`](@ref) to create a generic `Weights` vector.
"""
const MakeWeights = StatsStep{:MakeWeights, typeof(makeweights), true}

required(::MakeWeights) = (:data, :esample)
default(::MakeWeights) = (weightname=nothing,)
