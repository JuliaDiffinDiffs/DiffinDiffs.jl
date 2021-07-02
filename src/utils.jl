# A vector of fixed effects paired with a vector of interactions (empty if not interacted)
const FETerm = Pair{Vector{Symbol},Vector{Symbol}}

# Parse fixed effects from a generic term
function _parsefeterm(@nospecialize(t::AbstractTerm))
    if has_fe(t)
        s = fesymbol(t)
        return [s]=>Symbol[]
    end
end

# Parse fixed effects from an InteractionTerm
function _parsefeterm(@nospecialize(t::InteractionTerm))
    fes = (x for x in t.terms if has_fe(x))
    interactions = (x for x in t.terms if !has_fe(x))
    if !isempty(fes)
        fes = sort!([fesymbol(x) for x in fes])
        feints = sort!([Symbol(x) for x in interactions])
        return fes=>feints
    end
end

getfename(feterm::FETerm) = join(vcat("fe_".*string.(feterm[1]), feterm[2]), "&")

# Count the number of singletons dropped
function drop_singletons!(esample, fe::FixedEffect)
    cache = zeros(Int, fe.n)
    n = 0
    @inbounds for i in eachindex(esample)
        if esample[i]
            cache[fe.refs[i]] += 1
        end
    end
    @inbounds for i in eachindex(esample)
        if esample[i] && cache[fe.refs[i]] <= 1
            esample[i] = false
            n += 1
        end
    end
    return n
end

function Fstat(coef::Vector{Float64}, vcov_mat::AbstractMatrix{Float64}, has_intercept::Bool)
    length(coef) == has_intercept && return NaN
    if has_intercept
        coef = coef[1:end-1]
        vcov_mat = vcov_mat[1:end-1, 1:end-1]
    end
    return (coef' * (vcov_mat \ coef)) / length(coef)
end
