"""
    StatsStep{Alias,F<:Function,SpecNames,TraceNames}

Specify the function and arguments for moving a step
in an [`AbstractStatsProcedure`](@ref).
An instance of `StatsStep` is callable.

# Parameters
- `Alias::Symbol`: alias of the type for pretty-printing.
- `F<:Function`: type of the function to be called by `StatsStep`.
- `SpecNames::NTuple{N,Symbol}`: keys for arguments from [`StatsSpec`](@ref).
- `TraceNames::NTuple{N,Symbol}`: keys for arguments from objects returned by a previous `StatsStep`.

# Methods
    (step::StatsStep{A,F,S,T})(ntargs::NamedTuple; verbose::Bool=false) where {A,F,S,T}

Call an instance of function of type `F` with arguments from `ntargs`
formed by accessing the keys in `S` and `T` sequentially.

If a keyword argument `verbose` takes `true`
or `ntargs` contains a key-value pair `verbose=true`,
a message with the name of the `StatsStep` is printed to `stdout`.

## Returns
- `NamedTuple`: named intermidiate results.
"""
struct StatsStep{Alias,F<:Function,SpecNames,TraceNames} end

_f(::StatsStep{A,F}) where {A,F} = F.instance
_specnames(::StatsStep{A,F,S}) where {A,F,S} = S
_tracenames(::StatsStep{A,F,S,T}) where {A,F,S,T} = T

function (step::StatsStep{A,F,S,T})(ntargs::NamedTuple; verbose::Bool=false) where {A,F,S,T}
    verbose || (haskey(ntargs, :verbose) && ntargs.verbose) &&
        println("  Running ", step)
    args = NamedTuple{(S...,T...)}(ntargs)
    ret = F.instance(args...)
    if ret isa NamedTuple
        return merge(ntargs, ret)
    elseif ret === nothing
        return ntargs
    else
        error("unexpected returned object from function associated with StatsStep")
    end
end

show(io::IO, ::StatsStep{A}) where A = print(io, A)

function show(io::IO, ::MIME"text/plain", s::StatsStep{A,F,S,T}) where {A,F,S,T}
    print(io, A, " (", typeof(s).name.name, " that calls ")
    fmod = F.name.mt.module
    fmod == Main ? print(io, F.name.mt.name) : print(io, fmod, ".", F.name.mt.name)
    println(io, "):")
    println(io, "  arguments from StatsSpec: ", S)
    print(io, "  arguments from trace: ")
    T==() ? print(io, "()") : print(io, T)
end

"""
    AbstractStatsProcedure{Alias,T<:NTuple{N,StatsStep} where N}

Supertype for all types specifying the procedure for statistical estimation or inference.

Fallback methods for indexing and iteration are defined for
all subtypes of `AbstractStatsProcedure`.

# Parameters
- `Alias::Symbol`: alias of the type for pretty-printing.
- `T<:NTuple{N,StatsStep}`: steps involved in the procedure.
"""
abstract type AbstractStatsProcedure{A,T<:NTuple{N,StatsStep} where N} end

length(::AbstractStatsProcedure{A,T}) where {A,T} = length(T.parameters)
eltype(::Type{<:AbstractStatsProcedure}) = StatsStep
firstindex(::AbstractStatsProcedure{A,T}) where {A,T} = firstindex(T.parameters)
lastindex(::AbstractStatsProcedure{A,T}) where {A,T} = lastindex(T.parameters)

function getindex(p::AbstractStatsProcedure{A,T}, i) where {A,T}
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
    SharedStatsStep{T<:StatsStep,I}

A [`StatsStep`](@ref) that is possibly shared by
multiple instances of procedures that are subtypes of [`AbstractStatsProcedure`](@ref).
See also [`PooledStatsProcedure`](@ref).

