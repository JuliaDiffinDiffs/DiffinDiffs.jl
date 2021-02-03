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
