"""
    StatsStep{F<:Function,SpecNames,TraceNames}

Specify the function and arguments for moving a step
in an [`AbstractStatsProcedure`](@ref).
An instance of `StatsStep` is callable.

# Parameters
- `F<:Function`: type of the function to be called by `StatsStep`.
- `SpecNames::NTuple{N,Symbol}`: keys for arguments from [`StatsSpec`](@ref).
- `TraceNames::NTuple{N,Symbol}`: keys for arguments from objects returned by a previous `StatsStep`.

# Methods
    (step::StatsStep{F,S,T})(ntargs::NamedTuple; verbose::Bool=false) where {F,S,T}

Call an instance of function of type `F` with arguments from `ntargs`
formed by accessing the keys in `S` and `T` sequentially.

If a keyword argument `verbose` takes `true`
or `ntargs` contains a key-value pair `verbose=true`,
a message with the name of the `StatsStep` is printed to `stdout`.

## Returns
- `NamedTuple`: named intermidiate results.
"""
struct StatsStep{F<:Function,SpecNames,TraceNames} end

_f(step::StatsStep{F}) where {F} = F.instance
_specnames(step::StatsStep{F,S}) where {F,S} = S
_tracenames(step::StatsStep{F,S,T}) where {F,S,T} = T

function (step::StatsStep{F,S,T})(ntargs::NamedTuple; verbose::Bool=false) where {F,S,T}
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

macro show_StatsStep(step, name)
    return esc(quote
        function Base.show(io::IO, s::$step)
            if get(io, :compact, false)
                print(io, $name)
            else
                println(io, "StatsStep: ", $name)
                println(io, "  arguments from StatsSpec: ", $step.parameters[2])
                print(io, "  arguments from trace: ")
                $step.parameters[3] == () ? print(io, "()") : print(io, $step.parameters[3])
            end
        end
    end)
end

"""
    AbstractStatsProcedure{T<:NTuple{N,StatsStep} where N}

Supertype for all types specifying the procedure for statistical estimation or inference.

The procedure is determined by the parameter `T`,
which is a tuple of [`StatsStep`](@ref).
Fallback methods for indexing and iteration are defined for
all subtypes of `AbstractStatsProcedure`.
"""
abstract type AbstractStatsProcedure{T<:NTuple{N,StatsStep} where N} end

length(p::AbstractStatsProcedure{T}) where T = length(T.parameters)
eltype(::Type{<:AbstractStatsProcedure}) = StatsStep
firstindex(p::AbstractStatsProcedure{T}) where T = firstindex(T.parameters)
lastindex(p::AbstractStatsProcedure{T}) where T = lastindex(T.parameters)

function getindex(p::AbstractStatsProcedure{T}, i) where T
    fs = T.parameters[i]
    return fs isa Type && fs <: StatsStep ? fs.instance : [f.instance for f in fs]
end

getindex(p::AbstractStatsProcedure{T}, i::Int) where T = T.parameters[i].instance

iterate(p::AbstractStatsProcedure, state=1) =
    state > length(p) ? nothing : (p[state], state+1)

"""
    SharedStatsStep{T<:StatsStep,PID}

A [`StatsStep`](@ref) that is possibly shared by
multiple instances of procedures that are subtypes of [`AbstractStatsProcedure`](@ref).
See also [`PooledStatsProcedure`](@ref).

# Parameters
- `T<:StatsStep`: type of the only field `step`.
- `PID`: indices of the procedures that share this step.
"""
struct SharedStatsStep{T<:StatsStep,PID}
    step::T
end

#show(io::IO, step::SharedStatsStep) = show(io, step.step)

function show(io::IO, step::SharedStatsStep{T,PID}) where {T,PID}
    if get(io, :compact, false)
        show(io, step.step)
    else
        print(io, "Shared")
        show(io, step.step)
        print(io, "\n  shared by ", length(PID), " procedures")
    end
end

==(x::SharedStatsStep{T,PID1}, y::SharedStatsStep{T,PID2}) where {T,PID1,PID2} =
    x.step == y.step && Set(PID1) == Set(PID2)

_share(s::T, pid) where {T<:StatsStep} = SharedStatsStep{T,(Int.(pid)...,)}(s)
_sharedby(s::SharedStatsStep{T,PID}) where {T,PID} = PID
_f(s::SharedStatsStep) = _f(s.step)
_specnames(s::SharedStatsStep) = _specnames(s.step)
_tracenames(s::SharedStatsStep) = _tracenames(s.step)

const SharedStatsSteps = NTuple{N, Vector{SharedStatsStep}} where N
const StatsProcedures = NTuple{N, AbstractStatsProcedure} where N

"""
    PooledStatsProcedure{P<:StatsProcedures,S<:SharedStatsSteps,N}

A collection of procedures and shared steps.

An instance of `PooledStatsProcedure` is iterable among the shared steps
in a way that helps avoid repeating identical steps.
See also [`pool`](@ref).

# Fields
- `procs::P`: a tuple of instances of subtypes of [`AbstractStatsProcedure`](@ref).
- `steps::S`: a tuple of vectors [`SharedStatsStep`](@ref) for each procedure in `procs`.
"""
struct PooledStatsProcedure{P<:StatsProcedures,S<:SharedStatsSteps,N}
    procs::P
    steps::S
end

