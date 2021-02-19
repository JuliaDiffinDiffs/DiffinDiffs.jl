"""
    StatsStep{Alias, F<:Function}

Specify the function for moving a step in an [`AbstractStatsProcedure`](@ref).
An instance of `StatsStep` is callable.

# Parameters
- `Alias::Symbol`: alias of the type for pretty-printing.
- `F<:Function`: type of the function to be called by `StatsStep`.

# Methods
    (step::StatsStep{A,F})(ntargs::NamedTuple; verbose::Bool=false)

Call an instance of function of type `F` with arguments extracted from `ntargs`
via [`groupargs`](@ref) and [`combinedargs`](@ref).

A message with the name of the `StatsStep` is printed to `stdout`
if a keyword `verbose` takes the value `true`
or `ntargs` contains a key-value pair `verbose=true`.
The value from `ntargs` supersedes the keyword argument
in case both are specified.

## Returns
- `NamedTuple`: named intermediate results.
"""
struct StatsStep{Alias, F<:Function} end

_f(::StatsStep{A,F}) where {A,F} = F.instance

"""
    required(s::StatsStep)

Return a tuple of `Symbol`s representing the names of arguments
used to form [`groupargs`](@ref) that do not have defaults.
See also [`default`](@ref) and [`transformed`](@ref).
"""
required(::StatsStep) = ()

"""
    default(s::StatsStep)

Return a `NamedTuple` of arguments with keys showing the names
and values representing the defaults to be used to form [`groupargs`](@ref).
See also [`required`](@ref) and [`transformed`](@ref).
"""
default(::StatsStep) = NamedTuple()

"""
    transformed(s::StatsStep, ntargs::NamedTuple)

Return a tuple of arguments transformed from fields in `ntargs`
to be used to form [`groupargs`](@ref).
See also [`required`](@ref) and [`default`](@ref).
"""
transformed(::StatsStep, ::NamedTuple) = ()

_get(a::NTuple{N,Symbol}, @nospecialize(nt::NamedTuple)) where N =
    map(s->getfield(nt, s), a)
_get(a::NamedTuple{S1}, nt::NamedTuple{S2}) where {S1,S2} =
    map(s->getfield(ifelse(sym_in(s, S2), nt, a), s), S1)

"""
    groupargs(s::StatsStep, ntargs::NamedTuple)

Return a tuple of arguments that allow classifying multiple `ntargs`s into groups.
Equality (defined by `isequal`) of the returned tuples across `ntargs`s imply that
it is possible to exectute step `s` for only once
to obtain results for these `ntargs`s.

This function is important for [`proceed`](@ref) to work properly.
However, in most cases, there is no need to define new methods
for concrete [`StatsStep`](@ref)s.
Instead, one should define methods for
[`required`](@ref), [`default`](@ref) or [`transformed`](@ref).
See also [`combinedargs`](@ref).
"""
groupargs(s::StatsStep, @nospecialize(ntargs::NamedTuple)) =
    (_get(required(s), ntargs)..., _get(default(s), ntargs)...,
    transformed(s, ntargs)...)

"""
    combinedargs(s::StatsStep, allntargs::Any)

Return a tuple of arguments obtained by combining a collection of arguments
across multiple specifications.

The element type of `allntargs` can be assumed to be `NamedTuple`.
This function allows combining arguments that differ
across specifications in the same group classified based on [`groupargs`](@ref)
into objects that are accepted by the call of `s`.
See also [`proceed`](@ref).
"""
combinedargs(::StatsStep, ::Any) = ()

function (step::StatsStep{A,F})(@nospecialize(ntargs::NamedTuple);
        verbose::Bool=false) where {A,F}
    haskey(ntargs, :verbose) && (verbose = ntargs.verbose)
    verbose && printstyled("Running ", step, "\n", color=:green)
    ret = F.instance(groupargs(step, ntargs)..., combinedargs(step, (ntargs,))...)
    if ret isa Tuple{<:NamedTuple, Bool}
        return merge(ntargs, ret[1])
    else
        error("unexpected $(typeof(ret)) returned from $(F.name.mt.name) associated with StatsStep $A")
    end
end

(step::StatsStep)(; verbose::Bool=false) = step(NamedTuple(), verbose=verbose)

