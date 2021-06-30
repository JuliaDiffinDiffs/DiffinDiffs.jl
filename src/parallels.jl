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

Alias of [`Unconditional()`](@ref).
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

Alias of [`Exact()`](@ref).
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
    UnspecifiedParallel{C,S} <: AbstractParallel{C,S}

A parallel trends assumption (PTA) without explicitly specified
relations across treatment groups.
See also [`unspecifiedpr`](@ref).

With this parallel type,
operations for complying with a PTA are suppressed.
This is useful, for example,
when the user-provided regressors and sample restrictions
need to be accepted without any PTA-specific alteration.

# Fields
- `c::C`: an instance of [`ParallelCondition`](@ref).
- `s::S`: an instance of [`ParallelStrength`](@ref).
"""
struct UnspecifiedParallel{C,S} <: AbstractParallel{C,S}
    c::C
    s::S
    function UnspecifiedParallel(c::ParallelCondition=Unconditional(),
            s::ParallelStrength=Exact())
        return new{typeof(c),typeof(s)}(c, s)
    end
end

"""
    unspecifiedpr(c::ParallelCondition=Unconditional(), s::ParallelStrength=Exact())

Construct an [`UnspecifiedParallel`](@ref) with fields set by the arguments.
This is an alias of the inner constructor of [`UnspecifiedParallel`](@ref).
"""
unspecifiedpr(c::ParallelCondition=Unconditional(), s::ParallelStrength=Exact()) =
    UnspecifiedParallel(c, s)

show(io::IO, pr::UnspecifiedParallel) =
    print(IOContext(io, :compact=>true), "Unspecified{", pr.c, ",", pr.s, "}")

function show(io::IO, ::MIME"text/plain", pr::UnspecifiedParallel)
    print(io, pr.s, " among unspecified treatment groups")
    pr.c isa Unconditional || print(io, ":\n  ", pr.c)
end

"""
    TrendParallel{C,S} <: AbstractParallel{C,S}

Supertype for all parallel types that
assume a parallel trends assumption holds over all the relevant time periods.
"""
abstract type TrendParallel{C,S} <: AbstractParallel{C,S} end

"""
    TrendOrUnspecifiedPR{C,S}

Union type of [`TrendParallel{C,S}`](@ref) and [`UnspecifiedParallel{C,S}`](@ref).
"""
const TrendOrUnspecifiedPR{C,S} = Union{TrendParallel{C,S}, UnspecifiedParallel{C,S}}

"""
    istreated(pr::TrendParallel, x)

Test whether `x` represents the treatment time
for a group of units that are not treated.
See also [`istreated!`](@ref).
"""
function istreated end

"""
    istreated!(out::AbstractVector{Bool}, pr::TrendParallel, x::AbstractArray)

For each element in `x`,
test whether it represents the treatment time
for a group of units that are not treated and save the result in `out`.
See also [`istreated`](@ref).
"""
function istreated! end

"""
    NeverTreatedParallel{C,S} <: TrendParallel{C,S}

Assume a parallel trends assumption holds between any group
that received the treatment during the sample periods
and a group that did not receive any treatment in any sample period.
See also [`nevertreated`](@ref).

