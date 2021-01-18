
function check_data(data, tr::AbstractTreatment, pr::AbstractParallel,
    yterm::AbstractTerm, treatname::Symbol, xterms::TupleTerm,
    weights::Union{Symbol, Nothing}, subset::Union{AbstractVector, Nothing})

    istable(data) ||
        throw(ArgumentError("expected data in a Table, got $(typeof(data))"))
    
    vars = union(treatname, (termvars(t) for t in (tr, pr, yterm, xterms)))
    esample = BitArray(all(v->!ismissing(getproperty(row, v)), vars) for row in rows(data))

    if subset != nothing
        length(subset) != size(data, 1) &&
            throw("df has $(size(df, 1)) rows but the subset vector has $(length(subset)) elements")
        esample .&= .!ismissing.(x) .& x
    end

    if weights != nothing
        colweights = getcolumn(columns(data), weights)
        esample .&= .!ismissing.(colweights) .& (colweights .> 0)
    end
    
    sum(esample) == 0 && throw(ArgumentError("no nonmissing data"))
    
    return (vars=vars, esample=esample,)
end

const CheckData = StatsStep{:CheckData, typeof(check_data), (:data, :tr, :pr, :yterm, :treatname, :xterms, :weights, :subset), ()}