# Parameters
- `T<:StatsStep`: type of the only field `step`.
- `I`: indices of the procedures that share this step.
"""
struct SharedStatsStep{T<:StatsStep,I}
    step::T
    function SharedStatsStep(s::StatsStep, pid)
        pid = (unique!(sort!([pid...]))...,)
        return new{typeof(s), pid}(s)
    end
end

_sharedby(::SharedStatsStep{T,I}) where {T,I} = I
_f(s::SharedStatsStep) = _f(s.step)
_specnames(s::SharedStatsStep) = _specnames(s.step)
_tracenames(s::SharedStatsStep) = _tracenames(s.step)

show(io::IO, s::SharedStatsStep) = print(io, s.step)

function show(io::IO, ::MIME"text/plain", s::SharedStatsStep{T,I}) where {T,I}
    nps = length(I)
    print(io, s.step, " (StatsStep shared by ", nps, " procedure")
    nps > 1 ? print(io, "s)") : print(io, ")")
end

const SharedStatsSteps = NTuple{N, SharedStatsStep} where N
const StatsProcedures = NTuple{N, AbstractStatsProcedure} where N

"""
    PooledStatsProcedure{P<:StatsProcedures,S<:SharedStatsSteps}

A collection of procedures and shared steps.

An instance of `PooledStatsProcedure` is indexed and iterable among the shared steps
in a way that helps avoid repeating identical steps.
See also [`pool`](@ref).

# Fields
- `procs::P`: a tuple of instances of subtypes of [`AbstractStatsProcedure`](@ref).
- `steps::S`: a tuple of [`SharedStatsStep`](@ref) for the procedures in `procs`.
"""
struct PooledStatsProcedure{P<:StatsProcedures,S<:SharedStatsSteps}
    procs::P
    steps::S
end

function _sort(psteps::NTuple{N, Vector{SharedStatsStep}}) where N
    sorted = SharedStatsStep[]
    state = [length(s) for s in psteps]
    pending = BitArray(state.>0)
    while any(pending)
        pid = (1:N)[pending]
        firsts = [psteps[i][end-state[i]+1] for i in pid]
        for i in 1:length(firsts)
            nshared = length(_sharedby(firsts[i]))
            if nshared == 1
                push!(sorted, firsts[i])
                state[pid[i]] -= 1
            else
                shared = BitArray(s==firsts[i] for s in firsts)
                if sum(shared) == nshared
                    push!(sorted, firsts[i])
                    state[pid[shared]] .-= 1
                    break
                end
            end
        end
        pending = BitArray(state.>0)
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
        shared = ((Vector{SharedStatsStep}(undef, length(p)) for p in ps)...,)
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
        shared = (_sort(shared)...,)
    else
        shared = ((SharedStatsStep(s, i) for (i,p) in enumerate(ps) for s in p)...,)
    end
    return PooledStatsProcedure{typeof(ps), typeof(shared)}(ps, shared)
end

length(::PooledStatsProcedure{P,S}) where {P,S} = length(S.parameters)
eltype(::Type{<:PooledStatsProcedure}) = SharedStatsStep
firstindex(::PooledStatsProcedure{P,S}) where {P,S} = firstindex(S.parameters)
lastindex(::PooledStatsProcedure{P,S}) where {P,S} = lastindex(S.parameters)

getindex(ps::PooledStatsProcedure, i) = getindex(ps.steps, i)

iterate(ps::PooledStatsProcedure, state=1) = iterate(ps.steps, state)

show(io::IO, ps::PooledStatsProcedure) = print(io, typeof(ps).name.name)

function show(io::IO, ::MIME"text/plain", ps::PooledStatsProcedure{P,S}) where {P,S}
    nstep = length(S.parameters)
    print(io, typeof(ps).name.name, " with ", nstep, " step")
    nstep > 1 ? print(io, "s ") : print(io, " ")
    nps = length(P.parameters)
    print(io, "from ", nps, " procedure")
    nps > 1 ? print(io, "s:") : print(io, ":")
    for p in P.parameters
        print(io, "\n  ", p.parameters[1])
    end
end

"""
    StatsSpec{Alias,T<:AbstractStatsProcedure}

Record the specification for a statistical procedure of type `T`.

An instance of `StatsSpec` is callable and
its fields provide all information necessary for conducting the procedure.
An optional name for the specification can be attached as parameter `Alias`.

# Fields
- `args::NamedTuple`: arguments for the [`StatsStep`](@ref)s in `T`.

# Methods
    (sp::StatsSpec{A,T})(; verbose::Bool=false, keep=nothing, keepall::Bool=false)