show(io::IO, ::StatsStep{A}) where A = print(io, A)

function show(io::IO, ::MIME"text/plain", s::StatsStep{A,F}) where {A,F}
    print(io, A, " (", typeof(s).name.name, " that calls ")
    fmod = F.name.mt.module
    fmod == Main || print(io, fmod, ".")
    print(io, F.name.mt.name, ")")
end

"""
    AbstractStatsProcedure{Alias, T<:NTuple{N,StatsStep} where N}

Supertype for all types specifying the procedure for statistical estimation or inference.

Fallback methods for indexing and iteration are defined for
all subtypes of `AbstractStatsProcedure`.

# Parameters
- `Alias::Symbol`: alias of the type for pretty-printing.
- `T<:NTuple{N,StatsStep}`: steps involved in the procedure.
"""
abstract type AbstractStatsProcedure{Alias, T<:NTuple{N,StatsStep} where N} end

result(::Type{<:AbstractStatsProcedure}, @nospecialize(ntargs::NamedTuple)) = ntargs

length(::AbstractStatsProcedure{A,T}) where {A,T} = length(T.parameters)
eltype(::Type{<:AbstractStatsProcedure}) = StatsStep
firstindex(::AbstractStatsProcedure{A,T}) where {A,T} = firstindex(T.parameters)
lastindex(::AbstractStatsProcedure{A,T}) where {A,T} = lastindex(T.parameters)

function getindex(::AbstractStatsProcedure{A,T}, i) where {A,T}
    fs = T.parameters[i]
    return fs isa Type && fs <: StatsStep ? fs.instance : [f.instance for f in fs]
end

getindex(::AbstractStatsProcedure{A,T}, i::Int) where {A,T} = T.parameters[i].instance

iterate(p::AbstractStatsProcedure, state=1) =
    state > length(p) ? nothing : (p[state], state+1)

show(io::IO, ::AbstractStatsProcedure{A}) where A = print(io, A)

function show(io::IO, ::MIME"text/plain", p::AbstractStatsProcedure{A,T}) where {A,T}
    nstep = length(p)
    print(io, A, " (", typeof(p).name.name, " with ", nstep, " step")
    if nstep > 0
        nstep > 1 ? print(io, "s):\n  ") : print(io, "):\n  ")
        for (i, step) in enumerate(p)
            print(io, step)
            i < nstep && print(io, " |> ")
        end
    else
        print(io, ")")
    end
end

"""
    SharedStatsStep

A [`StatsStep`](@ref) that is possibly shared by
multiple instances of procedures that are subtypes of [`AbstractStatsProcedure`](@ref).
See also [`PooledStatsProcedure`](@ref).

# Fields
- `step::StatsStep`: the `step` that may be shared.
- `ids::Vector{Int}`: indices of procedures that share `step`.
"""
struct SharedStatsStep
    step::StatsStep
    ids::Vector{Int}
    function SharedStatsStep(s::StatsStep, ids)
        ids = unique!(sort!([ids...]))
        return new(s, ids)
    end
end

_sharedby(s::SharedStatsStep) = s.ids
_f(s::SharedStatsStep) = _f(s.step)
groupargs(s::SharedStatsStep, @nospecialize(ntargs::NamedTuple)) = groupargs(s.step, ntargs)
combinedargs(s::SharedStatsStep, v::AbstractArray) = combinedargs(s.step, v)

==(x::SharedStatsStep, y::SharedStatsStep) =
    x.step == y.step && x.ids == y.ids

show(io::IO, s::SharedStatsStep) = print(io, s.step)

function show(io::IO, ::MIME"text/plain", s::SharedStatsStep)
    nps = length(s.ids)
    print(io, s.step, " (StatsStep shared by ", nps, " procedure")
    nps > 1 ? print(io, "s)") : print(io, ")")
end

const StatsProcedures = NTuple{N, AbstractStatsProcedure} where N

"""
    PooledStatsProcedure

A collection of procedures and shared steps.

An instance of `PooledStatsProcedure` is indexed and iterable among the shared steps
in a way that helps avoid repeating identical steps.
See also [`pool`](@ref).

# Fields
- `procs::StatsProcedures`: a tuple of instances of subtypes of [`AbstractStatsProcedure`](@ref).
- `steps::Vector{SharedStatsStep}`: sorted [`SharedStatsStep`](@ref)s.
"""
struct PooledStatsProcedure
    procs::StatsProcedures
    steps::Vector{SharedStatsStep}
