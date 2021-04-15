using DiffinDiffsBase: RefArray, validstartstepstop, _scaledlabel

@testset "ScaledArray" begin
    refs = repeat(1:5, outer=2)
    pool = Date(1):Year(1):Date(5)
    sa = ScaledArray(RefArray(refs), Date(1), Year(1), Date(5))
    @test sa == ScaledArray(RefArray(refs), Date(1), Year(1), Date(5), pool)
    @test sa.refs == refs
    @test sa.start == Date(1)
    @test sa.step == Year(1)
    @test sa.stop == Date(5)
    @test sa.pool == pool
    @test sa == sa

    x = 1:10
    @test validstartstepstop(x, 10, -1, nothing, true) == (10, 1)
    @test_throws ArgumentError validstartstepstop(x, 1, -1, 10, true)
    p = PooledArray(x)
    p[1] = 2
    p[10] = 9
    @test validstartstepstop(p, nothing, 1, nothing, true) == (1, 10)
    @test_throws ArgumentError validstartstepstop(p, 2, 1, 9, true)
    @test validstartstepstop(p, 2, 1, nothing, false) == (2, 9)
    @test_throws ArgumentError validstartstepstop(p, 2, 1, 8, false)
    s = ScaledArray(1.0:2.0:9.0, 1.0, 2, 10)
    ss = validstartstepstop(s, 1, 2, 9, true)
    @test ss == (1.0, 9.0)
    @test typeof(ss) == Tuple{Float64, Float64}
    @test_throws ArgumentError validstartstepstop(1:5, 1, nothing, 1, true)
    @test_throws ArgumentError validstartstepstop(1:5, 1, Year(1), 1, true)
    @test_throws ArgumentError validstartstepstop(1:5, 1, 0, 1, true)

    sa1 = ScaledArray(p, 2, usepool=false)
    @test sa1.refs == [1, repeat(1:4, inner=2)..., 4]
    @test sa1.start == 2
    @test sa1.step == 2
    @test sa1.stop == 9
    @test sa1 != sa

    sa2 = ScaledArray(sa1, 2, 1, 10)
    @test sa2.refs == [1, repeat(1:2:7, inner=2)..., 7]
    @test sa2.start == 2
    @test sa2.step == 1
    @test sa2.stop == 10
    @test sa2 == sa1

    sa3 = ScaledArray(sa2, reftype=Int16, start=0, stop=8, usepool=false)
    @test sa3.refs == [3, repeat(3:2:9, inner=2)..., 9]
    @test eltype(sa3.refs) == Int16
    @test sa3.start == 0
    @test sa3.step == 1
    @test sa3.stop == 8
    @test sa3 == sa2

    sa4 = ScaledArray(sa3, start=2, stop=8, usepool=false)
    @test sa4.refs == [1, repeat(1:2:7, inner=2)..., 7]
    @test sa4.start == 2
    @test sa4.stop == 8
    @test sa4 == sa3

    sa5 = ScaledArray(sa4, usepool=false)
    @test sa5.refs == sa4.refs
    @test sa5.refs !== sa4.refs

    @test_throws ArgumentError ScaledArray(sa5, stop=7, usepool=false)

    @test size(sa) == (10,)
    @test IndexStyle(typeof(sa)) == IndexLinear()

    @test refarray(sa) === sa.refs
    @test refvalue(sa, 1) == Date(1)
    @test refpool(sa) === sa.pool

    ssa = view(sa, 3:4)
    @test refarray(ssa) == view(sa.refs, 3:4)
    @test refvalue(ssa, 1) == Date(1)
    @test refpool(ssa) === sa.pool

    @test sa[1] == Date(1)
    @test sa[1:2] == sa[[1,2]] == sa[(1:10).<3] == Date.(1:2)
end

@testset "_scaledlabel" begin
    x = Date.(10:-2:0)
    refs, start, step, stop = _scaledlabel(x, Year(1), start=Date(-1), stop=Date(11))
    @test refs == 12:-2:2
    @test eltype(refs) == Int32
    @test start == Date(-1)
    @test step == Year(1)
    @test stop == Date(11)

    refs, start, step, stop = _scaledlabel(x, Year(2), Int16)
    @test refs == 6:-1:1
    @test eltype(refs) == Int16
    @test start == Date(0)
    @test step == Year(2)
    @test stop == Date(10)

    x = ScaledArray(RefArray(refs), start, step, stop)
    refs1, start1, step1, stop1 = _scaledlabel(x, Year(2))
    @test refs1 == refs && refs1 !== refs
    @test eltype(refs1) == Int32
    @test start1 == start
    @test step1 == step
    @test stop1 == stop

    refs1, start1, step1, stop1 = _scaledlabel(x, Year(2), Int16)
    @test refs1 == 6:-1:1
    @test eltype(refs1) == Int16

    refs1, start1, step1, stop1 = _scaledlabel(x, Year(1), start=Date(-1), stop=Date(11))
    @test refs1 == 12:-2:2
    @test start1 == Date(-1)
    @test step1 == Year(1)

    refs, start, step, stop = _scaledlabel(1.0:200.0, 1, Int8)
    @test refs == 1:200
    @test eltype(refs) == Int16
    @test typeof(start) == Float64
    @test typeof(step) == Int

    refs, start, step, stop = _scaledlabel(1:typemax(Int16), 1, Int8)
    @test refs == 1:typemax(Int16)
    @test eltype(refs) == Int16
end
