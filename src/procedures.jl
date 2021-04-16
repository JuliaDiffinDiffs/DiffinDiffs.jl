"""
    checkdata(args...)

Check `data` is `Tables.AbstractColumns`-compatible
and find valid rows for options `subset` and `weightname`.
See also [`CheckData`](@ref).
"""
function checkdata(data, subset::Union{BitVector, Nothing}, weightname::Union{Symbol, Nothing})
    checktable(data)
    nrow = Tables.rowcount(data)
    if subset !== nothing
        length(subset) == nrow || throw(DimensionMismatch(
            "data contain $(nrow) rows while subset has $(length(subset)) elements"))
        esample = .!ismissing.(subset) .& subset
    else
        esample = trues(nrow)
    end

    if weightname !== nothing
        colweights = getcolumn(data, weightname)
        esample .&= .!ismissing.(colweights) .& (colweights .> 0)
    end
    sum(esample) == 0 && error("no nonmissing data")
    return (esample=esample,)
end

"""
    CheckData <: StatsStep

Call [`DiffinDiffsBase.checkdata`](@ref)
for some preliminary checks of the input data.
"""
const CheckData = StatsStep{:CheckData, typeof(checkdata), true}

required(::CheckData) = (:data,)
default(::CheckData) = (subset=nothing, weightname=nothing)

"""
    groupterms(args...)

Return the arguments for allowing later comparisons based on object-id.
See also [`GroupTerms`](@ref).
"""
groupterms(treatintterms::TermSet, xterms::TermSet) =
    (treatintterms = treatintterms, xterms = xterms)

"""
    GroupTerms <: StatsStep

Call [`DiffinDiffsBase.groupterms`](@ref)
to obtain one of the instances of `treatintterms` and `xterms`
that have been grouped by `==`
for allowing later comparisons based on object-id.

This step is only useful when working with [`@specset`](@ref) and [`proceed`](@ref).
"""
const GroupTerms = StatsStep{:GroupTerms, typeof(groupterms), false}

required(::GroupTerms) = (:treatintterms, :xterms)

function checktreatvars(::DynamicTreatment{SharpDesign}, pr::TrendParallel{Unconditional},
        treatvars::Vector{Symbol}, data)
    # treatvars should be cohort and time variables
    col1 = getcolumn(data, treatvars[1])
    col2 = getcolumn(data, treatvars[2])
    T1 = nonmissingtype(eltype(col1))
    T2 = nonmissingtype(eltype(col2))
    T1 == T2 || throw(ArgumentError(
        "nonmissing elements from columns $(treatvars[1]) and $(treatvars[2]) have different types $T1 and $T2"))
    T1 <: Union{Integer, RotatingTimeValue{<:Any, <:Integer}} ||
        col1 isa ScaledArray && col2 isa ScaledArray ||
        throw(ArgumentError("data columns $(treatvars[1]) and $(treatvars[2]) must either have integer elements or be ScaledArrays; see settime"))
    T1 <: ValidTimeType ||
        throw(ArgumentError("data column $(treatvars[1]) has unaccepted element type $(T1)"))
    eltype(pr.e) == T1 || throw(ArgumentError("element type $(eltype(pr.e)) of control cohorts from $pr does not match element type $T1 from data; expect $T1"))
end

function _overlaptime(tr::DynamicTreatment, tr_rows::BitVector, data)
    control_time = Set(view(refarray(getcolumn(data, tr.time)), .!tr_rows))
    treated_time = Set(view(refarray(getcolumn(data, tr.time)), tr_rows))
    return intersect(control_time, treated_time), control_time, treated_time
end

function overlap!(esample::BitVector, tr_rows::BitVector, tr::DynamicTreatment,
        ::NeverTreatedParallel{Unconditional}, treatname::Symbol, data)
    overlap_time, control_time, treated_time = _overlaptime(tr, tr_rows, data)
    length(control_time)==length(treated_time)==length(overlap_time) ||
        (esample .&= getcolumn(data, tr.time).∈(overlap_time,))
    tr_rows .&= esample
end

function overlap!(esample::BitVector, tr_rows::BitVector, tr::DynamicTreatment,
        pr::NotYetTreatedParallel{Unconditional}, treatname::Symbol, data)
    overlap_time, _c, _t = _overlaptime(tr, tr_rows, data)
    timetype = eltype(overlap_time)
    invpool = invrefpool(getcolumn(data, tr.time))
    if !(timetype <: RotatingTimeValue)
        ecut = pr.ecut[1]
        invpool === nothing || (ecut = invpool[ecut])
        valid_cohort = filter(x -> x < ecut || x in pr.e, overlap_time)
        filter!(x -> x < ecut, overlap_time)
    else
        ecut = pr.ecut
        invpool === nothing || (ecut = (invpool[e] for e in ecut))
        ecut = IdDict(e.rotation=>e.time for e in ecut)
        valid_cohort = filter(x -> x.time < ecut[x.rotation] || x in pr.e, overlap_time)
        filter!(x -> x.time < ecut[x.rotation], overlap_time)
    end
    esample .&= (refarray(getcolumn(data, tr.time)).∈(overlap_time,)) .&
        (refarray(getcolumn(data, treatname)).∈(valid_cohort,))
    tr_rows .&= esample
end

"""
    checkvars!(args...)

Exclude rows with missing data or violate the overlap condition
and find rows with data from treated units.
See also [`CheckVars`](@ref).
"""
function checkvars!(data, tr::AbstractTreatment, pr::AbstractParallel,
        yterm::AbstractTerm, treatname::Symbol, esample::BitVector,
        treatintterms::TermSet, xterms::TermSet)
    # Do not check eltype of treatintterms
    treatvars = union([treatname], termvars(tr), termvars(pr))
    checktreatvars(tr, pr, treatvars, data)

    allvars = union(treatvars, termvars(yterm), termvars(xterms))
    for v in allvars
        esample .&= .!ismissing.(getcolumn(data, v))
    end
    # Values of treatintterms from untreated units are ignored
    tr_rows = esample .& istreated.(Ref(pr), getcolumn(data, treatname))
    treatintvars = termvars(treatintterms)
    for v in treatintvars
        esample[tr_rows] .&= .!ismissing.(view(getcolumn(data, v), tr_rows))
    end
    isempty(treatintvars) || (tr_rows .&= esample)

    overlap!(esample, tr_rows, tr, pr, treatname, data)
    sum(esample) == 0 && error("no nonmissing data")
    return (esample=esample, tr_rows=tr_rows::BitVector)
end

"""
    CheckVars <: StatsStep

Call [`DiffinDiffsBase.checkvars!`](@ref) to exclude invalid rows for relevant variables.
"""
const CheckVars = StatsStep{:CheckVars, typeof(checkvars!), true}

required(::CheckVars) = (:data, :tr, :pr, :yterm, :treatname, :esample)
default(::CheckVars) = (treatintterms=TermSet(), xterms=TermSet())
copyargs(::CheckVars) = (6,)

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