end

function _sort(psteps::Vector{Vector{SharedStatsStep}})
    N = length(psteps)
    sorted = SharedStatsStep[]
    state = [length(s) for s in psteps]
    pending = state .> 0
    while any(pending)
        pid = (1:N)[pending]
        firsts = [psteps[i][end-state[i]+1] for i in pid]
        for (i, fstep) in enumerate(firsts)
            nshared = length(_sharedby(fstep))
            if nshared == 1
                push!(sorted, fstep)
                state[pid[i]] -= 1
            else
                shared = firsts .== Ref(fstep)
                if sum(shared) == nshared
                    push!(sorted, fstep)
                    state[pid[shared]] .-= 1
                    break
                end
            end
        end
        pending .= state .> 0
    end
    return sorted
end

"""
    pool(ps::AbstractStatsProcedure...)

Construct a [`PooledStatsProcedure`](@ref) by determining
how each [`StatsStep`](@ref) is shared among several procedures in `ps`.

It is unsafe to share the same [`StatsStep`](@ref) in different procedures
due to the relative position of this step to the other common steps
among these procedures.
The fallback method implemented for a collection of [`AbstractStatsProcedure`](@ref)
avoids sharing steps of which the relative positions
are not compatible between a pair of procedures.
"""
function pool(ps::AbstractStatsProcedure...)
    ps = (ps...,)
    nps = length(ps)
    steps = union(ps...)
    N = sum(length.(ps))
    if length(steps) < N
        shared = [Vector{SharedStatsStep}(undef, length(p)) for p in ps]
        step_pos = Dict{StatsStep,Dict{Int64,Int64}}()
        for (i, p) in enumerate(ps)
            for n in 1:length(p)
                if haskey(step_pos, p[n])
                    step_pos[p[n]][i] = n
                else
                    step_pos[p[n]] = Dict(i=>n)
                end
            end
        end
        for (step, pos) in step_pos
            if length(pos) == 1
                kv = collect(pos)[1]
                shared[kv[1]][kv[2]] = SharedStatsStep(step, kv[1])
            else
                shared_pid = collect(keys(pos))
                for c in combinations(shared_pid, 2)
                    csteps = intersect(ps[c[1]], ps[c[2]])
                    pos1 = sort(csteps, by=x->step_pos[x][c[1]])
                    pos2 = sort(csteps, by=x->step_pos[x][c[2]])
                    rank1 = findfirst(x->x==step, pos1)
                    rank2 = findfirst(x->x==step, pos2)
                    if rank1 != rank2
                        setdiff!(shared_pid, c)
                        shared[c[1]][pos[c[1]]] = SharedStatsStep(step, c[1])
                        shared[c[2]][pos[c[2]]] = SharedStatsStep(step, c[2])
                        length(shared_pid) <= 1 && break
                    end
                end
                if length(shared_pid) > 0
                    N = N - length(shared_pid) + 1
                    for p in shared_pid
                        shared[p][pos[p]] = SharedStatsStep(step, shared_pid)
                    end
                end
            end
        end
        shared = _sort(shared)
    else
        shared = [SharedStatsStep(s, i) for (i,p) in enumerate(ps) for s in p]
    end
    return PooledStatsProcedure(ps, shared)
end

length(p::PooledStatsProcedure) = length(p.steps)
eltype(::Type{PooledStatsProcedure}) = SharedStatsStep
firstindex(p::PooledStatsProcedure) = firstindex(p.steps)
lastindex(p::PooledStatsProcedure) = lastindex(p.steps)

getindex(p::PooledStatsProcedure, i) = getindex(p.steps, i)

iterate(p::PooledStatsProcedure, state=1) = iterate(p.steps, state)

==(x::PooledStatsProcedure, y::PooledStatsProcedure) =
    x.procs == y.procs && x.steps == y.steps

show(io::IO, p::PooledStatsProcedure) = print(io, typeof(p).name.name)

