"""
    ParallelCondition

Supertype for all types imposing conditions of parallel.
"""
abstract type ParallelCondition end

@fieldequal ParallelCondition

kwarg(v::ParallelCondition) = :c => v

"""
    Unconditional <: ParallelCondition

Assume some notion of parallel holds without conditions.
"""
struct Unconditional <: ParallelCondition end

show(io::IO, ::Unconditional) =
    get(io, :compact, false) ? print(io, "U") : print(io, "Unconditional")

"""
    unconditional()

Alias for [`Unconditional()`](@ref).
"""
unconditional() = Unconditional()

"""
    CovariateConditional <: ParallelCondition

Supertype for all types assuming some notion of parallel holds
after conditioning on covariates.
"""
abstract type CovariateConditional <: ParallelCondition end

"""
    ParallelStrength

Supertype for all types specifying the strength of parallel.
"""
abstract type ParallelStrength end

kwarg(v::ParallelStrength) = :s => v

"""
    Exact <: ParallelStrength

Assume some notion of parallel holds exactly.
"""
struct Exact <: ParallelStrength end

show(io::IO, ::Exact) =
    get(io, :compact, false) ? print(io, "P") : print(io, "Parallel")

"""
    exact()

Alias for [`Exact()`](@ref).
"""
exact() = Exact()

"""
    Approximate <: ParallelStrength

Supertype for all types assuming some notion of parallel holds approximately.
"""
abstract type Approximate <: ParallelStrength end

"""
    AbstractParallel{C<:ParallelCondition, S<:ParallelStrength}

Supertype for all parallel types.
"""
abstract type AbstractParallel{C<:ParallelCondition, S<:ParallelStrength} end

@fieldequal AbstractParallel

"""
    TrendParallel{C,S} <: AbstractParallel{C,S}

Supertype for all parallel types that
assume a parallel trends assumption holds over all the relevant time periods.
"""
abstract type TrendParallel{C,S} <: AbstractParallel{C,S} end

"""
    NeverTreatedParallel{C,S} <: TrendParallel{C,S}

Assume a parallel trends assumption holds between any group
that received the treatment during the sample periods
and a group that did not receive any treatment in any sample period.
See also [`nevertreated`](@ref).

# Fields
- `e::Vector{Int}`: group indices for units that did not receive any treatment.
- `c::C`: an instance of [`ParallelCondition`](@ref).
- `s::S`: an instance of [`ParallelStrength`](@ref).
"""
struct NeverTreatedParallel{C,S} <: TrendParallel{C,S}
    e::Vector{Int}
    c::C
    s::S
    function NeverTreatedParallel(e, c::ParallelCondition, s::ParallelStrength)
        e = unique!(sort!([e...]))
        isempty(e) && error("field `e` cannot be empty") 
        return new{typeof(c),typeof(s)}(e, c, s)
    end
end

istreated(pr::NeverTreatedParallel, x) = !(x in pr.e)

show(io::IO, pr::NeverTreatedParallel) =
    print(IOContext(io, :compact=>true), "NeverTreated{", pr.c, ",", pr.s, "}(", pr.e, ")")

function show(io::IO, ::MIME"text/plain", pr::NeverTreatedParallel)
    println(io, pr.s, " trends with any never-treated group:")
    print(io, "  Never-treated groups: ", pr.e)
    pr.c isa Unconditional || print(io, "\n  ", pr.c)
end

"""
    nevertreated(e, c::ParallelCondition, s::ParallelStrength)
    nevertreated(e; c=Unconditional(), s=Exact())

Construct a [`NeverTreatedParallel`](@ref) with fields set by the arguments.
By default, `c` is set as [`Unconditional()`](@ref)
and `s` is set as [`Exact()`](@ref).
When working with `@formula`,
a wrapper method of `nevertreated` calls this method.

# Examples
```jldoctest; setup = :(using DiffinDiffsBase)
julia> nevertreated(-1)
Parallel trends with any never-treated group:
  Never-treated groups: [-1]

julia> typeof(nevertreated(-1))
NeverTreatedParallel{Unconditional,Exact,Tuple{Int64}}

julia> nevertreated([-1, 0])
Parallel trends with any never-treated group:
  Never-treated groups: [-1, 0]

julia> nevertreated([-1, 0]) == nevertreated(-1:0) == nevertreated(Set([-1, 0]))
true
```
"""
nevertreated(e, c::ParallelCondition, s::ParallelStrength) =
    NeverTreatedParallel(e, c, s)
