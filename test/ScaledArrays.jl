using DiffinDiffsBase: RefArray, validpool, scaledlabel

@testset "ScaledArray" begin
    refs = repeat(1:5, outer=2)
    pool = Date(1):Year(1):Date(5)
    invpool = Dict(p=>i for (i, p) in enumerate(pool))
    sa = ScaledArray(RefArray(refs), pool, invpool)
    ssa = view(sa, 3:5)
    @test sa.refs === refs

    @test scale(sa) == Year(1)
    @test scale(ssa) == Year(1)
    @test size(sa) == (10,)
    @test IndexStyle(typeof(sa)) == IndexLinear()

    x = 1:10
    @test validpool(x, Int, 10, -1, nothing, true) == 10:-1:1
    @test_throws ArgumentError validpool(x, Int, 1, -1, 10, true)
    p = PooledArray(x)
    p[1] = 2
    p[10] = 9
    @test validpool(p, Int, nothing, 1, nothing, true) == 1:10
    @test_throws ArgumentError validpool(p, Int, 2, 1, 9, true)
    @test validpool(p, Int, 2, 1, nothing, false) == 2:9
    @test_throws ArgumentError validpool(p, Int, 2, 1, 8, false)
    s = ScaledArray(1.0:2.0:9.0, 1.0, 2, 10)
    ss = validpool(s, Float64, 1, 2, 9, true)
    @test ss == 1.0:2.0:9.0
    @test eltype(ss) == Float64
    @test_throws ArgumentError validpool(1:5, Int, 1, nothing, 1, true)
    @test_throws ArgumentError validpool(1:5, Int, 1, Year(1), 1, true)
    @test_throws ArgumentError validpool(1:5, Int, 1, 0, 1, true)

    sa1 = ScaledArray(p, 2, usepool=false)
    @test sa1.refs == [1, repeat(1:4, inner=2)..., 4]
    @test sa1.pool == 2:2:9
    @test sa1 != sa

    sa2 = ScaledArray(sa1, 2, 1, 10)
    @test sa2.refs == [1, repeat(1:2:7, inner=2)..., 7]
    @test sa2.pool == 2:10
    @test sa2 == sa1

    sa3 = ScaledArray(sa2, reftype=Int16, start=0, stop=8, usepool=false)
    @test sa3.refs == [3, repeat(3:2:9, inner=2)..., 9]
    @test eltype(sa3.refs) == Int16
    @test sa3.pool == 0:8
    @test sa3 == sa2

    sa4 = ScaledArray(sa3, start=2, stop=8, usepool=false)
    @test sa4.refs == [1, repeat(1:2:7, inner=2)..., 7]
    @test sa4.pool == 2:8
    @test sa4 == sa3

    sa5 = ScaledArray(sa4, usepool=false)
    @test sa5.refs == sa4.refs
    @test sa5.refs !== sa4.refs

    sa6 = ScaledArray([missing, 1, 2], 1)
    @test eltype(sa6) == Union{Int,Missing}
    @test sa6.refs == 0:2
    @test eltype(sa6.refs) == Int32
    @test ismissing(sa6[1])

    @test_throws ArgumentError ScaledArray(sa5, stop=7, usepool=false)
    @test_throws ArgumentError ScaledArray(RefArray(1:3), 1.0:0.5:3.0, Dict{Int,Int}())

    @test similar(sa, 4) == ScaledArray(RefArray(ones(Int, 4)), sa.pool, Dict{Date,Int}())
    @test similar(sa, (4,)) == similar(view(sa, 1:5), 4) == similar(sa, 4)

    xs = Date(5):Year(-1):Date(1)
    sa1 = align(xs, sa)
    @test sa1.pool == pool
    xs = Date(0):Year(1):Date(4)
    @test_throws ArgumentError align(xs, sa)
    sa1 = ScaledArray(sa, Year(-1))
    xs = Date(2):Year(1):Date(6)
    @test_throws ArgumentError align(xs, sa1)

    @test refarray(sa) === sa.refs
    @test refvalue(sa, 1) == Date(1)
    @test refpool(sa) === sa.pool
    @test invrefpool(sa) === sa.invpool

    @test refarray(ssa) == view(sa.refs, 3:5)
    @test refvalue(ssa, 1) == Date(1)
    @test refpool(ssa) === sa.pool
    @test invrefpool(ssa) === sa.invpool
    @test ssa == sa[3:5]

    @test sa[1] == Date(1)
    @test sa[1:2] == sa[[1,2]] == sa[(1:10).<3] == Date.(1:2)
    @test sa[1:2] isa ScaledArray
    @test ssa[1:2] isa ScaledArray

    sa[1] = Date(10)
    @test sa[1] == Date(10)
    sa[1:2] .= Date(100)
    @test sa[1:2] == [Date(100), Date(100)]
    @test last(sa.pool) == Date(100)
    @test_throws MethodError sa[1] = missing
    sa = allowmissing(sa)
    sa[1] = missing
    @test ismissing(sa[1])
    @test_throws ArgumentError disallowmissing(sa)
    sa[1] = Date(1)
    sa = disallowmissing(sa)
    @test eltype(sa) == Date
end

@testset "scaledlabel" begin
    x = Date.(10:-2:0)
    pl = Date(-1):Year(1):Date(11)
    refs, pool, invpool = scaledlabel(x, Year(1), start=Date(-1), stop=Date(11))
    @test refs == 12:-2:2
    @test eltype(refs) == Int32
    @test pool == pl

    pl = Date(0):Year(2):Date(10)
    ip = Dict(p=>i for (i, p) in enumerate(pl))
    refs, pool, invpool = scaledlabel(x, Year(2), Int16)
    @test refs == 6:-1:1
    @test eltype(refs) == Int16
    @test pool == pl
    @test invpool == ip
    @test valtype(invpool) == Int16

    x = ScaledArray(RefArray(refs), Date(0):Year(2):Date(10), invpool)
    refs1, pool1, invpool1 = scaledlabel(x, Year(2))
    @test refs1 == x.refs && refs1 !== x.refs
    @test eltype(refs1) == Int32
    @test pool1 == x.pool
    @test invpool1 == x.invpool && invpool1 !== x.invpool

    refs1, pool1, invpool1 = scaledlabel(x, Year(2), Int16)
    @test refs1 == 6:-1:1
    @test eltype(refs1) == Int16
    @test pool1 == pl
    @test invpool1 == ip
    @test valtype(invpool1) == Int16

    refs1, pool1, invpool1 = scaledlabel(x, Year(1), start=Date(-1), stop=Date(11))
    @test refs1 == 12:-2:2
    @test pool1 == Date(-1):Year(1):Date(11)

    refs, pool, invpool = scaledlabel(1.0:200.0, 1, Int8, Int)
    @test refs == 1:200
    @test eltype(refs) == Int16
    @test pool == 1:200
    @test eltype(pool) == Int
    @test invpool == Dict(i=>Int(i) for i in 1.0:200.0)

    refs, pool, invpool = scaledlabel(1:typemax(Int16), 1, Int8)
    @test refs == 1:typemax(Int16)
    @test eltype(refs) == Int16
    @test valtype(invpool) == Int16

    refs, pool, invpool = scaledlabel([missing, 1, 2], 1)
    @test refs == 0:2
    @test eltype(refs) == Int32
end