function show(io::IO, ::MIME"text/plain", p::PooledStatsProcedure)
    nstep = length(p.steps)
    print(io, typeof(p).name.name, " with ", nstep, " step")
    nstep > 1 ? print(io, "s ") : print(io, " ")
    nps = length(p.procs)
    print(io, "from ", nps, " procedure")
    nps > 1 ? print(io, "s:") : print(io, ":")
    for p in p.procs
        print(io, "\n  ", typeof(p).parameters[1])
    end
end

"""
    StatsSpec{Alias, T<:AbstractStatsProcedure}

Record the specification for a statistical procedure of type `T`.

An instance of `StatsSpec` is callable and
its fields provide all information necessary for conducting the procedure.
An optional name for the specification can be attached as parameter `Alias`.

# Fields
- `args::NamedTuple`: arguments for the [`StatsStep`](@ref)s in `T`.

# Methods
    (sp::StatsSpec{A,T})(; verbose::Bool=false, keep=nothing, keepall::Bool=false)

Execute the procedure of type `T` with the arguments specified in `args`.
By default, a dedicated result object for `T` is returned if it is available.
Otherwise, the last value returned by the last [`StatsStep`](@ref) is returned.

## Keywords
- `verbose::Bool=false`: print the name of each step when it is called.
- `keep=nothing`: names (of type `Symbol`) of additional objects to be returned.
- `keepall::Bool=false`: return all objects returned by each step.
"""
struct StatsSpec{Alias, T<:AbstractStatsProcedure}
    args::NamedTuple
    StatsSpec(name::Union{Symbol,String},
        T::Type{<:AbstractStatsProcedure}, @nospecialize(args::NamedTuple)) =
            new{Symbol(name),T}(args)
end

"""
    ==(x::StatsSpec{A1,T}, y::StatsSpec{A2,T})

Test whether two instances of [`StatsSpec`](@ref)
with the same parameter `T` also have the same field `args`.

See also [`≊`](@ref).
"""
==(x::StatsSpec{A1,T}, y::StatsSpec{A2,T}) where {A1,A2,T} = x.args == y.args

"""
    ≊(x::StatsSpec{A1,T}, y::StatsSpec{A2,T})

Test whether two instances of [`StatsSpec`](@ref)
with the same parameter `T` also have the field `args`
containing the same sets of key-value pairs
while ignoring the orders.
"""
≊(x::StatsSpec{A1,T}, y::StatsSpec{A2,T}) where {A1,A2,T} = x.args ≊ y.args

_procedure(::StatsSpec{A,T}) where {A,T} = T

function (sp::StatsSpec{A,T})(;
        verbose::Bool=false, keep=nothing, keepall::Bool=false) where {A,T}
    args = verbose ? merge(sp.args, (verbose=true,)) : sp.args
    ntall = result(T, foldl(|>, T(), init=args))
    if keepall
        return ntall
    else
        if keep === nothing
            if isempty(ntall)
                return nothing
            else
                return haskey(ntall, :result) ? ntall.result : ntall[end]
            end
        else
            # Cannot iterate Symbol
            if keep isa Symbol
                keep = (keep,)
            else
                eltype(keep)==Symbol ||
                    throw(ArgumentError("expect Symbol or collections of Symbols for the value of option `keep`"))
            end
            in(:result, keep) || (keep = (keep..., :result))
            names = ((n for n in keep if haskey(ntall, n))...,)
            return NamedTuple{names}(ntall)
        end
    end
end

show(io::IO, ::StatsSpec{A}) where {A} = print(io, A==Symbol("") ? "unnamed" : A)

_show_args(::IO, ::StatsSpec) = nothing

function show(io::IO, ::MIME"text/plain", sp::StatsSpec{A,T}) where {A,T}
    print(io, A==Symbol("") ? "unnamed" : A, " (", typeof(sp).name.name,
        " for ", T.parameters[1], ")")
    _show_args(io, sp)
end