Execute the procedure of type `T` with the arguments specified in `args`.
By default, only an object with a key `result` assigned by a [`StatsStep`](@ref)
or the last value returned by the last [`StatsStep`](@ref) is returned.

## Keywords
- `verbose::Bool=false`: print the name of each step when it is called.
- `keep=nothing`: names (of type `Symbol`) of additional objects to be returned.
- `keepall::Bool=false`: return all objects returned by each step.
"""
struct StatsSpec{Alias,T<:AbstractStatsProcedure}
    args::NamedTuple
    StatsSpec(name::Union{Symbol,String},
        T::Type{<:AbstractStatsProcedure}, args::NamedTuple) =
            new{Symbol(name),T}(args)
end

"""
    ==(x::StatsSpec{A1,T}, y::StatsSpec{A2,T})

Test whether two instances of [`StatsSpec`](@ref)
with the same parameter `T` also have the same field `args`.

See also [`≊`](@ref).
"""
==(x::StatsSpec{A1,T}, y::StatsSpec{A2,T}) where {A1,A2,T} =
    x.args == y.args

"""
    ≊(x::StatsSpec{A1,T}, y::StatsSpec{A2,T})

Test whether two instances of [`StatsSpec`](@ref)
with the same parameter `T` also have the field `args`
containing the same sets of key-value pairs
while ignoring the orders.
"""
≊(x::StatsSpec{A1,T}, y::StatsSpec{A2,T}) where {A1,A2,T} =
    x.args ≊ y.args

function (sp::StatsSpec{A,T})(;
        verbose::Bool=false, keep=nothing, keepall::Bool=false) where {A,T}
    args = verbose ? merge(sp.args, (verbose=true,)) : sp.args
    ntall = foldl(|>, T(), init=sp.args)
    if keepall
        return ntall
    elseif !isempty(ntall)
        res = haskey(ntall, :result) ? ntall.result : ntall[end]
        if keep === nothing
            return res
        else
            if keep isa Symbol
                keep = [keep]
            elseif eltype(keep) != Symbol
                throw(ArgumentError("expect Symbol or collections of Symbols for the value of option `keep`"))
            end
            return (result=res, (kv for kv in pairs(ntall) if kv[1] in keep)...)
        end
    else
        return nothing
    end
end

show(io::IO, ::StatsSpec{A}) where {A} = print(io, A==Symbol("") ? "unnamed" : A)

_show_args(::IO, ::StatsSpec) = nothing

function show(io::IO, ::MIME"text/plain", sp::StatsSpec{A,T}) where {A,T}
    print(io, A==Symbol("") ? "unnamed" : A, " (", typeof(sp).name.name,
        " for ", T.parameters[1], ")")
    _show_args(io, sp)
end

function run_specset(sps::AbstractVector{<:StatsSpec};
        verbose::Bool=false, keep=nothing, keepall::Bool=false)
    traces = Vector{NamedTuple}(undef, length(sps))
    fill!(traces, NamedTuple())
    tb = Table(spec=sps, trace=traces)
    gids = groupfind(r->procedure(r.spec), tb)
    steps = pool((p() for p in keys(gids))...)
    for step in steps
        verbose && println("  Running ", step)
        args = _specnames(step)
        tras = _tracenames(step)
        byf = r->merge(NamedTuple{args}(r.spec.args), NamedTuple{tras}(r.trace))
        taskids = vcat((gids[steps.procs[i]] for i in _sharedby(step))...)
        tasks = groupview(byf, view(tb, taskids))
        for (ins, subtb) in pairs(tasks)
            ret = _f(step)(ins...)
            for tr in subtb.trace
                tr = merge(tr, deepcopy(ret))
            end
        end
    end
    if keepall
        return tb
    elseif keep===nothing
        return [r[end] for r in tb.trace]
    else
        return [(;result=r.trace[end], (kv for kv in pairs(r.trace) if kv[1] in keep)...,
            (kv for kv in pairs(r.spec.args) if kv[1] in keep)...) for r in tb]
    end
end

function parse_specset_options(args)
    options = :(Dict{Symbol, Any}())
    for arg in args
        # Assume a symbol means the kwarg takes value true
        if isa(arg, Symbol)
            key = Expr(:quote, arg)
            push!(options.args, Expr(:call, :(=>), key, true))
        elseif isexpr(arg, :(=))
            key = Expr(:quote, arg.args[1])
            push!(options.args, Expr(:call, :(=>), key, arg.args[2]))
        else
            throw(ArgumentError("unexpected argument $arg to @specset"))
        end
    end
    return options
end

function spec_walker(x, parsers, formatters)
    @capture(x, StatsSpec(formatter_(parser_(rawargs__)))(;o__)) || return x
    push!(parsers, parser)
    push!(formatters, formatter)
    length(o) > 0 &&
        @warn "[options] specified for individual StatsSpec are ignored inside @specset"
    return :(push!(ntargs_set, $parser($(rawargs...))))
end

"""
    @specset [option option=val ...] default_args... begin ... end
    @specset [option option=val ...] default_args... for v in (...) ... end
    @specset [option option=val ...] default_args... for v in (...), w in (...) ... end

