"""
    TreatmentTerm{T<:AbstractTreatment} <: AbstractTerm

Contain specification information on treatment and parallel trends assumption.
See also [`treat`](@ref).

# Fields
- `sym::Symbol`: the column name of data representing treatment status.
- `tr::T`: a treatment type that specifies the treatment and indices of estimates.
- `pr::P`: a parallel type that specifies the parallel trends assumption.
"""
struct TreatmentTerm{T<:AbstractTreatment,P<:AbstractParallel} <: AbstractTerm
    sym::Symbol
    tr::T
    pr::P
end

"""
    treat(s::Symbol, t::AbstractTreatment, p::AbstractParallel)

Construct a [`TreatmentTerm`](@ref) with fields set by the arguments.
"""
treat(s::Symbol, t::AbstractTreatment, p::AbstractParallel) = TreatmentTerm(s, t, p)

"""
    treat(s::Term, t::FunctionTerm{FT}, p::FunctionTerm{FP})

Construct a [`TreatmentTerm`](@ref) with fields set by `s.sym`,
`FT.instance(t.args_parsed...)` and `FP.instance(p.args_parsed...)`.
This method is called by [`parse_treat(formula)`](@ref)
when the formula is constructed by `@formula`.
"""
treat(s::Term, t::FunctionTerm{FT}, p::FunctionTerm{FP}) where {FT,FP} =
    treat(s.sym, FT.instance(t.args_parsed...), FP.instance(p.args_parsed...))

"""
    hastreat(t)

Determine whether the term `t` contains an instance of [`TreatmentTerm`](@ref).
"""
hastreat(::TreatmentTerm) = true
hastreat(::FunctionTerm{typeof(treat)}) = true
hastreat(t::InteractionTerm) = any(hastreat(x) for x in t.terms)
hastreat(::AbstractTerm) = false
hastreat(t::FormulaTerm) = any(hastreat(x) for x in eachterm(t.rhs))

"""
    parse_treat(formula::FormulaTerm)

Extract the `TreatmentTerm` and any other term
in its interaction (if interacted) from the formula.
Return a `Pair` with the key being the `TreatmentTerm`
and the value being a tuple for any other term in the interaction.
"""
function parse_treat(@nospecialize(formula::FormulaTerm))
    # Use Array instead of Dict for detecting duplicate terms
    treats = Pair{TreatmentTerm,Tuple}[]
    for term in eachterm(formula.rhs)
        if hastreat(term)
            if term isa TreatmentTerm
                push!(treats, term=>())
            elseif term isa FunctionTerm
                push!(treats, treat(term.args_parsed...)=>())
            elseif term isa InteractionTerm
                trs = []
                ints = []
                for t in term.terms
                    if hastreat(t)
                        if t isa TreatmentTerm
                            push!(trs, t)
                        elseif t isa FunctionTerm
                            push!(trs, treat(t.args_parsed...))
                        end
                    else
                        push!(ints, t)
                    end
                end
                if length(trs)!=1
                    throw(ArgumentError("invlid term $term in formula.
                        An interaction term may contain at most one instance of `TreatmentTerm`."))
                else
                    push!(treats, trs[1]=>Tuple(ints))
                end
            end
        end
    end
    length(treats)>1 &&
        throw(ArgumentError("cannot accept more than one `TreatmentTerm`."))
    isempty(treats) &&
        throw(ArgumentError("no `TreatmentTerm` is found."))
    return treats[1]
end
