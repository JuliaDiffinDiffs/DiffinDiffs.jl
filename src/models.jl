"""
    did(t::TreatmentTerm, args...; kwargs...)

A wrapper method that accepts a [`TreatmentTerm`](@ref).
"""
did(@nospecialize(t::TreatmentTerm), args...; kwargs...) =
    did(t.tr, t.pr, args...; treatstatus=t.sym, kwargs...)

"""
    did(formula::FormulaTerm, args...; kwargs...)

A wrapper method that accepts a formula.
"""
function did(@nospecialize(formula::FormulaTerm), args...; kwargs...)
    treat, intacts = parse_treat(formula)
    return did(treat.tr, treat.pr, args...;
        treatstatus=treat.sym, treatintacts=intacts, formula=formula, kwargs...)
end

"""
    DIDResult <: StatisticalModel

Supertype for all types that collect DID estimation results
produced by [`did`](@ref).
"""
abstract type DIDResult <: StatisticalModel end

"""
    agg(r::DIDResult, args...; kwargs...)

Aggregate estimates stored in a [`DIDResult`](@ref).
"""
agg(r::DIDResult, args...; kwargs...) =
    throw("agg is not defined for $(typeof(r)).")

"""
    AggregatedDIDResult <: StatisticalModel

Supertype for all types that collect aggregated DID estimation results
produced by [`agg`](@ref).
"""
abstract type AggregatedDIDResult <: StatisticalModel end
