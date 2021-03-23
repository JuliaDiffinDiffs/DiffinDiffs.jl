function parse_fixedeffect!(data, ts::TermSet)
    fes = FixedEffect[]
    ids = Symbol[]
    has_fe_intercept = false
    for term in ts
        result = _parse_fixedeffect(data, term)
        if result !== nothing
            push!(fes, result[1])
            push!(ids, result[2])
            delete!(ts, term)
        end
    end
    order = sortperm(ids)
    fes .= fes[order]
    ids .= ids[order]
    if !isempty(fes)
        if any(fe->fe.interaction isa UnitWeights, fes)
            has_fe_intercept = true
            for t in ts
                t isa Union{ConstantTerm,InterceptTerm} && delete!(ts, t)
            end
            push!(ts, InterceptTerm{false}())
        end
    end
    return fes, ids, has_fe_intercept
end

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