Collect multiple [`StatsSpec`](@ref) and exucte the procedure,
possibly avoiding repeating identical steps from different specifications.

The specifications must be contained in either a `begin/end` block or a `for` loop.
`@specset` collects arguments passed to each call of [`StatsSpec`](@ref)
in such a code block and infers how the arguments need to be processed
for constructing a valid [`StatsSpec`](@ref) based on the names of functions
called within [`StatsSpec`](@ref).
Any function that wraps the call of [`StatsSpec`](@ref) is ignored.

Optional default arguments are accepted and need to be specified before the code block.
They are merged with the arguments provided for each individual specification
and replace the default values specified for each procedure.
These default arguments should be specified in the same pattern as
how arguments are specified for each specification inside the code block.

Options for the behavior of `@specset` can be provided in a bracket `[...]`
as the first argument with each option separated by white space.
For options that take a Boolean value,
specifying the name of the option is enough for setting the value to be true.
By default, `@specset` returns a `Vector`
that contains one object for each specification provided in the original order.
This object is either the one with a key `result` assigned by a [`StatsStep`](@ref)
or the last value returned by the last [`StatsStep`](@ref).

The following options are available for altering the behavior of `@specset`:

- `verbose::Bool=false`: print the name of each step when it is called.
- `keep=nothing`: names (of type `Symbol`) of additional objects to be returned.
- `keepall::Bool=false`: return all objects returned by each step.

When `keep` is specified, the returned object is a `Vector{NamedTuple}`
where the objects with keys specified in `keep` are combined with the default returned object
to form a `NamedTuple` for each specification.
When `keepall` is specified, a `TypedTables.Table` is returned
with the first column named `spec` being the collection of all [`StatsSpec`](@ref) constructed
and the second column named `trace` being a `Vector{NamedTuple}`
collecting objects returned by the steps in each procedure.
"""
macro specset(args...)
    nargs = length(args)
    nargs == 0 && throw(ArgumentError("no argument is found for @specset"))

    if nargs > 1
        if isexpr(args[1], :vect, :hcat, :vcat)
            options = parse_specset_options(args[1].args)
            nargs > 2 && (default_args = args[2:end-1])
        else
            default_args = args[1:end-1]
        end
    else
        options = :((;))
        default_args = nothing
    end

    specs = args[end]
    isexpr(specs, :block, :for) ||
        throw(ArgumentError("last argument to @specset must be begin/end block or for loop"))

    parsers = []
    formatters = []
    blk = postwalk(x->spec_walker(x, parsers, formatters), specs)
    length(parsers)==1 && length(formatters)==1 ||
        throw(ArgumentError("exactly one parser and one formatter are allowed for the inner @specset"))
    
    parser = parsers[1]
    formatter = formatters[1]
    defaults = default_args === nothing ? :((;)) : :($parser($(default_args...)))
    
    return quote
        local default_args = $defaults
        local ntargs_set = NamedTuple[]
        $blk
        local nsps = length(ntargs_set)
        local sps_set = [StatsSpec($formatter(merge(default_args, ntargs_set[i])))
            for i in 1:nsps]
        run_specset(sps_set; $(options...))
    end
end
