"""
    checkdata(args...)

Check `data` is a `Table` and find rows with nonmissing values for variables.
See also [`CheckData`](@ref).

# Returns
- `vars::Vector{Symbol}`: column names of relevant variables.
- `esample::BitArray`: Boolean indices for rows with nonmissing values for the variables.
"""
function checkdata(data, tr::AbstractTreatment, pr::AbstractParallel,
    yterm::AbstractTerm, treatname::Symbol, xterms::TupleTerm,
    weights::Union{Symbol, Nothing}, subset::Union{AbstractVector, Nothing})

    istable(data) ||
        throw(ArgumentError("expected data in a Table, got $(typeof(data))"))
    
    vars = union([treatname], (termvars(t) for t in (tr, pr, yterm, xterms))...)
    esample = BitArray(all(v->!ismissing(getproperty(row, v)), vars) for row in rows(data))

    if subset !== nothing
        length(subset) != size(data, 1) &&
            throw(DimensionMismatch("`data` of $(size(data, 1)) rows cannot be matched with `subset` vector of $(length(subset)) elements"))
        esample .&= .!ismissing.(subset) .& subset
    end

    if weights !== nothing
        colweights = getcolumn(columns(data), weights)
        esample .&= .!ismissing.(colweights) .& (colweights .> 0)
    end
    
    sum(esample) == 0 && error("no nonmissing data")
    
    return (vars=vars, esample=esample)
end

"""
    CheckData

A [`StatsStep`](@ref) that calls [`DiffinDiffsBase.checkdata`](@ref)
for some preliminary checks of the input data.
"""
const CheckData = StatsStep{:CheckData, typeof(checkdata), (:data, :tr, :pr, :yterm, :treatname, :xterms, :weights, :subset), ()}