# Fields
- `e::Tuple{Vararg{ValidTimeType}}`: group indices for units that did not receive any treatment.
- `c::C`: an instance of [`ParallelCondition`](@ref).
- `s::S`: an instance of [`ParallelStrength`](@ref).
"""
struct NeverTreatedParallel{C,S} <: TrendParallel{C,S}
    e::Tuple{Vararg{ValidTimeType}}
    c::C
    s::S
    function NeverTreatedParallel(e, c::ParallelCondition, s::ParallelStrength)
        e = applicable(iterate, e) ? (unique!(sort!([e...]))...,) : (e,)
        isempty(e) && error("field `e` cannot be empty")
        return new{typeof(c),typeof(s)}(e, c, s)
    end
end

istreated(pr::NeverTreatedParallel, x) = !(x in pr.e)

function istreated!(out::AbstractVector{Bool}, pr::NeverTreatedParallel,
        x::AbstractArray{<:Union{ValidTimeType, Missing}})
    e = Set(pr.e)
    out .= .!(x .∈ Ref(e))
end

function istreated!(out::AbstractVector{Bool}, pr::NeverTreatedParallel,
        x::ScaledArray{<:Union{ValidTimeType, Missing}})
    refs = refarray(x)
    invpool = invrefpool(x)
    e = Set(invpool[c] for c in pr.e if haskey(invpool, c))
    out .= .!(refs .∈ Ref(e))
end

show(io::IO, pr::NeverTreatedParallel) =
    print(IOContext(io, :compact=>true), "NeverTreated{", pr.c, ",", pr.s, "}",
        length(pr.e)==1 ? string("(", pr.e[1], ")") : pr.e)

function show(io::IO, ::MIME"text/plain", pr::NeverTreatedParallel)
    println(io, pr.s, " trends with any never-treated group:")
    print(io, "  Never-treated groups: ", join(string.(pr.e), ", "))
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
  Never-treated groups: -1

julia> typeof(nevertreated(-1))
NeverTreatedParallel{Unconditional,Exact}

julia> nevertreated([-1, 0])
Parallel trends with any never-treated group:
  Never-treated groups: -1, 0

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
- `e::Tuple{Vararg{ValidTimeType}}`: group indices for units that received the treatment relatively late.
- `ecut::Tuple{Vararg{ValidTimeType}}`: user-specified period(s) when units in a group in `e` started to receive treatment.
- `c::C`: an instance of [`ParallelCondition`](@ref).
- `s::S`: an instance of [`ParallelStrength`](@ref).

!!! note
    `ecut` could be different from `minimum(e)` if
    - never-treated groups are included and use indices with smaller values;
    - the sample has a rotating panel structure with periods overlapping with some others.
"""
struct NotYetTreatedParallel{C,S} <: TrendParallel{C,S}
    e::Tuple{Vararg{ValidTimeType}}
    ecut::Tuple{Vararg{ValidTimeType}}
    c::C
    s::S
    function NotYetTreatedParallel(e, ecut, c::ParallelCondition, s::ParallelStrength)
        e = applicable(iterate, e) ? (unique!(sort!([e...]))...,) : (e,)
        isempty(e) && throw(ArgumentError("field e cannot be empty"))
        ecut = applicable(iterate, ecut) ? (unique!(sort!([ecut...]))...,) : (ecut,)
        isempty(ecut) && throw(ArgumentError("field ecut cannot be empty"))
        eltype(e) == eltype(ecut) ||
            throw(ArgumentError("e and ecut must have the same element type"))
        return new{typeof(c), typeof(s)}(e, ecut, c, s)
    end
end

istreated(pr::NotYetTreatedParallel, x) = !(x in pr.e)

function istreated!(out::AbstractVector{Bool}, pr::NotYetTreatedParallel,
        x::AbstractArray{<:Union{ValidTimeType, Missing}})
    e = Set(pr.e)
    out .= .!(x .∈ Ref(e))
end

function istreated!(out::AbstractVector{Bool}, pr::NotYetTreatedParallel,
        x::ScaledArray{<:Union{ValidTimeType, Missing}})
    refs = refarray(x)
    invpool = invrefpool(x)
    e = Set(invpool[c] for c in pr.e if haskey(invpool, c))
    out .= .!(refs .∈ Ref(e))
end

show(io::IO, pr::NotYetTreatedParallel) =
    print(IOContext(io, :compact=>true), "NotYetTreated{", pr.c, ",", pr.s, "}",
        length(pr.e)==1 ? string("(", pr.e[1], ")") : pr.e)

function show(io::IO, ::MIME"text/plain", pr::NotYetTreatedParallel)
    println(io, pr.s, " trends with any not-yet-treated group:")
    println(io, "  Not-yet-treated groups: ", join(string.(pr.e), ", "))
    print(io, "  Treated since: ", join(string.(pr.ecut), ", "))
    pr.c isa Unconditional || print(io, "\n  ", pr.c)
end

"""
    notyettreated(e, ecut, c::ParallelCondition, s::ParallelStrength)
    notyettreated(e, ecut=e; c=Unconditional(), s=Exact())

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
  Not-yet-treated groups: 5
  Treated since: 5

julia> typeof(notyettreated(5))
NotYetTreatedParallel{Unconditional,Exact}

julia> notyettreated([-1, 5, 6], 5)
Parallel trends with any not-yet-treated group:
  Not-yet-treated groups: -1, 5, 6
  Treated since: 5

julia> notyettreated([4, 5, 6], [4, 5, 6])
Parallel trends with any not-yet-treated group:
  Not-yet-treated groups: 4, 5, 6
  Treated since: 4, 5, 6
```
"""
notyettreated(e, ecut, c::ParallelCondition, s::ParallelStrength) =
    NotYetTreatedParallel(e, ecut, c, s)
notyettreated(e, ecut=e; c::ParallelCondition=Unconditional(), s::ParallelStrength=Exact()) =
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
termvars(pr::UnspecifiedParallel) = union(termvars(pr.c), termvars(pr.s))
termvars(pr::NeverTreatedParallel) = union(termvars(pr.c), termvars(pr.s))
termvars(pr::NotYetTreatedParallel) = union(termvars(pr.c), termvars(pr.s))
