@testset "RotatingTimeValue" begin
    rt0 = RotatingTimeValue(1, Date(1))
    rt1 = RotatingTimeValue(1.0, Date(1))
    @test RotatingTimeValue(typeof(rt0), 1.0, Date(1)) === rt0

    @test rotatingtime(1.0, Date(1)) == rt1
    rot = repeat(5:-1:1, inner=5)
    time = repeat(1:5, outer=5)
    rt = rotatingtime(rot, time)
    @test eltype(rt) == RotatingTimeValue{Int, Int}
    @test getfield.(rt, :rotation) == rot
    @test getfield.(rt, :time) == time

    rtd = rotatingtime(1, Date(1))
    rt1 = rotatingtime(1, 1)
    @test rtd + Year(1) == Year(1) + rtd == rotatingtime(1, Date(2))
    @test rtd - Year(1) == rotatingtime(1, Date(0))
    @test 1 - rt1 == rotatingtime(1, 0)
    @test_throws MethodError Year(3) - rtd
    @test 2 * rt1 == rt1 * 2 == rotatingtime(1, 2)

    @test rt[1] - rt[2] == -1
    @test_throws ArgumentError rt[1] - rt[6]

    @test isless(rt[1], rt[2])
    @test isless(rt[6], rt[1])
    @test isless(rt[1], rt[7])
    @test isless(rt[1], 2.0)
    @test isless(1, rt[2])

    @test rt[1] == RotatingTimeValue(Int32(5), Int32(1))
    @test rt[1] == 1
    @test 1 == rt[1]

    @test zero(typeof(rt[1])) === RotatingTimeValue(0, 0)
    @test iszero(RotatingTimeValue(1, 0))
    @test !iszero(RotatingTimeValue(0, 1))

    @test convert(typeof(rt[1]), RotatingTimeValue(Int32(5), Int32(1))) ===
        RotatingTimeValue(5, 1)

    @test checkindex(Bool, 1:5, rt1)
    @test checkindex(Bool, 2:5, rt1) == false
    X = 1:5
    @test X[rt1] == 1
    rts = rotatingtime(1, 2:3)
    @test X[rts] == 2:3
    @test_throws BoundsError (1:2)[rts]

    @test iterate(rt1) == (rt1, nothing)
    @test iterate(rt1, 1) === nothing
    @test length(rt1) == 1

    @test sprint(show, rt[1]) == "5_1"
    w = VERSION < v"1.6.0" ? "" : " "
    @test sprint(show, MIME("text/plain"), rt[1]) == """
        RotatingTimeValue{Int64,$(w)Int64}:
          rotation: 5
          time:     1"""
end

@testset "RotatingTimeRange" begin
    rt1 = RotatingTimeValue(1, Date(1))
    rt5 = RotatingTimeValue(2, Date(5))
    rt1_1 = RotatingTimeValue(1, Date(5))
    r = rt1:Year(1):rt5
    @test r.value === rt1
    @test r.range == Date(1):Year(1):Date(5)
    @test first(r) === rt1
    @test step(r) == Year(1)
    @test last(r) === rt1_1
    @test length(r) == 5

    @test r[1] === rt1
    @test r[end] === rt1_1

    i1 = RotatingTimeValue(1, 1)
    i5 = RotatingTimeValue(2, 5)
    @test r[i1] === rt1
    @test r[i5] === rt5
end
