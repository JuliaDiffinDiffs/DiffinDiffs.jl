const Terms{N} = NTuple{N, AbstractTerm} where N

"""
    eachterm(t)

Return an iterable collection of terms in `t`.
"""
eachterm(@nospecialize(t::AbstractTerm)) = (t,)
eachterm(@nospecialize(t::Terms)) = t

==(a::Terms{N}, b::Terms{N}) where N = all([t in b for t in a])
==(a::InteractionTerm, b::InteractionTerm) = a.terms==b.terms
==(a::FormulaTerm, b::FormulaTerm) = a.lhs==b.lhs && a.rhs==b.rhs

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

Return a `Tuple` of three objects extracted from the right-hand-side of `formula`.

# Returns
- `TreatmentTerm`: the unique `TreatmentTerm` contained in the `formula`.
- `Tuple`: any term that is interacted with the `TreatmentTerm`.
- `Tuple`: any remaining term in `formula.rhs`.

Error will be raised if either existence or uniqueness of the `TreatmentTerm` is violated.
"""
function parse_treat(@nospecialize(formula::FormulaTerm))
    # Use Array for detecting duplicate terms
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
    xterms = Tuple(term for term in eachterm(formula.rhs) if !hastreat(term))
    return treats[1][1], treats[1][2], xterms
end