nevertreated(e; c::ParallelCondition=Unconditional(), s::ParallelStrength=Exact()) =
    NeverTreatedParallel(e, c, s)

"""
    nevertreated(ts::AbstractTerm...)

A wrapper method of `nevertreated` for working with `@formula`.
"""
@unpack nevertreated

"""
    NotYetTreatedParallel{C,S} <: TrendParallel{C,S}

Assume a parallel trends assumption holds between any group
that received the treatment relatively early
and any group that received the treatment relatively late (or never receved).
See also [`notyettreated`](@ref).

# Fields
- `e::Vector{Int}`: group indices for units that received the treatment relatively late.
- `ecut::Vector{Int}`: user-specified period(s) when units in a group in `e` started to receive treatment.
- `c::C`: an instance of [`ParallelCondition`](@ref).
- `s::S`: an instance of [`ParallelStrength`](@ref).

!!! note
    `ecut` could be different from `minimum(e)` if
    - never-treated groups are included and use indices with smaller values;
    - the sample has a rotating panel structure with periods overlapping with some others.
"""
struct NotYetTreatedParallel{C,S} <: TrendParallel{C,S}
    e::Vector{Int}
    ecut::Vector{Int}
    c::C
    s::S
    function NotYetTreatedParallel(e, ecut, c::ParallelCondition, s::ParallelStrength)
        e = unique!(sort!([e...]))
        isempty(e) && error("field `e` cannot be empty")
        ecut = unique!(sort!([ecut...]))
        isempty(ecut) && error("field `ecut` cannot be empty")
        return new{typeof(c),typeof(s)}(e, ecut, c, s)
    end
end

istreated(pr::NotYetTreatedParallel, x) = !(x in pr.e)

show(io::IO, pr::NotYetTreatedParallel) =
    print(IOContext(io, :compact=>true), "NotYetTreated{", pr.c, ",", pr.s, "}(", pr.e, ")")

function show(io::IO, ::MIME"text/plain", pr::NotYetTreatedParallel)
    println(io, pr.s, " trends with any not-yet-treated group:")
    println(io, "  Not-yet-treated groups: ", pr.e)
    print(io, "  Treated since: ", pr.ecut)
    pr.c isa Unconditional || print(io, "\n  ", pr.c)
end

"""
    notyettreated(e, ecut, c::ParallelCondition, s::ParallelStrength)
    notyettreated(e, ecut=minimum(e); c=Unconditional(), s=Exact())

Construct a [`NotYetTreatedParallel`](@ref) with
fields set by the arguments.
By default, `c` is set as [`Unconditional()`](@ref)
and `s` is set as [`Exact()`](@ref).
When working with `@formula`,
a wrapper method of `notyettreated` calls this method.

# Examples
```jldoctest; setup = :(using DiffinDiffsBase) 
julia> notyettreated(5)
Parallel trends with any not-yet-treated group:
  Not-yet-treated groups: [5]
  Treated since: [5]

julia> typeof(notyettreated(5))
NotYetTreatedParallel{Unconditional,Exact,Tuple{Int64},Tuple{Int64}}

julia> notyettreated([-1, 5, 6], 5)
Parallel trends with any not-yet-treated group:
  Not-yet-treated groups: [-1, 5, 6]
  Treated since: [5]

julia> notyettreated([4, 5, 6], [4, 5, 6])
Parallel trends with any not-yet-treated group:
  Not-yet-treated groups: [4, 5, 6]
  Treated since: [4, 5, 6]
```
"""
notyettreated(e, ecut, c::ParallelCondition, s::ParallelStrength) =
    NotYetTreatedParallel(e, ecut, c, s)
notyettreated(e, ecut=minimum(e);
    c::ParallelCondition=Unconditional(), s::ParallelStrength=Exact()) =
        NotYetTreatedParallel(e, ecut, c, s)

"""
    notyettreated(ts::AbstractTerm...)

A wrapper method of `notyettreated` for working with `@formula`.
"""
@unpack notyettreated

termvars(c::ParallelCondition) =
    error("StatsModels.termvars is not defined for $(typeof(c))")
termvars(::Unconditional) = Symbol[]
termvars(s::ParallelStrength) =
    error("StatsModels.termvars is not defined for $(typeof(s))")
termvars(::Exact) = Symbol[]
termvars(pr::AbstractParallel) =
    error("StatsModels.termvars is not defined for $(typeof(pr))")
termvars(pr::NeverTreatedParallel) = union(termvars(pr.c), termvars(pr.s))
termvars(pr::NotYetTreatedParallel) = union(termvars(pr.c), termvars(pr.s))
