"""
    TermSet <: AbstractSet{AbstractTerm}

Wrapped `Set{AbstractTerm}` that specifies a collection of terms.
Commonly used methods for `Set` work in the same way for `TermSet`.

Compared with `StatsModels.TermOrTerms`,
it does not maintain order of terms
but is more suitable for dynamically constructed terms.
"""
struct TermSet <: AbstractSet{AbstractTerm}
    terms::Set{AbstractTerm}
    TermSet(set::Set{AbstractTerm}) = new(set)
end

"""
    TermSet([itr])
    TermSet(ts::Union{Int, Symbol, AbstractTerm}...)

Construct a [`TermSet`](@ref) from a collection of terms.
Instead of passing an iterable collection,
one may pass the terms as arguments directly.
In the latter case, any `Int` or `Symbol` will be converted to a `Term`.
See also [`termset`](@ref), which is an alias for the constructor.
"""
TermSet() = TermSet(Set{AbstractTerm}())
TermSet(ts) = TermSet(Set{AbstractTerm}(ts))
TermSet(ts::Union{Int, Symbol, AbstractTerm}...) =
    TermSet(Set{AbstractTerm}(t isa AbstractTerm ? t : term(t) for t in ts))

"""
    termset([itr])
    termset(ts::Union{Int, Symbol, AbstractTerm}...)

Construct a [`TermSet`](@ref) from a collection of terms.
Instead of passing an iterable collection,
one may pass the terms as arguments directly.
In the latter case, any `Int` or `Symbol` will be converted to a `Term`.
"""
termset() = TermSet(Set{AbstractTerm}())
termset(ts) = TermSet(Set{AbstractTerm}(ts))
termset(ts::Union{Int, Symbol, AbstractTerm}...) =
    TermSet(Set{AbstractTerm}(t isa AbstractTerm ? t : term(t) for t in ts))

Base.isempty(ts::TermSet) = isempty(ts.terms)
Base.length(ts::TermSet)  = length(ts.terms)
Base.in(x, ts::TermSet) = in(x, ts.terms)
Base.push!(ts::TermSet, x) = push!(ts.terms, x)
Base.pop!(ts::TermSet, x) = pop!(ts.terms, x)
Base.pop!(ts::TermSet, x, default) = pop!(ts.terms, x, default)
Base.delete!(ts::TermSet, x) = delete!(ts.terms, x)
Base.empty!(ts::TermSet) = empty!(ts.terms)

Base.eltype(::Type{TermSet}) = AbstractTerm
Base.iterate(ts::TermSet, i...) = iterate(ts.terms, i...)
Base.emptymutable(::TermSet, ::Type{<:AbstractTerm}) = termset()

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
                        push!(ints, t)
                    end
                end
            else
                push!(xterms, term)
            end
        else
            push!(xterms, term)
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

Remove any `ConstantTerm` or `InterceptTerm`
and return Boolean values indicating whether terms explictly requiring
including/excluding the intercept exist.

This function is useful for obtaining a unique way of specifying the intercept
before going through the `schema`--`apply_schema` pipeline defined in `StatsModels`.
"""
function parse_intercept!(ts::TermSet)
    hasintercept = false
    hasomitsintercept = false
    for t in ts
        if isintercept(t)
            delete!(ts, t)
            hasintercept = true
        end
        if isomitsintercept(t)
            delete!(ts, t)
            hasomitsintercept = true
        end
    end
    return hasintercept, hasomitsintercept
end

schema(ts::TermSet, data, hints=nothing) =
    Schema(t=>concrete_term(t, VecColumnTable(data), hints) for t in ts)

concrete_term(t::Term, dt::VecColumnTable, hint) =
    concrete_term(t, getproperty(dt, t.sym), hint)
concrete_term(t::Term, dt::VecColumnTable, hints::Dict{Symbol}) =
    concrete_term(t, getproperty(dt, t.sym), get(hints, t.sym, nothing))
concrete_term(::Term, ::VecColumnTable, hint::AbstractTerm) = hint

termvars(ts::TermSet) = mapreduce(termvars, union, ts, init=Symbol[])
