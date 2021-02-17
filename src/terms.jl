const Terms{N} = NTuple{N, AbstractTerm} where N

"""
    eachterm(t)

Return an iterable collection of terms in `t`.
"""
eachterm(@nospecialize(t::AbstractTerm)) = (t,)
eachterm(@nospecialize(t::Terms)) = t

==(@nospecialize(a::Terms), @nospecialize(b::Terms)) =
    length(a)==length(b) && all(t->t in b, a)
==(@nospecialize(a::InteractionTerm), @nospecialize(b::InteractionTerm)) =
    a.terms==b.terms
==(@nospecialize(a::FormulaTerm), @nospecialize(b::FormulaTerm)) =
    a.lhs==b.lhs && a.rhs==b.rhs

"""
    TreatmentTerm{T<:AbstractTreatment} <: AbstractTerm

A term that contains specifications on treatment and parallel trends assumption.
See also [`treat`](@ref).

# Fields
- `sym::Symbol`: the column name of data representing treatment status.
- `tr::T`: a treatment type that specifies the causal parameters of interest.
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
hastreat(@nospecialize(t::FormulaTerm)) = any(hastreat(x) for x in eachterm(t.rhs))

"""
    parse_treat(formula::FormulaTerm)

Extract terms related to treatment specifications from `formula`.

# Returns
- `TreatmentTerm`: the unique `TreatmentTerm` contained in the `formula`.
- `Terms`: a tuple of any term that is interacted with the `TreatmentTerm`.
- `Terms`: a tuple of remaining terms in `formula.rhs`.

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

# A tentative solution to changes made in StatsModels v0.6.21
hasintercept(::Tuple{}) = false
omitsintercept(::Tuple{}) = false

isintercept(t::AbstractTerm) = t in (InterceptTerm{true}(), ConstantTerm(1))
isomitsintercept(t::AbstractTerm) =
    t in (InterceptTerm{false}(), ConstantTerm(0), ConstantTerm(-1))

"""
    parse_intercept(ts::Terms)

Convert any `ConstantTerm` to `InterceptTerm` and add them to the end of the tuple.
This is useful for obtaining a unique way of specifying the intercept
before going through the `schema`--`apply_schema` pipeline defined in `StatsModels`.
"""
function parse_intercept(@nospecialize(ts::Terms))
    out = AbstractTerm[t for t in ts if !(isintercept(t) || isomitsintercept(t))]
    omitsintercept(ts) && push!(out, InterceptTerm{false}())
    # This order is assumed by InteractionWeightedDIDs.Fstat
    hasintercept(ts) && push!(out, InterceptTerm{true}())
    return (out...,)
end

termvars(::Tuple{}) = Symbol[]
