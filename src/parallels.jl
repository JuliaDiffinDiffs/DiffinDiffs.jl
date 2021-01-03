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

show(io::IO, C::Unconditional) =
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

Supertype for all types specifying the the strength of parallel.
"""
abstract type ParallelStrength end

kwarg(v::ParallelStrength) = :s => v

"""
    Exact <: ParallelStrength

Assume some notion of parallel holds exactly.
"""
struct Exact <: ParallelStrength end

show(io::IO, S::Exact) =
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
    AbstractParallel{C<:ParallelCondition,S<:ParallelStrength}

Supertype for all parallel types.
"""
abstract type AbstractParallel{C<:ParallelCondition,S<:ParallelStrength} end

@fieldequal AbstractParallel

"""
    TrendParallel{C,S} <: AbstractParallel{C,S}

Supertype for all parallel types that
assume a parallel trends assumption holds over all the relevant time periods.
"""
abstract type TrendParallel{C,S} <: AbstractParallel{C,S} end

"""
    NeverTreatedParallel{T<:Integer,C,S} <: TrendParallel{C,S}

Assume a parallel trends assumption holds between any group
that received the treatment during the sample periods
and a group that did not receive any treatment in any sample period.
See also [`nevertreated`](@ref).

# Fields
- `e::Vector{T}`: group indices for units that did not receive any treatment.
- `c::C`: a [`ParallelCondition`](@ref).
- `s::S`: a [`ParallelStrength`](@ref).
"""
struct NeverTreatedParallel{T<:Integer,C,S} <: TrendParallel{C,S}
    e::Vector{T}
    c::C
    s::S
    NeverTreatedParallel(e::Vector{T}, c::C, s::S) where
        {T<:Integer,C<:ParallelCondition,S<:ParallelStrength} =
            new{T,C,S}(unique!(sort!(e)), c, s)
end

function show(io::IO, pr::NeverTreatedParallel)
    if get(io, :compact, false)
        print(io, "NeverTreated{", pr.c, ",", pr.s, "}(", pr.e,")")
    else
        println(io, pr.s, " trends with any never-treated group:")
        println(io, "  Never-treated groups: ", pr.e)
        pr.c isa Unconditional ? nothing : println(io, "  ", pr.c)
    end
end

"""
    nevertreated(itr, c::ParallelCondition, s::ParallelStrength)
    nevertreated(itr; c=Unconditional(), s=Exact())

Construct a [`NeverTreatedParallel`](@ref) with field `e`
set by unique elements in `itr`.
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
NeverTreatedParallel{Int64,Unconditional,Exact}

julia> nevertreated([-1, 0])
Parallel trends with any never-treated group:
  Never-treated groups: [-1, 0]

julia> nevertreated([-1, 0]) == nevertreated(-1:0) == nevertreated(Set([-1, 0]))
true
```
"""
nevertreated(itr, c::ParallelCondition, s::ParallelStrength) =
    NeverTreatedParallel([itr...], c, s)
nevertreated(itr; c::ParallelCondition=Unconditional(), s::ParallelStrength=Exact()) =
    NeverTreatedParallel([itr...], c, s)

"""
    nevertreated(ts::AbstractTerm...)

A wrapper method of `nevertreated` for working with `@formula`.
"""
@unpack nevertreated

"""
    NotYetTreatedParallel{T<:Integer,C,S} <: TrendParallel{C,S}

Assume a parallel trends assumption holds between any group
that received the treatment relatively early
and any group that received the treatment relatively late (or never receved).
See also [`notyettreated`](@ref).

# Fields
- `e::Vector{T}`: group indices for units that received the treatment relatively late.
- `emin::Union{Vector{T},Nothing}`: user-specified period(s) when units in a group in `e` started to receive treatment.
- `c::C`: a [`ParallelCondition`](@ref).
- `s::S`: a [`ParallelStrength`](@ref).

!!! note
    `emin` could be different from `minimum(e)` if
    - never-treated groups are included and use indices with smaller values;
    - the sample has a rotating panel structure with periods overlapping with some others.
"""
struct NotYetTreatedParallel{T<:Integer,C,S} <: TrendParallel{C,S}
    e::Vector{T}
    emin::Union{Vector{T},Nothing}
    c::C
    s::S
    NotYetTreatedParallel(e::Vector{T}, emin::Union{Vector{T},Nothing}, c::C, s::S) where
        {T<:Integer,C<:ParallelCondition,S<:ParallelStrength} =
            new{T,C,S}(unique!(sort!(e)),
                emin isa Nothing ? emin : unique!(sort!(emin)), c, s)
end

function show(io::IO, pr::NotYetTreatedParallel)
    if get(io, :compact, false)
        print(io, "NotYetTreated{", pr.c, ",", pr.s, "}(", pr.e, ", ")
        print(io, pr.emin isa Nothing ? "NA" : pr.emin, ")")
    else
        println(io, pr.s, " trends with any not-yet-treated group:")
        println(io, "  Not-yet-treated groups: ", pr.e)
        println(io, "  Treated since: ", pr.emin isa Nothing ? "not specified" : pr.emin)
        pr.c isa Unconditional ? nothing : println(io, "  ", pr.c)
    end
end

"""
    notyettreated(itr, emin, c::ParallelCondition, s::ParallelStrength)
    notyettreated(itr, emin=nothing; c=Unconditional(), s=Exact())

Construct a [`NotYetTreatedParallel`](@ref) with
elements in `itr` for field `e` and optional `emin`
if `emin` is not `minimum(e)`.
By default, `c` is set as [`Unconditional()`](@ref)
and `s` is set as [`Exact()`](@ref).
When working with `@formula`,
a wrapper method of `notyettreated` calls this method.

# Examples
```jldoctest; setup = :(using DiffinDiffsBase) 
julia> notyettreated(5)
Parallel trends with any not-yet-treated group:
  Not-yet-treated groups: [5]
  Treated since: not specified

julia> typeof(notyettreated(5))
NotYetTreatedParallel{Int64,Unconditional,Exact}

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
notyettreated(itr, emin, c::ParallelCondition, s::ParallelStrength) =
    NotYetTreatedParallel([itr...], emin isa Nothing ? emin : [emin...], c, s)
notyettreated(itr, emin=nothing;
    c::ParallelCondition=Unconditional(), s::ParallelStrength=Exact()) =
        NotYetTreatedParallel([itr...], emin isa Nothing ? emin : [emin...], c, s)

"""
    notyettreated(ts::AbstractTerm...)

A wrapper method of `notyettreated` for working with `@formula`.
"""
@unpack notyettreated