"""
    proceed(sps::AbstractVector{<:StatsSpec}; kwargs...)

Carry out the procedures for the [`StatsSpec`](@ref)s in `sps`
while trying to avoid repeating identical steps for the [`StatsSpec`](@ref)s.
See also [`@specset`](@ref).

# Keywords
- `verbose::Bool=false`: print the name of each step when it is called.
- `keep=nothing`: names (of type `Symbol`) of additional objects to be returned.
- `keepall::Bool=false`: return all objects generated by procedures along with arguments from the [`StatsSpec`](@ref)s.

# Returns
- `Vector`: results for each specification in the same order of `sps`.

By default, either a dedicated result object for the corresponding procedure
or the last value returned by the last [`StatsStep`](@ref)
becomes an element in the returned `Vector` for each [`StatsSpec`](@ref).
When either `keep` or `keepall` is specified,
a `NamedTuple` with additional objects is formed for each [`StatsSpec`](@ref).
"""
function proceed(sps::AbstractVector{<:StatsSpec};
        verbose::Bool=false, keep=nothing, keepall::Bool=false)
    nsps = length(sps)
    nsps == 0 && throw(ArgumentError("expect a nonempty vector"))
    traces = Vector{NamedTuple}(undef, nsps)
    for i in 1:nsps
        traces[i] = sps[i].args
    end
    gids = groupfind(r->_procedure(r)(), sps)
    steps = pool((p for p in keys(gids))...)
    ntask_total = 0
    for step in steps
        ntask = 0
        verbose && printstyled("Running ", step, "...")
        taskids = vcat((gids[steps.procs[i]] for i in _sharedby(step))...)
        tasks = groupview(r->groupargs(step, r), view(traces, taskids))
        for (ins, subtb) in pairs(tasks)
            ret = _f(step)(ins..., combinedargs(step, subtb)...)
            if ret isa Tuple{<:NamedTuple, Bool}
                ret, share = ret
            else
                fname = typeof(_f(step)).name.mt.name
                stepname = typeof(step.step).parameters[1]
                error("unexpected type $(typeof(ret)) of object returned from $fname associated with StatsStep $stepname")
            end
            ntask += 1
            ntask_total += 1
            if share
                for i in eachindex(subtb)
                    subtb[i] = merge(subtb[i], ret)
                end
            else
                for i in eachindex(subtb)
                    subtb[i] = merge(subtb[i], deepcopy(ret))
                end
            end
        end
        nprocs = length(_sharedby(step))
        verbose && printstyled("Finished ", ntask, ntask > 1 ? " tasks" : " task", " for ",
            nprocs, nprocs > 1 ? " procedures\n" : " procedure\n")
    end
    nprocs = length(steps.procs)
    verbose && printstyled("All steps finished (", ntask_total,
        ntask_total > 1 ? " tasks" : " task", " for ", nprocs,
        nprocs > 1 ? " procedures)\n" : " procedure)\n", bold=true, color=:green)
    for i in 1:nsps
        traces[i] = result(_procedure(sps[i]), traces[i])
    end
    if keepall
        return traces
    elseif keep === nothing
        return [haskey(r, :result) ? r.result : isempty(r) ? nothing : r[end] for r in traces]
    else
        # Cannot iterate Symbol
        if keep isa Symbol
            keep = (keep,)
        else
            eltype(keep) == Symbol ||
                throw(ArgumentError("expect Symbol or collections of Symbols for the value of option `keep`"))
        end
        in(:result, keep) || (keep = (keep..., :result))
        for i in 1:nsps
            names = ((n for n in keep if haskey(traces[i], n))...,)
            traces[i] = NamedTuple{names}(traces[i])
        end
        return traces
    end
end

function _parse!(options::Expr, args)
    noproceed = false
    for arg in args
        # Assume a symbol means the kwarg takes value true
        if isa(arg, Symbol)
            if arg == :noproceed
                noproceed = true
            else
                key = Expr(:quote, arg)
                push!(options.args, Expr(:call, :(=>), key, true))
            end
        elseif isexpr(arg, :(=))
            if arg.args[1] == :noproceed
                noproceed = arg.args[2]
            else
                key = Expr(:quote, arg.args[1])
                push!(options.args, Expr(:call, :(=>), key, arg.args[2]))
            end
        else
            throw(ArgumentError("unexpected option $arg"))
        end
    end
    return noproceed
end

function _spec_walker1(x, parsers, formatters, ntargs_set)
    @capture(x, StatsSpec(formatter_(parser_(rawargs__))...)(;o__)) || return x
    push!(parsers, parser)
    push!(formatters, formatter)
    return :(push!($ntargs_set, $parser($(rawargs...))))
