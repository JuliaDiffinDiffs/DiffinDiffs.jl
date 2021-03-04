const Terms{N} = NTuple{N, AbstractTerm} where N
const TermSet = IdDict{AbstractTerm, Nothing}

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
- `TermSet`: a set of terms that are interacted with the `TreatmentTerm`.
- `TermSet`: a set of remaining terms in `formula.rhs`.

Error will be raised if either existence or uniqueness of the `TreatmentTerm` is violated.
"""
function parse_treat(@nospecialize(formula::FormulaTerm))
    mettreat = false
    treatterm = nothing
    ints = TermSet()
    xterms = TermSet()
    for term in eachterm(formula.rhs)
        if term isa TreatmentTerm
            if !mettreat
                mettreat = true
                treatterm = term
            else
                throw(ArgumentError("cannot accept more than one TreatmentTerm"))
            end
        elseif term isa FunctionTerm{typeof(treat)}
            if !mettreat
                mettreat = true
                treatterm = treat(term.args_parsed...)
            else
                throw(ArgumentError("cannot accept more than one TreatmentTerm"))
            end
        elseif term isa InteractionTerm
            if hastreat(term)
                !mettreat ||
                    throw(ArgumentError("cannot accept more than one TreatmentTerm"))
                for t in term.terms
                    if t isa TreatmentTerm
                        if !mettreat
                            mettreat = true
                            treatterm = t
                        else
                            throw(ArgumentError("cannot accept more than one TreatmentTerm"))
                        end
                    elseif t isa FunctionTerm{typeof(treat)}
                        if !mettreat
                            mettreat = true
                            treatterm = treat(t.args_parsed...)
                        else
                            throw(ArgumentError("cannot accept more than one TreatmentTerm"))
                        end
                    else
                        ints[t] = nothing
                    end
                end
            else
                xterms[term] = nothing
            end
        else
            xterms[term] = nothing
        end
    end
    mettreat || throw(ArgumentError("no TreatmentTerm is found"))
    return treatterm::TreatmentTerm, ints, xterms
end

isintercept(t::AbstractTerm) = t in (InterceptTerm{true}(), ConstantTerm(1))
isomitsintercept(t::AbstractTerm) =
    t in (InterceptTerm{false}(), ConstantTerm(0), ConstantTerm(-1))

"""
    parse_intercept(ts::TermSet)

Convert any `ConstantTerm` to `InterceptTerm`
and return Boolean values indicating whether terms explictly requiring
including/excluding the intercept exist.

This function is useful for obtaining a unique way of specifying the intercept
before going through the `schema`--`apply_schema` pipeline defined in `StatsModels`.
"""
function parse_intercept!(ts::TermSet)
    hasintercept = false
    hasomitsintercept = false
    for t in keys(ts)
        if isintercept(t)
            delete!(ts, t)
            hasintercept = true
        end
        if isomitsintercept(t)
            delete!(ts, t)
            hasomitsintercept = true
        end
    end
    hasintercept && (ts[InterceptTerm{true}()] = nothing)
    hasomitsintercept && (ts[InterceptTerm{false}()] = nothing)
    return hasintercept, hasomitsintercept
end

termvars(ts::TermSet) = mapreduce(termvars, union, keys(ts), init=Symbol[])
