"""
    @fieldequal Supertype

Define a method of `==` for all subtypes of `Supertype`
such that `==` returns true if two instances have the same field values.
"""
macro fieldequal(Supertype)
    return esc(quote
        function ==(a::T, b::T) where T <: $Supertype
            f = fieldnames(T)
            getfield.(Ref(a),f) == getfield.(Ref(b),f)
        end
    end)
end

"""
    eachterm(t)

Return an iterable collection of terms in `t`.
"""
eachterm(@nospecialize(t::AbstractTerm)) = (t,)
eachterm(@nospecialize(t::NTuple{N, AbstractTerm})) where {N} = t

"""
    c(args...)

Construct a vector from `ConstantTerm`s provided as arguments.
This method is useful for working with `@formula`.
"""
c(args...) = [arg isa ConstantTerm ? arg.n :
    throw(ArgumentError("only `ConstantTerm`s are accepted.")) for arg in args]

"""
    unpack(t::ConstantTerm)

Return the value represented by `t`.
"""
unpack(t::ConstantTerm) = t.n

"""
    unpack(t::Term)

Call the method of function named `t.sym` with no argument if it exists in `Main`;
return `t.sym` otherwise.

This method allows specifying functions with no argument in `@formula`.
"""
function unpack(t::Term)
    if isdefined(Main, t.sym)
        f = getfield(Main,  t.sym)
        hasmethod(f, Tuple{}) ? f() : t
    else
        return t.sym
    end
end

"""
    unpack(t::FunctionTerm{F})

Call the function represented by `t`.
"""
unpack(t::FunctionTerm{F}) where F = F.instance(t.args_parsed...)

"""
    kwarg(v)

Return a key-value `Pair` with the key being a keyword argument name
and the value being `v`.
The key is determined by the type of `v`.
"""
kwarg(::Any) = nothing

"""
    @unpack functionname

Define a method of `functionname` that accepts terms generated by `@formula`
as arguments.
This method can be used to translate terms into
arguments that match the other methods of `functionname`.
Each term is processed by [`unpack`](@ref) and [`kwarg`](@ref).
"""
macro unpack(functionname)
    return esc(quote
        function $functionname(ts::AbstractTerm...)
            args, kwargs = [], []
            for t in ts
                v = unpack(t)
                kv = kwarg(v)
                kv isa Nothing ? push!(args, v) : push!(kwargs, kv)
            end
            return $functionname(args...; kwargs...)
        end
    end)
end

"""
    exampledata()

Return the names of available example datasets.
"""
exampledata() =
    [name[1:end-4] for name in readdir((@__DIR__)*"/../data")
        if length(name)>4 && name[end-3:end]==".csv"]

"""
    exampledata(name::Union{Symbol,String})

Return a `CSV.File` by loading the example dataset with the specified name.
"""
function exampledata(name::Union{Symbol,String})
    "$(name)" in exampledata() ||
        throw(ArgumentError("example dataset $(name) is not found"))
    return CSV.File((@__DIR__)*"/../data/$(name).csv")
end