end

function _spec_walker2(x, parsers, formatters, ntargs_set)
    @capture(x, StatsSpec(formatter_(parser_(rawargs__))...)) || return x
    push!(parsers, parser)
    push!(formatters, formatter)
    return :(push!($ntargs_set, $parser($(rawargs...))))
end

"""
    @specset [option option=val ...] default_args... begin ... end
    @specset [option option=val ...] default_args... for v in (...) ... end
    @specset [option option=val ...] default_args... for v in (...), w in (...) ... end

Construct a vector of [`StatsSpec`](@ref) with shared default values for arguments
and then conduct the procedures by calling [`proceed`](@ref).

# Arguments
- `[option option=val ...]`: optional settings for @specset including keyword arguments for [`proceed`](@ref).
- `default_args...`: optional default values for arguments shared by all [`StatsSpec`](@ref)s.
- `code block`: a `begin/end` block or a `for` loop containing arguments for constructing [`StatsSpec`](@ref)s.

# Notes
`@specset` transforms `Expr`s that construct [`StatsSpec`](@ref)
to collect the sets of arguments from the code block
and infers how the arguments entered by users need to be processed
based on the names of functions called within [`StatsSpec`](@ref).
For end users, `Macro`s that generate `Expr`s for these function calls should be provided.

Optional default arguments are merged
with the arguments provided for each individual specification
and supersede any default value associated with each [`StatsStep`](@ref)
via [`default`](@ref).
These default arguments should be specified in the same pattern as
how arguments are specified for each specification inside the code block,
as `@specset` processes these arguments by calling
the same functions found in the code block.

Options for the behavior of `@specset` can be provided in a bracket `[...]`
as the first argument with each option separated by white space.
For options that take a Boolean value,
specifying the name of the option is enough for setting the value to be true.
    
The following options are available for altering the behavior of `@specset`:
- `noproceed::Bool=false`: do not call [`proceed`](@ref) and return the vector of [`StatsSpec`](@ref).
- `verbose::Bool=false`: print the name of each step when it is called.
- `keep=nothing`: names (of type `Symbol`) of additional objects to be returned.
- `keepall::Bool=false`: return all objects generated by procedures along with arguments from the [`StatsSpec`](@ref)s.
"""
macro specset(args...)
    nargs = length(args)
    nargs == 0 && throw(ArgumentError("no argument is found for @specset"))
    options = :(Dict{Symbol, Any}())
    noproceed = false
    default_args = nothing
    if nargs > 1
        if isexpr(args[1], :vect, :hcat, :vcat)
            noproceed = _parse!(options, args[1].args)
            nargs > 2 && (default_args = _args_kwargs(args[2:end-1]))
        else
            default_args = _args_kwargs(args[1:end-1])
        end
    end
    specs = macroexpand(__module__, args[end])
    isexpr(specs, :block, :for) ||
        throw(ArgumentError("last argument to @specset must be begin/end block or for loop"))

    parsers, formatters, ntargs_set = Symbol[], Symbol[], NamedTuple[]
    walked = postwalk(x->_spec_walker1(x, parsers, formatters, ntargs_set), specs)
    walked = postwalk(x->_spec_walker2(x, parsers, formatters, ntargs_set), walked)
    nparser = length(unique!(parsers))
    nparser == 1 ||
        throw(ArgumentError("found $nparser parsers from arguments while expecting one"))
    nformatter = length(unique!(formatters))
    nformatter == 1 ||
        throw(ArgumentError("found $nformatter formatters from arguments while expecting one"))
    
    parser, formatter = parsers[1], formatters[1]
    if default_args === nothing
        defaults = :(NamedTuple())
    else
        defaults = esc(:($parser($(default_args[1]...); $(default_args[2]...))))
    end

    blk = quote
        $(esc(walked))
        local nspec = length($ntargs_set)
        local sps = Vector{StatsSpec}(undef, nspec)
        for i in 1:nspec
            sps[i] = StatsSpec($(esc(formatter))(merge($defaults, $ntargs_set[i]))...)
        end
    end

    if noproceed
        return quote
            $blk
            sps
        end
    else
        return quote
            $blk
            proceed(sps; $options...)
        end
    end
end