==(x::PooledStatsProcedure{P,S,N}, y::PooledStatsProcedure{P,S,N}) where {P,S,N} =
    x.procs == y.procs && x.steps == y.steps

"""
    pool(ps::AbstractStatsProcedure...)

Construct a [`PooledStatsProcedure`](@ref) by determining
how each [`StatsStep`](@ref) is shared among several procedures in `ps`.

It might not be safe to share the same [`StatsStep`](@ref) in different procedures
due to the relative position of this step to the other common steps
among these procedures.
The fallback method implemented for a collection of [`AbstractStatsProcedure`](@ref)
avoids sharing steps of which the relative positions
are not compatible between a pair of procedures.
"""
function pool(ps::AbstractStatsProcedure...)
    ps = (ps...,)
    nps = length(ps)
    shared = ((Vector{SharedStatsStep}(undef, length(p)) for p in ps)...,)
    for (pid, p) in enumerate(ps)
        shared[pid] .= _share.(collect(p), pid)
    end
    steps = union(collect(p) for p in ps)
    N = sum(length.(ps))
    if length(steps) < N
        step_loc = Dict{StatsStep,Dict{Int64,Int64}}()
        for (i, p) in enumerate(ps)
            for n in 1:length(p)
                if haskey(step_loc, p[n])
                    step_loc[p[n]][i] = n
                else
                    step_loc[p[n]] = Dict(i=>n)
                end
            end
        end
        for (step, loc) in step_loc
            if length(loc) == 1
                continue
            else
                shared_pid = collect(keys(loc))
                for c in combinations(shared_pid, 2)
                    csteps = intersect(ps[c[1]], ps[c[2]])
                    rank1 = findfirst(x->x==step, sort!([step_loc[s][c[1]] for s in csteps]))
                    rank2 = findfirst(x->x==step, sort!([step_loc[s][c[2]] for s in csteps]))
                    if rank1 != rank2
                        setdiff(shared_pid, c)
                        length(shared_pid) <= 1 && break
                    end
                end
                if length(shared_pid) >= 2
                    N = N - length(shared_pid) + 1
                    for s in shared_pid
                        shared[s][loc[s]] = _share(step, shared_pid)
                    end
                end
            end
        end
    end
    return PooledStatsProcedure{typeof(ps), typeof(shared), N}(ps, shared)
end

length(ps::PooledStatsProcedure{P,S,N}) where {P,S,N} = N
eltype(::Type{<:PooledStatsProcedure}) = SharedStatsStep

function iterate(ps::PooledStatsProcedure, state=deepcopy(ps.steps))
    state = state[BitArray(length.(state).>0)]
    length(state) > 0 || return nothing
    firsts = first.(state)
    for i in length(firsts)
        nshared = length(_sharedby(firsts[i]))
        if nshared == 1
            deleteat!(state[i],1)
            return (firsts[i], state)
        else
            shared = firsts.==firsts[i]
            if sum(shared) == nshared
                for p in state[BitArray(shared)]
                    deleteat!(p, 1)
                end
                return (firsts[i], state)
            end
        end
    end
    error("bad construction of $(typeof(ps))")
end

"""
    StatsSpec{T<:AbstractStatsProcedure}

Record the specification for a statistical procedure of type `T`.
An instance of `StatsSpec` is callable and
its fields provide all information necessary for conducting the procedure.

# Fields
- `name::String`: an optional name for the specification.
- `args::NamedTuple`: arguments for the [`StatsStep`](@ref) in `T`.

# Methods
    (sp::StatsSpec{T})(; verbose::Bool=false, keep=nothing, keepall::Bool=false)

Execute the procedure of type `T` with the arguments specified in `args`.
By default, only an object with a key `result` assigned by a [`StatsStep`](@ref)
or the last value returned by the last [`StatsStep`](@ref) is returned.

## Keywords
- `verbose::Bool=false`: print the name of each step when it is called.
- `keep=nothing`: names (of type `Symbol`) of additional objects to be returned.
- `keepall::Bool=false`: return all objects returned by each step.
"""
struct StatsSpec{T<:AbstractStatsProcedure}
    name::String
    args::NamedTuple
end

StatsSpec(T::Type{<:AbstractStatsProcedure}, name::String, args::NamedTuple) =
    StatsSpec{T}(name, args)

"""
    ==(x::StatsSpec{T}, y::StatsSpec{T})

Test whether two instances of [`StatsSpec`](@ref)
with the same parameter `T` also have the same field `args`.

See also [`≊`](@ref).
"""
==(x::StatsSpec{T}, y::StatsSpec{T}) where T =
    x.args == y.args

"""
    ≊(x::StatsSpec{T}, y::StatsSpec{T})

Test whether two instances of [`StatsSpec`](@ref)
with the same parameter `T` also have the field `args`
containing the same sets of key-value pairs
while ignoring the orders.
"""
≊(x::StatsSpec{T}, y::StatsSpec{T}) where T =
    x.args ≊ y.args

_isnamed(sp::StatsSpec) = sp.name != ""
_procedure(sp::StatsSpec{T}) where T = T

function (sp::StatsSpec{T})(; verbose::Bool=false, keep=nothing, keepall::Bool=false) where T
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
    @capture(x, StatsSpec(formatter_(parser_(rawargs__))))(;o__) || return x
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
